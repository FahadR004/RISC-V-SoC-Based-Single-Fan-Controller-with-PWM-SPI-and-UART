`timescale 1ns/1ps
module tb_peripheral_edges;
  logic clk=0,reset_n=0,req=0,we=0;
  logic [31:0] addr=0,wdata=0,rdata;
  logic [3:0] strb=0;
  logic error,pwm,sclk,mosi,miso,cs,tx,rx=1;
  logic [7:0] spi_received,terminal_byte;
  logic spi_done,terminal_valid;
  int received_count=0;
  logic [7:0] last_terminal;
  always #5 clk=~clk;
  peripheral_subsystem dut(.clk,.reset_n,.bus_req(req),.bus_we(we),.bus_addr(addr),
    .bus_wdata(wdata),.bus_wstrb(strb),.bus_rdata(rdata),.bus_error(error),
    .fan_pwm(pwm),.spi_sclk(sclk),.spi_mosi(mosi),.spi_miso(miso),.spi_cs_n(cs),.uart_tx(tx),.uart_rx(rx));
  spi_slave_model #(.RESPONSE('h96)) slave(.sclk,.cs_n(cs),.mosi,.miso,.received(spi_received),.transaction_done(spi_done));
  uart_terminal_model #(.BAUD_DIV(8)) terminal(.clk,.reset_n,.serial_in(tx),.received_byte(terminal_byte),.byte_valid(terminal_valid));
  always @(posedge terminal_valid) begin last_terminal=terminal_byte;received_count++;end
  task automatic access(bit wr,logic [31:0] a,d,logic [3:0] s,bit err=0);
    @(negedge clk);req=1;we=wr;addr=a;wdata=d;strb=s;#1;
    assert(error===err) else $fatal(1,"address %h error expected %b got %b",a,err,error);
    @(negedge clk);req=0;we=0;
  endtask
  task automatic send_rx(byte value,int div,bit stop_good=1);
    @(negedge clk);#2;rx=0;
    #(div*10);
    for(int i=0;i<8;i++) begin rx=value[i];#(div*10);end
    rx=stop_good;#(div*10);rx=1;#(div*30);
  endtask
  initial begin
    repeat(3) @(negedge clk);reset_n=1;
    // Every undefined word in all peripheral windows must be rejected.
    for(int region=0;region<3;region++) begin
      for(int off=0;off<4096;off+=4) begin
        bit valid_offset;
        valid_offset=(region==0)?off<=12:((region==1)?off<=20:off<=16);
        access(0,'h40000000+region*4096+off,0,0,!valid_offset);
      end
    end
    // CPU byte addresses are normalized to a word address at the peripheral boundary.
    access(1,'h40000004,'h12345678,15);
    access(1,'h40000005,'h0000aa00,2);
    assert(dut.u_pwm.period_cycles=='h1234aa78) else $fatal(1,"MMIO byte address");
    access(1,'h40000004,8,15);access(1,'h40000008,0,15);access(1,'h40000000,1,15);
    repeat(16) begin @(negedge clk);assert(!pwm) else $fatal(1,"zero duty");end
    access(1,'h40000008,8,15);
    repeat(16) begin @(negedge clk);assert(pwm) else $fatal(1,"full duty");end
    for(int div=2;div<=5;div++) begin
      access(1,'h40001004,div,15);access(1,'h40001000,1,15);
      access(1,'h40001008,'ha5^div,1);
      access(1,'h40001004,9,15);
      assert(dut.u_spi.clk_div==div) else $fatal(1,"SPI busy divider changed");
      access(1,'h40001000,0,1);
      wait(!dut.u_spi.busy);@(negedge clk);
      assert(spi_received==('ha5^div) && spi_done && dut.u_spi.rx_data=='h96) else $fatal(1,"SPI transfer");
      repeat(3) @(negedge clk);
      assert(dut.u_spi.done) else $fatal(1,"SPI completion not sticky");
      access(1,'h40001010,12,0);
      assert(dut.u_spi.done && dut.u_spi.error_status) else $fatal(1,"SPI zero strobe");
      access(1,'h40001010,12,1);
    end
    access(1,'h40002004,8,15);access(1,'h40002000,1,1);access(1,'h40002008,'ha6,1);
    access(1,'h40002004,20,15);access(1,'h40002000,0,1);
    assert(dut.u_uart.baud_div==8 && dut.u_uart.enabled) else $fatal(1,"UART busy config changed");
    wait(!dut.u_uart.tx_busy);repeat(5) @(negedge clk);
    assert(received_count==1 && last_terminal=='ha6) else $fatal(1,"independent UART TX decoder");
    access(1,'h40002010,36,1);
    for(int div=4;div<=16;div+=2) begin
      access(1,'h40002004,div,15);
      send_rx(8'h81^div,div);
      assert(dut.u_uart.rx_valid && dut.u_uart.rx_data==(8'h81^div)) else $fatal(1,"UART independent RX div=%0d got=%h",div,dut.u_uart.rx_data);
      access(0,'h4000200c,0,0);
      assert(!dut.u_uart.rx_valid) else $fatal(1,"RX consume");
    end
    send_rx('h55,16,0);
    assert(dut.u_uart.framing_error) else $fatal(1,"framing error missing");
    access(1,'h40002010,16,0);assert(dut.u_uart.framing_error) else $fatal(1,"UART zero strobe");
    access(1,'h40002010,16,1);assert(!dut.u_uart.framing_error) else $fatal(1,"framing clear");
    send_rx('h11,16);send_rx('h22,16);
    assert(dut.u_uart.rx_data=='h11 && dut.u_uart.overrun_error) else $fatal(1,"RX overrun");
    access(1,'h4000200c,0,15,1);access(1,'h4000100c,0,15,1);access(1,'h40001014,0,15,1);
    access(1,'h40001008,'h55,1);access(1,'h40002008,'h55,1);
    @(negedge clk);reset_n=0;repeat(3) @(negedge clk);
    assert(cs && !sclk && tx && !pwm && !dut.u_uart.tx_busy && !dut.u_spi.busy) else $fatal(1,"active reset");
    reset_n=1;repeat(3) @(negedge clk);
    assert(!dut.u_uart.rx_valid && !dut.u_uart.overrun_error) else $fatal(1,"reset status");
    $display("TB_PERIPHERAL_EDGES PASS");$finish;
  end
  initial begin #1000000;$fatal(1,"peripheral edges timeout");end
endmodule
