`timescale 1ns / 1ps
`include "falafel_pkg.sv"

module falafel_wrapper
  import falafel_pkg::*;
#(
    parameter unsigned NUM_HEADER_QUEUES = 1,
    parameter unsigned NUM_ALLOC_QUEUES = 1,
    parameter unsigned NUM_FREE_QUEUES = 1,
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
    input  logic              mem_rsp_val_i,  // resp valid
    output logic              mem_rsp_rdy_o,  // falafel ready
    input  logic [DATA_W-1:0] mem_rsp_data_i  // resp data
);

  localparam NUM_OP_FIFO_ENTRIES = 4;
  localparam [DATA_W-1:0] MSG_ID_SIZE = 8;
  localparam ALLOC_ENTRY_WIDTH = MSG_ID_SIZE + DATA_W;

  logic alloc_fifo_write_en, alloc_fifo_read_en, alloc_fifo_full, alloc_fifo_empty;
  logic [ALLOC_ENTRY_WIDTH-1:0] alloc_fifo_din, alloc_fifo_dout;

  logic free_fifo_write_en, free_fifo_read_en, free_fifo_full, free_fifo_empty;
  logic [DATA_W-1:0] free_fifo_din, free_fifo_dout;

  logic resp_fifo_write_en, resp_fifo_read_en, resp_fifo_full, resp_fifo_empty;
  logic [DATA_W-1:0] resp_fifo_din, resp_fifo_dout;

  logic [DATA_W-1:0] alloc_fifo_dout_size;

  logic req_alloc_valid, is_alloc;

  assign req_alloc_valid = (!alloc_fifo_empty) || (!free_fifo_empty);
  assign is_alloc = !alloc_fifo_empty;

  logic result_ready;
  assign result_ready = !resp_fifo_full;

  logic [MSG_ID_SIZE-1:0] alloc_fifo_din_id;
  logic [DATA_W-1:0] alloc_fifo_din_size;
  logic [MSG_ID_SIZE-1:0] alloc_fifo_dout_id;

  assign alloc_fifo_din = {alloc_fifo_din_id, alloc_fifo_din_size};
  assign alloc_fifo_dout_size = alloc_fifo_dout[DATA_W-1:0];
  assign alloc_fifo_dout_id = alloc_fifo_dout[DATA_W+:MSG_ID_SIZE];

  // Config registers
  config_regs_t config_regs;


  logic [MSG_ID_SIZE-1:0] id_buffer_d, id_buffer_q;
  assign id_buffer_d = alloc_fifo_read_en ? alloc_fifo_dout_id : id_buffer_q;

  always_ff @(posedge clk_i) begin
    id_buffer_q <= id_buffer_d;
  end

  falafel_input_arbiter #(
      .NUM_HEADER_QUEUES(NUM_HEADER_QUEUES),
      .NUM_ALLOC_QUEUES (NUM_ALLOC_QUEUES),
      .NUM_FREE_QUEUES  (NUM_FREE_QUEUES)
  ) i_falafel_input_arbiter (
      .clk_i,
      .rst_ni,

      .req_val_i (req_val_i),
      .req_rdy_o (req_rdy_o),
      .req_data_i(req_data_i),

      .alloc_fifo_full_i    (alloc_fifo_full),
      .alloc_fifo_write_o   (alloc_fifo_write_en),
      .alloc_fifo_din_size_o(alloc_fifo_din_size),
      .alloc_fifo_din_id_o  (alloc_fifo_din_id),
      .free_fifo_full_i     (free_fifo_full),
      .free_fifo_write_o    (free_fifo_write_en),
      .free_fifo_din_o      (free_fifo_din),

      .config_o(config_regs)
  );

  logic falafel_req_ready;
  assign alloc_fifo_read_en = is_alloc ? falafel_req_ready : 0;
  assign free_fifo_read_en  = !(is_alloc) ? falafel_req_ready : 0;

  falafel i_falafel (
      .clk_i,
      .rst_ni,
      .falafel_config_i(config_regs),
      .config_alloc_strategy_i(0),  // TODO
      .req_alloc_ready_o(falafel_req_ready),
      .is_alloc_i(is_alloc),
      .req_alloc_valid_i(req_alloc_valid),

      .addr_to_free_i(free_fifo_dout),
      .size_to_allocate_i(alloc_fifo_dout_size),

      .rsp_result_is_write_o(resp_fifo_write_en),
      .rsp_result_val_o(  /* TODO */),
      .rsp_result_data_o(resp_fifo_din),
      .result_ready_i(result_ready),

      //----------- memory request ------------//
      .mem_req_val_o,  // req valid
      .mem_req_rdy_i,  // mem ready
      .mem_req_is_write_o,  // 1 for write, 0 for read
      .mem_req_is_cas_o,  // 1 for cas, 0 for write
      .mem_req_addr_o,  // address
      .mem_req_data_o,  // write data
      .mem_req_cas_exp_o,  // comp
      .mem_rsp_val_i,  // resp valid
      .mem_rsp_rdy_o,  // falafel ready
      .mem_rsp_data_i
  );


  falafel_fifo #(
      .DATA_W(ALLOC_ENTRY_WIDTH),
      .NUM_ENTRIES(NUM_OP_FIFO_ENTRIES)
  ) i_alloc_fifo (
      .clk_i,
      .rst_ni,
      .write_i(alloc_fifo_write_en),
      .read_i (alloc_fifo_read_en),
      .full_o (alloc_fifo_full),
      .empty_o(alloc_fifo_empty),
      .din_i  (alloc_fifo_din),
      .dout_o (alloc_fifo_dout)
  );

  falafel_fifo #(
      .DATA_W(DATA_W),
      .NUM_ENTRIES(NUM_OP_FIFO_ENTRIES)
  ) i_free_fifo (
      .clk_i,
      .rst_ni,
      .write_i(free_fifo_write_en),
      .read_i (free_fifo_read_en),
      .full_o (free_fifo_full),
      .empty_o(free_fifo_empty),
      .din_i  (free_fifo_din),
      .dout_o (free_fifo_dout)
  );

  falafel_fifo #(
      .DATA_W(DATA_W),
      .NUM_ENTRIES(NUM_OP_FIFO_ENTRIES)
  ) i_resp_fifo (
      .clk_i,
      .rst_ni,
      .write_i(resp_fifo_write_en),
      .read_i (resp_fifo_read_en),
      .full_o (resp_fifo_full),
      .empty_o(resp_fifo_empty),
      .din_i  (resp_fifo_din),
      .dout_o (resp_fifo_dout)
  );

  falafel_output_fsm i_falafel_output_fsm (
      .clk_i,
      .rst_ni,

      .rsp_rdy_i (resp_rdy_i),
      .rsp_val_o (resp_val_o),
      .rsp_data_o(resp_data_o),

      .resp_fifo_empty_i(resp_fifo_empty),
      .resp_fifo_read_o (resp_fifo_read_en),
      .resp_fifo_dout_i (resp_fifo_dout)
  );

endmodule
