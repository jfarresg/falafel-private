`timescale 1ns / 1ps

module falafel_core_wrapper
  import falafel_pkg::*;
(
    input logic clk_i,
    input logic rst_ni,

    input logic [DATA_W-1:0] falafel_config_free_list_ptr,
    input logic [DATA_W-1:0] falafel_config_lock_ptr,
    input logic [DATA_W-1:0] falafel_config_lock_id,

    //----------- fifo interfaces ------------//
    input  logic              alloc_fifo_empty_i,
    output logic              alloc_fifo_read_o,
    input  logic [DATA_W-1:0] alloc_fifo_dout_i,

    input  logic              free_fifo_empty_i,
    output logic              free_fifo_read_o,
    input  logic [DATA_W-1:0] free_fifo_dout_i,

    input  logic              resp_fifo_full_i,
    output logic              resp_fifo_write_o,
    output logic [DATA_W-1:0] resp_fifo_din_o,

    //----------- memory request -----------//
    output logic              mem_req_val_o,       // req valid
    input  logic              mem_req_rdy_i,       // mem ready
    output logic              mem_req_is_write_o,  // 1 for write, 0 for read
    output logic              mem_req_is_cas_o,    // 1 for cas, 0 for write
    output logic [DATA_W-1:0] mem_req_addr_o,      // address
    output logic [DATA_W-1:0] mem_req_data_o,      // write data
    output logic [DATA_W-1:0] mem_req_cas_exp_o,   // compare & swap expected value

    //----------- memory response ------------//
    input  logic              mem_rsp_val_i,  // resp valid
    output logic              mem_rsp_rdy_o,  // falafel ready
    input  logic [DATA_W-1:0] mem_rsp_data_i, // resp data

    //----------- fifo interfaces ------------//
    output logic              sbrk_req_val_o,
    input  logic              sbrk_rsp_val_i,
    input  logic [DATA_W-1:0] sbrk_rsp_ptr_i
);

  config_regs_t falafel_config;

  falafel_core i_falafel_core (
      .falafel_config_i(falafel_config),
      .mem_req_ack_i(mem_req_rdy_i),
      .*
  );

  assign falafel_config.free_list_ptr = falafel_config_free_list_ptr;
  assign falafel_config.lock_ptr = falafel_config_lock_ptr;
  assign falafel_config.lock_id = falafel_config_lock_id;
endmodule
