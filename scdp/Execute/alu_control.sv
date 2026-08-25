module alu_control_module (
    input logic [1:0] alu_op,
    input logic [2:0] funct3,
    input logic [6:0] funct7,
    input logic r_i_type_diff, // 5th Bit of Opcode
    output logic [3:0] alu_control
);

// R-Type
localparam ALU_ADD  = 4'b0000;
localparam ALU_SUB  = 4'b0001;
localparam ALU_SLL  = 4'b0010;
localparam ALU_SLT   = 4'b0011;
localparam ALU_SLTU  = 4'b0100;
localparam ALU_XOR  = 4'b0101;
localparam ALU_SRL  = 4'b0110;
localparam ALU_SRA  = 4'b0111;
localparam ALU_OR  = 4'b1000;
localparam ALU_AND = 4'b1001;

// I-Type (Arithmetic)
// localparam ALU_ADDI =  6'b001_010; // 00_0000
// localparam ALU_SLTI =  6'b001_011;
// localparam ALU_SLTIU =  6'b001_100;
// localparam ALU_XORI =  6'b001_101;
// localparam ALU_ORI =  6'b001_110;
// localparam ALU_ANDI = 6'b001_111;
// localparam ALU_SLLI = 6'b010_000;
// localparam ALU_SRLI = 6'b010_001;
// localparam ALU_SRAI = 6'b010_010;


// I-Type (Unconditional Branch) // REQUIRES ADDRESS ADDITION
// localparam ALU_JALR = 6'b100_010;

// J-Type  // DOES NOT USE ALU
// localparam ALU_JAL = 6'b100_001;


// U-Type
localparam ALU_LUI = 4'b1010;

// ONLY NEEDS ADDITION 
// localparam ALU_AUIPC = 6'b100_100;

// // Extra
// localparam ALU_FENCE = 
// localparam ALU_ECALL =
// localparam ALU_EBREAK =


always @(*) begin
    case (alu_op)
        2'b00: begin  // Load / Store / AUIPC / JALR
            alu_control = ALU_ADD;
        end
        
        2'b01: begin  // Conditional Branches -> Not needed anymore as ALU now continuously assigns flags of lt, ltu and eq on every cycle so the result calculation is not needed and branch_adder_mux uses the funct3 for resolution itself
            alu_control = ALU_SUB;
        end
        
        2'b10: begin  // R-type or I-type arithmetic
            case (funct3)
                3'b000: begin  // ADD/SUB
                    if (r_i_type_diff && funct7 == 7'b0100000)
                        alu_control = ALU_SUB;
                    else
                        alu_control = ALU_ADD;
                end
                3'b001: alu_control = ALU_SLL; // SLL or SLLI are the same as shamt is can only be in 5 bits
                3'b010: alu_control = ALU_SLT;
                3'b011: alu_control = ALU_SLTU;
                3'b100: alu_control = ALU_XOR;
                3'b101: begin  // SRL/SRA
                    if (funct7 == 7'b0100000)
                        alu_control = ALU_SRA;
                    else
                        alu_control = ALU_SRL;
                end
                3'b110: alu_control = ALU_OR;
                3'b111: alu_control = ALU_AND;
                default: alu_control = ALU_ADD;
            endcase
        end

        2'b11: begin // Load Upper Immediate
            alu_control = ALU_LUI;
        end
        default: alu_control = ALU_ADD;
    endcase
end

endmodule