`timescale 1ns/1ps
module tb_interconnect;
  logic core_re=0,core_we=0;
  logic[31:0] core_addr=0,core_wdata='h12345678,core_rdata;
  logic[3:0] core_wstrb=5;
  logic core_error,dmem_we,config_we,periph_req,periph_we,periph_error=0;
  logic[9:0] dmem_addr;
  logic[7:0] config_addr;
  logic[31:0] dmem_rdata='h11111111,config_rdata='h22222222,periph_rdata='h33333333,periph_addr,periph_wdata;
  logic[3:0] periph_wstrb;
  soc_interconnect dut(.*);
  task automatic check(logic[31:0] a,int region);
    core_addr=a;#1;
    assert(core_error== (region==0)) else $fatal(1,"decode error %h",a);
    assert(dmem_we==(core_we && region==1) && config_we==(core_we && region==2) && periph_req==(region==3)) else $fatal(1,"decode select %h",a);
    if(region==1) assert(core_rdata==dmem_rdata && dmem_addr==((a-'h10000000)>>2)) else $fatal(1,"data SRAM path");
    if(region==2) assert(core_rdata==config_rdata && config_addr==((a-'h20000000)>>2)) else $fatal(1,"config SRAM path");
    if(region==3) assert(core_rdata==periph_rdata && periph_addr==a && periph_wstrb==5 && periph_wdata==core_wdata) else $fatal(1,"peripheral path");
  endtask
  initial begin
    for(int wr=0;wr<2;wr++) begin
      core_we=wr;core_re=!wr;
      check(0,0);check('h0fffffff,0);check('h10000000,1);check('h10000fff,1);check('h10001000,0);
      check('h1fffffff,0);check('h20000000,2);check('h200003ff,2);check('h20000400,0);
      check('h3fffffff,0);check('h40000000,3);check('h40001000,3);check('h40002fff,3);check('h40003000,0);check('hffffffff,0);
    end
    core_addr='h40000000;periph_error=1;#1;assert(core_error) else $fatal(1,"error propagation");
    core_we=0;core_re=0;#1;assert(!core_error && !periph_req && !dmem_we && !config_we) else $fatal(1,"idle decode");
    $display("TB_INTERCONNECT PASS");$finish;
  end
endmodule
