module uart (
  input  logic        clk,
  input  logic        reset_n,
  input  logic        bus_req,
  input  logic        bus_we,
  input  logic [11:0] bus_addr,
  input  logic [31:0] bus_wdata,
  input  logic [3:0]  bus_wstrb,
  output logic [31:0] bus_rdata,
  output logic        bus_error,
  output logic        uart_tx,
  input  logic        uart_rx,
  output logic        tx_busy,
  output logic        rx_valid
);
  typedef enum logic [1:0] {RX_IDLE, RX_START, RX_DATA, RX_STOP} rx_state_t;
  logic        enabled;
  logic [15:0] baud_div;
  logic [15:0] tx_count;
  logic [3:0]  tx_bit;
  logic [9:0]  tx_shift;
  logic        tx_done;
  rx_state_t   rx_state;
  logic [15:0] rx_count;
  logic [2:0]  rx_bit;
  logic [7:0]  rx_shift;
  logic [7:0]  rx_data;
  logic        framing_error;
  logic        overrun_error;
  (* async_reg = "true" *) logic rx_meta, rx_sync;
  logic [15:0] merged_div;
  logic consume_rx;
  assign consume_rx = bus_req && !bus_we && !bus_error && bus_addr == 12'h00c;
  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin rx_meta <= 1'b1; rx_sync <= 1'b1; end
    else begin rx_meta <= uart_rx; rx_sync <= rx_meta; end
  end
  always_comb begin
    merged_div = baud_div;
    if (bus_wstrb[0]) merged_div[7:0] = bus_wdata[7:0];
    if (bus_wstrb[1]) merged_div[15:8] = bus_wdata[15:8];
  end

  always_comb begin
    bus_rdata = 32'b0;
    bus_error = 1'b0;
    unique case (bus_addr)
      6'h00: bus_rdata = {31'b0, enabled};
      6'h04: bus_rdata = {16'b0, baud_div};
      6'h08: bus_rdata = 32'b0;
      6'h0c: bus_rdata = {24'b0, rx_data};
      6'h10: bus_rdata = {26'b0, overrun_error, framing_error, rx_valid,
                          tx_done, tx_busy, enabled};
      default: if (bus_req) bus_error = 1'b1;
    endcase
    if (bus_req && bus_we && bus_addr == 12'h00c) bus_error = 1'b1;
  end

  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      enabled       <= 1'b0;
      baud_div      <= 16'd16;
      tx_count      <= 16'd0;
      tx_bit        <= 4'd0;
      tx_shift      <= 10'h3ff;
      uart_tx       <= 1'b1;
      tx_busy       <= 1'b0;
      tx_done       <= 1'b0;
      rx_state      <= RX_IDLE;
      rx_count      <= 16'd0;
      rx_bit        <= 3'd0;
      rx_shift      <= 8'd0;
      rx_data       <= 8'd0;
      rx_valid      <= 1'b0;
      framing_error <= 1'b0;
      overrun_error <= 1'b0;
    end else begin
      if (consume_rx) rx_valid <= 1'b0;
      if (tx_busy) begin
        if (tx_count == baud_div - 1) begin
          tx_count <= 16'd0;
          if (tx_bit == 4'd9) begin
            tx_busy <= 1'b0;
            tx_done <= 1'b1;
            uart_tx <= 1'b1;
          end else begin
            tx_bit   <= tx_bit + 1'b1;
            tx_shift <= {1'b1, tx_shift[9:1]};
            uart_tx  <= tx_shift[1];
          end
        end else tx_count <= tx_count + 1'b1;
      end

      if (!enabled) begin
        rx_state <= RX_IDLE;
        uart_tx  <= 1'b1;
      end else begin
        unique case (rx_state)
          RX_IDLE: if (!rx_sync) begin
            rx_count <= (baud_div >> 1) - 1'b1;
            rx_state <= RX_START;
          end
          RX_START: if (rx_count == 0) begin
            if (!rx_sync) begin
              rx_count <= baud_div - 1;
              rx_bit   <= 3'd0;
              rx_state <= RX_DATA;
            end else rx_state <= RX_IDLE;
          end else rx_count <= rx_count - 1'b1;
          RX_DATA: if (rx_count == 0) begin
            rx_shift[rx_bit] <= rx_sync;
            rx_count <= baud_div - 1;
            if (rx_bit == 3'd7) rx_state <= RX_STOP;
            else rx_bit <= rx_bit + 1'b1;
          end else rx_count <= rx_count - 1'b1;
          RX_STOP: if (rx_count == 0) begin
            if (!rx_sync) framing_error <= 1'b1;
            else if (rx_valid && !consume_rx) overrun_error <= 1'b1;
            else begin
              rx_data  <= rx_shift;
              rx_valid <= 1'b1;
            end
            rx_state <= RX_IDLE;
          end else rx_count <= rx_count - 1'b1;
        endcase
      end

      if (bus_req && bus_we && !bus_error) begin
        unique case (bus_addr[5:0])
          6'h00: if (bus_wstrb[0]) begin
            if (tx_busy || rx_state != RX_IDLE) overrun_error <= 1'b1;
            else enabled <= bus_wdata[0];
          end
          6'h04: if (bus_wstrb[0] || bus_wstrb[1]) begin
            if (tx_busy || rx_state != RX_IDLE) overrun_error <= 1'b1;
            else if (merged_div < 4) begin baud_div <= 16'd4; overrun_error <= 1'b1; end
            else baud_div <= merged_div;
          end
          6'h08: if (bus_wstrb[0]) begin
            if (enabled && !tx_busy) begin
              tx_shift <= {1'b1, bus_wdata[7:0], 1'b0};
              uart_tx  <= 1'b0;
              tx_count <= 16'd0;
              tx_bit   <= 4'd0;
              tx_busy  <= 1'b1;
              tx_done  <= 1'b0;
            end else overrun_error <= 1'b1;
          end
          6'h10: if (bus_wstrb[0]) begin
            if (bus_wdata[2]) tx_done       <= 1'b0;
            if (bus_wdata[3]) rx_valid      <= 1'b0;
            if (bus_wdata[4]) framing_error <= 1'b0;
            if (bus_wdata[5]) overrun_error <= 1'b0;
          end
          default: overrun_error <= 1'b1;
        endcase
      end
    end
  end
endmodule
