`timescale 1ns/1ps
module tb_pwm;
  logic clk = 0, reset_n = 0;
  logic bus_req, bus_we;
  logic [11:0] bus_addr;
  logic [31:0] bus_wdata, bus_rdata;
  logic [3:0] bus_wstrb;
  logic bus_error, pwm_out, enabled;
  logic [31:0] period_cycles, duty_cycles;
  always #5 clk = ~clk;

  pwm_fan_ctrl dut (.*);

  task automatic write_reg(input logic [11:0] a, input logic [31:0] d);
    @(negedge clk); bus_req=1; bus_we=1; bus_addr=a; bus_wdata=d; bus_wstrb=4'hf;
    @(negedge clk); bus_req=0; bus_we=0;
  endtask

  initial begin
    bus_req=0; bus_we=0; bus_addr=0; bus_wdata=0; bus_wstrb=0;
    repeat(3) @(negedge clk); reset_n=1;
    write_reg(12'h004, 10);
    write_reg(12'h008, 3);
    write_reg(12'h000, 1);
    repeat(2) @(posedge clk);
    begin
      automatic int highs = 0;
      for (int i=0; i<20; i++) begin @(negedge clk); if (pwm_out) highs++; end
      assert(highs == 6) else $fatal(1, "PWM expected 6 high cycles, got %0d", highs);
    end
    write_reg(12'h008, 15);
    assert(duty_cycles == 10) else $fatal(1, "PWM duty did not clamp");
    assert(dut.config_error) else $fatal(1, "PWM error status not set");
    write_reg(12'h00c, 4);
    assert(!dut.config_error) else $fatal(1, "PWM error status did not clear");
    $display("TB_PWM PASS");
    $finish;
  end

  assert property (@(posedge clk) disable iff(!reset_n) pwm_out |-> enabled);
  initial begin #100000; $fatal(1,"PWM timeout"); end
endmodule
