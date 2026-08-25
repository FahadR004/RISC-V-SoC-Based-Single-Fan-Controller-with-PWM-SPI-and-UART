`timescale 1ns/1ps

module tb_register_file;

localparam DATA_WIDTH  = 32;
localparam REG_NUMS    = 32;

logic clk;
logic rst_n;
// Register Numbers
logic [$clog2(REG_NUMS)-1:0] read_reg1; // rs1
logic [$clog2(REG_NUMS)-1:0] read_reg2; // rs2
logic [$clog2(REG_NUMS)-1:0] write_reg;

// WriteBack Data
logic [DATA_WIDTH-1:0] write_data;

// Control Signals
logic regWrite;

// Output of the Register File
logic [DATA_WIDTH-1:0] read_data1;
logic [DATA_WIDTH-1:0] read_data2;

int errors = 0;
int checks = 0;

register_file #(
    .DATA_WIDTH (DATA_WIDTH),
    .REG_NUMS (REG_NUMS)
) dut (
   .clk(clk),
   .rst_n(rst_n),
   .read_reg1(read_reg1),
   .read_reg2(read_reg2),
   .write_reg(write_reg),
   .write_data(write_data),
   .regWrite(regWrite),
   .read_data1(read_data1),
   .read_data2(read_data2)
);

initial clk = 0;
always #5 clk = ~clk;

initial begin
    $dumpfile("tb_register_file.vcd");
    $dumpvars(0, tb_register_file);
end

task automatic do_write(input [4:0] addr, input [DATA_WIDTH-1:0] data);
    @(negedge clk);           // set up inputs away from the edge
    write_reg  = addr;
    write_data = data;
    regWrite   = 1;
    @(posedge clk);           // write commits here
    @(negedge clk);
    regWrite   = 0;
endtask

// The hardcoded delays are not scalable unlike negedge. If you change the clock time, then this would introduce the race condition you were trying to avoid. 
// task automatic do_write(input [4:0] addr, input [DATA_WIDTH-1:0] data);
//     @(posedge clk) #1;
//     write_reg = addr;
//     write_data = data;
//     regWrite = 1;
//     @ (posedge clk); #2;
//     regWrite = 0;
// endtask

task automatic check(input string name, input [DATA_WIDTH-1:0] got, input [DATA_WIDTH-1:0] exp);
    checks++;
    if (got !== exp) begin
        errors++;
        $display("  [FAIL] %s: expected=%h got=%h", name, exp, got);
    end else begin
        $display("  [PASS] %s = %h", name, got);
    end
endtask

initial begin
    // Init
    rst_n = 0;
    @(negedge clk);
    
    rst_n = 1'b1;
    @(negedge clk);
    // Test 1: x0 reads as 0 before any writes
    read_reg1 = 5'd0;
    read_reg2 = 5'd0;
    #1;
    $display("Test 1: x0 default read");
    check("x0_read1", read_data1, 32'h0);
    check("x0_read2", read_data2, 32'h0);

    // Test 2: basic write then read-back
    do_write(5'd1, 32'hAAAA5555);
    read_reg1 = 5'd1;
    #1;
    $display("Test 2: write x1, read x1");
    check("x1_read", read_data1, 32'hAAAA5555);

    // Test 3: write a second register, read both simultaneously
    do_write(5'd2, 32'h12345678);
    read_reg1 = 5'd1;
    read_reg2 = 5'd2;
    #1;
    $display("Test 3: simultaneous read of x1 and x2");
    check("x1_read", read_data1, 32'hAAAA5555);
    check("x2_read", read_data2, 32'h12345678);

    // Test 4: x0 write is discarded (still reads 0)
    do_write(5'd0, 32'hDEADBEEF);
    read_reg1 = 5'd0;
    #1;
    $display("Test 4: attempted write to x0 is ignored");
    check("x0_still_zero", read_data1, 32'h0);

    // Test 5: regWrite=0 should not write
    @(negedge clk);
    write_reg  = 5'd3;
    write_data = 32'hFFFFFFFF;
    regWrite   = 0;
    @(negedge clk);
    read_reg1 = 5'd3;
    #1;
    $display("Test 5: regWrite=0 blocks write");
    check("x3_unwritten", read_data1, 32'h0);

    // Test 6: read-before-write same cycle — read should reflect OLD value,
    // since write only commits at the clock edge
    do_write(5'd4, 32'h11111111); // x4 = 0x11111111 first
    @(negedge clk);
    write_reg  = 5'd4;
    write_data = 32'h22222222;
    regWrite   = 1;
    read_reg1  = 5'd4;
    #1;
    $display("Test 6: read same reg being written, before edge (expect old value)");
    check("x4_old_value", read_data1, 32'h11111111);
    @(posedge clk);
    #1;
    $display("Test 6b: read same reg after edge (expect new value)");
    check("x4_new_value", read_data1, 32'h22222222);
    @(negedge clk);
    regWrite = 0;

    if (errors == 0)
        $display("\nALL PASS: %0d checks, 0 errors", checks);
    else
        $display("\nFAILED: %0d checks, %0d errors", checks, errors);

    $finish;
end


endmodule