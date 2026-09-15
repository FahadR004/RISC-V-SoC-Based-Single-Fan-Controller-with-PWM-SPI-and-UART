module uart_terminal_model #(
  parameter int BAUD_DIV = 16
) (
  input logic clk,
  input logic reset_n,
  input logic serial_in,
  output logic [7:0] received_byte,
  output logic byte_valid
);
  initial begin
    if(BAUD_DIV<4) $fatal(1,"UART terminal divider must be at least four");
    received_byte=0;byte_valid=0;
    forever begin
      @(negedge serial_in);
      if(reset_n) begin
        fork
          begin
            repeat(BAUD_DIV+BAUD_DIV/2) @(negedge clk);
            for(int i=0;i<8;i++) begin
              received_byte[i]=serial_in;repeat(BAUD_DIV) @(negedge clk);
            end
            if(serial_in!==1'b1) $error("UART terminal: invalid stop bit");
            byte_valid=1;
            @(negedge clk);
          end
          begin @(negedge reset_n);end
        join_any
        disable fork;
        byte_valid=0;
      end
    end
  end
endmodule
