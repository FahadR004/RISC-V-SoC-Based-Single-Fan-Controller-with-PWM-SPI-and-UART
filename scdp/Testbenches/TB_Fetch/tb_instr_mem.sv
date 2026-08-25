module tb_instr_memory;

localparam ADDR_WIDTH = 32;
localparam INSTR_WIDTH = 32;
localparam DEPTH = 1024;

logic [ADDR_WIDTH-1:0] pc_address;
logic [INSTR_WIDTH-1:0] instruction;

instr_memory #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .INSTR_WIDTH(INSTR_WIDTH),
    .DEPTH(DEPTH)
) dut (
    .pc_address(pc_address),
    .instruction(instruction)
);

initial begin
  $dumpfile("tb_instr_mem.vcd");
  $dumpvars(0, tb_instr_mem);
end

initial begin
    dut.memory[0] = 32'h00000013;   // Test instruction 1 (ADDI x0, x0, 0)
    dut.memory[1] = 32'h00100093;   // Test instruction 2 (ADDI x1, x0, 1)
    dut.memory[2] = 32'h00200113;   // Test instruction 3 (ADDI x2, x0, 2)
    dut.memory[3] = 32'h00300193;   // Test instruction 4 (ADDI x3, x0, 3)
    dut.memory[4] = 32'hDEADBEEF;   // Test instruction 5 (arbitrary value)
    
    // Test 1: Read from word address 0 (byte address 0x00000000)
    pc_address = 32'h00000000;
    #1;
    assert(instruction == 32'h00000013) else $error("Test 1 failed: instruction = %0h, expected 00000013", instruction);
    $display("Test 1 PASSED: Read from address 0x00000000 = 0x%0h", instruction);
    
    // Test 2: Read from word address 1 (byte address 0x00000004)
    pc_address = 32'h00000004;
    #1;
    assert(instruction == 32'h00100093) else $error("Test 2 failed: instruction = %0h, expected 00100093", instruction);
    $display("Test 2 PASSED: Read from address 0x00000004 = 0x%0h", instruction);
    
    // Test 3: Read from word address 2 (byte address 0x00000008)
    pc_address = 32'h00000008;
    #1;
    assert(instruction == 32'h00200113) else $error("Test 3 failed: instruction = %0h, expected 00200113", instruction);
    $display("Test 3 PASSED: Read from address 0x00000008 = 0x%0h", instruction);
    
    // Test 4: Read from word address 3 (byte address 0x0000000C)
    pc_address = 32'h0000000C;
    #1;
    assert(instruction == 32'h00300193) else $error("Test 4 failed: instruction = %0h, expected 00300193", instruction);
    $display("Test 4 PASSED: Read from address 0x0000000C = 0x%0h", instruction);
    
    // Test 5: Read from word address 4 (byte address 0x00000010)
    pc_address = 32'h00000010;
    #1;
    assert(instruction == 32'hDEADBEEF) else $error("Test 5 failed: instruction = %0h, expected DEADBEEF", instruction);
    $display("Test 5 PASSED: Read from address 0x00000010 = 0x%0h", instruction);
    
    $display("\nAll instruction memory tests PASSED!");
    $finish;
end

endmodule