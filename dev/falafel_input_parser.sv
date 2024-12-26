`timescale 1ns / 1ps
`include "falafel_pkg.sv"

module falafel_input_parser
  import falafel_pkg::*;
(
    input logic clk_i,
    input logic rst_ni,

    input  logic              req_val_i,
    output logic              req_rdy_o,
    input  logic [DATA_W-1:0] req_data_i,

    output logic         alloc_req_val_o,
    input  logic         alloc_req_rdy_i,
    output alloc_entry_t alloc_req_data_o,

    output logic         free_req_val_o,
    input  logic         free_req_rdy_i,
    output alloc_entry_t free_req_data_o,

    output logic              config_reg_write_o,
    output logic [DATA_W-1:0] config_reg_data_o,
    output logic [DATA_W-1:0] config_reg_addr_o
);

  localparam NUM_FIFO_ENTRIES = 2;
  localparam ENTRY_WIDTH = MSG_ID_SIZE + DATA_W;

  typedef enum logic [2:0] {
    STATE_READ_HEADER,
    STATE_READ_ALLOC_DATA,
    STATE_READ_FREE_DATA,
    STATE_WRITE_CONFIG_REG
  } input_state_e;

  // internal buffers
  input_state_e input_state_d, input_state_q;
  logic [MSG_ID_SIZE-1:0] id_buffer_d, id_buffer_q;
  logic [REG_ADDR_SIZE-1:0] reg_addr_buffer_d, reg_addr_buffer_q;


  // fifo signals
  logic                                 alloc_fifo_write_en;
  logic                                 alloc_fifo_read_en;
  logic                                 alloc_fifo_full;
  logic                                 alloc_fifo_empty;
  logic               [ENTRY_WIDTH-1:0] alloc_fifo_din;
  logic               [ENTRY_WIDTH-1:0] alloc_fifo_dout;
  logic                                 free_fifo_write_en;
  logic                                 free_fifo_read_en;
  logic                                 free_fifo_full;
  logic                                 free_fifo_empty;
  logic               [ENTRY_WIDTH-1:0] free_fifo_din;
  logic               [ENTRY_WIDTH-1:0] free_fifo_dout;


  // variables for casting
  alloc_entry_t                         fifo_din;
  base_header_t                         input_header;
  config_reg_header_t                   input_config_header;


  assign input_header = base_header_t'(req_data_i);
  assign input_config_header = config_reg_header_t'(req_data_i);
  assign fifo_din = {id_buffer_q, req_data_i};

  assign alloc_fifo_din = ENTRY_WIDTH'(fifo_din);
  assign free_fifo_din = ENTRY_WIDTH'(fifo_din);

  always_comb begin
    input_state_d = input_state_q;

    id_buffer_d = id_buffer_q;
    reg_addr_buffer_d = reg_addr_buffer_q;

    alloc_fifo_write_en = 1'b0;
    free_fifo_write_en = 1'b0;

    config_reg_write_o = 1'b0;
    req_rdy_o = 0;

    unique case (input_state_q)
      STATE_READ_HEADER: begin
        req_rdy_o = 1'b1;

        if (req_val_i && req_rdy_o) begin
          unique case (input_header.opcode)
            REQ_ALLOC_MEM: input_state_d = STATE_READ_ALLOC_DATA;
            REQ_FREE_MEM: input_state_d = STATE_READ_FREE_DATA;
            REQ_ACCESS_REGISTER: input_state_d = STATE_WRITE_CONFIG_REG;
            default: ;
          endcase

          id_buffer_d = input_header.id;
          reg_addr_buffer_d = input_config_header.addr;
        end
      end

      STATE_READ_ALLOC_DATA: begin
        req_rdy_o = !alloc_fifo_full;

        if (req_val_i && req_rdy_o) begin
          input_state_d = STATE_READ_HEADER;
          alloc_fifo_write_en = 1'b1;
        end
      end

      STATE_READ_FREE_DATA: begin
        req_rdy_o = !free_fifo_full;

        if (req_val_i && req_rdy_o) begin
          input_state_d = STATE_READ_HEADER;
          free_fifo_write_en = 1'b1;
        end
      end

      STATE_WRITE_CONFIG_REG: begin
        req_rdy_o = 1'b1;

        if (req_val_i && req_rdy_o) begin
          input_state_d = STATE_READ_HEADER;
          config_reg_write_o = 1'b1;
        end
      end

      default: ;
    endcase
  end

  // modules
  falafel_fifo #(
      .DATA_W     (ENTRY_WIDTH),
      .NUM_ENTRIES(NUM_FIFO_ENTRIES)
  ) i_alloc_req_fifo (
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
      .DATA_W     (ENTRY_WIDTH),
      .NUM_ENTRIES(NUM_FIFO_ENTRIES)
  ) i_free_req_fifo (
      .clk_i,
      .rst_ni,
      .write_i(free_fifo_write_en),
      .read_i (free_fifo_read_en),
      .full_o (free_fifo_full),
      .empty_o(free_fifo_empty),
      .din_i  (free_fifo_din),
      .dout_o (free_fifo_dout)
  );

  // flops
  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      input_state_q <= STATE_READ_HEADER;
      id_buffer_q <= '0;
      reg_addr_buffer_q <= '0;
    end else begin
      input_state_q <= input_state_d;
      id_buffer_q <= id_buffer_d;
      reg_addr_buffer_q <= reg_addr_buffer_d;
    end
  end

  // output logic
  assign alloc_req_val_o = !alloc_fifo_empty;
  assign alloc_fifo_read_en = (alloc_req_val_o && alloc_req_rdy_i);
  assign alloc_req_data_o = alloc_entry_t'(alloc_fifo_dout);

  assign free_req_val_o = !free_fifo_empty;
  assign free_fifo_read_en = (free_req_val_o && free_req_rdy_i);
  assign free_req_data_o = alloc_entry_t'(free_fifo_dout);

  assign config_reg_addr_o = 64'(reg_addr_buffer_q);
  assign config_reg_data_o = req_data_i;
endmodule
