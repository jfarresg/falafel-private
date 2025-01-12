// SPDX-FileCopyrightText: © 2025 Joan Farres Garcia
//
// SPDX-License-Identifier: BSD-3-Clause


module dual_port_ram_wrapper #(
    parameter DATA_W = 32,
    parameter ADDR_W = 10,
    parameter NUM_ENTRIES = 2 ** ADDR_W
) (
    input logic clk_i,

    input logic              we0_i,
    input logic              we1_i,
    input logic [ADDR_W-1:0] addr0_i,
    input logic [ADDR_W-1:0] addr1_i,
    input logic [DATA_W-1:0] data0_i,
    input logic [DATA_W-1:0] data1_i,

    output logic [DATA_W-1:0] data0_o,
    output logic [DATA_W-1:0] data1_o
);

  localparam M_DEPTH = NUM_ENTRIES;

  (* ram_style = "block" *) logic [DATA_W-1:0] mem_q[M_DEPTH-1:0];
  logic [ADDR_W-1:0] addr0_q;
  logic [ADDR_W-1:0] addr1_q;

  initial begin
    for (int i = 0; i < M_DEPTH; i++) begin
      mem_q[i] = '0;
    end
  end

  always_ff @(posedge clk_i) begin
    if (we0_i) mem_q[addr0_i] <= data0_i;

    // if (we0_i) begin
    //   $display("mem_q[%h] = %h", addr0_i, data0_i);
    // end

    addr0_q <= addr0_i;
  end

  always_ff @(posedge clk_i) begin
    if (we1_i) mem_q[addr1_i] <= data1_i;

    addr1_q <= addr1_i;
  end

  assign data0_o = mem_q[addr0_q];
  assign data1_o = mem_q[addr1_q];
endmodule
