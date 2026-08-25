module branch_adder_mux # (
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    // From Fetch
    input logic [ADDR_WIDTH-1:0] pc_current_addr,
    input logic [ADDR_WIDTH-1:0] pc_plus_4,
    
    // From Decode
    input logic branch,
    input logic jump,
    input logic jalr,
    input logic [2:0] funct3,
    input logic [DATA_WIDTH-1:0] immediate,
    input logic [DATA_WIDTH-1:0] rs1_data, // read_data1
    
    // From ALU
    input logic eq,
    input logic lt,
    input logic ltu,

    // Output
    output logic [ADDR_WIDTH-1:0] next_pc_address 
);

// Conditional Branches (branch)
// beq, bne etc

// Unconditional Branches 
// jal rd, offset (jump)
// Target Address = PC + Immediate Value
// Operation = rd <- PC + 4  and PC <- PC + Immediate

// jalr rd, rs1, offset (jalr)
// Target Address = rs1 + Immediate Value
// Operation = rd <- PC + 4 and PC <- (rs1 + offset (address calculation)) & 0xFFFF_FFFE (= 11..._1110 )(Forces LSB to zero)


logic branch_taken;
logic branch_cond;
logic [DATA_WIDTH-1:0] branch_target;
logic [DATA_WIDTH-1:0] jalr_target;

always @(*) begin
    case (funct3)
        3'b000: branch_cond = eq;        // BEQ
        3'b001: branch_cond = !eq;       // BNE
        3'b100: branch_cond = lt;        // BLT
        3'b101: branch_cond = !lt;       // BGE
        3'b110: branch_cond = ltu;       // BLTU
        3'b111: branch_cond = !ltu;      // BGEU
        default: branch_cond = 1'b0;
    endcase
end

assign branch_taken = (branch && branch_cond) || jump;

// PC-relative target for conditional branches + jal
assign branch_target = pc_current_addr + immediate;

// JALR target address
assign jalr_target = (rs1_data + immediate) & 32'hFFFF_FFFE;

assign next_pc_address = jalr ? jalr_target :
                         branch_taken ? branch_target :
                         pc_plus_4;

endmodule