module falafel_output_fsm
  import falafel_pkg::*;
(
    input logic clk_i,
    input logic rst_ni,

    //-------------- response ---------------//
    input  logic              rsp_rdy_i,
    output logic              rsp_val_o,
    output logic [DATA_W-1:0] rsp_data_o,

    //----------- fifo interfaces ------------//
    input  logic              resp_fifo_empty_i,
    output logic              resp_fifo_read_o,
    input  logic [DATA_W-1:0] resp_fifo_dout_i
);

  logic [DATA_W-1:0] buffer_d, buffer_q;
  logic flag_d, flag_q; // 1 if we have to send the copy

  assign buffer_d = resp_fifo_read_o ? resp_fifo_dout_i : buffer_q;

  always_comb begin
    resp_fifo_read_o = 1'b0;
    rsp_val_o = 1'b0;
    rsp_data_o = resp_fifo_dout_i;

    flag_d = flag_q;

    if (rsp_rdy_i && (!resp_fifo_empty_i || flag_q)) begin
      if (flag_q) begin
        flag_d = 1'b0;
        rsp_val_o = 1'b1;
        rsp_data_o = buffer_q;
      end else begin
        flag_d = 1'b1;
        resp_fifo_read_o = 1'b1;
        rsp_val_o = 1'b1;
        rsp_data_o = resp_fifo_dout_i;
      end
    end
  end

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      buffer_q <= '0;
      flag_q <= 1'b0;
    end else begin
      buffer_q <= buffer_d;
      flag_q <= flag_d;
    end
  end

  // always_comb begin
  //   resp_fifo_read_o = 1'b0;
  //   rsp_val_o = 1'b0;
  //   rsp_data_o = resp_fifo_dout_i;

  //   if (rsp_rdy_i && !resp_fifo_empty_i) begin
  //     resp_fifo_read_o = 1'b1;
  //     rsp_val_o = 1'b1;
  //     rsp_data_o = resp_fifo_dout_i;
  //   end
  // end
endmodule
