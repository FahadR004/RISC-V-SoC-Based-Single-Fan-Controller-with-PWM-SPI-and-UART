#!/usr/bin/env python3
"""
run_riscv_tests.py - Batch-run the rv32ui-p-* riscv-tests against rv32_scdp
using QuestaSim, and report a pass/fail summary.

What it does:
    1. Auto-discovers every .sv file under --design-dir (excluding anything
       matching --exclude), compiles them into a QuestaSim work library.
    2. For every rv32ui-p-* ELF binary in --tests-dir, extracts both code (.text.init)
       and data (.data + .bss) sections into $readmemh-compatible hex files.
    3. Runs QuestaSim in batch mode against both hex files via +INSTR_HEX=...
       and +DATA_HEX=... plusargs, captures [PASS]/[FAIL]/[TIMEOUT] output, and tallies results.
    4. Prints a summary table at the end, with failing tests called out.

Requirements:
    pip install pyelftools
    QuestaSim's bin folder (containing vsim.exe/vlib.exe/vlog.exe) on PATH,
    or pass --vsim/--vlib/--vlog pointing at the executables directly.

Usage:
    python run_riscv_tests.py --tests-dir . --design-dir .

Run with -h for all options.
"""
import argparse
import shutil
import struct
import subprocess
import sys
from pathlib import Path

try:
    from elftools.elf.elffile import ELFFile
except ImportError:
    print("ERROR: pyelftools is required. Install with: pip install pyelftools")
    sys.exit(1)


def discover_design_files(design_dir: Path, exclude_substrings: list[str]) -> list[Path]:
    """Find every .sv file under design_dir, skipping anything whose relative
    path contains one of exclude_substrings (case-insensitive)."""
    all_files = sorted(design_dir.rglob("*.sv"))
    kept = []
    for f in all_files:
        rel = str(f.relative_to(design_dir)).lower()
        if any(ex.lower() in rel for ex in exclude_substrings):
            continue
        kept.append(f)
    return kept


def extract_section(elf: ELFFile, name: str) -> tuple[bytes | None, int | None]:
    """Helper to extract raw bytes and base address for an ELF section."""
    section = elf.get_section_by_name(name)
    if section is None:
        return None, None
    return section.data(), section['sh_addr']


def write_hex_file(data: bytes, path: Path) -> int:
    """Write bytes as 32-bit hex words suitable for $readmemh.
    Pads to 4-byte boundaries if needed. Returns word count."""
    if len(data) % 4 != 0:
        data += b"\x00" * (4 - (len(data) % 4))

    with open(path, "w") as out:
        for i in range(0, len(data), 4):
            word = struct.unpack_from("<I", data, i)[0]
            out.write(f"{word:08x}\n")

    return len(data) // 4


def elf_to_split_hex(elf_path: Path, instr_hex_path: Path, data_hex_path: Path) -> tuple[int, int]:
    """Extract .text.init for instr_memory, and .data + .bss for data_memory.
    Returns tuple of (instr_words, data_words)."""
    with open(elf_path, "rb") as f:
        elf = ELFFile(f)

        # 1. Instruction Memory (.text.init)
        text_bytes, _ = extract_section(elf, ".text.init")
        if text_bytes is None:
            raise ValueError(f"{elf_path.name}: no .text.init section found")
        instr_words = write_hex_file(text_bytes, instr_hex_path)

        # 2. Data Memory (.data + .bss)
        data_bytes, data_base = extract_section(elf, ".data")
        if data_bytes is None:
            data_bytes = b""
            data_base = 0

        bss_section = elf.get_section_by_name(".bss")
        if bss_section is not None and bss_section["sh_size"] > 0:
            bss_size = bss_section["sh_size"]
            bss_base = bss_section["sh_addr"]
            
            # Pad gap between .data and .bss if they are non-contiguous
            expected_bss_offset = bss_base - data_base
            if data_bytes and expected_bss_offset > len(data_bytes):
                data_bytes += b"\x00" * (expected_bss_offset - len(data_bytes))
            
            data_bytes += b"\x00" * bss_size

        data_words = write_hex_file(data_bytes, data_hex_path)

    return instr_words, data_words


def find_test_binaries(tests_dir: Path) -> list[Path]:
    """Return every rv32ui-p-* file with no extension (i.e. the ELF itself,
    not the accompanying .dump), sorted for stable output ordering."""
    candidates = sorted(tests_dir.glob("rv32ui-p-*"))
    return [p for p in candidates if p.is_file() and p.suffix == ""]


def compile_design(sim_dir: Path, design_dir: Path, exclude_substrings: list[str],
                   vlib: str, vlog: str) -> None:
    print("=== Discovering design files ===")
    file_paths = discover_design_files(design_dir, exclude_substrings)
    for f in file_paths:
        print(f"  {f.relative_to(design_dir)}")
    print(f"({len(file_paths)} files)\n")

    if not file_paths:
        print("ERROR: no design files found -- check --design-dir and --exclude.")
        sys.exit(1)

    print("=== Compiling design + testbench ===")
    work_dir = sim_dir / "work"
    if work_dir.exists():
        shutil.rmtree(work_dir)

    subprocess.run([vlib, "work"], cwd=sim_dir, check=True)

    result = subprocess.run(
        [vlog, "-sv"] + [str(p) for p in file_paths],
        cwd=sim_dir, capture_output=True, text=True
    )
    print(result.stdout)
    if result.returncode != 0:
        print(result.stderr)
        print("ERROR: compilation failed, aborting.")
        sys.exit(1)
    print("=== Compile OK ===\n")


def run_one_test(sim_dir: Path, instr_hex: str, data_hex: str, vsim: str,
                 timeout_sec: int) -> tuple[str, str]:
    """Runs vsim in batch mode passing both instruction and data hex plusargs."""
    cmd = [
        vsim, "-c", "work.tb_top_rv32_scdp",
        f"+INSTR_HEX={instr_hex}",
        f"+DATA_HEX={data_hex}",
        "-do", "run -all; quit",
    ]
    try:
        result = subprocess.run(
            cmd, cwd=sim_dir, capture_output=True, text=True,
            timeout=timeout_sec
        )
    except subprocess.TimeoutExpired:
        return "PROC_TIMEOUT", f"vsim process exceeded {timeout_sec}s wall-clock limit"

    for line in result.stdout.splitlines():
        if "[PASS]" in line:
            return "PASS", line.strip()
        if "[FAIL]" in line:
            return "FAIL", line.strip()
        if "[TIMEOUT]" in line:
            return "TIMEOUT", line.strip()

    tail = "\n".join(result.stdout.splitlines()[-15:])
    return "ERROR", f"No PASS/FAIL/TIMEOUT line found. Last output:\n{tail}"


def main():
    parser = argparse.ArgumentParser(description="Batch-run riscv-tests against rv32_scdp in QuestaSim")
    parser.add_argument("--tests-dir", required=True, type=Path,
                        help="Folder containing rv32ui-p-* ELF binaries")
    parser.add_argument("--design-dir", required=True, type=Path,
                        help="Root folder containing your .sv RTL files and tb_top_rv32_scdp.sv")
    parser.add_argument("--sim-dir", default=Path("./sim_run"), type=Path,
                        help="Working directory for vlib/vlog/vsim and generated hex files")
    parser.add_argument("--exclude", nargs="*",
                        default=["Testbenches", "no_tb_top_rv32_scdp.sv"],
                        help="Skip any .sv file whose relative path contains one of these substrings")
    parser.add_argument("--vlib", default="vlib", help="Path to vlib executable")
    parser.add_argument("--vlog", default="vlog", help="Path to vlog executable")
    parser.add_argument("--vsim", default="vsim", help="Path to vsim executable")
    parser.add_argument("--timeout", type=int, default=120,
                        help="Per-test wall-clock timeout in seconds (default: 120)")
    parser.add_argument("--skip-compile", action="store_true",
                        help="Reuse an already-compiled work library instead of recompiling")
    parser.add_argument("--filter", default=None,
                        help="Only run tests whose filename contains this substring")
    args = parser.parse_args()

    if not args.tests_dir.is_dir():
        print(f"ERROR: tests dir not found: {args.tests_dir}")
        sys.exit(1)
    if not args.design_dir.is_dir():
        print(f"ERROR: design dir not found: {args.design_dir}")
        sys.exit(1)
    args.tests_dir = args.tests_dir.resolve()
    args.design_dir = args.design_dir.resolve()
    args.sim_dir.mkdir(parents=True, exist_ok=True)

    tests = find_test_binaries(args.tests_dir)
    if args.filter:
        tests = [t for t in tests if args.filter in t.name]
    if not tests:
        print("No matching rv32ui-p-* test binaries found.")
        sys.exit(1)

    print(f"Found {len(tests)} test(s): {', '.join(t.name for t in tests)}\n")

    if not args.skip_compile:
        compile_design(args.sim_dir, args.design_dir, args.exclude, args.vlib, args.vlog)

    results = {}
    for elf_path in tests:
        instr_hex_name = elf_path.name + ".instr.hex"
        data_hex_name = elf_path.name + ".data.hex"
        
        instr_hex_path = args.sim_dir / instr_hex_name
        data_hex_path = args.sim_dir / data_hex_name

        try:
            n_instr, n_data = elf_to_split_hex(elf_path, instr_hex_path, data_hex_path)
        except Exception as e:
            print(f"[SKIP] {elf_path.name}: hex conversion failed ({e})")
            results[elf_path.name] = ("SKIP", str(e))
            continue

        print(f"--- Running {elf_path.name} (Instr: {n_instr} words, Data: {n_data} words) ---")
        status, detail = run_one_test(args.sim_dir, instr_hex_name, data_hex_name, args.vsim, args.timeout)
        results[elf_path.name] = (status, detail)
        print(f"    {detail}\n")

    print("=" * 70)
    print("SUMMARY")
    print("=" * 70)

    passed = [n for n, (s, _) in results.items() if s == "PASS"]
    failed = [n for n, (s, _) in results.items() if s in ("FAIL", "TIMEOUT", "PROC_TIMEOUT", "ERROR")]
    skipped = [n for n, (s, _) in results.items() if s == "SKIP"]

    for name in sorted(results):
        status, _ = results[name]
        marker = "PASS" if status == "PASS" else status
        print(f"  [{marker:>13}] {name}")

    print("-" * 70)
    print(f"Total: {len(results)}   Passed: {len(passed)}   Failed: {len(failed)}   Skipped: {len(skipped)}")

    if failed:
        print("\nFailing tests:")
        for name in failed:
            status, detail = results[name]
            print(f"  {name} [{status}]: {detail}")
        sys.exit(1)


if __name__ == "__main__":
    main()