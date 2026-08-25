module alu #( 
    parameter DATA_WIDTH = 32
) (
    input logic [3:0] alu_control,
    input logic [DATA_WIDTH-1:0] alu_src_a,
    input logic [DATA_WIDTH-1:0] alu_src_b,
    output logic [DATA_WIDTH-1:0] result,

    // FLAG OUTPUTS
    output logic lt,
    output logic ltu,
    output logic eq
);

localparam ALU_ADD  = 4'b0000;
localparam ALU_SUB  = 4'b0001;
localparam ALU_SLL  = 4'b0010;
localparam ALU_SLT  = 4'b0011;
localparam ALU_SLTU = 4'b0100;
localparam ALU_XOR  = 4'b0101;
localparam ALU_SRL  = 4'b0110;
localparam ALU_SRA  = 4'b0111;
localparam ALU_OR   = 4'b1000;
localparam ALU_AND  = 4'b1001;
localparam ALU_LUI  = 4'b1010;

logic signed [DATA_WIDTH-1:0] signed_a, signed_b;
assign signed_a = alu_src_a;
assign signed_b = alu_src_b;

always @(*) begin
    case (alu_control)
        ALU_ADD:  result = alu_src_a + alu_src_b;
        ALU_SUB:  result = alu_src_a - alu_src_b;
        ALU_AND:  result = alu_src_a & alu_src_b;
        ALU_OR:   result = alu_src_a | alu_src_b;
        ALU_XOR:  result = alu_src_a ^ alu_src_b;
        ALU_SLL:  result = alu_src_a << alu_src_b[4:0];
        ALU_SRL:  result = alu_src_a >> alu_src_b[4:0];
        ALU_SRA:  result = $signed(alu_src_a) >>> alu_src_b[4:0];
        ALU_SLT:  result = ($signed(alu_src_a) < $signed(alu_src_b)) ? 1 : 0;
        ALU_SLTU: result = (alu_src_a < alu_src_b) ? 1 : 0;
        ALU_LUI:  result = alu_src_b;
        default:  result = {DATA_WIDTH{1'b0}};
    endcase
end

assign lt = signed_a < signed_b;
assign ltu = alu_src_a < alu_src_b;
assign eq = alu_src_a == alu_src_b;

endmodule