// Code your testbench here
// or browse Examples
`timescale 1ns/1ps

module tb_data_memory;

localparam ADDR_WIDTH = 32;
localparam DATA_WIDTH = 32;
localparam DEPTH      = 1024;

logic clk;
logic [ADDR_WIDTH-1:0] address;
logic [2:0]            funct3;
logic memRead;
logic memWrite;
logic [DATA_WIDTH-1:0] write_data;
logic [DATA_WIDTH-1:0] read_data;

// funct3 encodings (RISC-V)
localparam F3_B  = 3'b000; // LB/SB
localparam F3_H  = 3'b001; // LH/SH
localparam F3_W  = 3'b010; // LW/SW
localparam F3_BU = 3'b100; // LBU
localparam F3_HU = 3'b101; // LHU

data_memory #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .DEPTH(DEPTH)
) dut (
    .clk(clk),
    .address(address),
    .funct3(funct3),
    .memRead(memRead),
    .memWrite(memWrite),
    .write_data(write_data),
    .read_data(read_data)
);

int errors = 0;
int checks = 0;

task automatic check(
    input string name,
    input logic [DATA_WIDTH-1:0] got,
    input logic [DATA_WIDTH-1:0] exp
);
    checks++;
    if (got !== exp) begin
        errors++;
        $display("[FAIL] %s: expected=%0h got=%0h", name, exp, got);
    end else begin
        $display("[PASS] %s = %0h", name, got);
    end
endtask

initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

initial begin
    $dumpfile("tb_data_memory.vcd");
    $dumpvars(0, tb_data_memory);
end

initial begin
    // For independent read tests
    dut.memory[0] = 32'h00000013;
    dut.memory[1] = 32'h00100093;
    dut.memory[2] = 32'h89ABCDEF; // used for byte/half load tests
    dut.memory[4] = 32'hDEADBEEF;

    address    = 32'h0;
    funct3     = F3_W;
    memRead    = 1'b0;
    memWrite   = 1'b0;
    write_data = 32'h0;

    $display("\nTest 1: memRead=0 -> read_data must be 0 regardless of memory contents");
    address = 32'h00000000; funct3 = F3_W; memRead = 1'b0;
    #1; check("memRead_deasserted_forces_zero", read_data, 32'h0);

    $display("\nTest 2: memRead=1, funct3=LW -> reads preloaded word at address 0");
    address = 32'h00000000; funct3 = F3_W; memRead = 1'b1;
    #1; check("read_preloaded_word0", read_data, 32'h00000013);

    $display("\nTest 3: memRead=1, funct3=LW -> reads preloaded word at address 0x4");
    address = 32'h00000004; funct3 = F3_W; memRead = 1'b1;
    #1; check("read_preloaded_word1", read_data, 32'h00100093);

    $display("\nTest 4: memRead=1, funct3=LW -> reads preloaded word at address 0x10 (word 4)");
    address = 32'h00000010; funct3 = F3_W; memRead = 1'b1;
    #1; check("read_preloaded_word4", read_data, 32'hDEADBEEF);

    $display("\nTest 5: LB / LBU sign vs zero extension (word 2 = 0x89ABCDEF)");
    address = 32'h00000008; funct3 = F3_B; memRead = 1'b1; // byte0 = 0xEF
    #1; check("LB_offset0_sign_extend", read_data, 32'hFFFFFFEF);
    address = 32'h00000008; funct3 = F3_BU; memRead = 1'b1;
    #1; check("LBU_offset0_zero_extend", read_data, 32'h000000EF);

    address = 32'h0000000B; funct3 = F3_B; memRead = 1'b1; // byte3 = 0x89
    #1; check("LB_offset3_sign_extend", read_data, 32'hFFFFFF89);
    address = 32'h0000000B; funct3 = F3_BU; memRead = 1'b1;
    #1; check("LBU_offset3_zero_extend", read_data, 32'h00000089);

    $display("\nTest 6: LH / LHU sign vs zero extension (word 2 = 0x89ABCDEF)");
    address = 32'h00000008; funct3 = F3_H; memRead = 1'b1; // low half = 0xCDEF
    #1; check("LH_lowhalf_sign_extend", read_data, 32'hFFFFCDEF);
    address = 32'h00000008; funct3 = F3_HU; memRead = 1'b1;
    #1; check("LHU_lowhalf_zero_extend", read_data, 32'h0000CDEF);

    address = 32'h0000000A; funct3 = F3_H; memRead = 1'b1; // high half = 0x89AB
    #1; check("LH_highhalf_sign_extend", read_data, 32'hFFFF89AB);
    address = 32'h0000000A; funct3 = F3_HU; memRead = 1'b1;
    #1; check("LHU_highhalf_zero_extend", read_data, 32'h000089AB);

    $display("\nTest 7: synchronous SW write -> value not visible until after posedge clk");
    memRead    = 1'b0;
    address    = 32'h00000020; // word 8
    funct3     = F3_W;
    write_data = 32'hCAFEBABE;
    memWrite   = 1'b1;

    // Immediately after setting memWrite (still combinational settle, before clk edge),
    // the write must NOT have landed yet -- proves the write is truly synchronous,
    // not combinational/latched.
    memRead = 1'b1;
    #1;
    check("write_not_visible_before_clk_edge", read_data, 32'h0);

    @(posedge clk);
    #1; // allow write to land, then settle read
    memWrite = 1'b0;
    check("write_visible_after_clk_edge", read_data, 32'hCAFEBABE);

    $display("\nTest 8: memWrite=0 must not modify memory even if write_data changes");
    write_data = 32'h11111111; // different value, but memWrite is low
    memWrite   = 1'b0;
    @(posedge clk);
    #1;
    check("no_write_when_memWrite_low", read_data, 32'hCAFEBABE); // unchanged

    $display("\nTest 9: write then read-back at a different address (word 9)");
    address    = 32'h00000024; // word 9
    write_data = 32'h5A5A5A5A;
    funct3     = F3_W;
    memWrite   = 1'b1;
    memRead    = 1'b0;
    @(posedge clk);
    #1;
    memWrite = 1'b0;
    memRead  = 1'b1;
    #1;
    check("write_then_read_word9", read_data, 32'h5A5A5A5A);

    // Confirm word 8 (from Test 7) is untouched by the word 9 write
    address = 32'h00000020;
    #1;
    check("earlier_write_word8_still_intact", read_data, 32'hCAFEBABE);

    $display("\nTest 10: back-to-back writes on consecutive clock edges");
    address    = 32'h00000030; // word 12
    write_data = 32'h00000001;
    funct3     = F3_W;
    memWrite   = 1'b1;
    memRead    = 1'b0;
    @(posedge clk);
    #1;
    write_data = 32'h00000002; // overwrite same address next cycle
    @(posedge clk);
    #1;
    memWrite = 1'b0;
    memRead  = 1'b1;
    #1;
    check("second_write_overwrites_first", read_data, 32'h00000002);

    $display("\nTest 11: SB write -> only targeted byte changes, others preserved");
    // word 13 (0x34), start from known word 0xAABBCCDD via full-word write
    address    = 32'h00000034;
    write_data = 32'hAABBCCDD;
    funct3     = F3_W;
    memWrite   = 1'b1;
    memRead    = 1'b0;
    @(posedge clk);
    #1;

    // SB to offset 0: write 0xFF -> expect 0xAABBCCFF
    address    = 32'h00000034;
    write_data = 32'h000000FF;
    funct3     = F3_B;
    memWrite   = 1'b1;
    @(posedge clk);
    #1;
    memWrite = 1'b0;
    memRead  = 1'b1;
    funct3   = F3_W;
    address  = 32'h00000034;
    #1;
    check("SB_offset0_preserves_other_bytes", read_data, 32'hAABBCCFF);

    // SB to offset 3 (address 0x34 + 3 = 0x37): write 0x11 -> expect 0x11BBCCFF
    address    = 32'h00000037;
    write_data = 32'h00000011;
    funct3     = F3_B;
    memWrite   = 1'b1;
    memRead    = 1'b0;
    @(posedge clk);
    #1;
    memWrite = 1'b0;
    memRead  = 1'b1;
    funct3   = F3_W;
    address  = 32'h00000034; // read back the whole word
    #1;
    check("SB_offset3_preserves_other_bytes", read_data, 32'h11BBCCFF);

    $display("\nTest 12: SH write -> only targeted halfword changes, other preserved");
    // word 14 (0x38), start from known word 0x12345678
    address    = 32'h00000038;
    write_data = 32'h12345678;
    funct3     = F3_W;
    memWrite   = 1'b1;
    memRead    = 1'b0;
    @(posedge clk);
    #1;

    // SH to low half (offset 0): write 0xBEEF -> expect 0x1234BEEF
    address    = 32'h00000038;
    write_data = 32'h0000BEEF;
    funct3     = F3_H;
    memWrite   = 1'b1;
    @(posedge clk);
    #1;
    memWrite = 1'b0;
    memRead  = 1'b1;
    funct3   = F3_W;
    address  = 32'h00000038;
    #1;
    check("SH_lowhalf_preserves_other_half", read_data, 32'h1234BEEF);

    // SH to high half (address 0x38 + 2 = 0x3A): write 0xFACE -> expect 0xFACEBEEF
    address    = 32'h0000003A;
    write_data = 32'h0000FACE;
    funct3     = F3_H;
    memWrite   = 1'b1;
    memRead    = 1'b0;
    @(posedge clk);
    #1;
    memWrite = 1'b0;
    memRead  = 1'b1;
    funct3   = F3_W;
    address  = 32'h00000038; // read back the whole word
    #1;
    check("SH_highhalf_preserves_other_half", read_data, 32'hFACEBEEF);
    if (errors == 0)
        $display("\nAll data memory tests PASSED! (%0d checks)", checks);
    else
        $display("\n%0d/%0d checks FAILED", errors, checks);

    $finish;
end

endmodule