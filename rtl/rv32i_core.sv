module rv32i_core #(
  parameter logic [31:0] RESET_VECTOR = 32'h0000_0000
) (
  input  logic        clk,
  input  logic        reset_n,
  output logic [31:0] imem_addr,
  input  logic [31:0] imem_rdata,
  input  logic        imem_error,
  output logic        data_re,
  output logic        data_we,
  output logic [31:0] data_addr,
  output logic [31:0] data_wdata,
  output logic [3:0]  data_wstrb,
  input  logic [31:0] data_rdata,
  input  logic        data_error,
  output logic [31:0] debug_pc,
  output logic        trap,
  output logic        halted
);
  logic [31:0] regs [0:31];
  logic [31:0] pc;
  logic [31:0] next_pc;
  logic [31:0] wb_data;
  logic [4:0]  wb_rd;
  logic        wb_en;
  logic        illegal;

  logic [6:0] opcode;
  logic [2:0] funct3;
  logic [6:0] funct7;
  logic [4:0] rs1;
  logic [4:0] rs2;
  logic [4:0] rd;
  logic [31:0] op1;
  logic [31:0] op2;
  logic [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;
  logic [31:0] effective_addr;

  assign opcode = imem_rdata[6:0];
  assign rd     = imem_rdata[11:7];
  assign funct3 = imem_rdata[14:12];
  assign rs1    = imem_rdata[19:15];
  assign rs2    = imem_rdata[24:20];
  assign funct7 = imem_rdata[31:25];
  assign op1    = (rs1 == 0) ? 32'b0 : regs[rs1];
  assign op2    = (rs2 == 0) ? 32'b0 : regs[rs2];

  assign imm_i = {{20{imem_rdata[31]}}, imem_rdata[31:20]};
  assign imm_s = {{20{imem_rdata[31]}}, imem_rdata[31:25], imem_rdata[11:7]};
  assign imm_b = {{19{imem_rdata[31]}}, imem_rdata[31], imem_rdata[7],
                  imem_rdata[30:25], imem_rdata[11:8], 1'b0};
  assign imm_u = {imem_rdata[31:12], 12'b0};
  assign imm_j = {{11{imem_rdata[31]}}, imem_rdata[31], imem_rdata[19:12],
                  imem_rdata[20], imem_rdata[30:21], 1'b0};

  assign imem_addr = pc;
  assign debug_pc  = pc;

  always_comb begin
    next_pc        = pc + 32'd4;
    wb_data        = 32'b0;
    wb_rd          = rd;
    wb_en          = 1'b0;
    data_re        = 1'b0;
    data_we        = 1'b0;
    data_addr      = 32'b0;
    data_wdata     = 32'b0;
    data_wstrb     = 4'b0000;
    effective_addr = op1 + imm_i;
    illegal        = 1'b0;

    unique case (opcode)
      7'b0110111: begin // LUI
        wb_en   = 1'b1;
        wb_data = imm_u;
      end
      7'b0010111: begin // AUIPC
        wb_en   = 1'b1;
        wb_data = pc + imm_u;
      end
      7'b1101111: begin // JAL
        wb_en   = 1'b1;
        wb_data = pc + 32'd4;
        next_pc = pc + imm_j;
      end
      7'b1100111: begin // JALR
        if (funct3 != 3'b000) illegal = 1'b1;
        else begin
          wb_en   = 1'b1;
          wb_data = pc + 32'd4;
          next_pc = (op1 + imm_i) & 32'hffff_fffe;
        end
      end
      7'b1100011: begin // BRANCH
        unique case (funct3)
          3'b000: if (op1 == op2) next_pc = pc + imm_b;
          3'b001: if (op1 != op2) next_pc = pc + imm_b;
          3'b100: if ($signed(op1) < $signed(op2)) next_pc = pc + imm_b;
          3'b101: if ($signed(op1) >= $signed(op2)) next_pc = pc + imm_b;
          3'b110: if (op1 < op2) next_pc = pc + imm_b;
          3'b111: if (op1 >= op2) next_pc = pc + imm_b;
          default: illegal = 1'b1;
        endcase
      end
      7'b0000011: begin // LOAD
        effective_addr = op1 + imm_i;
        data_addr = effective_addr;
        data_re   = 1'b1;
        wb_en     = 1'b1;
        unique case (funct3)
          3'b000: begin // LB
            unique case (effective_addr[1:0])
              2'd0: wb_data = {{24{data_rdata[7]}}, data_rdata[7:0]};
              2'd1: wb_data = {{24{data_rdata[15]}}, data_rdata[15:8]};
              2'd2: wb_data = {{24{data_rdata[23]}}, data_rdata[23:16]};
              2'd3: wb_data = {{24{data_rdata[31]}}, data_rdata[31:24]};
            endcase
          end
          3'b001: begin // LH
            if (effective_addr[0]) illegal = 1'b1;
            else if (effective_addr[1]) wb_data = {{16{data_rdata[31]}}, data_rdata[31:16]};
            else wb_data = {{16{data_rdata[15]}}, data_rdata[15:0]};
          end
          3'b010: begin // LW
            if (effective_addr[1:0] != 0) illegal = 1'b1;
            wb_data = data_rdata;
          end
          3'b100: begin // LBU
            unique case (effective_addr[1:0])
              2'd0: wb_data = {24'b0, data_rdata[7:0]};
              2'd1: wb_data = {24'b0, data_rdata[15:8]};
              2'd2: wb_data = {24'b0, data_rdata[23:16]};
              2'd3: wb_data = {24'b0, data_rdata[31:24]};
            endcase
          end
          3'b101: begin // LHU
            if (effective_addr[0]) illegal = 1'b1;
            else if (effective_addr[1]) wb_data = {16'b0, data_rdata[31:16]};
            else wb_data = {16'b0, data_rdata[15:0]};
          end
          default: illegal = 1'b1;
        endcase
      end
      7'b0100011: begin // STORE
        effective_addr = op1 + imm_s;
        data_addr = effective_addr;
        data_we   = 1'b1;
        unique case (funct3)
          3'b000: begin // SB
            data_wstrb = 4'b0001 << effective_addr[1:0];
            data_wdata = {4{op2[7:0]}};
          end
          3'b001: begin // SH
            if (effective_addr[0]) illegal = 1'b1;
            data_wstrb = effective_addr[1] ? 4'b1100 : 4'b0011;
            data_wdata = {2{op2[15:0]}};
          end
          3'b010: begin // SW
            if (effective_addr[1:0] != 0) illegal = 1'b1;
            data_wstrb = 4'b1111;
            data_wdata = op2;
          end
          default: illegal = 1'b1;
        endcase
      end
      7'b0010011: begin // OP-IMM
        wb_en = 1'b1;
        unique case (funct3)
          3'b000: wb_data = op1 + imm_i;
          3'b010: wb_data = ($signed(op1) < $signed(imm_i)) ? 32'd1 : 32'd0;
          3'b011: wb_data = (op1 < imm_i) ? 32'd1 : 32'd0;
          3'b100: wb_data = op1 ^ imm_i;
          3'b110: wb_data = op1 | imm_i;
          3'b111: wb_data = op1 & imm_i;
          3'b001: begin
            if (funct7 != 7'b0000000) illegal = 1'b1;
            wb_data = op1 << imem_rdata[24:20];
          end
          3'b101: begin
            if (funct7 == 7'b0000000) wb_data = op1 >> imem_rdata[24:20];
            else if (funct7 == 7'b0100000) wb_data = $signed(op1) >>> imem_rdata[24:20];
            else illegal = 1'b1;
          end
        endcase
      end
      7'b0110011: begin // OP
        wb_en = 1'b1;
        unique case ({funct7, funct3})
          {7'b0000000,3'b000}: wb_data = op1 + op2;
          {7'b0100000,3'b000}: wb_data = op1 - op2;
          {7'b0000000,3'b001}: wb_data = op1 << op2[4:0];
          {7'b0000000,3'b010}: wb_data = ($signed(op1) < $signed(op2)) ? 32'd1 : 32'd0;
          {7'b0000000,3'b011}: wb_data = (op1 < op2) ? 32'd1 : 32'd0;
          {7'b0000000,3'b100}: wb_data = op1 ^ op2;
          {7'b0000000,3'b101}: wb_data = op1 >> op2[4:0];
          {7'b0100000,3'b101}: wb_data = $signed(op1) >>> op2[4:0];
          {7'b0000000,3'b110}: wb_data = op1 | op2;
          {7'b0000000,3'b111}: wb_data = op1 & op2;
          default: illegal = 1'b1;
        endcase
      end
      7'b0001111: begin // FENCE/FENCE.I are NOPs in this uncached core
        if (funct3 != 3'b000 && funct3 != 3'b001) illegal = 1'b1;
      end
      7'b1110011: begin // ECALL/EBREAK trap; CSRs are outside RV32I scope here
        illegal = 1'b1;
      end
      default: illegal = 1'b1;
    endcase

    // IALIGN=32: only the selected target is checked, so untaken branches
    // with an unaligned immediate do not fault.
    if (next_pc[1:0] != 0 || pc[1:0] != 0 || imem_error) illegal = 1'b1;

    if (illegal || halted || !reset_n) begin
      wb_en      = 1'b0;
      data_re    = 1'b0;
      data_we    = 1'b0;
      data_wstrb = 4'b0;
    end
  end

  always_ff @(posedge clk or negedge reset_n) begin : p_state
    if (!reset_n) begin
      pc     <= RESET_VECTOR;
      trap   <= 1'b0;
      halted <= 1'b0;
      for (int i = 0; i < 32; i++) regs[i] <= 32'b0;
    end else if (!halted) begin
      if (illegal || ((data_re || data_we) && data_error)) begin
        trap   <= 1'b1;
        halted <= 1'b1;
      end else begin
        pc <= next_pc;
        if (wb_en && wb_rd != 0) regs[wb_rd] <= wb_data;
        regs[0] <= 32'b0;
      end
    end
  end
endmodule
