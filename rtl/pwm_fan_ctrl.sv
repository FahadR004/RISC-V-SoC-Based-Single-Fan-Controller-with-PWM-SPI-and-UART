module pwm_fan_ctrl (
  input  logic        clk,
  input  logic        reset_n,
  input  logic        bus_req,
  input  logic        bus_we,
  input  logic [11:0] bus_addr,
  input  logic [31:0] bus_wdata,
  input  logic [3:0]  bus_wstrb,
  output logic [31:0] bus_rdata,
  output logic        bus_error,
  output logic        pwm_out,
  output logic        enabled,
  output logic [31:0] period_cycles,
  output logic [31:0] duty_cycles
);
  logic [31:0] counter;
  logic        config_error;

  function automatic logic [31:0] merge_bytes(
    input logic [31:0] old_value,
    input logic [31:0] new_value,
    input logic [3:0] strobes
  );
    logic [31:0] value;
    value = old_value;
    for (int i = 0; i < 4; i++)
      if (strobes[i]) value[i*8 +: 8] = new_value[i*8 +: 8];
    return value;
  endfunction

  always_comb begin
    bus_rdata = 32'b0;
    bus_error = bus_req && (bus_addr[11:4] != 8'h00);
    unique case (bus_addr[3:0])
      4'h0: bus_rdata = {31'b0, enabled};
      4'h4: bus_rdata = period_cycles;
      4'h8: bus_rdata = duty_cycles;
      4'hc: bus_rdata = {29'b0, config_error, pwm_out, enabled};
      default: begin
        bus_rdata = 32'b0;
        if (bus_req) bus_error = 1'b1;
      end
    endcase
  end

  always_ff @(posedge clk or negedge reset_n) begin : p_pwm
    logic [31:0] candidate;
    if (!reset_n) begin
      enabled       <= 1'b0;
      period_cycles <= 32'd100;
      duty_cycles   <= 32'd0;
      counter       <= 32'd0;
      config_error  <= 1'b0;
    end else begin
      if (!enabled || counter >= period_cycles - 1) counter <= 32'd0;
      else counter <= counter + 1'b1;

      if (bus_req && bus_we && !bus_error && |bus_wstrb) begin
        unique case (bus_addr[3:0])
          4'h0: begin
            candidate = merge_bytes({31'b0, enabled}, bus_wdata, bus_wstrb);
            enabled <= candidate[0];
            if (!candidate[0]) counter <= 32'd0;
          end
          4'h4: begin
            candidate = merge_bytes(period_cycles, bus_wdata, bus_wstrb);
            if (candidate < 2) begin
              period_cycles <= 32'd2;
              if (duty_cycles > 2) duty_cycles <= 32'd2;
              config_error  <= 1'b1;
            end else begin
              period_cycles <= candidate;
              if (duty_cycles > candidate) duty_cycles <= candidate;
            end
            counter <= 32'd0;
          end
          4'h8: begin
            candidate = merge_bytes(duty_cycles, bus_wdata, bus_wstrb);
            if (candidate > period_cycles) begin
              duty_cycles  <= period_cycles;
              config_error <= 1'b1;
            end else duty_cycles <= candidate;
          end
          4'hc: if (bus_wstrb[0] && bus_wdata[2]) config_error <= 1'b0;
          default: config_error <= 1'b1;
        endcase
      end
    end
  end

  always_comb pwm_out = enabled && (counter < duty_cycles);
endmodule
