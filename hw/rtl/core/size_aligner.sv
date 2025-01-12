// SPDX-FileCopyrightText: © 2025 Joan Farres Garcia
//
// SPDX-License-Identifier: BSD-3-Clause


module size_aligner
  import falafel_pkg::*;
(
    input logic clk_i,
    input logic rst_ni,

    input  logic [DATA_W-1:0] size_i,
    input  logic [DATA_W-1:0] alignment_i,
    output logic              is_error_o,
    output logic [DATA_W-1:0] aligned_size_o
);

  always_comb begin
    aligned_size_o = size_i;
    is_error_o = 1'b0;

    if (|size) begin
      aligned_size_o = size_i + (alignment_i - 1) & ~(alignment_i - 1);
    end else begin
      aligned_size_o = '0;
      is_error_o = 1'b1;
    end
  end

endmodule
