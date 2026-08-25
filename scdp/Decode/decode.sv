module Decode #(
    parameter ADDR_WIDTH = 32,
    parameter INSTR_WIDTH = 32, // 4 byte instruction
    parameter DATA_WIDTH = 32,
    parameter REG_NUMS = 32
) (
    input logic clk,
    input logic rst_n,
    input logic [INSTR_WIDTH-1:0] instruction,
    input logic [DATA_WIDTH-1:0] write_data, // For Write Back

    // Control Signals
    output logic branch,
    output logic jump,
    output logic jalr,
    output logic memRead,
    output logic memToReg,
    output logic [1:0] aluOp,
    output logic memWrite, 
    output logic aluSrc,
    output logic regWrite, // XXXXX

    // Register File Input
    output logic [DATA_WIDTH-1:0] read_data1,
    output logic [DATA_WIDTH-1:0] read_data2,

    // Immediate Generator Output
    output logic [ADDR_WIDTH-1:0] immediate,
    
    // For ALU OP
    output logic [6:0] opcode,
    output logic [2:0] funct3,
    output logic [6:0] funct7
);

// Register File Input
logic [$clog2(REG_NUMS)-1:0] read_reg1; // rs1
logic [$clog2(REG_NUMS)-1:0] read_reg2; // rs2
logic [$clog2(REG_NUMS)-1:0] write_reg; // rd

assign read_reg1 = instruction[19:15];
assign read_reg2 = instruction[24:20];
assign write_reg = instruction[11:7];

control_unit #(
    .ADDR_WIDTH (ADDR_WIDTH),
    .INSTR_WIDTH (INSTR_WIDTH),
    .DATA_WIDTH (DATA_WIDTH),
    .REG_NUMS (REG_NUMS)
) cu (
    .instruction (instruction),
    .branch      (branch),
    .jump        (jump),
    .jalr        (jalr),
    .memRead     (memRead),
    .memToReg    (memToReg),
    .aluOp       (aluOp),
    .memWrite    (memWrite),
    .aluSrc      (aluSrc),
    .regWrite    (regWrite),
    .opcode      (opcode),
    .funct3      (funct3),
    .funct7      (funct7)
);

register_file #(
    .DATA_WIDTH (DATA_WIDTH),
    .REG_NUMS (REG_NUMS)
) reg_file (
   .clk(clk),
   .rst_n(rst_n),
   .read_reg1(read_reg1),
   .read_reg2(read_reg2),
   .write_reg(write_reg),
   .write_data(write_data),
   .regWrite(regWrite),
   .read_data1(read_data1),
   .read_data2(read_data2)
);

immediate_generator #(
    .DATA_WIDTH(DATA_WIDTH)
) imm_gen (
    .instruction(instruction),
    .immediate  (immediate)
);
    
endmodule