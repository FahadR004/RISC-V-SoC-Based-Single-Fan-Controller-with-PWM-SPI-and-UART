module instr_memory #(
    parameter ADDR_WIDTH = 32,
    parameter INSTR_WIDTH = 32, // 4 byte instruction
    parameter DEPTH = 1024
)(
    input logic [ADDR_WIDTH-1:0] pc_address, // byte address
    output logic [INSTR_WIDTH-1:0] instruction
); 

logic [INSTR_WIDTH-1:0] memory [0:DEPTH-1];

// Byte to word address conversion
logic [$clog2(DEPTH)-1:0] word_address;
assign word_address = pc_address[$clog2(DEPTH)+1 : 2]; // $clog2(1024) returns 10. We require 10 bits to address 1024 words. 
// However, if we did 10:2, then we would only have 9-bits. Hence, we add plus one. So, we can have a total of 10-bits.
// Additionally, shift by 2 is equivalent to divide by 4. A word has 4 bytes, so we require 2 less bits to address a word.

// Asynchronous read for single-cycle behavior
assign instruction = memory[word_address];

// initial begin
//     $readmemh("instructions.hex", memory);
// end

endmodule
