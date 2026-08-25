module control_unit #(
    parameter ADDR_WIDTH  = 32,
    parameter INSTR_WIDTH = 32,
    parameter DATA_WIDTH  = 32,
    parameter REG_NUMS    = 32
) (
    input  logic [INSTR_WIDTH-1:0] instruction,

    // Control Signals Output
    output logic       branch,     // conditional branch (BEQ, BNE, ...)
    output logic       jump,       // unconditional jump, target = PC + imm (JAL)
    output logic       jalr,       // unconditional jump, target = rs1 + imm (JALR)
    output logic       memRead,
    output logic       memToReg,
    output logic [1:0] aluOp,    
    output logic       memWrite,
    output logic       aluSrc,
    output logic       regWrite,

    output logic [6:0] opcode,
    output logic [2:0] funct3,
    output logic [6:0] funct7
);

logic [6:0] opcode_bits;

assign opcode      = opcode_bits;
assign opcode_bits = instruction[6:0];
assign funct3      = instruction[14:12];
assign funct7      = instruction[31:25];

// OPCODES
// R-Type = 7'b011_0011 | 0x33 | 51
// (Arithmetic) I-Type = 7'b001_0011 | 0x13 | 19
// (Load) I-Type = 7'b000_0011 | 0x03 | 3
// S-Type = 7'b010_0011 | 0x23 | 35
// B-Type = 7'b110_0011 | 0x63 | 99
// (LUI) U-Type = 7'b011_0111 | 0x37 | 55 
// (AUIPC) U-Type = 7'b001_0111 | 0x17 | 23
// J-Type = 7'b110_1111 | 0x6F | 111
// (jalr) I-Type = 7'b110_0111 | 0x67 | 101

// aluOp == 00 -> For ADD (for load/store)
// aluOp == 01 -> For SUB (for branch)
// aluOp == 10 -> For R-type and I-type arithmetic (defer to funct3/funct7)
// aluOp == 11 -> For upper immediate

always_comb begin
    // Default
    branch   = 0;
    jump     = 0;
    jalr     = 0;
    memRead  = 0;
    memToReg = 0;
    aluOp    = 2'b00;
    memWrite = 0;
    aluSrc   = 0;
    regWrite = 0;

    case (opcode_bits)
        // Arithmetic (R-type)
        7'h33: begin  // ADD, SUB, AND, OR, XOR, SLL, SRL, SRA
            // branch   = 0;
            // jump     = 0;
            // jalr     = 0;
            // memRead  = 0;
            // memToReg = 0;
            aluOp    = 2'b10;   // defer to funct3/funct7 in alu_control
            // memWrite = 0;
            aluSrc   = 0;       // register
            regWrite = 1;
        end

        // Arithmetic Immediate (I-type)
        7'h13: begin  // ADDI, ANDI, ORI, XORI, SLTI, SLTIU, SLLI, SRLI, SRAI
            // branch   = 0;
            // jump     = 0;
            // jalr     = 0;
            // memRead  = 0;
            // memToReg = 0;
            aluOp    = 2'b10;   // defer to funct3/funct7 in alu_control
            // memWrite = 0;
            aluSrc   = 1;       // immediate
            regWrite = 1;
        end

        // Load Instructions (I-type)
        7'h03: begin  // LW, LB, LH, LBU, LHU
            // branch   = 0;
            // jump     = 0;
            // jalr     = 0;
            memRead  = 1;
            memToReg = 1;
            aluOp    = 2'b00;   // ADD (address calc)
            // memWrite = 0;
            aluSrc   = 1;       // immediate
            regWrite = 1;
        end

        // Store Instructions (S-type)
        7'h23: begin  // SW, SB, SH
            // branch   = 0;
            // jump     = 0;
            // jalr     = 0;
            // memRead  = 0;
            // memToReg = 0;
            aluOp    = 2'b00;   // ADD (address calc)
            memWrite = 1;
            aluSrc   = 1;       // immediate
            // regWrite = 0;
        end
        
        // Branch Instructions (B-type)
        7'h63: begin  // BEQ, BNE, BLT, BGE, BLTU, BGEU
            branch   = 1;
            // jump     = 0;
            // jalr     = 0;
            // memRead  = 0;
            // memToReg = 0;
            aluOp    = 2'b01;   // SUBTRACT (comparison)
            // memWrite = 0;
            aluSrc   = 0;       // register
            // regWrite = 0;
        end
        
        // Upper Immediate (U-type)
        7'h37: begin  // LUI
            // branch   = 0;
            // jump     = 0;
            // jalr     = 0;
            // memRead  = 0;
            // memToReg = 0;
            aluOp    = 2'b11;   // pass-through / load-upper-immediate
            // memWrite = 0;
            aluSrc   = 1;       // immediate
            regWrite = 1;
        end

        // Add Upper Immediate to PC (U-type)
        7'h17: begin  // AUIPC
            // branch   = 0;
            // jump     = 0;
            // jalr     = 0;
            // memRead  = 0;
            // memToReg = 0;
            aluOp    = 2'b00;   // ADD (PC + immediate)
            // memWrite = 0;
            aluSrc   = 1;       // immediate
            regWrite = 1;
        end

        // JAL (J-type)
        7'h6F: begin  // JAL
            // branch   = 0;
            jump     = 1;
            // jalr     = 0;
            // memRead  = 0;
            // memToReg = 0;
            // aluOp    = 2'b00;
            // memWrite = 0;
            // aluSrc   = 0;
            regWrite = 1;       // save return address (PC+4)
        end

           // JALR (I-type)
        7'h67: begin  // JALR
            // branch   = 0;
            // jump     = 0;
            jalr     = 1;
            // memRead  = 0;
            // memToReg = 0;
            aluOp    = 2'b00;   // ADD (rs1 + imm)
            // memWrite = 0;
            aluSrc   = 1;       // immediate
            regWrite = 1;       // save return address (PC+4)
        end

        // MISC-MEM (FENCE) — no-op: single-cycle, in-order, no reordering to fence
        7'h0F: begin
            // all defaults already correct (no state change)
        end

        // SYSTEM (ECALL/EBREAK) — no trap handling implemented yet
        7'h73: begin
            // TODO: implement trap/exception redirect if needed later;
            // currently a no-op — test programs relying on ecall for
            // pass/fail signaling will not behave as expected
        end
    endcase
end

endmodule