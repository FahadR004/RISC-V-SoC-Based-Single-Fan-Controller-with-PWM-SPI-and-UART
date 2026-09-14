module soc_interconnect (
  input  logic        core_re,
  input  logic        core_we,
  input  logic [31:0] core_addr,
  input  logic [31:0] core_wdata,
  input  logic [3:0]  core_wstrb,
  output logic [31:0] core_rdata,
  output logic        core_error,
  output logic        dmem_we,
  output logic [9:0]  dmem_addr,
  input  logic [31:0] dmem_rdata,
  output logic        config_we,
  output logic [7:0]  config_addr,
  input  logic [31:0] config_rdata,
  output logic        periph_req,
  output logic        periph_we,
  output logic [31:0] periph_addr,
  output logic [31:0] periph_wdata,
  output logic [3:0]  periph_wstrb,
  input  logic [31:0] periph_rdata,
  input  logic        periph_error
);
  import soc_addr_pkg::*;
  logic request, dmem_sel, config_sel, periph_sel;

  always_comb begin
    request      = core_re || core_we;
    dmem_sel     = request && core_addr >= DMEM_BASE && core_addr < DMEM_BASE + DMEM_SIZE;
    config_sel   = request && core_addr >= CONFIG_BASE && core_addr < CONFIG_BASE + CONFIG_SIZE;
    periph_sel   = request && core_addr >= PWM_BASE && core_addr < UART_BASE + PERIPH_SIZE;
    dmem_we      = core_we && dmem_sel;
    dmem_addr    = (core_addr - DMEM_BASE) >> 2;
    config_we    = core_we && config_sel;
    config_addr  = (core_addr - CONFIG_BASE) >> 2;
    periph_req   = periph_sel;
    periph_we    = core_we;
    periph_addr  = core_addr;
    periph_wdata = core_wdata;
    periph_wstrb = core_wstrb;
    core_rdata   = 32'b0;
    core_error   = request && !(dmem_sel || config_sel || periph_sel);
    if (dmem_sel) core_rdata = dmem_rdata;
    if (config_sel) core_rdata = config_rdata;
    if (periph_sel) begin
      core_rdata = periph_rdata;
      core_error = periph_error;
    end
  end
endmodule
