`timescale 1ns/1ps

module tb_execute;

localparam ADDR_WIDTH  = 32;
localparam INSTR_WIDTH = 32;
localparam DATA_WIDTH  = 32;
localparam REG_NUMS    = 32;

logic [ADDR_WIDTH-1:0] pc_current_addr;
logic [ADDR_WIDTH-1:0] pc_plus_4;
logic                  aluSrc;
logic [1:0]            aluOp;
logic [6:0]            opcode;
logic [2:0]            funct3;
logic [6:0]            funct7;
logic                  branch;
logic                  jump;
logic                  jalr;
logic [DATA_WIDTH-1:0] read_data1;
logic [DATA_WIDTH-1:0] read_data2;
logic [DATA_WIDTH-1:0] immediate;
logic [DATA_WIDTH-1:0] result;
logic [ADDR_WIDTH-1:0] next_pc_address;

int errors = 0;
int checks = 0;

Execute #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .INSTR_WIDTH(INSTR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .REG_NUMS(REG_NUMS)
) dut (
    .pc_current_addr (pc_current_addr),
    .pc_plus_4       (pc_plus_4),
    .aluSrc          (aluSrc),
    .aluOp           (aluOp),
    .opcode          (opcode),
    .funct3          (funct3),
    .funct7          (funct7),
    .branch          (branch),
    .jump            (jump),
    .jalr            (jalr),
    .read_data1      (read_data1),
    .read_data2      (read_data2),
    .immediate       (immediate),
    .result          (result),
    .next_pc_address (next_pc_address)
);s

task automatic check(input string name, input logic [31:0] got, input logic [31:0] exp);
    checks++;
    if (got !== exp) begin
        errors++;
        $display("[FAIL] %s: expected=%0h got=%0h", name, exp, got);
    end else begin
        $display("[PASS] %s = %0h", name, got);
    end
endtask 

task automatic reset_inputs();
    pc_current_addr = 32'h0;
    pc_plus_4       = 32'h4;
    aluSrc          = 1'b0;
    aluOp           = 2'b00;
    opcode          = 7'h00;
    funct3          = 3'b000;
    funct7          = 7'b0000000;
    branch          = 1'b0;
    jump            = 1'b0;
    jalr            = 1'b0;
    read_data1      = 32'h0;
    read_data2      = 32'h0;
    immediate       = 32'h0;
endtask

initial begin
    $dumpfile("tb_execute");
    $dumpvars(0, tb_execute);
end

initial begin
    $display("=== Execute Testbench ===");

    $display("\n-- R-type ADD (x3 = x1 + x2) --");
    reset_inputs();
    opcode = 7'h33; funct3 = 3'b000; funct7 = 7'b0000000;
    aluOp = 2'b10; aluSrc = 1'b0;
    read_data1 = 32'd10; read_data2 = 32'd15;
    pc_current_addr = 32'h100; pc_plus_4 = 32'h104;
    #1;
    check("r_add_result", result, 32'd25);
    check("r_add_next_pc_is_fallthrough", next_pc_address, 32'h104);

    $display("\n-- R-type SUB (x3 = x1 - x2), funct7 bit30 set, R-type so opcode[5]=1 --");
    reset_inputs();
    opcode = 7'h33; funct3 = 3'b000; funct7 = 7'b0100000;
    aluOp = 2'b10; aluSrc = 1'b0;
    read_data1 = 32'd20; read_data2 = 32'd5;
    #1; check("r_sub_result", result, 32'd15);

    $display("\n-- I-type ADDI: funct7 bits (imm[11:5]) look like SUB pattern but must still ADD --");
    reset_inputs();
    opcode = 7'h13; funct3 = 3'b000; funct7 = 7'b0100000; // opcode[5]=0 -> I-type
    aluOp = 2'b10; aluSrc = 1'b1;
    read_data1 = 32'd100; immediate = 32'd5;
    #1; check("i_addi_ignores_funct7", result, 32'd105);

    $display("\n-- I-type SRAI: shift-type bit (funct7[5]) still valid regardless of opcode[5] --");
    reset_inputs();
    opcode = 7'h13; funct3 = 3'b101; funct7 = 7'b0100000; // SRAI
    aluOp = 2'b10; aluSrc = 1'b1;
    read_data1 = 32'h8000_0000; immediate = 32'd4; // shamt = 4
    #1; check("i_srai_sign_extends", result, 32'hF800_0000);

    $display("\n-- Load address calc (LW): aluOp=00 forces ADD regardless of funct3/funct7 --");
    reset_inputs();
    opcode = 7'h03; funct3 = 3'b010; funct7 = 7'b1111111; // garbage funct7, should be ignored
    aluOp = 2'b00; aluSrc = 1'b1;
    read_data1 = 32'h2000; immediate = 32'h10;
    #1; check("lw_address_calc", result, 32'h2010);

    $display("\n-- LUI: aluOp=11, result passes immediate through --");
    reset_inputs();
    opcode = 7'h37; aluOp = 2'b11; aluSrc = 1'b1;
    read_data1 = 32'hDEAD_BEEF; immediate = 32'hABCDE000;
    #1; check("lui_passthrough", result, 32'hABCDE000);


    // Branch resolution through the full chain: funct3 -> eq/lt/ltu -> next_pc

    $display("\n-- BEQ taken --");
    reset_inputs();
    opcode = 7'h63; funct3 = 3'b000; aluOp = 2'b01; aluSrc = 1'b0;
    branch = 1'b1;
    pc_current_addr = 32'h200; pc_plus_4 = 32'h204; immediate = 32'h20;
    read_data1 = 32'd7; read_data2 = 32'd7; // equal
    #1; check("beq_taken_next_pc", next_pc_address, 32'h220);

    $display("\n-- BEQ not taken --");
    read_data2 = 32'd8; // not equal
    #1; check("beq_not_taken_next_pc", next_pc_address, 32'h204);

    $display("\n-- BNE taken --");
    reset_inputs();
    opcode = 7'h63; funct3 = 3'b001; aluOp = 2'b01; aluSrc = 1'b0;
    branch = 1'b1;
    pc_current_addr = 32'h200; pc_plus_4 = 32'h204; immediate = 32'h20;
    read_data1 = 32'd7; read_data2 = 32'd8; // not equal
    #1; check("bne_taken_next_pc", next_pc_address, 32'h220);

    $display("\n-- BLT taken (signed) --");
    reset_inputs();
    opcode = 7'h63; funct3 = 3'b100; aluOp = 2'b01; aluSrc = 1'b0;
    branch = 1'b1;
    pc_current_addr = 32'h200; pc_plus_4 = 32'h204; immediate = 32'h20;
    read_data1 = 32'hFFFFFFFF; read_data2 = 32'd1; // -1 < 1 (signed)
    #1; check("blt_signed_taken", next_pc_address, 32'h220);

    $display("\n-- BLTU not taken (same bits, unsigned interpretation) --");
    reset_inputs();
    opcode = 7'h63; funct3 = 3'b110; aluOp = 2'b01; aluSrc = 1'b0;
    branch = 1'b1;
    pc_current_addr = 32'h200; pc_plus_4 = 32'h204; immediate = 32'h20;
    read_data1 = 32'hFFFFFFFF; read_data2 = 32'd1; // huge unsigned, not < 1
    #1; check("bltu_unsigned_not_taken", next_pc_address, 32'h204);

    $display("\n-- BGE taken --");
    reset_inputs();
    opcode = 7'h63; funct3 = 3'b101; aluOp = 2'b01; aluSrc = 1'b0;
    branch = 1'b1;
    pc_current_addr = 32'h200; pc_plus_4 = 32'h204; immediate = 32'h20;
    read_data1 = 32'd10; read_data2 = 32'd5; // 10 >= 5
    #1; check("bge_taken", next_pc_address, 32'h220);

    $display("\n-- BGEU taken --");
    reset_inputs();
    opcode = 7'h63; funct3 = 3'b111; aluOp = 2'b01; aluSrc = 1'b0;
    branch = 1'b1;
    pc_current_addr = 32'h200; pc_plus_4 = 32'h204; immediate = 32'h20;
    read_data1 = 32'hFFFFFFFF; read_data2 = 32'd1; // unsigned 10 >= 5-equivalent (huge >= 1)
    #1; check("bgeu_taken", next_pc_address, 32'h220);

    $display("\n-- JAL: unconditional, PC-relative --");
    reset_inputs();
    opcode = 7'h6F; jump = 1'b1;
    pc_current_addr = 32'h300; pc_plus_4 = 32'h304; immediate = 32'h40;
    #1; check("jal_target", next_pc_address, 32'h340);

    $display("\n-- JALR: target = (rs1 + imm) & ~1, aluOp=00 for its own address-calc use --");
    reset_inputs();
    opcode = 7'h67; jalr = 1'b1; aluOp = 2'b00; aluSrc = 1'b1;
    pc_current_addr = 32'h300; pc_plus_4 = 32'h304;
    read_data1 = 32'h1001; immediate = 32'h10; // sum = 0x1011, odd
    #1;
    check("jalr_target_masked", next_pc_address, 32'h1010);
    check("jalr_result_also_computed", result, 32'h1011); // ALU still computes rs1+imm for +4 use elsewhere

    $display("\n=== Testbench complete: %0d/%0d passed ===", checks - errors, checks);
    if (errors == 0)
        $display("ALL TESTS PASSED");
    else
        $display("%0d TEST(S) FAILED", errors);

    $finish;
end

endmodule