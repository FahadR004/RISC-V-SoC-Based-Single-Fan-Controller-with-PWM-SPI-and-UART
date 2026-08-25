`timescale 1ns/1ps

// Generic riscv-tests runner for rv32_scdp.
//
// Loads a hex file (produced by elf2hex.py) into instr_memory, runs the
// core, and watches for the ECALL that every rv32ui-p-* test ends with.
// At that point, x10 (a0) == 0 means pass; nonzero means fail, and
// x3 (gp) >> 1 gives the number of the specific check that failed.
//
// Usage (pass the hex file at simulation invocation, e.g. in Verilator/
// Questa via a plusarg):
//   +HEXFILE=rv32ui-p-add.hex
// If no plusarg is given, defaults to "rv32ui-p-add.hex" for quick manual runs.

module tb_top_rv32_scdp;

localparam ADDR_WIDTH  = 32;
localparam INSTR_WIDTH = 32;
localparam DATA_WIDTH  = 32;
localparam REG_NUMS    = 32;
localparam DEPTH       = 1024;

localparam int MAX_CYCLES = 100000; // watchdog: adjust upward for longer tests

logic clk;
logic rst_n;

top_rv32_scdp #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .INSTR_WIDTH(INSTR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .REG_NUMS(REG_NUMS),
    .DEPTH(DEPTH)
) dut (
    .clk(clk),
    .rst_n(rst_n)
);

// ECALL detection: opcode==SYSTEM(0x73), funct3==000, imm[11:0]==0
// (imm==1 would be EBREAK -- distinct encoding, not used by these tests'
// pass/fail signal).
wire is_ecall = (dut.opcode == 7'h73) &&
                (dut.funct3 == 3'b000) &&
                (dut.instruction[31:20] == 12'h000);

integer cycle_count;
string instr_hex_file;
string data_hex_file;
logic [DATA_WIDTH-1:0] a0_val;
logic [DATA_WIDTH-1:0] gp_val;

initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

initial begin
    if (!$value$plusargs("INSTR_HEX=%s", instr_hex_file)) begin
        instr_hex_file = "rv32ui-p-add.instr.hex";
    end
    if (!$value$plusargs("DATA_HEX=%s", data_hex_file)) begin
        data_hex_file = "rv32ui-p-add.data.hex";
    end 

    $display("=== Running %s (data: %s) ===", instr_hex_file, data_hex_file);
    $readmemh(instr_hex_file, dut.fetch_stage.instr_mem.memory);
    $readmemh(data_hex_file, dut.memory_stage.data_mem.memory);  

    rst_n = 0;
    cycle_count = 0;
    @(negedge clk);
    @(negedge clk);
    rst_n = 1;

    forever begin
        @(negedge clk);
        cycle_count = cycle_count + 1;

        if (is_ecall) begin
            a0_val = dut.decode_stage.reg_file.registers[10];
            gp_val = dut.decode_stage.reg_file.registers[3];

            if (a0_val == 0) begin
                $display("[PASS] %s (gp=%0d, cycles=%0d)",
                          instr_hex_file, gp_val, cycle_count);
            end else begin
                $display("[FAIL] %s: check #%0d failed (a0=0x%0h, gp=0x%0h, cycles=%0d)",
                          instr_hex_file, gp_val >> 1, a0_val, gp_val, cycle_count);
            end
            $finish;
        end

        if (cycle_count >= MAX_CYCLES) begin
            $display("[TIMEOUT] %s: exceeded %0d cycles without reaching ecall (stuck PC=0x%0h)",
                      instr_hex_file, MAX_CYCLES, dut.pc_current_addr);
            $finish;
        end
    end
end

endmodule