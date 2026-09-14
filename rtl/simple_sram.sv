module simple_sram #(
  parameter int ADDR_WIDTH = 10,
  parameter string INIT_FILE = ""
) (
  input  logic                  clk,
  input  logic [ADDR_WIDTH-1:0] addr,
  input  logic                  we,
  input  logic [3:0]            wstrb,
  input  logic [31:0]           wdata,
  output logic [31:0]           rdata
);
  localparam int DEPTH = 1 << ADDR_WIDTH;
  logic [31:0] mem [0:DEPTH-1];

  initial begin
    if (INIT_FILE != "") $readmemh(INIT_FILE, mem);
  end

  always_comb rdata = mem[addr];

  // Plain clocked process permits verification backdoor preload while remaining synthesizable.
  always @(posedge clk) begin
    if (we) begin
      if (wstrb[0]) mem[addr][7:0]   <= wdata[7:0];
      if (wstrb[1]) mem[addr][15:8]  <= wdata[15:8];
      if (wstrb[2]) mem[addr][23:16] <= wdata[23:16];
      if (wstrb[3]) mem[addr][31:24] <= wdata[31:24];
    end
  end
endmodule
