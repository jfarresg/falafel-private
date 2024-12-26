`timescale 1ns / 1ps

`include "falafel_pkg.sv"

module falafel_input_buffer
  import falafel_pkg::*;
#(
    parameter QUEUE_ID = MSG_ID_SIZE'(0)
) (
    input logic clk_i,
    input logic rst_ni,

    input  logic              req_val_i,
    output logic              req_rdy_o,
    input  logic [DATA_W-1:0] req_data_i,

    output logic         buffered_req_val_o,
    input  logic         buffered_req_rdy_i,
    output alloc_entry_t buffered_req_data_o
);

  localparam NUM_FIFO_ENTRIES = 2;
  localparam ENTRY_WIDTH = MSG_ID_SIZE + DATA_W;



  // fifo signals
  logic                           fifo_write_en;
  logic                           fifo_read_en;
  logic                           fifo_full;
  logic                           fifo_empty;
  logic         [ENTRY_WIDTH-1:0] fifo_din;
  logic         [ENTRY_WIDTH-1:0] fifo_dout;

  alloc_entry_t                   fifo_din_struct;

  assign fifo_din_struct = {QUEUE_ID, req_data_i};

  assign req_rdy_o = !fifo_full;
  assign fifo_write_en = (req_val_i && req_rdy_o);
  assign fifo_din = ENTRY_WIDTH'(fifo_din_struct);


  falafel_fifo #(
      .DATA_W     (ENTRY_WIDTH),
      .NUM_ENTRIES(NUM_FIFO_ENTRIES)
  ) i__req_fifo (
      .clk_i,
      .rst_ni,
      .write_i(fifo_write_en),
      .read_i (fifo_read_en),
      .full_o (fifo_full),
      .empty_o(fifo_empty),
      .din_i  (fifo_din),
      .dout_o (fifo_dout)
  );

  assign buffered_req_val_o = !fifo_empty;
  assign fifo_read_en = (buffered_req_val_o && buffered_req_rdy_i);
  assign buffered_req_data_o = alloc_entry_t'(fifo_dout);
endmodule
