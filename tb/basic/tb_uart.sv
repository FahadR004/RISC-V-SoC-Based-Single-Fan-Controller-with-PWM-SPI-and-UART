`timescale 1ns/1ps
module tb_uart;
  logic clk=0, reset_n=0;
  logic bus_req, bus_we;
  logic [11:0] bus_addr;
  logic [31:0] bus_wdata, bus_rdata;
  logic [3:0] bus_wstrb;
  logic bus_error, uart_tx, uart_rx, tx_busy, rx_valid;
  always #5 clk=~clk;
  assign uart_rx = uart_tx;

  uart dut (.*);

  task automatic write_reg(input logic [11:0] a, input logic [31:0] d);
    @(negedge clk); bus_req=1; bus_we=1; bus_addr=a; bus_wdata=d; bus_wstrb=4'hf;
    @(negedge clk); bus_req=0; bus_we=0;
  endtask

  initial begin
    bus_req=0; bus_we=0; bus_addr=0; bus_wdata=0; bus_wstrb=0;
    repeat(3) @(negedge clk); reset_n=1;
    write_reg(12'h004, 8);
    write_reg(12'h000, 1);
    write_reg(12'h008, 8'hc3);
    wait(rx_valid); @(negedge clk);
    bus_req=1; bus_we=0; bus_addr=12'h00c; #1;
    assert(bus_rdata[7:0] == 8'hc3) else $fatal(1, "UART loopback mismatch %h", bus_rdata[7:0]);
    @(negedge clk); bus_req=0;
    assert(!rx_valid) else $fatal(1, "UART RX valid did not clear on read");
    write_reg(12'h008, 8'h11);
    write_reg(12'h008, 8'h22);
    assert(dut.overrun_error) else $fatal(1, "UART busy-write error missing");
    $display("TB_UART PASS");
    $finish;
  end
  initial begin #100000; $fatal(1,"UART timeout"); end
endmodule
