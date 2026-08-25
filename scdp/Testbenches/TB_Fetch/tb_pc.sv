module tb_pc;

localparam ADDR_WIDTH = 32;

logic clk;
logic rst_n;
logic [ADDR_WIDTH-1:0] next_pc;
logic [ADDR_WIDTH-1:0] pc_current;

pc_register #(
    .ADDR_WIDTH(ADDR_WIDTH)
) dut (
    .clk(clk),
    .rst_n(rst_n),
    .next_pc(next_pc),
    .pc_current(pc_current)
);

initial begin
    clk = 0;
    forever #5 clk = ~clk;  // 10ns period
end


initial begin
  $dumpfile("tb_pc.vcd");
  $dumpvars(0, tb_pc);
end

initial begin
    // Initialize
    rst_n = 0;
    next_pc = 32'd0;
    
    // Test 1: Reset
    #10;
    assert(pc_current == 32'd0) else $error("Reset failed: pc_current = %0d, expected 0", pc_current);
    $display("Test 1 PASSED: Reset works correctly");
    
    // Test 2: Release reset and update PC
    rst_n = 1;
    next_pc = 32'd4;
    #10;
    assert(pc_current == 32'd4) else $error("PC update failed: pc_current = %0d, expected 4", pc_current);
    $display("Test 2 PASSED: PC updated to 4");
    
    // Test 3: Update PC to next value
    next_pc = 32'd8;
    #10;
    assert(pc_current == 32'd8) else $error("PC update failed: pc_current = %0d, expected 8", pc_current);
    $display("Test 3 PASSED: PC updated to 8");
    
    // Test 4: Update PC to larger value
    next_pc = 32'h1000;
    #10;
    assert(pc_current == 32'h1000) else $error("PC update failed: pc_current = %0h, expected 1000", pc_current);
    $display("Test 4 PASSED: PC updated to 0x1000");
    
    // Test 5: Reset while running
    rst_n = 0;
    #10;
    assert(pc_current == 32'd0) else $error("Reset during operation failed: pc_current = %0d, expected 0", pc_current);
    $display("Test 5 PASSED: Reset during operation works correctly");
    
    $display("\nAll tests PASSED!");
    $finish;
end

endmodule