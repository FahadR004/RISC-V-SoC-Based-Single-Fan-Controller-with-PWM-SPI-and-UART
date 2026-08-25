`timescale 1ns/1ps

module tb_immediate_generator;

parameter DATA_WIDTH = 32;

logic [DATA_WIDTH-1:0] instruction;
logic [DATA_WIDTH-1:0] immediate;

integer errors = 0;
integer tests  = 0;

immediate_generator #(
    .DATA_WIDTH(DATA_WIDTH)
) dut (
    .instruction(instruction),
    .immediate  (immediate)
);

// Builds instructions and expected immediates directly
task automatic check(
    input [DATA_WIDTH-1:0] instr,
    input [DATA_WIDTH-1:0] expected,
    input string           name
);
    begin
        instruction = instr;
        #1; // allow combinational settle
        tests++;
        if (immediate !== expected) begin
            errors++;
            $display("FAIL [%0s]: instr=%h  expected=%h  got=%h",
                        name, instr, expected, immediate);
        end else begin
            $display("PASS [%0s]: instr=%h  imm=%h", name, instr, immediate);
        end
    end
endtask

initial begin
    $dumpfile("tb_immediate_generator.vcd");
    $dumpvars(0, tb_immediate_generator);
end

initial begin

    // I-type: ADDI / load-style, positive immediate
    // imm[11:0] = instruction[31:20]
    // instr: imm=0x123, rs1=x1, funct3=000, rd=x2, opcode=0010011 (ADDI)
    check(32'b000000010010_00001_000_00010_0010011,
            32'h0000_0012,
            "I-type ADDI positive");

    // I-type: negative immediate (sign extension test), opcode = LW (0000011)
    // imm = -1 (12'hFFF)
    check(32'b111111111111_00001_010_00010_0000011,
            32'hFFFF_FFFF,
            "I-type LW negative (sign-extend)");

    // I-type: JALR, opcode = 1100111
    // imm = 0x7FF (max positive 12-bit because we dont' have negative addresses and we jump to positive addresses)
    check(32'b011111111111_00001_000_00010_1100111,
            32'h0000_07FF,
            "I-type JALR positive");

    // S-type: SW, opcode = 0100011
    // imm[11:5]=instr[31:25], imm[4:0]=instr[11:7]
    // Target imm = 0xFFFFFFFE (-2): imm[11:5]=1111111, imm[4:0]=11110
    check(32'b1111111_00000_00001_010_11110_0100011,
            32'hFFFF_FFFE,
            "S-type SW negative");

    // S-type: positive small immediate = 5
    // imm[11:5]=0000000, imm[4:0]=00101
    check(32'b0000000_00010_00001_010_00101_0100011,
            32'h0000_0005,
            "S-type SW positive");

    // B-type: BEQ, opcode = 1100011
    // imm[12|10:5|4:1|11] packed from instr[31|30:25|11:8|7], LSB fixed 0
    // Target imm = 0x00000FFE (positive, max 13-bit even value before sign bit)
    // instr[31]=0(sign), instr[30:25]=111111, instr[11:8]=1111, instr[7]=1
    check(32'b0_111111_00010_00001_000_1111_1_1100011,
            32'h0000_0FFE,
            "B-type BEQ positive max");

    // B-type: negative immediate, imm = -2 (all branch bits set except final 0)
    // instr[31]=1, instr[30:25]=111111, instr[11:8]=1111, instr[7]=1
    check(32'b1_111111_00010_00001_000_1111_1_1100011,
            32'hFFFF_FFFE,
            "B-type BNE negative"); // BNE negative means we're jumping backward, like, say in a loop.

    // U-type: LUI, opcode = 0110111
    // imm = instr[31:12] << 12
    check({20'hABCDE, 5'd2, 7'b0110111},
        32'hABCDE000,
        "U-type LUI");

    // U-type: AUIPC, opcode = 0010111
    check({20'h12345, 5'd2, 7'b0010111},
        32'h12345000,
        "U-type AUIPC");

    // J-type: JAL, opcode = 1101111
    // imm[20|10:1|11|19:12] packed from instr[31|30:21|20|19:12], LSB fixed 0
    // Target: positive small value, imm = 0x00000004 (offset of 4)
    // instr[31]=0, instr[19:12]=00000000, instr[20]=0, instr[30:21]=0000000010
    check({1'b0, 10'b0000000010, 1'b0, 8'b00000000, 5'd2, 7'b1101111},
            32'h0000_0004,
            "J-type JAL positive");

    // J-type: negative immediate, imm = -4
    // instr[31]=1, instr[30:21]=1111111110, instr[20]=1, instr[19:12]=11111111
    check({1'b1, 10'b1111111110, 1'b1, 8'b11111111, 5'd2, 7'b1101111},
            32'hFFFF_FFFC,
            "J-type JAL negative");

    // Default: unrecognized opcode -> immediate should be 0
    check(32'b0000000_00000_00000_000_00000_1111111,
            32'h0000_0000,
            "Default (unknown opcode)");

    $display("=== Testbench complete: %0d/%0d passed ===",
                tests - errors, tests);
    if (errors == 0)
        $display("ALL TESTS PASSED");
    else
        $display("%0d TEST(S) FAILED", errors);

    $finish;
end

endmodule