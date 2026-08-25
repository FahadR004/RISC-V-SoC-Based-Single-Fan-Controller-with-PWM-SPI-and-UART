`timescale 1ns/1ps

module tb_control_unit;

localparam ADDR_WIDTH  = 32;
localparam INSTR_WIDTH = 32;
localparam DATA_WIDTH  = 32;
localparam REG_NUMS    = 32;

logic [31:0] instruction;

logic       branch;
logic       jump;
logic       jalr;
logic       memRead;
logic       memToReg;
logic [1:0] aluOp;
logic       memWrite;
logic       aluSrc;
logic       regWrite;

logic [6:0] opcode;
logic [2:0] funct3;
logic [6:0] funct7;

int errors = 0;
int checks = 0;

control_unit #(
    .ADDR_WIDTH (ADDR_WIDTH),
    .INSTR_WIDTH (INSTR_WIDTH),
    .DATA_WIDTH (DATA_WIDTH),
    .REG_NUMS (REG_NUMS)
) dut (
    .instruction (instruction),
    .branch      (branch),
    .jump        (jump),
    .jalr        (jalr),
    .memRead     (memRead),
    .memToReg    (memToReg),
    .aluOp       (aluOp),
    .memWrite    (memWrite),
    .aluSrc      (aluSrc),
    .regWrite    (regWrite),
    .opcode      (opcode),
    .funct3      (funct3),
    .funct7      (funct7)
);

// Build a 32-bit instruction word from fields (funct7/rs2/rs1/funct3/rd/opcode)
function automatic logic [31:0] make_instr(
    input logic [6:0] f7,
    input logic [4:0] rs2,
    input logic [4:0] rs1,
    input logic [2:0] f3,
    input logic [4:0] rd,
    input logic [6:0] op
); 
    return {f7, rs2, rs1, f3, rd, op};
endfunction

// Checks one control-signal field and reports a mismatch if found
task automatic check(input string name, input logic got, input logic exp);
    checks++;
    if (got !== exp) begin
        errors++;
        $display("  [FAIL] %s: expected=%0b got=%0b", name, exp, got);
    end
endtask

task automatic checkALUOp(input string name, input logic [1:0] got, input logic [1:0] exp);
    checks++;
    if (got !== exp) begin
        errors++;
        $display("  [FAIL] %s: expected=%0b got=%0b", name, exp, got);
    end
endtask

// Drives one instruction and checks all expected control outputs
task automatic run_case(
    input string       name,
    input logic [31:0] instr,
    input logic         e_branch,
    input logic         e_jump,
    input logic         e_jalr,
    input logic         e_memRead,
    input logic         e_memToReg,
    input logic [1:0]   e_aluOp,
    input logic         e_memWrite,
    input logic         e_aluSrc,
    input logic         e_regWrite
);
    instruction = instr;
    #1; // allow combinational logic to settle

    $display("Test: %s (instr=%h, opcode=%h)", name, instr, opcode);
    check ("branch",   branch,   e_branch);
    check ("jump",     jump,     e_jump);
    check ("jalr",     jalr,     e_jalr);
    check ("memRead",  memRead,  e_memRead);
    check ("memToReg", memToReg, e_memToReg);
    checkALUOp("aluOp",    aluOp,    e_aluOp);
    check ("memWrite", memWrite, e_memWrite);
    check ("aluSrc",   aluSrc,   e_aluSrc);
    check ("regWrite", regWrite, e_regWrite);
endtask

initial begin
    $dumpfile("tb_control_unit.vcd");
    $dumpvars(0, tb_control_unit);
end

initial begin
    // name, instr,branch,jump,jalr,memRead,memToReg,aluOp,memWrite,aluSrc,regWrite

    // LW: opcode 0x03
    run_case("LW",
        make_instr(7'h0, 5'd0, 5'd1, 3'b010, 5'd2, 7'h03),
        0,0,0, 1,1, 2'b00, 0,1, 1);

    // ADDI: opcode 0x13
    run_case("ADDI",
        make_instr(7'h0, 5'd0, 5'd1, 3'b000, 5'd2, 7'h13),
        0,0,0, 0,0, 2'b10, 0,1, 1);

    // JALR: opcode 0x67
    run_case("JALR",
        make_instr(7'h0, 5'd0, 5'd1, 3'b000, 5'd2, 7'h67),
        0,0,1, 0,0, 2'b00, 0,1, 1);

    // ADD (R-type): opcode 0x33, funct3=0, funct7=0
    run_case("ADD (R-type)",
        make_instr(7'h00, 5'd3, 5'd1, 3'b000, 5'd2, 7'h33),
        0,0,0, 0,0, 2'b10, 0,0, 1);

    // SUB (R-type): opcode 0x33, funct3=0, funct7=0x20
    run_case("SUB (R-type)",
        make_instr(7'h20, 5'd3, 5'd1, 3'b000, 5'd2, 7'h33),
        0,0,0, 0,0, 2'b10, 0,0, 1);

    // SW: opcode 0x23
    run_case("SW",
        make_instr(7'h0, 5'd3, 5'd1, 3'b010, 5'd0, 7'h23),
        0,0,0, 0,0, 2'b00, 1,1, 0);

    // BEQ: opcode 0x63
    run_case("BEQ",
        make_instr(7'h0, 5'd3, 5'd1, 3'b000, 5'd0, 7'h63),
        1,0,0, 0,0, 2'b01, 0,0, 0);

    // JAL: opcode 0x6F
    run_case("JAL",
        {25'h0, 7'h6F},
        0,1,0, 0,0, 2'b00, 0,0, 1);

    // LUI: opcode 0x37
    run_case("LUI",
        {20'h0, 5'd1, 7'h37},
        0,0,0, 0,0, 2'b11, 0,1, 1);

    // AUIPC: opcode 0x17
    run_case("AUIPC",
        {20'h0, 5'd1, 7'h17},
        0,0,0, 0,0, 2'b00, 0,1, 1);

    // FENCE: opcode 0x0F — should behave as full no-op
    run_case("FENCE",
        {25'h0, 7'h0F},
        0,0,0, 0,0, 2'b00, 0,0, 0);

    // ECALL: opcode 0x73 — currently a no-op placeholder
    run_case("ECALL",
        {25'h0, 7'h73},
    0,0,0, 0,0, 2'b00, 0,0, 0);

    // Unknown/reserved opcode: everything should fall back to defaults (all 0)
    run_case("Unknown opcode (defaults)",
        {25'h0, 7'h5B},
        0,0,0, 0,0, 2'b00, 0,0, 0);

    // funct3 / funct7 passthrough check
    instruction = make_instr(7'h20, 5'd5, 5'd6, 3'b101, 5'd7, 7'h33); // SRA
    #1;
    $display("Test: funct3/funct7 passthrough (instr=%h)", instruction);
    checks++;
    if (funct3 !== 3'b101) begin
        errors++;
        $display("  [FAIL] funct3: expected=101 got=%b", funct3);
    end
    checks++;
    if (funct7 !== 7'h20) begin
        errors++;
        $display("  [FAIL] funct7: expected=20 got=%h", funct7);
    end

    if (errors == 0)
        $display("ALL PASS: %0d checks, 0 errors", checks);
    else
        $display("FAILED: %0d checks, %0d errors", checks, errors);

    $finish;
end

endmodule