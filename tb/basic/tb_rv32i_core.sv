`timescale 1ns/1ps
module tb_rv32i_core;
  logic clk=0, reset_n=0;
  logic [31:0] imem_addr, imem_rdata;
  logic data_re, data_we;
  logic [31:0] data_addr, data_wdata, data_rdata;
  logic [3:0] data_wstrb;
  logic data_error;
  logic [31:0] debug_pc;
  logic trap, halted;
  logic imem_error;
  assign imem_error = imem_addr >= 256;
  logic [31:0] imem [0:63];
  logic [31:0] dmem [0:63];
  always #5 clk=~clk;

  assign imem_rdata = imem[imem_addr[7:2]];
  always_comb begin
    data_rdata = dmem[data_addr[7:2]];
    data_error = (data_re || data_we) &&
                 !(data_addr >= 32'h1000_0000 && data_addr < 32'h1000_0100);
  end
  always @(posedge clk) if (data_we && !data_error) begin
    for (int i=0; i<4; i++) if (data_wstrb[i])
      dmem[data_addr[7:2]][i*8 +: 8] <= data_wdata[i*8 +: 8];
  end

  rv32i_core dut (.*);

  initial begin
    for (int i=0; i<64; i++) begin imem[i]=32'h0000_0013; dmem[i]=0; end
    imem[0] = 32'h0050_0093; // addi x1,x0,5
    imem[1] = 32'h0070_0113; // addi x2,x0,7
    imem[2] = 32'h0020_81b3; // add  x3,x1,x2
    imem[3] = 32'h1000_0237; // lui  x4,0x10000
    imem[4] = 32'h0032_2023; // sw   x3,0(x4)
    imem[5] = 32'h0002_2283; // lw   x5,0(x4)
    imem[6] = 32'h0032_8463; // beq  x5,x3,+8
    imem[7] = 32'h0010_0313; // addi x6,x0,1 (skipped)
    imem[8] = 32'h0020_0313; // addi x6,x0,2
    imem[9] = 32'h0010_0073; // ebreak -> trap/halt
    repeat(3) @(negedge clk); reset_n=1;
    wait(halted);
    assert(trap) else $fatal(1, "core did not trap on EBREAK");
    assert(dut.regs[3] == 12) else $fatal(1, "ADD failed");
    assert(dmem[0] == 12 && dut.regs[5] == 12) else $fatal(1, "load/store failed");
    assert(dut.regs[6] == 2) else $fatal(1, "branch failed");
    assert(dut.regs[0] == 0) else $fatal(1, "x0 changed");
    $display("TB_RV32I_CORE PASS");
    $finish;
  end
  initial begin #100000; $fatal(1,"core timeout"); end
endmodule
