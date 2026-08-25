module tb_rv32_scdp;

localparam ADDR_WIDTH = 32;
localparam INSTR_WIDTH = 32;
localparam DEPTH = 1024;

logic clk;
logic rst_n;

rv32_scdp #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .INSTR_WIDTH(INSTR_WIDTH),
    .DEPTH(DEPTH)
) dut (
    .clk(clk),
    .rst_n(rst_n)
);

initial begin
    clk = 0;
    forever #5 clk = ~clk;  // 10ns period
end

initial begin
    $dumpfile("tb_rv32_scdp.vcd");
    $dumpvars(0, tb_rv32_scdp);
end


initial begin
    dut.fetch_stage.instr_mem.memory[0] = 32'h00000013;   // Word 0: ADDI x0, x0, 0
    dut.fetch_stage.instr_mem.memory[1] = 32'h00100093;   // Word 1: ADDI x1, x0, 1
    dut.fetch_stage.instr_mem.memory[2] = 32'h00200113;   // Word 2: ADDI x2, x0, 2
    dut.fetch_stage.instr_mem.memory[3] = 32'h00300193;   // Word 3: ADDI x3, x0, 3
    dut.fetch_stage.instr_mem.memory[4] = 32'h00400213;   // Word 4: ADDI x4, x0, 4
    dut.fetch_stage.instr_mem.memory[5] = 32'h00500293;   // Word 5: ADDI x5, x0, 5
    
    // Initialize
    rst_n = 0;
    
    // Test 1: Reset
    @(posedge clk); #1;
    assert(dut.pc_current_addr == 32'd0) else $error("Reset failed: pc = %0d", dut.pc_current_addr);
    $display("Test 1 PASSED: Reset - PC = 0x%0h", dut.pc_current_addr);
    
    // Test 2: Release reset and start fetching
    rst_n = 1;
    assert(dut.instruction == 32'h00000013) else $error("Test 2 failed: instruction = %0h, expected 00000013", dut.instruction);
    assert(dut.pc_current_addr == 32'd0) else $error("Test 2 failed: pc = %0h, expected 0", dut.pc_current_addr);
    assert(dut.pc_plus_4 == 32'd4) else $error("Test 2 failed: pc_plus_4 = %0h, expected 4", dut.pc_plus_4);
    $display("Test 2 PASSED: First instruction fetch - PC = 0x%0h, Instruction = 0x%0h, PC+4 = 0x%0h", 
             dut.pc_current_addr, dut.instruction, dut.pc_plus_4);
    
    // Test 3: Fetch second instruction (PC should update to 4)
    @(posedge clk); #1;
    assert(dut.instruction == 32'h00100093) else $error("Test 3 failed: instruction = %0h, expected 00100093", dut.instruction);
    assert(dut.pc_current_addr == 32'd4) else $error("Test 3 failed: pc = %0h, expected 4", dut.pc_current_addr);
    assert(dut.pc_plus_4 == 32'd8) else $error("Test 3 failed: pc_plus_4 = %0h, expected 8", dut.pc_plus_4);
    $display("Test 3 PASSED: Second instruction fetch - PC = 0x%0h, Instruction = 0x%0h, PC+4 = 0x%0h", 
             dut.pc_current_addr, dut.instruction, dut.pc_plus_4);
    
    // Test 4: Fetch third instruction
    @(posedge clk); #1;
    assert(dut.instruction == 32'h00200113) else $error("Test 4 failed: instruction = %0h, expected 00200113", dut.instruction);
    assert(dut.pc_current_addr == 32'd8) else $error("Test 4 failed: pc = %0h, expected 8", dut.pc_current_addr);
    assert(dut.pc_plus_4 == 32'd12) else $error("Test 4 failed: pc_plus_4 = %0h, expected 12", dut.pc_plus_4);
    $display("Test 4 PASSED: Third instruction fetch - PC = 0x%0h, Instruction = 0x%0h, PC+4 = 0x%0h", 
             dut.pc_current_addr, dut.instruction, dut.pc_plus_4);
    
    // Test 5: Fetch fourth instruction
    @(posedge clk); #1;
    assert(dut.instruction == 32'h00300193) else $error("Test 5 failed: instruction = %0h, expected 00300193", dut.instruction);
    assert(dut.pc_current_addr == 32'd12) else $error("Test 5 failed: pc = %0h, expected 12", dut.pc_current_addr);
    assert(dut.pc_plus_4 == 32'd16) else $error("Test 5 failed: pc_plus_4 = %0h, expected 16", dut.pc_plus_4);
    $display("Test 5 PASSED: Fourth instruction fetch - PC = 0x%0h, Instruction = 0x%0h, PC+4 = 0x%0h", 
             dut.pc_current_addr, dut.instruction, dut.pc_plus_4);
    
    // Test 6: Fetch fifth instruction
    @(posedge clk); #1;
    assert(dut.instruction == 32'h00400213) else $error("Test 6 failed: instruction = %0h, expected 00400213", dut.instruction);
    assert(dut.pc_current_addr == 32'd16) else $error("Test 6 failed: pc = %0h, expected 16", dut.pc_current_addr);
    assert(dut.pc_plus_4 == 32'd20) else $error("Test 6 failed: pc_plus_4 = %0h, expected 20", dut.pc_plus_4);
    $display("Test 6 PASSED: Fifth instruction fetch - PC = 0x%0h, Instruction = 0x%0h, PC+4 = 0x%0h", 
             dut.pc_current_addr, dut.instruction, dut.pc_plus_4);
    
    // Test 7: Fetch sixth instruction
    @(posedge clk); #1;
    assert(dut.instruction == 32'h00500293) else $error("Test 7 failed: instruction = %0h, expected 00500293", dut.instruction);
    assert(dut.pc_current_addr == 32'd20) else $error("Test 7 failed: pc = %0h, expected 20", dut.pc_current_addr);
    assert(dut.pc_plus_4 == 32'd24) else $error("Test 7 failed: pc_plus_4 = %0h, expected 24", dut.pc_plus_4);
    $display("Test 7 PASSED: Sixth instruction fetch - PC = 0x%0h, Instruction = 0x%0h, PC+4 = 0x%0h", 
             dut.pc_current_addr, dut.instruction, dut.pc_plus_4);
    
    // Test 8: Reset during operation
    rst_n = 0;
    @(posedge clk); #1;
    assert(dut.pc_current_addr == 32'd0) else $error("Test 8 failed: Reset during operation failed");
    assert(dut.pc_plus_4 == 32'd4) else $error("Test 8 failed: pc_plus_4 not recalculated");
    $display("Test 8 PASSED: Reset during operation - PC reset to 0x%0h, PC+4 = 0x%0h", dut.pc_current_addr, dut.pc_plus_4);
    
    
    $display("All top-level module tests PASSED!");
    $finish;
end

endmodule
