// SPDX-FileCopyrightText: © 2025 Joan Farres Garcia
//
// SPDX-License-Identifier: BSD-3-Clause


module falafel_output_fsm
  import falafel_pkg::*;
(
    // verilator lint_off UNUSEDSIGNAL
    input logic clk_i,
    input logic rst_ni,
    // verilator lint_on UNUSEDSIGNAL

    //-------------- response ---------------//
    input  logic              rsp_rdy_i,
    output logic              rsp_val_o,
    output logic [DATA_W-1:0] rsp_data_o,

    //----------- fifo interfaces ------------//
    input  logic              resp_fifo_empty_i,
    output logic              resp_fifo_read_o,
    input  logic [DATA_W-1:0] resp_fifo_dout_i
);

  always_comb begin
    resp_fifo_read_o = 1'b0;
    rsp_val_o = 1'b0;
    rsp_data_o = resp_fifo_dout_i;

    if (rsp_rdy_i && !resp_fifo_empty_i) begin
      resp_fifo_read_o = 1'b1;
      rsp_val_o = 1'b1;
      rsp_data_o = resp_fifo_dout_i;
    end
  end
endmodule
