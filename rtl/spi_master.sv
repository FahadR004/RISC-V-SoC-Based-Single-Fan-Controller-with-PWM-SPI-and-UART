module spi_master (
  input  logic        clk,
  input  logic        reset_n,
  input  logic        bus_req,
  input  logic        bus_we,
  input  logic [11:0] bus_addr,
  input  logic [31:0] bus_wdata,
  input  logic [3:0]  bus_wstrb,
  output logic [31:0] bus_rdata,
  output logic        bus_error,
  output logic        spi_sclk,
  output logic        spi_mosi,
  input  logic        spi_miso,
  output logic        spi_cs_n,
  output logic        busy,
  output logic        done
);
  logic        enabled;
  logic [15:0] clk_div;
  logic [15:0] div_count;
  logic [7:0]  tx_shift;
  logic [7:0]  rx_shift;
  logic [7:0]  rx_data;
  logic [2:0]  bit_count;
  logic        error_status;
  logic [15:0] merged_div;
  always_comb begin
    merged_div = clk_div;
    if (bus_wstrb[0]) merged_div[7:0] = bus_wdata[7:0];
    if (bus_wstrb[1]) merged_div[15:8] = bus_wdata[15:8];
  end

  always_comb begin
    bus_rdata = 32'b0;
    bus_error = 1'b0;
    unique case (bus_addr)
      6'h00: bus_rdata = {31'b0, enabled};
      6'h04: bus_rdata = {16'b0, clk_div};
      6'h08: bus_rdata = {24'b0, tx_shift};
      6'h0c: bus_rdata = {24'b0, rx_data};
      6'h10: bus_rdata = {28'b0, error_status, done, busy, enabled};
      6'h14: bus_rdata = {31'b0, spi_cs_n};
      default: if (bus_req) bus_error = 1'b1;
    endcase
    if (bus_req && bus_we && (bus_addr == 12'h00c || bus_addr == 12'h014)) bus_error = 1'b1;
  end

  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      enabled      <= 1'b0;
      clk_div      <= 16'd2;
      div_count    <= 16'd0;
      tx_shift     <= 8'd0;
      rx_shift     <= 8'd0;
      rx_data      <= 8'd0;
      bit_count    <= 3'd0;
      error_status <= 1'b0;
      busy         <= 1'b0;
      done         <= 1'b0;
      spi_sclk     <= 1'b0;
      spi_mosi     <= 1'b0;
      spi_cs_n     <= 1'b1;
    end else begin
      if (busy) begin
        if (div_count == clk_div - 1) begin
          div_count <= 16'd0;
          if (!spi_sclk) begin
            spi_sclk <= 1'b1;
            rx_shift <= {rx_shift[6:0], spi_miso};
          end else begin
            spi_sclk <= 1'b0;
            if (bit_count == 3'd7) begin
              busy     <= 1'b0;
              done     <= 1'b1;
              spi_cs_n <= 1'b1;
              rx_data  <= rx_shift;
            end else begin
              bit_count <= bit_count + 1'b1;
              tx_shift  <= {tx_shift[6:0], 1'b0};
              spi_mosi  <= tx_shift[6];
            end
          end
        end else div_count <= div_count + 1'b1;
      end

      if (bus_req && bus_we && !bus_error) begin
        unique case (bus_addr[5:0])
          6'h00: if (bus_wstrb[0]) begin
            // An active transfer finishes; CTRL changes are rejected until idle.
            if (busy) error_status <= 1'b1;
            else enabled <= bus_wdata[0];
            if (bus_wdata[2:1] != 2'b00) error_status <= 1'b1;
          end
          6'h04: if (bus_wstrb[0] || bus_wstrb[1]) begin
            if (busy) error_status <= 1'b1;
            else if (merged_div < 2) begin
              clk_div <= 16'd2;
              error_status <= 1'b1;
            end else clk_div <= merged_div;
          end
          6'h08: if (bus_wstrb[0]) begin
            if (enabled && !busy) begin
              tx_shift  <= bus_wdata[7:0];
              rx_shift  <= 8'd0;
              bit_count <= 3'd0;
              div_count <= 16'd0;
              spi_mosi  <= bus_wdata[7];
              spi_sclk  <= 1'b0;
              spi_cs_n  <= 1'b0;
              busy      <= 1'b1;
              done      <= 1'b0;
            end else error_status <= 1'b1;
          end
          6'h10: if (bus_wstrb[0]) begin
            if (bus_wdata[3]) error_status <= 1'b0;
            if (bus_wdata[2]) done <= 1'b0;
          end
          default: error_status <= 1'b1;
        endcase
      end
    end
  end
endmodule
