module virtual_fan_model #(
  parameter int SAMPLE_CYCLES = 1000,
  parameter int MAX_RPM = 5000
) (
  input  logic clk,
  input  logic reset_n,
  input  logic pwm_in,
  output logic [31:0] rpm_estimate
);
  int unsigned sample_count;
  int unsigned high_count;
  initial begin
    if(SAMPLE_CYCLES<1 || MAX_RPM<0) $fatal(1,"invalid virtual fan parameters");
  end

  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      sample_count <= 0;
      high_count <= 0;
      rpm_estimate <= 0;
    end else if (sample_count == SAMPLE_CYCLES-1) begin
      rpm_estimate <= ((64'(high_count) + (pwm_in ? 1 : 0)) * MAX_RPM) / SAMPLE_CYCLES;
      sample_count <= 0;
      high_count <= 0;
    end else begin
      sample_count <= sample_count + 1;
      if (pwm_in) high_count <= high_count + 1;
    end
  end
endmodule
