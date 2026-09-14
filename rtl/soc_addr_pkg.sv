package soc_addr_pkg;
  localparam logic [31:0] IMEM_BASE   = 32'h0000_0000;
  localparam logic [31:0] IMEM_SIZE   = 32'h0000_1000;
  localparam logic [31:0] DMEM_BASE   = 32'h1000_0000;
  localparam logic [31:0] DMEM_SIZE   = 32'h0000_1000;
  localparam logic [31:0] CONFIG_BASE = 32'h2000_0000;
  localparam logic [31:0] CONFIG_SIZE = 32'h0000_0400;
  localparam logic [31:0] PWM_BASE    = 32'h4000_0000;
  localparam logic [31:0] SPI_BASE    = 32'h4000_1000;
  localparam logic [31:0] UART_BASE   = 32'h4000_2000;
  localparam logic [31:0] PERIPH_SIZE = 32'h0000_1000;
endpackage
