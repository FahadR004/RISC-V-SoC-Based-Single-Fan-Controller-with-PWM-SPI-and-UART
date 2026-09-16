module peripheral_subsystem (
  input  logic        clk,
  input  logic        reset_n,
  input  logic        bus_req,
  input  logic        bus_we,
  input  logic [31:0] bus_addr,
  input  logic [31:0] bus_wdata,
  input  logic [3:0]  bus_wstrb,
  output logic [31:0] bus_rdata,
  output logic        bus_error,
  output logic        fan_pwm,
  output logic        spi_sclk,
  output logic        spi_mosi,
  input  logic        spi_miso,
  output logic        spi_cs_n,
  output logic        uart_tx,
  input  logic        uart_rx
);
  import soc_addr_pkg::*;
  logic pwm_sel, spi_sel, uart_sel;
  logic [31:0] pwm_rdata, spi_rdata, uart_rdata;
  logic pwm_error, spi_error, uart_error;
  logic unused_pwm_en, unused_spi_busy, unused_spi_done;
  logic unused_uart_busy, unused_uart_valid;
  logic [31:0] unused_period, unused_duty;

  always_comb begin
    pwm_sel  = bus_req && bus_addr >= PWM_BASE  && bus_addr < PWM_BASE  + PERIPH_SIZE;
    spi_sel  = bus_req && bus_addr >= SPI_BASE  && bus_addr < SPI_BASE  + PERIPH_SIZE;
    uart_sel = bus_req && bus_addr >= UART_BASE && bus_addr < UART_BASE + PERIPH_SIZE;
    bus_rdata = 32'b0;
    bus_error = bus_req && !(pwm_sel || spi_sel || uart_sel);
    if (pwm_sel) begin bus_rdata = pwm_rdata; bus_error = pwm_error; end
    if (spi_sel) begin bus_rdata = spi_rdata; bus_error = spi_error; end
    if (uart_sel) begin bus_rdata = uart_rdata; bus_error = uart_error; end
  end

  pwm_fan_ctrl u_pwm (
    .clk, .reset_n, .bus_req(pwm_sel), .bus_we,
    .bus_addr({bus_addr[11:2],2'b00}), .bus_wdata, .bus_wstrb,
    .bus_rdata(pwm_rdata), .bus_error(pwm_error), .pwm_out(fan_pwm),
    .enabled(unused_pwm_en), .period_cycles(unused_period), .duty_cycles(unused_duty)
  );

  spi_master u_spi (
    .clk, .reset_n, .bus_req(spi_sel), .bus_we,
    .bus_addr({bus_addr[11:2],2'b00}), .bus_wdata, .bus_wstrb,
    .bus_rdata(spi_rdata), .bus_error(spi_error), .spi_sclk, .spi_mosi,
    .spi_miso, .spi_cs_n, .busy(unused_spi_busy), .done(unused_spi_done)
  );

  uart u_uart (
    .clk, .reset_n, .bus_req(uart_sel), .bus_we,
    .bus_addr({bus_addr[11:2],2'b00}), .bus_wdata, .bus_wstrb,
    .bus_rdata(uart_rdata), .bus_error(uart_error), .uart_tx, .uart_rx,
    .tx_busy(unused_uart_busy), .rx_valid(unused_uart_valid)
  );
endmodule
