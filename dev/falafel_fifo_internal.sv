`timescale 1ns / 1ps

module falafel_fifo_internal #(
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

  localparam ADDR_W = $clog2(NUM_ENTRIES);
  localparam MAX_ENTRY = ADDR_W'(NUM_ENTRIES - 1);

  logic [DATA_W-1:0] entries_q[NUM_ENTRIES];

  logic [ADDR_W-1:0] read_addr_d;
  logic [ADDR_W-1:0] read_addr_q;
  logic [ADDR_W-1:0] write_addr_d;
  logic [ADDR_W-1:0] write_addr_q;
  logic is_last_write_d;
  logic is_last_write_q;
  logic wr_en;

  always_comb begin
    is_last_write_d = is_last_write_q;
    read_addr_d = read_addr_q;
    write_addr_d = write_addr_q;
    wr_en = 0;

    unique case ({
      write_i, read_i
    })
      2'b10:   is_last_write_d = 1;
      2'b01:   is_last_write_d = 0;
      default: ;
    endcase

    if (read_i && !empty_o) begin

      if (read_addr_q == MAX_ENTRY) begin
        read_addr_d = 0;
      end else begin
        read_addr_d = read_addr_q + 1;
      end
    end

    if (write_i && !full_o) begin
      wr_en = 1;

      if (write_addr_q == MAX_ENTRY) begin
        write_addr_d = 0;
      end else begin
        write_addr_d = write_addr_q + 1;
      end
    end
  end

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      for (int i = 0; i < NUM_ENTRIES; i++) entries_q[i] <= '0;

      read_addr_q     <= '0;
      write_addr_q    <= '0;
      is_last_write_q <= '0;
    end else begin
      read_addr_q     <= read_addr_d;
      write_addr_q    <= write_addr_d;
      is_last_write_q <= is_last_write_d;

      if (wr_en) entries_q[write_addr_d] <= din_i;
    end
  end

  assign full_o  = (read_addr_q == write_addr_q) && is_last_write_q;
  assign empty_o = (read_addr_q == write_addr_q) && !is_last_write_q;
  assign dout_o  = entries_q[read_addr_q];
endmodule
