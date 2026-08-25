module data_memory #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter DEPTH      = 1024
)(
    input  logic clk,
    input logic [ADDR_WIDTH-1:0] address, // byte address
    input logic [2:0] funct3,  // load/store width + signedness
    input logic memRead,
    input logic memWrite,
    input logic [DATA_WIDTH-1:0] write_data,

    output logic [DATA_WIDTH-1:0] read_data
);

logic [DATA_WIDTH-1:0] memory [0:DEPTH-1];

// Byte to word address conversion
logic [$clog2(DEPTH)-1:0] word_address;
assign word_address = address[$clog2(DEPTH)+1 : 2]; // $clog2(1024) returns 10. We require 10 bits to address 1024 words. 
// However, if we did 10:2, then we would only have 9-bits. Hence, we add plus one. So, we can have a total of 10-bits.
// Additionally, shift by 2 is equivalent to divide by 4. A word has 4 bytes, so we require 2 less bits to address a word.

logic [1:0] byte_offset;
assign byte_offset = address[1:0];

// Write path: byte/halfword/word masked write
logic [DATA_WIDTH-1:0] write_mask;
logic [DATA_WIDTH-1:0] shifted_write_data;

always_comb begin
    case (funct3)
        3'b000: begin // SB
            case (byte_offset)
                2'b00: begin write_mask = 32'h0000_00FF; shifted_write_data = {24'b0, write_data[7:0]}; end
                2'b01: begin write_mask = 32'h0000_FF00; shifted_write_data = {16'b0, write_data[7:0], 8'b0}; end
                2'b10: begin write_mask = 32'h00FF_0000; shifted_write_data = {8'b0, write_data[7:0], 16'b0}; end
                2'b11: begin write_mask = 32'hFF00_0000; shifted_write_data = {write_data[7:0], 24'b0}; end
            endcase
        end
        3'b001: begin // SH (assumes 2-byte-aligned address)
            if (byte_offset[1] == 1'b0) begin
                write_mask = 32'h0000_FFFF; shifted_write_data = {16'b0, write_data[15:0]};
            end else begin
                write_mask = 32'hFFFF_0000; shifted_write_data = {write_data[15:0], 16'b0};
            end
        end
        default: begin // SW (010) and anything else -> full word
            write_mask = 32'hFFFF_FFFF;
            shifted_write_data = write_data;
        end
    endcase
end

always_ff @(posedge clk) begin 
    if (memWrite) begin
        memory[word_address] <= (memory[word_address] & ~write_mask) | (shifted_write_data & write_mask);
    end
end

//  Read path: byte/halfword/word extract + sign/zero extend
logic [DATA_WIDTH-1:0] raw_word;
assign raw_word = memory[word_address];

logic [7:0]  read_byte;
logic [15:0] read_half;

always_comb begin
    case (byte_offset)
        2'b00: read_byte = raw_word[7:0];
        2'b01: read_byte = raw_word[15:8];
        2'b10: read_byte = raw_word[23:16];
        2'b11: read_byte = raw_word[31:24];
    endcase

    read_half = byte_offset[1] ? raw_word[31:16] : raw_word[15:0];
end

always_comb begin
    if (!memRead) begin
        read_data = {DATA_WIDTH{1'b0}};
    end else begin
        case (funct3)
            3'b000:  read_data = {{24{read_byte[7]}},  read_byte}; // LB  (sign-extend)
            3'b100:  read_data = {24'b0,                read_byte}; // LBU (zero-extend)
            3'b001:  read_data = {{16{read_half[15]}}, read_half}; // LH  (sign-extend)
            3'b101:  read_data = {16'b0,                read_half}; // LHU (zero-extend)
            default: read_data = raw_word;                          // LW  (010) / default
        endcase
    end
end

endmodule