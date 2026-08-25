module pc_adder # (
    parameter ADDR_WIDTH = 32
) (
    input logic [ADDR_WIDTH-1:0] curr_pc,
    output logic [ADDR_WIDTH-1:0] pc_plus_4
);

assign pc_plus_4 = curr_pc + ADDR_WIDTH'(3'd4);

endmodule