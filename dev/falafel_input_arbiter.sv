`timescale 1ns / 1ps
`include "falafel_pkg.sv"

module falafel_input_arbiter
  import falafel_pkg::*;
#(
    parameter unsigned NUM_HEADER_QUEUES = 1,
    parameter unsigned NUM_ALLOC_QUEUES  = 1,
    parameter unsigned NUM_FREE_QUEUES   = 1,

    localparam unsigned NUM_QUEUES = NUM_HEADER_QUEUES + NUM_ALLOC_QUEUES + NUM_FREE_QUEUES
) (
    input logic clk_i,
    input logic rst_ni,

    //--------------- request ---------------//
    input  logic              req_val_i [NUM_QUEUES],
    output logic              req_rdy_o [NUM_QUEUES],
    input  logic [DATA_W-1:0] req_data_i[NUM_QUEUES],

    //----------- fifo interfaces ------------//
    input  logic                   alloc_fifo_full_i,
    output logic                   alloc_fifo_write_o,
    output logic [     DATA_W-1:0] alloc_fifo_din_size_o,
    output logic [MSG_ID_SIZE-1:0] alloc_fifo_din_id_o,

    input  logic              free_fifo_full_i,
    output logic              free_fifo_write_o,
    output logic [DATA_W-1:0] free_fifo_din_o,

    //------------- config regs --------------//
    output config_regs_t config_o
);

  logic                      config_reg_write;
  logic         [DATA_W-1:0] config_reg_data;
  logic         [DATA_W-1:0] config_reg_addr;


  logic                      queue_alloc_fifo_val  [NUM_HEADER_QUEUES + NUM_ALLOC_QUEUES];
  logic                      queue_alloc_fifo_rdy  [NUM_HEADER_QUEUES + NUM_ALLOC_QUEUES];
  alloc_entry_t              queue_alloc_fifo_entry[NUM_HEADER_QUEUES + NUM_ALLOC_QUEUES];

  logic                      queue_free_fifo_val   [ NUM_HEADER_QUEUES + NUM_FREE_QUEUES];
  logic                      queue_free_fifo_rdy   [ NUM_HEADER_QUEUES + NUM_FREE_QUEUES];
  alloc_entry_t              queue_free_fifo_entry [ NUM_HEADER_QUEUES + NUM_FREE_QUEUES];

  generate
    begin : g_header_queues
      for (genvar i = 0; i < NUM_HEADER_QUEUES; i++) begin : g_header_i
        if (i == 0) begin : g_header_n0
          falafel_input_parser i_falafel_input_parser (
              .clk_i,
              .rst_ni,
              .req_val_i         (req_val_i[i]),
              .req_rdy_o         (req_rdy_o[i]),
              .req_data_i        (req_data_i[i]),
              .alloc_req_val_o   (queue_alloc_fifo_val[i]),
              .alloc_req_rdy_i   (queue_alloc_fifo_rdy[i]),
              .alloc_req_data_o  (queue_alloc_fifo_entry[i]),
              .free_req_val_o    (queue_free_fifo_val[i]),
              .free_req_rdy_i    (queue_free_fifo_rdy[i]),
              .free_req_data_o   (queue_free_fifo_entry[i]),
              .config_reg_write_o(config_reg_write),
              .config_reg_data_o (config_reg_data),
              .config_reg_addr_o (config_reg_addr)
          );
        end else begin : g_header_n
          // verilator lint_off PINMISSING
          falafel_input_parser i_falafel_input_parser (
              .clk_i,
              .rst_ni,
              .req_val_i         (req_val_i[i]),
              .req_rdy_o         (req_rdy_o[i]),
              .req_data_i        (req_data_i[i]),
              .alloc_req_val_o   (queue_alloc_fifo_val[i]),
              .alloc_req_rdy_i   (queue_alloc_fifo_rdy[i]),
              .alloc_req_data_o  (queue_alloc_fifo_entry[i]),
              .free_req_val_o    (queue_free_fifo_val[i]),
              .free_req_rdy_i    (queue_free_fifo_rdy[i]),
              .free_req_data_o   (queue_free_fifo_entry[i]),
              .config_reg_write_o(  /* unused */),
              .config_reg_data_o (  /* unused */),
              .config_reg_addr_o (  /* unused */)
          );
          // verilator lint_on PINMISSING
        end
      end
    end
  endgenerate

  generate
    begin : g_alloc_queues
      for (
          genvar i = NUM_HEADER_QUEUES; i < NUM_HEADER_QUEUES + NUM_ALLOC_QUEUES; i++
      ) begin : g_alloc_i
        falafel_input_buffer i_falafel_input_buffer (
            .clk_i,
            .rst_ni,
            .req_val_i          (req_val_i[i]),
            .req_rdy_o          (req_rdy_o[i]),
            .req_data_i         (req_data_i[i]),
            .buffered_req_val_o (queue_alloc_fifo_val[i]),
            .buffered_req_rdy_i (queue_alloc_fifo_rdy[i]),
            .buffered_req_data_o(queue_alloc_fifo_entry[i])
        );
      end
    end
  endgenerate

  generate
    begin : g_free_queues
      for (
          genvar i = NUM_HEADER_QUEUES; i < NUM_HEADER_QUEUES + NUM_FREE_QUEUES; i++
      ) begin : g_free_i
        falafel_input_buffer i_falafel_input_buffer (
            .clk_i,
            .rst_ni,
            .req_val_i          (req_val_i[i+NUM_ALLOC_QUEUES]),
            .req_rdy_o          (req_rdy_o[i+NUM_ALLOC_QUEUES]),
            .req_data_i         (req_data_i[i+NUM_ALLOC_QUEUES]),
            .buffered_req_val_o (queue_free_fifo_val[i]),
            .buffered_req_rdy_i (queue_free_fifo_rdy[i]),
            .buffered_req_data_o(queue_free_fifo_entry[i])
        );
      end
    end
  endgenerate


  always_comb begin
    alloc_fifo_write_o = 1'b0;
    alloc_fifo_din_size_o = '0;
    alloc_fifo_din_id_o = '0;

    for (int i = 0; i < NUM_HEADER_QUEUES + NUM_ALLOC_QUEUES; i++) begin
      queue_alloc_fifo_rdy[i] = 1'b0;
    end

    if (!alloc_fifo_full_i) begin
      for (int i = 0; i < NUM_HEADER_QUEUES + NUM_ALLOC_QUEUES; i++) begin
        if (queue_alloc_fifo_val[i]) begin
          queue_alloc_fifo_rdy[i] = 1'b1;
          alloc_fifo_write_o = 1'b1;
          alloc_fifo_din_size_o = queue_alloc_fifo_entry[i].size;
          alloc_fifo_din_id_o = queue_alloc_fifo_entry[i].id;
          break;
        end
      end
    end
  end

  always_comb begin
    free_fifo_write_o = 1'b0;
    free_fifo_din_o   = '0;

    for (int i = 0; i < NUM_HEADER_QUEUES + NUM_FREE_QUEUES; i++) begin
      queue_free_fifo_rdy[i] = 1'b0;
    end

    if (!free_fifo_full_i) begin
      for (int i = 0; i < NUM_HEADER_QUEUES + NUM_FREE_QUEUES; i++) begin
        if (queue_free_fifo_val[i]) begin
          queue_free_fifo_rdy[i] = 1'b1;
          free_fifo_write_o = 1'b1;
          free_fifo_din_o = queue_free_fifo_entry[i].size;
          break;
        end
      end
    end
  end

  falafel_config_regs i_falafel_config_registers (
      .clk_i,
      .rst_ni,
      .write_i (config_reg_write),
      .addr_i  (config_reg_addr),
      .data_i  (config_reg_data),
      .config_o(config_o)
  );
endmodule
