// SPDX-FileCopyrightText: © 2025 Joan Farres Garcia
//
// SPDX-License-Identifier: BSD-3-Clause


`timescale 1ns / 1ps

module falafel_input_parser_wrapper
  import falafel_pkg::*;
(
    input logic clk_i,
    input logic rst_ni,

    //--------------- request ---------------//
    input  logic              req_val_i,
    output logic              req_rdy_o,
    input  logic [DATA_W-1:0] req_data_i,

    //----------- fifo interfaces ------------//
    output logic                   alloc_req_val_o,
    input  logic                   alloc_req_rdy_i,
    output logic [MSG_ID_SIZE-1:0] alloc_req_data_id_o,
    output logic [     DATA_W-1:0] alloc_req_data_size_o,

    output logic                   free_req_val_o,
    input  logic                   free_req_rdy_i,
    output logic [MSG_ID_SIZE-1:0] free_req_data_id_o,
    output logic [     DATA_W-1:0] free_req_data_size_o,

    //----------- memory response ------------//
    output logic              config_reg_write_o,
    output logic [DATA_W-1:0] config_reg_data_o,
    output logic [DATA_W-1:0] config_reg_addr_o
);

  alloc_entry_t alloc_req_data_struct;
  alloc_entry_t free_req_data_struct;

  falafel_input_parser i_falafel_input_parser (
      .alloc_req_data_o(alloc_req_data_struct),
      .free_req_data_o (free_req_data_struct),
      .*
  );

  assign alloc_req_data_id_o   = alloc_req_data_struct.id;
  assign alloc_req_data_size_o = alloc_req_data_struct.size;
  assign free_req_data_id_o    = free_req_data_struct.id;
  assign free_req_data_size_o  = free_req_data_struct.size;
endmodule
