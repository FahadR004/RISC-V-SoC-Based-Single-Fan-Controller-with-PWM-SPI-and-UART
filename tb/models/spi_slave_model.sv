module spi_slave_model #(
  parameter logic [7:0] RESPONSE = 8'h3c
) (
  input  logic sclk,
  input  logic cs_n,
  input  logic mosi,
  output logic miso,
  output logic [7:0] received,
  output logic transaction_done
);
  logic [7:0] response_shift;
  logic [2:0] bit_count;

  initial begin
    miso = RESPONSE[7];
    received = 8'b0;
    response_shift = RESPONSE;
    bit_count = 3'd0;
    transaction_done = 1'b0;
  end

  always @(negedge cs_n) begin
    response_shift = RESPONSE;
    bit_count = 3'd0;
    miso = RESPONSE[7];
    transaction_done = 1'b0;
  end

  // Completion is recorded on the eighth sample edge, before CS release.
  always @(posedge sclk) if (!cs_n) begin
    received = {received[6:0], mosi};
    if (bit_count == 3'd7) transaction_done = 1'b1;
  end

  always @(negedge sclk) if (!cs_n) begin
    if (bit_count == 3'd7) transaction_done = 1'b1;
    else begin
      bit_count = bit_count + 1'b1;
      response_shift = {response_shift[6:0], 1'b0};
      miso = response_shift[7];
    end
  end
endmodule
