// SPDX-FileCopyrightText: © 2025 Joan Farres Garcia
//
// SPDX-License-Identifier: BSD-3-Clause


`timescale 1ns / 1ps

module falafel_block_parser
  import falafel_pkg::*;
(
    input free_block_t block_i,
    input word_t       requested_size_i,

    output logic  is_null_o,
    output logic  is_big_enough_o,
    output word_t next_block_ptr
);

  assign is_null_o = block_i.next_ptr == NULL_PTR;
  assign is_big_enough_o = block_i.size >= requested_size_i;
  assign next_block_ptr = block_i.next_ptr;
endmodule
