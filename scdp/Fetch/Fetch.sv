module Fetch # (
    parameter ADDR_WIDTH = 32, 
    parameter INSTR_WIDTH = 32,
    parameter DEPTH = 1024
) (
    input logic clk,
    input logic rst_n,
    input logic [ADDR_WIDTH-1:0] next_pc, // PC+4 from adder to increment PC value
    output logic [INSTR_WIDTH-1:0] instruction, // Output of the Fetch Stage is a 32-bit instruction
    output logic [ADDR_WIDTH-1:0] current_pc
);

logic [ADDR_WIDTH-1:0] pc_current_addr; // From PC to Instruction Memory

pc_register # (
    .ADDR_WIDTH(ADDR_WIDTH)
) pc (
    .clk(clk),
    .rst_n(rst_n),
    .next_pc(next_pc), // Incoming PC+4 value from adder
    .pc_current(pc_current_addr)
);

instr_memory # (
    .ADDR_WIDTH(ADDR_WIDTH),
    .INSTR_WIDTH(INSTR_WIDTH),
    .DEPTH(DEPTH)
) instr_mem (
    .pc_address(pc_current_addr),
    .instruction(instruction) // Output of the Fetch Stage is a 32-bit instruction
);

assign current_pc = pc_current_addr ;

    
endmodule