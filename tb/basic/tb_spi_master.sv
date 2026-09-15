`timescale 1ns/1ps
module tb_spi_master;
  logic clk=0, reset_n=0;
  logic bus_req, bus_we;
  logic [11:0] bus_addr;
  logic [31:0] bus_wdata, bus_rdata;
  logic [3:0] bus_wstrb;
  logic bus_error, spi_sclk, spi_mosi, spi_miso, spi_cs_n, busy, done;
  logic [7:0] received;
  logic transaction_done;
  always #5 clk=~clk;

  spi_master dut (.*);
  spi_slave_model #(.RESPONSE(8'h3c)) slave (
    .sclk(spi_sclk), .cs_n(spi_cs_n), .mosi(spi_mosi), .miso(spi_miso),
    .received, .transaction_done
  );

  task automatic write_reg(input logic [11:0] a, input logic [31:0] d);
    @(negedge clk); bus_req=1; bus_we=1; bus_addr=a; bus_wdata=d; bus_wstrb=4'hf;
    @(negedge clk); bus_req=0; bus_we=0;
  endtask

  initial begin
    bus_req=0; bus_we=0; bus_addr=0; bus_wdata=0; bus_wstrb=0;
    repeat(3) @(negedge clk); reset_n=1;
    write_reg(12'h004, 2);
    write_reg(12'h000, 1);
    write_reg(12'h008, 8'ha5);
    wait(done); @(negedge clk);
    bus_req=1; bus_we=0; bus_addr=12'h00c; #1;
    assert(bus_rdata[7:0] == 8'h3c) else $fatal(1, "SPI RX mismatch %h", bus_rdata[7:0]);
    assert(received == 8'ha5) else $fatal(1, "SPI TX mismatch %h", received);
    bus_req=0;
    write_reg(12'h008, 8'h55);
    write_reg(12'h008, 8'haa);
    assert(dut.error_status) else $fatal(1, "SPI busy-write error missing");
    $display("TB_SPI PASS");
    $finish;
  end
  initial begin #100000; $fatal(1,"SPI timeout"); end
endmodule
