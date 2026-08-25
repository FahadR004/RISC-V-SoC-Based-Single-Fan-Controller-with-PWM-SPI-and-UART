module tb_fetch;

localparam ADDR_WIDTH = 32;
localparam INSTR_WIDTH = 32;
localparam DEPTH = 1024;

logic clk;
logic rst_n;
logic [ADDR_WIDTH-1:0] next_pc;
logic [INSTR_WIDTH-1:0] instruction;
logic [ADDR_WIDTH-1:0] current_pc;

Fetch #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .INSTR_WIDTH(INSTR_WIDTH),
    .DEPTH(DEPTH)
) dut (
    .clk(clk),
    .rst_n(rst_n),
    .next_pc(next_pc),
    .instruction(instruction),
    .current_pc(current_pc)
);

initial begin
    clk = 0;
    forever #5 clk = ~clk;  // 10ns period
end

initial begin
  $dumpfile("tb_fetch.vcd");
  $dumpvars(0, tb_fetch);
end

initial begin
    // Initialize memory with test instructions
    dut.instr_mem.memory[0] = 32'h00000013;   // Word 0: ADDI x0, x0, 0
    dut.instr_mem.memory[1] = 32'h00100093;   // Word 1: ADDI x1, x0, 1
    dut.instr_mem.memory[2] = 32'h00200113;   // Word 2: ADDI x2, x0, 2
    dut.instr_mem.memory[3] = 32'h00300193;   // Word 3: ADDI x3, x0, 3
    dut.instr_mem.memory[4] = 32'h00400213;   // Word 4: ADDI x4, x0, 4
    
    // Initialize
    rst_n = 0;
    next_pc = 32'd0;
    
    // Test 1: Reset
    #10;
    assert(current_pc == 32'd0) else $error("Reset failed: current_pc = %0d", current_pc);
    $display("Test 1 PASSED: Reset - current_pc = 0x%0h", current_pc);
    
    // Test 2: Release reset and fetch first instruction
    rst_n = 1;
    next_pc = 32'd0;  // PC+4 for next cycle
    #10;
    assert(instruction == 32'h00000013) else $error("Test 2 failed: instruction = %0h, expected 00000013", instruction);
    assert(current_pc == 32'd0) else $error("Test 2 failed: current_pc = %0h, expected 0", current_pc);
    $display("Test 2 PASSED: Fetched instruction 0x%0h at PC 0x%0h", instruction, current_pc);
    
    // Test 3: Fetch second instruction
    next_pc = 32'd4;  // PC+4 for next cycle
    #10;
    assert(instruction == 32'h00100093) else $error("Test 3 failed: instruction = %0h, expected 00100093", instruction);
    assert(current_pc == 32'd4) else $error("Test 3 failed: current_pc = %0h, expected 4", current_pc);
    $display("Test 3 PASSED: Fetched instruction 0x%0h at PC 0x%0h", instruction, current_pc);
    
    // Test 4: Fetch third instruction
    next_pc = 32'd8;  // PC+4 for next cycle
    #10;
    assert(instruction == 32'h00200113) else $error("Test 4 failed: instruction = %0h, expected 00200113", instruction);
    assert(current_pc == 32'd8) else $error("Test 4 failed: current_pc = %0h, expected 8", current_pc);
    $display("Test 4 PASSED: Fetched instruction 0x%0h at PC 0x%0h", instruction, current_pc);
    
    // Test 5: Fetch fourth instruction
    next_pc = 32'd12;  // PC+4 for next cycle
    #10;
    assert(instruction == 32'h00300193) else $error("Test 5 failed: instruction = %0h, expected 00300193", instruction);
    assert(current_pc == 32'd12) else $error("Test 5 failed: current_pc = %0h, expected 12", current_pc);
    $display("Test 5 PASSED: Fetched instruction 0x%0h at PC 0x%0h", instruction, current_pc);
    
    // Test 6: Fetch fifth instruction
    next_pc = 32'd16;  // PC+4 for next cycle
    #10;
    assert(instruction == 32'h00400213) else $error("Test 6 failed: instruction = %0h, expected 00400213", instruction);
    assert(current_pc == 32'd16) else $error("Test 6 failed: current_pc = %0h, expected 16", current_pc);
    $display("Test 6 PASSED: Fetched instruction 0x%0h at PC 0x%0h", instruction, current_pc);
    
    // Test 7: Jump to different address (PC = 0x1000)
    next_pc = 32'h1004;  // PC+4 for next cycle
    #10;
    // Memory at word address 0x400 (0x1000 / 4) should be 0 (uninitialized)
    assert(current_pc == 32'h1004) else $error("Test 7 failed: current_pc = %0h, expected 1004", current_pc);
    $display("Test 7 PASSED: Jump to address 0x%0h, fetched instruction 0x%0h", current_pc, instruction);
    
    // Test 8: Reset during operation
    rst_n = 0;
    #10;
    assert(current_pc == 32'd0) else $error("Test 8 failed: Reset during operation failed", current_pc);
    $display("Test 8 PASSED: Reset during operation - current_pc reset to 0x%0h", current_pc);
    
    $display("\nAll Fetch module tests PASSED!");
    $finish;
end

endmodule