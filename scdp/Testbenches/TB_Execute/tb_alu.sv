`timescale 1ns/1ps

module tb_alu;

localparam DATA_WIDTH = 32;

logic [3:0] alu_control;
logic [DATA_WIDTH-1:0] alu_src_a;
logic [DATA_WIDTH-1:0] alu_src_b;
logic [DATA_WIDTH-1:0] result;
logic lt;
logic ltu;
logic eq;

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

alu #(
    .DATA_WIDTH(DATA_WIDTH)
) dut (
    .alu_control (alu_control),
    .alu_src_a   (alu_src_a),
    .alu_src_b   (alu_src_b),
    .result      (result),
    .lt          (lt),
    .ltu         (ltu),
    .eq          (eq)
);

// Checks result only; flags checked separately since they're always-on
// and independent of alu_control (per the new design).
task automatic check_result(
    input string name,
    input logic [DATA_WIDTH-1:0] got_result,
    input logic [DATA_WIDTH-1:0] exp_result
);
    checks++;
    if (got_result !== exp_result) begin
        errors++;
        $display("[FAIL] %s: expected result=%0h, got result=%0h",
                  name, exp_result, got_result);
    end else begin
        $display("[PASS] %s: result=%0h", name, got_result);
    end
endtask

task automatic check_flags(
    input string name,
    input logic got_eq,  input logic exp_eq,
    input logic got_lt,  input logic exp_lt,
    input logic got_ltu, input logic exp_ltu
);
    checks++;
    if (got_eq !== exp_eq || got_lt !== exp_lt || got_ltu !== exp_ltu) begin
        errors++;
        $display("[FAIL] %s: expected eq=%0b lt=%0b ltu=%0b, got eq=%0b lt=%0b ltu=%0b",
                  name, exp_eq, exp_lt, exp_ltu, got_eq, got_lt, got_ltu);
    end else begin
        $display("[PASS] %s: eq=%0b lt=%0b ltu=%0b", name, got_eq, got_lt, got_ltu);
    end
endtask

initial begin
    $dumpfile("tb_alu.vcd");
    $dumpvars(0, tb_alu);
end

initial begin
    $display("=== ALU Testbench ===");

    $display("\n-- ADD --");
    alu_control = ALU_ADD; alu_src_a = 32'd10; alu_src_b = 32'd15;
    #1; check_result("add_basic", result, 32'd25);

    alu_control = ALU_ADD; alu_src_a = 32'hFFFFFFFF; alu_src_b = 32'd1; // -1 + 1
    #1; check_result("add_overflow_to_zero", result, 32'h0);

    $display("\n-- SUB --");
    alu_control = ALU_SUB; alu_src_a = 32'd20; alu_src_b = 32'd5;
    #1; check_result("sub_basic", result, 32'd15);

    alu_control = ALU_SUB; alu_src_a = 32'd7; alu_src_b = 32'd7;
    #1; check_result("sub_equal_operands_zero", result, 32'h0);

    alu_control = ALU_SUB; alu_src_a = 32'd5; alu_src_b = 32'd10; // negative result
    #1; check_result("sub_negative_result", result, 32'hFFFFFFFB);

    $display("\n-- AND / OR / XOR --");
    alu_control = ALU_AND; alu_src_a = 32'hF0F0F0F0; alu_src_b = 32'h0FF00FF0;
    #1; check_result("and_basic", result, 32'h00F000F0);

    alu_control = ALU_AND; alu_src_a = 32'hAAAA0000; alu_src_b = 32'h55550000;
    #1; check_result("and_result_zero", result, 32'h0);

    alu_control = ALU_OR; alu_src_a = 32'hF0F0F0F0; alu_src_b = 32'h0F0F0F0F;
    #1; check_result("or_basic", result, 32'hFFFFFFFF);

    alu_control = ALU_OR; alu_src_a = 32'h0; alu_src_b = 32'h0;
    #1; check_result("or_result_zero", result, 32'h0);

    alu_control = ALU_XOR; alu_src_a = 32'hFFFF0000; alu_src_b = 32'h0000FFFF;
    #1; check_result("xor_basic", result, 32'hFFFFFFFF);

    alu_control = ALU_XOR; alu_src_a = 32'hDEADBEEF; alu_src_b = 32'hDEADBEEF;
    #1; check_result("xor_identical_zero", result, 32'h0);

    $display("\n-- SLL / SRL / SRA --");
    alu_control = ALU_SLL; alu_src_a = 32'h0000_0001; alu_src_b = 32'd4;
    #1; check_result("sll_basic", result, 32'h0000_0010);

    // shamt uses only bottom 5 bits; upper bits of alu_src_b must be ignored
    alu_control = ALU_SLL; alu_src_a = 32'h0000_0001; alu_src_b = 32'hFFFF_FFE4; // low 5 bits = 4
    #1; check_result("sll_shamt_masked", result, 32'h0000_0010);

    alu_control = ALU_SRL; alu_src_a = 32'h8000_0000; alu_src_b = 32'd4;
    #1; check_result("srl_logical_no_sign_ext", result, 32'h0800_0000);

    alu_control = ALU_SRA; alu_src_a = 32'h8000_0000; alu_src_b = 32'd4;
    #1; check_result("sra_sign_extends", result, 32'hF800_0000);

    alu_control = ALU_SRA; alu_src_a = 32'h7000_0000; alu_src_b = 32'd4; // positive, no sign ext
    #1; check_result("sra_positive_no_sign_ext", result, 32'h0700_0000);

    alu_control = ALU_SRL; alu_src_a = 32'h0000_00F0; alu_src_b = 32'd8;
    #1; check_result("srl_shift_to_zero", result, 32'h0);

    $display("\n-- SLT / SLTU (result output, used as arithmetic rd value) --");
    alu_control = ALU_SLT; alu_src_a = 32'd5; alu_src_b = 32'd10; // 5 < 10 -> 1
    #1; check_result("slt_true", result, 32'd1);

    alu_control = ALU_SLT; alu_src_a = 32'd10; alu_src_b = 32'd5; // 10 < 5 -> 0
    #1; check_result("slt_false", result, 32'd0);

    // signed comparison: -1 < 1 must be true even though -1 is a large unsigned value
    alu_control = ALU_SLT; alu_src_a = 32'hFFFFFFFF; alu_src_b = 32'd1;
    #1; check_result("slt_signed_negative_lt_positive", result, 32'd1);

    alu_control = ALU_SLTU; alu_src_a = 32'd5; alu_src_b = 32'd10;
    #1; check_result("sltu_true", result, 32'd1);

    // unsigned comparison: 0xFFFFFFFF is huge unsigned, so NOT less than 1
    alu_control = ALU_SLTU; alu_src_a = 32'hFFFFFFFF; alu_src_b = 32'd1;
    #1; check_result("sltu_unsigned_large_not_lt", result, 32'd0);

    $display("\n-- LUI (pass-through) --");
    alu_control = ALU_LUI; alu_src_a = 32'hDEAD_BEEF; alu_src_b = 32'hABCDE000;
    #1; check_result("lui_passes_src_b_ignores_src_a", result, 32'hABCDE000);

    alu_control = ALU_LUI; alu_src_a = 32'h0; alu_src_b = 32'h0;
    #1; check_result("lui_zero_immediate", result, 32'h0);

    $display("\n-- default / unused control code --");
    alu_control = 4'b1111; alu_src_a = 32'hFFFF_FFFF; alu_src_b = 32'hFFFF_FFFF;
    #1; check_result("default_case_zero_output", result, 32'h0);

    // Flags check
    $display("\n-- Flags: equal operands --");
    alu_src_a = 32'd42; alu_src_b = 32'd42;
    alu_control = ALU_ADD;
    #1; check_flags("flags_equal_during_add", eq, 1'b1, lt, 1'b0, ltu, 1'b0);
    alu_control = ALU_AND;
    #1; check_flags("flags_equal_during_and", eq, 1'b1, lt, 1'b0, ltu, 1'b0);
    alu_control = ALU_LUI;
    #1; check_flags("flags_equal_during_lui", eq, 1'b1, lt, 1'b0, ltu, 1'b0);

    $display("\n-- Flags: signed less-than (negative vs positive) --");
    alu_src_a = 32'hFFFFFFFF; alu_src_b = 32'd1; // -1 vs 1
    alu_control = ALU_SUB;
    #1; check_flags("flags_signed_neg_lt_pos_during_sub", eq, 1'b0, lt, 1'b1, ltu, 1'b0);
    alu_control = ALU_XOR; // unrelated op, flags must not change
    #1; check_flags("flags_signed_neg_lt_pos_during_xor", eq, 1'b0, lt, 1'b1, ltu, 1'b0);

    $display("\n-- Flags: unsigned interpretation of same bit pattern --");
    // Same operands as above (0xFFFFFFFF vs 1): lt=1 (signed), but ltu=0 (huge unsigned)
    alu_control = ALU_OR;
    #1; check_flags("flags_unsigned_large_not_lt_during_or", eq, 1'b0, lt, 1'b1, ltu, 1'b0);

    $display("\n-- Flags: a > b (neither equal nor less) --");
    alu_src_a = 32'd100; alu_src_b = 32'd50;
    alu_control = ALU_SLL;
    #1; check_flags("flags_greater_than_during_sll", eq, 1'b0, lt, 1'b0, ltu, 1'b0);

    $display("\n-- Flags: a < b, both signed and unsigned agree (small positives) --");
    alu_src_a = 32'd3; alu_src_b = 32'd9;
    alu_control = ALU_SRA;
    #1; check_flags("flags_small_positive_lt", eq, 1'b0, lt, 1'b1, ltu, 1'b1);

    $display("\n-- Flags: zero operands, equal --");
    alu_src_a = 32'h0; alu_src_b = 32'h0;
    alu_control = ALU_SLT;
    #1; check_flags("flags_both_zero_equal", eq, 1'b1, lt, 1'b0, ltu, 1'b0);

    $display("\n-- Flags: default/unused alu_control does not affect flags --");
    alu_src_a = 32'd5; alu_src_b = 32'd10;
    alu_control = 4'b1111; // unused code, result falls to default
    #1; check_flags("flags_valid_during_unused_control_code", eq, 1'b0, lt, 1'b1, ltu, 1'b1);

    $display("\n=== Testbench complete: %0d/%0d passed ===", checks - errors, checks);
    if (errors == 0)
        $display("ALL TESTS PASSED");
    else
        $display("%0d TEST(S) FAILED", errors);

    $finish;
end

endmodule