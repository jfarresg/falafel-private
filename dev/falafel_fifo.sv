`timescale 1ns / 1ps

module falafel_fifo #(
    parameter NUM_ENTRIES = 64,  // number of entries
    parameter DATA_W      = 16   // entry data width
) (
    input logic clk_i,
    input logic rst_ni,

    input  logic read_i,   // read from fifo
    input  logic write_i,  // write to fifo
    output logic full_o,   // fifo is full
    output logic empty_o,  // fifo is empty

    input  logic [DATA_W-1:0] din_i,  // input data
    output logic [DATA_W-1:0] dout_o  // output data
);

  logic internal_write;
  logic internal_read;
  logic internal_empty;
  logic internal_full;
  logic [DATA_W-1:0] internal_din;
  logic [DATA_W-1:0] internal_dout;

  logic empty_d, empty_q;
  logic [DATA_W-1:0] dout_d, dout_q;
  logic read_last_cycle_d, read_last_cycle_q;
  logic bypass;

  assign internal_din   = din_i;
  assign internal_write = bypass ? 1'b0 : write_i;

  falafel_fifo_internal #(
      .NUM_ENTRIES(NUM_ENTRIES),
      .DATA_W(DATA_W)
  ) i_falafel_fifo_internal (
      .clk_i,
      .rst_ni,
      .read_i (internal_read),
      .write_i(internal_write),
      .full_o (internal_full),
      .empty_o(internal_empty),
      .din_i  (internal_din),
      .dout_o (internal_dout)
  );


  always_comb begin
    empty_d = empty_q;
    read_last_cycle_d = 1'b0;

    bypass = 1'b0;
    internal_read = 1'b0;

    if (empty_q) begin
      if (!internal_empty) begin
        internal_read = 1'b1;
        empty_d = 1'b0;
        read_last_cycle_d = 1'b1;
      end else begin
        if (write_i) begin
          empty_d = 1'b0;
          bypass  = 1;
        end
      end
    end else if (read_i) begin
      if (!internal_empty) begin
        internal_read = 1'b1;
        empty_d = 1'b0;
        read_last_cycle_d = 1'b1;
      end else begin
        if (write_i) begin
          empty_d = 1'b0;
          bypass  = 1;
        end else begin
          empty_d = 1'b1;
        end
      end
    end
  end

  assign dout_d = bypass ? din_i : (read_last_cycle_q ? internal_dout : dout_q);


  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      empty_q <= 1'b1;
      dout_q <= '0;
      read_last_cycle_q <= 1'b0;
    end else begin
      empty_q <= empty_d;
      dout_q <= dout_d;
      read_last_cycle_q <= read_last_cycle_d;
    end
  end

  assign empty_o = empty_q;
  assign dout_o  = read_last_cycle_q ? internal_dout : dout_q;
  assign full_o  = internal_full;
endmodule
