`timescale 1ns/1ps
module tb_sram;
  logic clk = 0;
  logic [3:0] addr;
  logic we;
  logic [3:0] wstrb;
  logic [31:0] wdata, rdata;
  always #5 clk = ~clk;

  simple_sram #(.ADDR_WIDTH(4)) dut (.*);

  initial begin
    addr = 0; we = 0; wstrb = 0; wdata = 0;
    @(negedge clk); addr = 3; wdata = 32'haabb_ccdd; wstrb = 4'hf; we = 1;
    @(negedge clk); we = 0;
    #1 assert(rdata == 32'haabb_ccdd) else $fatal(1, "full SRAM write failed");
    wdata = 32'h1122_3344; wstrb = 4'b0101; we = 1;
    @(negedge clk); we = 0;
    #1 assert(rdata == 32'haa22_cc44) else $fatal(1, "byte-enable SRAM write failed: %h", rdata);
    for(int a=0;a<16;a++) begin
      logic[31:0] expected;
      expected=$urandom;
      @(negedge clk);addr=a;we=1;wstrb=15;wdata=expected;
      @(negedge clk);we=0;
      for(int mask=0;mask<16;mask++) begin
        @(negedge clk);we=1;wstrb=mask;wdata=$urandom;
        for(int lane=0;lane<4;lane++) if(mask & (1<<lane)) expected[lane*8+:8]=wdata[lane*8+:8];
        @(negedge clk);we=0;#1;
        assert(rdata===expected) else $fatal(1,"SRAM address/mask a=%0d mask=%h",a,mask);
      end
    end
    $display("TB_SRAM PASS");
    $finish;
  end
  initial begin #100000;$fatal(1,"SRAM timeout");end
endmodule
