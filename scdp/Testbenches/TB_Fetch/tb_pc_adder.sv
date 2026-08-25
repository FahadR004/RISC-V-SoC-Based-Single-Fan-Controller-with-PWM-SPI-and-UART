module tb_pc_adder;

localparam ADDR_WIDTH = 32;

logic [ADDR_WIDTH-1:0] curr_pc;
logic [ADDR_WIDTH-1:0] pc_plus_4;

pc_adder #(
    .ADDR_WIDTH(ADDR_WIDTH)
) dut (
    .curr_pc(curr_pc),
    .pc_plus_4(pc_plus_4)
);

initial begin
  $dumpfile("tb_pc_adder.vcd");
  $dumpvars(0, tb_pc_adder);
end

initial begin
    // Test 1: PC = 0, should get 4
    curr_pc = 32'd0;
    #1;
    assert(pc_plus_4 == 32'd4) else $error("Test 1 failed: pc_plus_4 = %0d, expected 4", pc_plus_4);
    $display("Test 1 PASSED: 0 + 4 = %0d", pc_plus_4);
    
    // Test 2: PC = 4, should get 8
    curr_pc = 32'd4;
    #1;
    assert(pc_plus_4 == 32'd8) else $error("Test 2 failed: pc_plus_4 = %0d, expected 8", pc_plus_4);
    $display("Test 2 PASSED: 4 + 4 = %0d", pc_plus_4);
    
    // Test 3: PC = 0x1000, should get 0x1004
    curr_pc = 32'h1000;
    #1;
    assert(pc_plus_4 == 32'h1004) else $error("Test 3 failed: pc_plus_4 = %0h, expected 1004", pc_plus_4);
    $display("Test 3 PASSED: 0x1000 + 4 = 0x%0h", pc_plus_4);
    
    // Test 4: PC = 0xFFFFFFFC, should wrap around to 0x00000000 (with overflow)
    curr_pc = 32'hFFFFFFFC;
    #1;
    assert(pc_plus_4 == 32'h00000000) else $error("Test 4 failed: pc_plus_4 = %0h, expected 00000000", pc_plus_4);
    $display("Test 4 PASSED: 0xFFFFFFFC + 4 = 0x%0h (overflow)", pc_plus_4);
    
    // Test 5: PC = 0x80000000, should get 0x80000004
    curr_pc = 32'h80000000;
    #1;
    assert(pc_plus_4 == 32'h80000004) else $error("Test 5 failed: pc_plus_4 = %0h, expected 80000004", pc_plus_4);
    $display("Test 5 PASSED: 0x80000000 + 4 = 0x%0h", pc_plus_4);
    
    $display("\nAll tests PASSED!");
    $finish;
end

endmodule
