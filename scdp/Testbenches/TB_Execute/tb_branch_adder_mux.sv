`timescale 1ns/1ps

module tb_branch_adder_mux;

localparam ADDR_WIDTH = 32;
localparam DATA_WIDTH = 32;

logic [ADDR_WIDTH-1:0] pc_current_addr;
logic [ADDR_WIDTH-1:0] pc_plus_4;
logic branch;
logic jump;
logic jalr;
logic [2:0] funct3;
logic [DATA_WIDTH-1:0] immediate;
logic [DATA_WIDTH-1:0] rs1_data;
logic eq;
logic lt;
logic ltu;
logic [ADDR_WIDTH-1:0] next_pc_address;

int errors = 0;
int checks = 0;

branch_adder_mux #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
) dut (
    .pc_current_addr (pc_current_addr),
    .pc_plus_4       (pc_plus_4),
    .branch          (branch),
    .jump            (jump),
    .jalr            (jalr),
    .funct3          (funct3),
    .immediate       (immediate),
    .rs1_data        (rs1_data),
    .eq              (eq),
    .lt              (lt),
    .ltu             (ltu),
    .next_pc_address (next_pc_address)
);

initial begin
    $dumpfile("tb_branch_adder_mux.vcd");
    $dumpvars(0, tb_branch_adder_mux);
end

task automatic check(input string name, input logic [31:0] got, input logic [31:0] exp);
    checks++;
    if (got !== exp) begin
        errors++;
        $display("[FAIL] %s: expected=%0h got=%0h", name, exp, got);
    end else begin
        $display("[PASS] %s = %0h", name, got);
    end
endtask

// Common defaults, overridden per test
task automatic reset_inputs();
    pc_current_addr = 32'h0;
    pc_plus_4       = 32'h4;
    branch          = 1'b0;
    jump            = 1'b0;
    jalr            = 1'b0;
    funct3          = 3'b000;
    immediate       = 32'h0;
    rs1_data        = 32'h0;
    eq              = 1'b0;
    lt              = 1'b0;
    ltu             = 1'b0;
endtask

initial begin
    $display("=== branch_adder_mux Testbench ===");

    // -------------------------------------------------------------
    $display("\n-- No control signal asserted: fall through to PC+4 --");
    reset_inputs();
    pc_current_addr = 32'h100; pc_plus_4 = 32'h104;
    #1; check("fallthrough_pc_plus_4", next_pc_address, 32'h104);

    // -------------------------------------------------------------
    $display("\n-- BEQ (funct3=000) --");
    reset_inputs();
    pc_current_addr = 32'h100; pc_plus_4 = 32'h104; immediate = 32'h20;
    branch = 1'b1; funct3 = 3'b000;

    eq = 1'b1; // equal -> taken
    #1; check("beq_taken", next_pc_address, 32'h120);

    eq = 1'b0; // not equal -> not taken
    #1; check("beq_not_taken", next_pc_address, 32'h104);

    // -------------------------------------------------------------
    $display("\n-- BNE (funct3=001) --");
    reset_inputs();
    pc_current_addr = 32'h100; pc_plus_4 = 32'h104; immediate = 32'h20;
    branch = 1'b1; funct3 = 3'b001;

    eq = 1'b0; // not equal -> taken
    #1; check("bne_taken", next_pc_address, 32'h120);

    eq = 1'b1; // equal -> not taken
    #1; check("bne_not_taken", next_pc_address, 32'h104);

    // -------------------------------------------------------------
    $display("\n-- BLT (funct3=100) --");
    reset_inputs();
    pc_current_addr = 32'h100; pc_plus_4 = 32'h104; immediate = 32'h20;
    branch = 1'b1; funct3 = 3'b100;

    lt = 1'b1; // rs1 < rs2 -> taken
    #1; check("blt_taken", next_pc_address, 32'h120);

    lt = 1'b0; // not less -> not taken
    #1; check("blt_not_taken", next_pc_address, 32'h104);

    // -------------------------------------------------------------
    $display("\n-- BGE (funct3=101) --");
    reset_inputs();
    pc_current_addr = 32'h100; pc_plus_4 = 32'h104; immediate = 32'h20;
    branch = 1'b1; funct3 = 3'b101;

    lt = 1'b0; // not less -> BGE taken (>=)
    #1; check("bge_taken", next_pc_address, 32'h120);

    lt = 1'b1; // less -> BGE not taken
    #1; check("bge_not_taken", next_pc_address, 32'h104);

    // -------------------------------------------------------------
    $display("\n-- BLTU (funct3=110) --");
    reset_inputs();
    pc_current_addr = 32'h100; pc_plus_4 = 32'h104; immediate = 32'h20;
    branch = 1'b1; funct3 = 3'b110;

    ltu = 1'b1; // unsigned less -> taken
    #1; check("bltu_taken", next_pc_address, 32'h120);

    ltu = 1'b0;
    #1; check("bltu_not_taken", next_pc_address, 32'h104);

    // -------------------------------------------------------------
    $display("\n-- BGEU (funct3=111) --");
    reset_inputs();
    pc_current_addr = 32'h100; pc_plus_4 = 32'h104; immediate = 32'h20;
    branch = 1'b1; funct3 = 3'b111;

    ltu = 1'b0; // not less (unsigned) -> BGEU taken (>=)
    #1; check("bgeu_taken", next_pc_address, 32'h120);

    ltu = 1'b1;
    #1; check("bgeu_not_taken", next_pc_address, 32'h104);

    // -------------------------------------------------------------
    $display("\n-- branch=0 should never take, regardless of flags/funct3 --");
    reset_inputs();
    pc_current_addr = 32'h100; pc_plus_4 = 32'h104; immediate = 32'h20;
    branch = 1'b0; funct3 = 3'b000; eq = 1'b1; // eq true, but branch deasserted
    #1; check("branch_deasserted_ignored", next_pc_address, 32'h104);

    // -------------------------------------------------------------
    $display("\n-- default/unused funct3 under branch=1 should not take --");
    reset_inputs();
    pc_current_addr = 32'h100; pc_plus_4 = 32'h104; immediate = 32'h20;
    branch = 1'b1; funct3 = 3'b010; // unused encoding
    eq = 1'b1; lt = 1'b1; ltu = 1'b1; // all flags true, still shouldn't matter
    #1; check("undefined_funct3_not_taken", next_pc_address, 32'h104);

    // -------------------------------------------------------------
    $display("\n-- JAL (jump=1): always taken, PC-relative target --");
    reset_inputs();
    pc_current_addr = 32'h200; pc_plus_4 = 32'h204; immediate = 32'h40;
    jump = 1'b1;
    #1; check("jal_target", next_pc_address, 32'h240);

    // jump should override even if branch flags say "not taken"
    reset_inputs();
    pc_current_addr = 32'h200; pc_plus_4 = 32'h204; immediate = 32'h40;
    jump = 1'b1; branch = 1'b0; eq = 1'b0; lt = 1'b0; ltu = 1'b0;
    #1; check("jal_unconditional_regardless_of_flags", next_pc_address, 32'h240);

    // -------------------------------------------------------------
    $display("\n-- JALR: target = (rs1 + imm) & ~1 --");
    reset_inputs();
    pc_current_addr = 32'h300; pc_plus_4 = 32'h304;
    jalr = 1'b1; rs1_data = 32'h1000; immediate = 32'h10;
    #1; check("jalr_basic", next_pc_address, 32'h1010);

    // LSB masking: rs1+imm produces an odd address, must be cleared to even
    reset_inputs();
    pc_current_addr = 32'h300; pc_plus_4 = 32'h304;
    jalr = 1'b1; rs1_data = 32'h1001; immediate = 32'h10; // sum = 0x1011 (odd)
    #1; check("jalr_lsb_masked_to_even", next_pc_address, 32'h1010);

    // negative immediate (sign-extended, e.g. -4) still resolves correctly
    reset_inputs();
    pc_current_addr = 32'h300; pc_plus_4 = 32'h304;
    jalr = 1'b1; rs1_data = 32'h2000; immediate = 32'hFFFFFFFC; // -4
    #1; check("jalr_negative_immediate", next_pc_address, 32'h1FFC);

    // -------------------------------------------------------------
    $display("\n-- Priority: jalr must win over branch_taken/jump --");
    reset_inputs();
    pc_current_addr = 32'h400; pc_plus_4 = 32'h404; immediate = 32'h40;
    jalr = 1'b1; jump = 1'b1; branch = 1'b1; funct3 = 3'b000; eq = 1'b1;
    rs1_data = 32'h5000;
    #1; check("jalr_priority_over_jump_and_branch", next_pc_address, 32'h5040);

    // Priority: branch_taken must win over plain pc_plus_4 when jalr=0
    reset_inputs();
    pc_current_addr = 32'h400; pc_plus_4 = 32'h404; immediate = 32'h40;
    jalr = 1'b0; jump = 1'b0; branch = 1'b1; funct3 = 3'b000; eq = 1'b1;
    #1; check("branch_priority_over_fallthrough", next_pc_address, 32'h440);

    // -------------------------------------------------------------
    $display("\n=== Testbench complete: %0d/%0d passed ===", checks - errors, checks);
    if (errors == 0)
        $display("ALL TESTS PASSED");
    else
        $display("%0d TEST(S) FAILED", errors);

    $finish;
end

endmodule