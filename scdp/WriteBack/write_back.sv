module Write_Back #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
) (
    input logic memToReg,
    input logic [DATA_WIDTH-1:0] mem_read_data,
    input logic [DATA_WIDTH-1:0] alu_result,

    input logic jalr,
    input logic jump,
    input logic [ADDR_WIDTH-1:0] pc_plus_4,
    
    output logic [DATA_WIDTH-1:0] write_data
);

assign write_data = (jump || jalr) ? pc_plus_4 : memToReg ? mem_read_data : alu_result;
    
endmodule