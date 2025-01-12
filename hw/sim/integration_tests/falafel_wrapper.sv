// SPDX-FileCopyrightText: © 2025 Joan Farres Garcia
//
// SPDX-License-Identifier: BSD-3-Clause


module falafel_wrapper
  import falafel_pkg::*;
#(
    localparam unsigned NUM_HEADER_QUEUES = 2,
    localparam unsigned NUM_ALLOC_QUEUES  = 2,
    localparam unsigned NUM_FREE_QUEUES   = 2,

    localparam unsigned NUM_QUEUES = NUM_HEADER_QUEUES + NUM_ALLOC_QUEUES + NUM_FREE_QUEUES
) (
    input logic clk_i,
    input logic rst_ni,

    //--------------- request ---------------//
    input  logic [       0:0] req_val_i [NUM_QUEUES],
    output logic [       0:0] req_rdy_o [NUM_QUEUES],
    input  logic [DATA_W-1:0] req_data_i[NUM_QUEUES],

    //-------------- response ---------------//
    input  logic              resp_rdy_i,
    output logic              resp_val_o,
    output logic [DATA_W-1:0] resp_data_o,

    //----------- memory request ------------//
    output logic              mem_req_val_o,       // req valid
    input  logic              mem_req_rdy_i,       // mem ready
    output logic              mem_req_is_write_o,  // 1 for write, 0 for read
    output logic              mem_req_is_cas_o,    // 1 for cas, 0 for write
    output logic [DATA_W-1:0] mem_req_addr_o,      // address
    output logic [DATA_W-1:0] mem_req_data_o,      // write data
    output logic [DATA_W-1:0] mem_req_cas_exp_o,   // compare & swap expected value

    //----------- memory response ------------//
    input  logic              mem_resp_val_i,  // resp valid
    output logic              mem_resp_rdy_o,  // falafel ready
    input  logic [DATA_W-1:0] mem_resp_data_i  // resp data
);

  falafel #(
      .NUM_HEADER_QUEUES(NUM_HEADER_QUEUES),
      .NUM_ALLOC_QUEUES (NUM_ALLOC_QUEUES),
      .NUM_FREE_QUEUES  (NUM_FREE_QUEUES)
  ) i_falafel (
      .*
  );
endmodule
