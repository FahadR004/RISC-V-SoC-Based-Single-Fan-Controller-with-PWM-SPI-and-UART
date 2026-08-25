`timescale 1ns/1ps

module tb_write_back;

localparam DATA_WIDTH = 32;
localparam ADDR_WIDTH = 32;

logic memToReg;
logic [DATA_WIDTH-1:0] mem_read_data;
logic [DATA_WIDTH-1:0] alu_result;
logic jalr;
logic jump;
logic [ADDR_WIDTH-1:0] pc_plus_4;
logic [DATA_WIDTH-1:0] write_data;

int errors = 0;
int checks = 0;

Write_Back #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
) dut (
    .memToReg(memToReg),
    .mem_read_data(mem_read_data),
    .alu_result(alu_result),
    .jalr(jalr),
    .jump(jump),
    .pc_plus_4(pc_plus_4),
    .write_data(write_data)
);

task automatic check(
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

task automatic reset_inputs();
    memToReg      = 1'b0;
    mem_read_data = 32'h0;
    alu_result    = 32'h0;
    jalr          = 1'b0;
    jump          = 1'b0;
    pc_plus_4     = 32'h0;
endtask

initial begin
    $dumpfile("tb_write_back.vcd");
    $dumpvars(0, tb_write_back);
end

initial begin
    $display("=== Write_Back Testbench ===");

    $display("\n-- Default path: R-type/I-type arithmetic (memToReg=0, jump=0, jalr=0) --");
    reset_inputs();
    alu_result = 32'hAAAA_BBBB;
    mem_read_data = 32'h1111_1111; // garbage, must be ignored
    pc_plus_4 = 32'h2222_2222;      // garbage, must be ignored
    #1; check("alu_result_selected", write_data, 32'hAAAA_BBBB);

    $display("\n-- Load path: memToReg=1, jump=0, jalr=0 --");
    reset_inputs();
    memToReg = 1'b1;
    mem_read_data = 32'hCAFE_BABE;
    alu_result = 32'hDEAD_DEAD;     // garbage, must be ignored
    #1; check("mem_read_data_selected", write_data, 32'hCAFE_BABE);

    $display("\n-- JAL path: jump=1, memToReg=0, jalr=0 --");
    reset_inputs();
    jump = 1'b1;
    pc_plus_4 = 32'h0000_1004;
    alu_result = 32'hFFFF_FFFF;     // garbage, must be ignored
    mem_read_data = 32'hEEEE_EEEE;  // garbage, must be ignored
    #1; check("jal_selects_pc_plus_4", write_data, 32'h0000_1004);

    $display("\n-- JALR path: jalr=1, memToReg=0, jump=0 --");
    reset_inputs();
    jalr = 1'b1;
    pc_plus_4 = 32'h0000_2008;
    alu_result = 32'h1234_5678;     // garbage, must be ignored
    #1; check("jalr_selects_pc_plus_4", write_data, 32'h0000_2008);

    $display("\n-- Priority: jump/jalr must win over memToReg --");
    reset_inputs();
    jump = 1'b1;
    memToReg = 1'b1;                // both asserted simultaneously (shouldn't happen from a correct
                                     // decode stage, but tests the mux's priority defensively)
    pc_plus_4 = 32'h0000_3000;
    mem_read_data = 32'hBEEF_BEEF;  // must be ignored despite memToReg=1
    #1; check("jump_overrides_memToReg", write_data, 32'h0000_3000);

    reset_inputs();
    jalr = 1'b1;
    memToReg = 1'b1;
    pc_plus_4 = 32'h0000_4000;
    mem_read_data = 32'hBEEF_BEEF;
    #1; check("jalr_overrides_memToReg", write_data, 32'h0000_4000);

    $display("\n-- Priority: jump and jalr both asserted (shouldn't happen, but must resolve deterministically) --");
    reset_inputs();
    jump = 1'b1;
    jalr = 1'b1;
    pc_plus_4 = 32'h0000_5000;
    #1; check("jump_and_jalr_both_set_still_pc_plus_4", write_data, 32'h0000_5000);

    $display("\n-- All flags zero, alu_result and mem_read_data both nonzero --");
    reset_inputs();
    alu_result = 32'h0000_0007;
    mem_read_data = 32'h0000_0099;
    #1; check("all_flags_zero_defaults_to_alu_result", write_data, 32'h0000_0007);

    if (errors == 0)
        $display("\nAll Write_Back tests PASSED! (%0d checks)", checks);
    else
        $display("\n%0d/%0d checks FAILED", errors, checks);

    $finish;
end

endmodule