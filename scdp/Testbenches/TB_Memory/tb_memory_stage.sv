`timescale 1ns/1ps

module tb_memory_stage;

localparam ADDR_WIDTH = 32;
localparam DATA_WIDTH = 32;
localparam DEPTH      = 1024;

logic clk;
logic [ADDR_WIDTH-1:0] address;
logic memRead;
logic memWrite;
logic [DATA_WIDTH-1:0] write_data;
logic [DATA_WIDTH-1:0] mem_read_data;

Memory #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .DEPTH(DEPTH)
) dut (
    .clk(clk),
    .address(address),
    .memRead(memRead),
    .memWrite(memWrite),
    .write_data(write_data),
    .mem_read_data(mem_read_data)
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
    $dumpfile("tb_memory_stage.vcd");
    $dumpvars(0, tb_memory_stage);
end

initial begin
    // Preload directly through the hierarchy: dut (Memory) -> data_mem (data_memory) -> memory array
    dut.data_mem.memory[0] = 32'h00000013;
    dut.data_mem.memory[1] = 32'h00100093;
    dut.data_mem.memory[4] = 32'hDEADBEEF;

    address    = 32'h0;
    memRead    = 1'b0;
    memWrite   = 1'b0;
    write_data = 32'h0;

    $display("\nTest 1: memRead=0 -> mem_read_data must be 0 regardless of memory contents");
    address = 32'h00000000; memRead = 1'b0;
    #1; check("memRead_deasserted_forces_zero", mem_read_data, 32'h0);

    $display("\nTest 2: memRead=1 -> reads preloaded word at address 0");
    address = 32'h00000000; memRead = 1'b1;
    #1; check("read_preloaded_word0", mem_read_data, 32'h00000013);

    $display("\nTest 3: memRead=1 -> reads preloaded word at address 0x4");
    address = 32'h00000004; memRead = 1'b1;
    #1; check("read_preloaded_word1", mem_read_data, 32'h00100093);

    $display("\nTest 4: memRead=1 -> reads preloaded word at address 0x10 (word 4)");
    address = 32'h00000010; memRead = 1'b1;
    #1; check("read_preloaded_word4", mem_read_data, 32'hDEADBEEF);

    // ---------------------------------------------------------
    $display("\nTest 5: synchronous write -> value not visible until after posedge clk");
    memRead    = 1'b0;
    address    = 32'h00000020; // word 8
    write_data = 32'hCAFEBABE;
    memWrite   = 1'b1;

    memRead = 1'b1;
    #1;
    check("write_not_visible_before_clk_edge", mem_read_data, 32'h0);

    @(posedge clk);
    #1;
    memWrite = 1'b0;
    check("write_visible_after_clk_edge", mem_read_data, 32'hCAFEBABE);

    // ---------------------------------------------------------
    $display("\nTest 6: memWrite=0 must not modify memory even if write_data changes");
    write_data = 32'h11111111;
    memWrite   = 1'b0;
    @(posedge clk);
    #1;
    check("no_write_when_memWrite_low", mem_read_data, 32'hCAFEBABE);

    // ---------------------------------------------------------
    $display("\nTest 7: write then read-back at a different address (word 9)");
    address    = 32'h00000024; // word 9
    write_data = 32'h5A5A5A5A;
    memWrite   = 1'b1;
    memRead    = 1'b0;
    @(posedge clk);
    #1;
    memWrite = 1'b0;
    memRead  = 1'b1;
    #1;
    check("write_then_read_word9", mem_read_data, 32'h5A5A5A5A);

    address = 32'h00000020;
    #1;
    check("earlier_write_word8_still_intact", mem_read_data, 32'hCAFEBABE);

    // ---------------------------------------------------------
    $display("\nTest 8: back-to-back writes on consecutive clock edges");
    address    = 32'h00000030; // word 12
    write_data = 32'h00000001;
    memWrite   = 1'b1;
    memRead    = 1'b0;
    @(posedge clk);
    #1;
    write_data = 32'h00000002;
    @(posedge clk);
    #1;
    memWrite = 1'b0;
    memRead  = 1'b1;
    #1;
    check("second_write_overwrites_first", mem_read_data, 32'h00000002);

    // ---------------------------------------------------------
    if (errors == 0)
        $display("\nAll Memory stage tests PASSED! (%0d checks)", checks);
    else
        $display("\n%0d/%0d checks FAILED", errors, checks);

    $finish;
end

endmodule