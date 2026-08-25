`timescale 1ns/1ps

module tb_decode;

localparam ADDR_WIDTH = 32;
localparam INSTR_WIDTH = 32;
localparam DATA_WIDTH = 32;
localparam REG_NUMS = 32;

logic clk;
logic rst_n;
logic [INSTR_WIDTH-1:0] instruction;
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

int errors = 0;
int checks = 0;

Decode #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .INSTR_WIDTH(INSTR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .REG_NUMS(REG_NUMS)
) dut (
    .clk(clk),
    .rst_n(rst_n),
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

function automatic logic [31:0] make_i_type(
    input logic [11:0] imm,
    input logic [4:0] rs1,
    input logic [2:0] funct3_i,
    input logic [4:0] rd,
    input logic [6:0] op
);
    return {imm, rs1, funct3_i, rd, op};
endfunction

function automatic logic [31:0] make_r_type(
    input logic [6:0] funct7_i,
    input logic [4:0] rs2,
    input logic [4:0] rs1,
    input logic [2:0] funct3_i,
    input logic [4:0] rd,
    input logic [6:0] op
);
    return {funct7_i, rs2, rs1, funct3_i, rd, op};
endfunction

function automatic logic [31:0] make_s_type(
    input logic [11:0] imm,
    input logic [4:0] rs2,
    input logic [4:0] rs1,
    input logic [2:0] funct3_i,
    input logic [6:0] op
);
    return {imm[11:5], rs2, rs1, funct3_i, imm[4:0], op};
endfunction

function automatic logic [31:0] make_b_type(
    input logic [12:0] imm,
    input logic [4:0] rs2,
    input logic [4:0] rs1,
    input logic [2:0] funct3_i,
    input logic [6:0] op
);
    return {imm[12], imm[10:5], rs2, rs1, funct3_i, imm[4:1], imm[11], op};
endfunction

function automatic logic [31:0] make_j_type(
    input logic [20:0] imm,
    input logic [4:0] rd,
    input logic [6:0] op
);
    return {imm[20], imm[10:1], imm[11], imm[19:12], rd, op};
endfunction

task automatic check_logic(
    input string name,
    input logic got,
    input logic exp
);
    checks++;
    if (got !== exp) begin
        errors++;
        $display("[FAIL] %s: expected=%0b got=%0b", name, exp, got);
    end else begin
        $display("[PASS] %s = %0b", name, got);
    end
endtask

task automatic check_word(
    input string name,
    input logic [DATA_WIDTH-1:0] got,
    input logic [DATA_WIDTH-1:0] exp
);
    checks++;
    if (got !== exp) begin
        errors++;
        $display("[FAIL] %s: expected=%0h got=%0h", name, exp, got);
    end else begin
        $display("[PASS] %s = %0h", name, got);
    end
endtask

task automatic check_three(
    input string name,
    input logic [2:0] got,
    input logic [2:0] exp
);
    checks++;
    if (got !== exp) begin
        errors++;
        $display("[FAIL] %s: expected=%0b got=%0b", name, exp, got);
    end else begin
        $display("[PASS] %s = %0b", name, got);
    end
endtask

task automatic check_opcode(
    input string name,
    input logic [6:0] got,
    input logic [6:0] exp
);
    checks++;
    if (got !== exp) begin
        errors++;
        $display("[FAIL] %s: expected=%0h got=%0h", name, exp, got);
    end else begin
        $display("[PASS] %s = %0h", name, got);
    end
endtask

initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

initial begin
    $dumpfile("tb_decode.vcd");
    $dumpvars(0, tb_decode);
end

initial begin
    rst_n = 0;
    instruction = 32'h0;
    write_data = 32'h0;

    @(negedge clk);
    @(negedge clk);     

    rst_n = 1;
    @(negedge clk);

    #1;
    $display("\nTest 1: reset / default decode");
    check_logic("branch", branch, 1'b0);
    check_logic("jump", jump, 1'b0);
    check_logic("jalr", jalr, 1'b0);
    check_logic("memRead", memRead, 1'b0);
    check_logic("memToReg", memToReg, 1'b0);
    check_logic("memWrite", memWrite, 1'b0);
    check_logic("aluSrc", aluSrc, 1'b0);
    check_logic("regWrite", regWrite, 1'b0);
    check_word("read_data1", read_data1, 32'h0);
    check_word("read_data2", read_data2, 32'h0);

    // Write x1 = 0x11111111 using an ADDI instruction so register_file writes to x1.
    $display("\nTest 2: write x1 using ADDI");
    instruction = make_i_type(12'h111, 5'd0, 3'b000, 5'd1, 7'h13);
    write_data = 32'h11111111;
    #1;
    check_logic("regWrite_x1", regWrite, 1'b1);
    @(posedge clk);
    @(negedge clk);

    // Write x2 = 0x22222222.
    $display("\nTest 3: write x2 using ADDI");
    instruction = make_i_type(12'h222, 5'd0, 3'b000, 5'd2, 7'h13);
    write_data = 32'h22222222;
    #1;
    check_logic("regWrite_x2", regWrite, 1'b1);
    @(posedge clk);
    @(negedge clk);

    // R-type ADD x3, x1, x2
    $display("\nTest 4: R-type ADD decode");
    instruction = make_r_type(7'h00, 5'd2, 5'd1, 3'b000, 5'd3, 7'h33);
    write_data = 32'h0;
    #1;
    check_logic("aluSrc_add", aluSrc, 1'b0);
    check_logic("regWrite_add", regWrite, 1'b1);
    check_word("read_data1_add", read_data1, 32'h11111111);
    check_word("read_data2_add", read_data2, 32'h22222222);
    check_opcode("opcode_add", opcode, 7'h33);
    check_three("funct3_add", funct3, 3'b000);
    @(negedge clk);   

    // I-type ADDI x5, x1, 10
    $display("\nTest 5: I-type ADDI decode");
    instruction = make_i_type(12'd10, 5'd1, 3'b000, 5'd5, 7'h13);
    #1;
    check_logic("aluSrc_addi", aluSrc, 1'b1);
    check_logic("regWrite_addi", regWrite, 1'b1);
    check_word("read_data1_addi", read_data1, 32'h11111111);
    check_word("immediate_addi", immediate, 32'd10);
    check_opcode("opcode_addi", opcode, 7'h13);
    @(negedge clk);   

    // S-type SW x2, 8(x1)
    $display("\nTest 6: S-type SW decode");
    instruction = make_s_type(12'd8, 5'd2, 5'd1, 3'b010, 7'h23);
    #1;
    check_logic("memWrite_sw", memWrite, 1'b1);
    check_logic("aluSrc_sw", aluSrc, 1'b1);
    check_logic("regWrite_sw", regWrite, 1'b0);
    check_word("immediate_sw", immediate, 32'd8);
    check_opcode("opcode_sw", opcode, 7'h23);
    @(negedge clk);
    
    // B-type BEQ x1, x2, 8
    $display("\nTest 7: B-type BEQ decode");
    instruction = make_b_type(13'd8, 5'd2, 5'd1, 3'b000, 7'h63);
    #1;
    check_logic("branch_beq", branch, 1'b1);
    check_logic("aluSrc_beq", aluSrc, 1'b0);
    check_logic("regWrite_beq", regWrite, 1'b0);
    check_word("immediate_beq", immediate, 32'd8);
    check_opcode("opcode_beq", opcode, 7'h63);
    @(negedge clk);

    // J-type JAL x4, 16
    $display("\nTest 8: J-type JAL decode");
    instruction = make_j_type(21'd16, 5'd4, 7'h6F);
    #1;
    check_logic("jump_jal", jump, 1'b1);
    check_logic("regWrite_jal", regWrite, 1'b1);
    check_word("immediate_jal", immediate, 32'd16);
    check_opcode("opcode_jal", opcode, 7'h6F);
    @(negedge clk);

    // JALR x5, x1, 4
    $display("\nTest 9: JALR decode");
    instruction = make_i_type(12'd4, 5'd1, 3'b000, 5'd5, 7'h67);
    #1;
    check_logic("jalr_jalr", jalr, 1'b1);
    check_logic("aluSrc_jalr", aluSrc, 1'b1);
    check_logic("regWrite_jalr", regWrite, 1'b1);
    check_word("immediate_jalr", immediate, 32'd4);
    check_opcode("opcode_jalr", opcode, 7'h67);
    @(negedge clk);

    if (errors == 0) begin
        $display("\nALL PASS: %0d checks, 0 errors", checks);
    end else begin
        $display("\nFAILED: %0d checks, %0d errors", checks, errors);
    end

    $finish;
end

endmodule
