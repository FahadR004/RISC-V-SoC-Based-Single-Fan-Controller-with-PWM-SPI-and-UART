module register_file #(
    parameter DATA_WIDTH = 32,
    parameter REG_NUMS = 32
) ( 
    input logic clk,
    input logic rst_n,
    // Register Numbers
    input logic [$clog2(REG_NUMS)-1:0] read_reg1, // rs1
    input logic [$clog2(REG_NUMS)-1:0] read_reg2, // rs2
    input logic [$clog2(REG_NUMS)-1:0] write_reg,

    // WriteBack Data
    input logic [DATA_WIDTH-1:0] write_data,

    // Control Signals
    input logic regWrite,

    // Output of the Register File
    output logic [DATA_WIDTH-1:0] read_data1,
    output logic [DATA_WIDTH-1:0] read_data2
);

logic [DATA_WIDTH-1:0] registers [REG_NUMS-1:0];

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (int i = 0; i < REG_NUMS; i++)
            registers[i] <= '0;
    end else if (regWrite && write_reg != '0) begin
        registers[write_reg] <= write_data;
    end
end

assign read_data1 = (read_reg1 == '0) ? '0 : registers[read_reg1];
assign read_data2 = (read_reg2 == '0) ? '0 : registers[read_reg2];

endmodule