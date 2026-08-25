module top_rv32_scdp # (
    parameter ADDR_WIDTH = 32,
    parameter INSTR_WIDTH = 32, // 4 byte instruction
    parameter DATA_WIDTH = 32, 
    parameter REG_NUMS = 32,
    parameter DEPTH = 1024
) (
    input logic clk,
    input logic rst_n
);

// Fetch
logic [ADDR_WIDTH-1:0] pc_plus_4;

logic [ADDR_WIDTH-1:0] next_pc;
logic [INSTR_WIDTH-1:0] instruction;
logic [ADDR_WIDTH-1:0] pc_current_addr;

// Decode
// instruction input to decode "stage" from fetch 
logic [DATA_WIDTH-1:0] write_data;

logic branch;
logic jump;
logic jalr;
logic memRead;
logic memToReg;
logic [1:0] aluOp;
logic memWrite;
logic aluSrc;
logic regWrite;


logic [DATA_WIDTH-1:0] read_data1;
logic [DATA_WIDTH-1:0] read_data2;
logic [DATA_WIDTH-1:0] immediate;
logic [6:0] opcode;
logic [2:0] funct3;
logic [6:0] funct7;

// Execute Stage
logic [DATA_WIDTH-1:0] alu_result;

// Memory Stage
logic [DATA_WIDTH-1:0] mem_read_data;



pc_adder #(
    .ADDR_WIDTH(ADDR_WIDTH)
) pc_adder_inst (
    .curr_pc(pc_current_addr),
    .pc_plus_4(pc_plus_4)
);

// // Temporarily connected it as is. Will later be a mux
// assign next_pc = pc_plus_4;

Fetch # (
    .ADDR_WIDTH(ADDR_WIDTH),
    .INSTR_WIDTH(INSTR_WIDTH),
    .DEPTH(DEPTH)
) fetch_stage (
    .clk(clk),
    .rst_n(rst_n),
    .next_pc(next_pc), // PC+4 from adder to increment PC value
    .instruction(instruction), // Output of the Fetch Stage is a 32-bit instruction
    .current_pc(pc_current_addr) // Output of the Fetch Stage also includs the current PC address
);

Decode #(
.ADDR_WIDTH(ADDR_WIDTH),
.INSTR_WIDTH(INSTR_WIDTH),
.DATA_WIDTH(DATA_WIDTH),
.REG_NUMS(REG_NUMS)
) decode_stage (
    // Inputs
    .clk(clk),
    .rst_n(rst_n),
    
    // Input from 
    .instruction(instruction),
    .write_data(write_data),
    .branch(branch),
    .jump(jump),
    .jalr(jalr),
    .memRead(memRead),
    .memToReg(memToReg),
    .aluOp(aluOp),
    .memWrite(memWrite),
    .aluSrc(aluSrc),
    .regWrite(regWrite),
    .read_data1(read_data1),
    .read_data2(read_data2),
    .immediate(immediate),
    .opcode(opcode),
    .funct3(funct3),
    .funct7(funct7)
);

Execute #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .INSTR_WIDTH(INSTR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .REG_NUMS(REG_NUMS)
) execute_stage (
    // Input from Fetch Stage
    .pc_current_addr(pc_current_addr),
    .pc_plus_4(pc_plus_4),

    // Input from Decode Stage
    .aluSrc(aluSrc),
    .aluOp(aluOp),
    .opcode(opcode),
    .funct3(funct3),
    .funct7(funct7),
    .branch(branch),
    .jump(jump),
    .jalr(jalr),
    .read_data1(read_data1),
    .read_data2(read_data2),
    .immediate(immediate),

    // Output of the Execute Stage
    .result(alu_result),
    .next_pc_address (next_pc)
);

Memory #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .DEPTH(DEPTH)
) memory_stage (
    // Inputs
    .clk(clk),
    .address(alu_result),
    .memRead(memRead),
    .memWrite(memWrite),
    .funct3(funct3),
    // Output of Register File as input to Memory Stage
    .write_data(read_data2),
    // Output of the Memory Stage
    .mem_read_data(mem_read_data)
);

Write_Back # (
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
) write_back_stage (
    // Inputs
    .memToReg(memToReg),
    .mem_read_data(mem_read_data),
    .alu_result(alu_result),
    .jalr(jalr),
    .jump(jump),
    .pc_plus_4(pc_plus_4),
    // Output
    .write_data(write_data)
);

endmodule