module Execute # (
    parameter ADDR_WIDTH = 32,
    parameter INSTR_WIDTH = 32, // 4 byte instruction
    parameter DATA_WIDTH = 32,
    parameter REG_NUMS = 32
) (
    // From Fetch
    input logic [ADDR_WIDTH-1:0] pc_current_addr,
    input logic [ADDR_WIDTH-1:0] pc_plus_4,
    
    // From Decode
    input logic aluSrc,
    input logic [1:0] aluOp,
    input logic [6:0] opcode,
    input logic [2:0] funct3,
    input logic [6:0] funct7,
    input logic branch,
    input logic jump,
    input logic jalr,
    input logic [DATA_WIDTH-1:0] read_data1,
    input logic [DATA_WIDTH-1:0] read_data2,
    input logic [DATA_WIDTH-1:0] immediate,
    
    // Output
    output logic [DATA_WIDTH-1:0] result,
    output logic [ADDR_WIDTH-1:0] next_pc_address
);

logic [3:0] alu_control;
logic [DATA_WIDTH-1:0]  alu_src_a;
logic [DATA_WIDTH-1:0] alu_src_b;
logic lt;
logic eq;
logic ltu;

// First ALU operand mux 
assign alu_src_a = (opcode == 7'h17) ? pc_current_addr : read_data1;

// Second ALU operand mux
assign alu_src_b = aluSrc ? immediate: read_data2; 

// ALU Control Module
alu_control_module alu_control_ (
    .alu_op(aluOp),
    .funct3(funct3),
    .funct7(funct7),
    .r_i_type_diff (opcode[5]),
    .alu_control(alu_control) // Output
);

// ALU
alu # (
    .DATA_WIDTH(DATA_WIDTH)
) alu_module (
    // Inputs
    .alu_control(alu_control),
    .alu_src_a(alu_src_a),
    .alu_src_b(alu_src_b),
    
    // Outputs
    .result(result),
    .eq(eq),
    .lt(lt),
    .ltu(ltu)
);

branch_adder_mux #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
) branch_adder_mux_module (
    .pc_current_addr(pc_current_addr),
    .pc_plus_4(pc_plus_4),
    .branch(branch),
    .jump(jump),  
    .jalr(jalr),
    .funct3(funct3),
    .immediate(immediate),
    .rs1_data (read_data1),
    .eq(eq),
    .lt(lt),
    .ltu(ltu),

    // Output
    .next_pc_address(next_pc_address)
);


endmodule