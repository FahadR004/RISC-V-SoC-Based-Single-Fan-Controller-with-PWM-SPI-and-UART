module pc_register #(
    parameter ADDR_WIDTH = 32
) (
    input logic clk,
    input logic rst_n,
    input logic [ADDR_WIDTH-1:0] next_pc, // Next PC value (Byte Address)
    output logic [ADDR_WIDTH-1:0] pc_current // Current PC value (Byte Address)
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pc_current <= {ADDR_WIDTH{1'b0}};  // Reset 
        else
            pc_current <= next_pc;  // Update to next PC value            
    end

endmodule