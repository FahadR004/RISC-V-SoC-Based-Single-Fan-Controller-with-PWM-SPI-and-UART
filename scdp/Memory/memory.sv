module Memory #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter DEPTH = 1024
) (
    input logic clk,
    input logic [ADDR_WIDTH-1:0] address, // alu result 
    input logic [2:0] funct3,
    input logic memRead,
    input logic memWrite,
    input logic [DATA_WIDTH-1:0] write_data, // read_data2 from register file

    output logic [DATA_WIDTH-1:0] mem_read_data // data read from memory
);

data_memory #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .DEPTH(DEPTH)
) data_mem (
    .clk(clk),
    .address(address),
    .funct3(funct3),
    .memRead(memRead),
    .memWrite(memWrite),
    .write_data(write_data),
    // Output of 
    .read_data(mem_read_data)
);


endmodule