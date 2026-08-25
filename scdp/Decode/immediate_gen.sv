module immediate_generator #(
    parameter DATA_WIDTH = 32
) (
    input logic [DATA_WIDTH-1:0] instruction,

    output logic [DATA_WIDTH-1:0] immediate
);

logic [6:0] opcode;
assign opcode = instruction[6:0];

// See README.md / Control Unit File for OpCode Table reference

always @(*) begin
    case (opcode)
        7'h13, // I-type (ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI)
        7'h03, // I-type (LW, LB, LH, LBU, LHU)
        7'h67: begin // I-type (JALR)
            immediate = {{20{instruction[31]}}, instruction[31:20]};
        end

        7'h23: begin // S-type (SW, SB, SH)
            immediate = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
        end

        7'h63: begin // B-type (BEQ, BNE, BLT, BGE, BLTU, BGEU)
            immediate = {{20{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0};
        end

        7'h37, // U-type (LUI)
        7'h17: begin // U-type (AUIPC)
            immediate = {instruction[31:12], 12'b0};
        end

        7'h6F: begin // J-type (JAL)
            immediate = {{12{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21], 1'b0};
        end

        default: begin
            immediate = {DATA_WIDTH{1'b0}};
        end
    endcase
end

endmodule