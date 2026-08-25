`timescale 1ns/1ps

module tb_alu_control;

logic [1:0] alu_op;
logic [2:0] funct3;
logic [6:0] funct7;
logic r_i_type_diff;
logic [3:0] alu_control;

int errors = 0;
int checks = 0;

localparam ALU_ADD  = 4'b0000;
localparam ALU_SUB  = 4'b0001;
localparam ALU_SLL  = 4'b0010;
localparam ALU_SLT  = 4'b0011;
localparam ALU_SLTU = 4'b0100;
localparam ALU_XOR  = 4'b0101;
localparam ALU_SRL  = 4'b0110;
localparam ALU_SRA  = 4'b0111;
localparam ALU_OR   = 4'b1000;
localparam ALU_AND  = 4'b1001;
localparam ALU_LUI  = 4'b1010;

alu_control_module dut (
    .alu_op        (alu_op),
    .funct3        (funct3),
    .funct7        (funct7),
    .r_i_type_diff (r_i_type_diff),
    .alu_control   (alu_control)
);

task automatic check(
    input string name,
    input logic [3:0] got,
    input logic [3:0] exp
);
    checks++;
    if (got !==  exp) begin
        errors++;
        $display("[FAIL] %s: expected=%0h got=%0h", name, exp, got);
    end else begin
        $display("[PASS] %s = %0h", name, got);
    end
endtask

initial begin
    $dumpfile("tb_alu_control.vcd");
    $dumpvars(0, tb_alu_control);
end

initial begin
    $display("=== alu_control Testbench ===");

    // aluOp = 00 -> ADD, regardless of funct3/funct7/r_i_type_diff
    $display("\n-- alu_op = 00 (Load/Store/AUIPC/JALR address calc) --");
    alu_op = 2'b00; funct3 = 3'b000; funct7 = 7'b0000000; r_i_type_diff = 1'b0;
    #1; check("aluOp00_base", alu_control, ALU_ADD);

    alu_op = 2'b00; funct3 = 3'b111; funct7 = 7'b1111111; r_i_type_diff = 1'b1;
    #1; check("aluOp00_ignores_others", alu_control, ALU_ADD);

    // aluOp = 01 -> SUB, regardless of funct3/funct7/r_i_type_diff
    $display("\n-- alu_op = 01 (Branch comparison) --");
    alu_op = 2'b01; funct3 = 3'b000; funct7 = 7'b0000000; r_i_type_diff = 1'b0;
    #1; check("aluOp01_base", alu_control, ALU_SUB);

    alu_op = 2'b01; funct3 = 3'b101; funct7 = 7'b0100000; r_i_type_diff = 1'b1;
    #1; check("aluOp01_ignores_others", alu_control, ALU_SUB);

    // aluOp = 11 -> LUI, regardless of funct3/funct7/r_i_type_diff
    $display("\n-- alu_op = 11 (LUI) --");
    alu_op = 2'b11; funct3 = 3'b000; funct7 = 7'b0000000; r_i_type_diff = 1'b0;
    #1; check("aluOp11_base", alu_control, ALU_LUI);

    alu_op = 2'b11; funct3 = 3'b010; funct7 = 7'b0100000; r_i_type_diff = 1'b1;
    #1; check("aluOp11_ignores_others", alu_control, ALU_LUI);

    // aluOp = 10 -> R-type / I-type arithmetic, decode via funct3
    $display("\n-- alu_op = 10, funct3 = 000, R-type (r_i_type_diff=1) --");
    alu_op = 2'b10; funct3 = 3'b000; r_i_type_diff = 1'b1;

    funct7 = 7'b0000000;
    #1; check("R_add",  alu_control, ALU_ADD);

    funct7 = 7'b0100000;
    #1; check("R_sub",  alu_control, ALU_SUB);

    $display("\n-- alu_op = 10, funct3 = 000, I-type ADDI (r_i_type_diff=0) --");
    alu_op = 2'b10; funct3 = 3'b000; r_i_type_diff = 1'b0;

    funct7 = 7'b0000000;
    #1; check("I_addi_plain", alu_control, ALU_ADD);

    // Bug-catching case: imm[11:5] happens to equal 0100000, must NOT be read as SUB
    funct7 = 7'b0100000;
    #1; check("I_addi_imm_looks_like_sub", alu_control, ALU_ADD);

    $display("\n-- alu_op = 10, funct3 = 001 (SLL/SLLI, shamt-only, no ambiguity) --");
    alu_op = 2'b10; funct3 = 3'b001; funct7 = 7'b0000000; r_i_type_diff = 1'b1;
    #1; check("R_sll", alu_control, ALU_SLL);
    r_i_type_diff = 1'b0;
    #1; check("I_slli", alu_control, ALU_SLL);

    $display("\n-- alu_op = 10, funct3 = 010 (SLT/SLTI) --");
    alu_op = 2'b10; funct3 = 3'b010; funct7 = 7'b0000000; r_i_type_diff = 1'b1;
    #1; check("R_slt", alu_control, ALU_SLT);
    r_i_type_diff = 1'b0;
    #1; check("I_slti", alu_control, ALU_SLT);

    $display("\n-- alu_op = 10, funct3 = 011 (SLTU/SLTIU) --");
    alu_op = 2'b10; funct3 = 3'b011; funct7 = 7'b0000000; r_i_type_diff = 1'b1;
    #1; check("R_sltu", alu_control, ALU_SLTU);
    r_i_type_diff = 1'b0;
    #1; check("I_sltiu", alu_control, ALU_SLTU);

    $display("\n-- alu_op = 10, funct3 = 100 (XOR/XORI) --");
    alu_op = 2'b10; funct3 = 3'b100; funct7 = 7'b0000000; r_i_type_diff = 1'b1;
    #1; check("R_xor", alu_control, ALU_XOR);
    r_i_type_diff = 1'b0;
    #1; check("I_xori", alu_control, ALU_XOR);

    $display("\n-- alu_op = 10, funct3 = 101, R-type SRL/SRA (funct7 bit 30 always valid) --");
    alu_op = 2'b10; funct3 = 3'b101; r_i_type_diff = 1'b1;
    funct7 = 7'b0000000;
    #1; check("R_srl", alu_control, ALU_SRL);
    funct7 = 7'b0100000;
    #1; check("R_sra", alu_control, ALU_SRA);

    $display("\n-- alu_op = 10, funct3 = 101, I-type SRLI/SRAI (bit 30 still valid) --");
    alu_op = 2'b10; funct3 = 3'b101; r_i_type_diff = 1'b0;
    funct7 = 7'b0000000;
    #1; check("I_srli", alu_control, ALU_SRL);
    funct7 = 7'b0100000;
    #1; check("I_srai", alu_control, ALU_SRA);

    $display("\n-- alu_op = 10, funct3 = 110 (OR/ORI) --");
    alu_op = 2'b10; funct3 = 3'b110; funct7 = 7'b0000000; r_i_type_diff = 1'b1;
    #1; check("R_or", alu_control, ALU_OR);
    r_i_type_diff = 1'b0;
    #1; check("I_ori", alu_control, ALU_OR);

    $display("\n-- alu_op = 10, funct3 = 111 (AND/ANDI) --");
    alu_op = 2'b10; funct3 = 3'b111; funct7 = 7'b0000000; r_i_type_diff = 1'b1;
    #1; check("R_and", alu_control, ALU_AND);
    r_i_type_diff = 1'b0;
    #1; check("I_andi", alu_control, ALU_AND);

    $display("\n=== Testbench complete: %0d/%0d passed ===", checks - errors, checks);
    if (errors == 0)
        $display("ALL TESTS PASSED");
    else
        $display("%0d TEST(S) FAILED", errors);

    $finish;
end

endmodule