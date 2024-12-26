`timescale 1ns / 1ps
`include "falafel_pkg.sv"

module falafel_config_regs
  import falafel_pkg::*;
(
    input logic clk_i,
    input logic rst_ni,

    input logic write_i,
    input logic [DATA_W-1:0] addr_i,
    input logic [DATA_W-1:0] data_i,

    output config_regs_t config_o
);
  typedef logic [DATA_W-1:0] word_t;

  config_regs_t config_d, config_q;

  always_comb begin
    config_d = config_q;

    if (write_i) begin
      unique case (addr_i)
        FREE_LIST_PTR_ADDR: config_d.free_list_ptr = word_t'(data_i);
        LOCK_PTR_ADDR: config_d.lock_ptr = word_t'(data_i);
        LOCK_ID_ADDR: config_d.lock_id = word_t'(data_i);
        default: ;
      endcase
    end
  end

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      config_q <= '0;
    end else begin
      config_q <= config_d;
    end
  end

  assign config_o = config_q;
endmodule
