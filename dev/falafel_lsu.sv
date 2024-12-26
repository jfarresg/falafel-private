`include "falafel_pkg.sv"

module falafel_lsu
  import falafel_pkg::*;
(
    input logic clk_i,
    input logic rst_ni,

    (* mark_debug = "true" *) input header_req_t core_req_header_i,
    (* mark_debug = "true" *) output header_rsp_t core_rsp_header_o,
    (* mark_debug = "true" *) input logic core_rdy_i,
    (* mark_debug = "true" *) output logic lsu_ready_o,

    //----------- memory request ------------//
    (* mark_debug = "true" *) output logic mem_req_val_o,  // req valid
    (* mark_debug = "true" *) input logic mem_req_rdy_i,  // mem ready
    (* mark_debug = "true" *) output logic mem_req_is_write_o,  // 1 for write, 0 for read
    (* mark_debug = "true" *) output logic mem_req_is_cas_o,  // 1 for cas, 0 for write
    (* mark_debug = "true" *) output logic [DATA_W-1:0] mem_req_addr_o,  // address
    (* mark_debug = "true" *) output logic [DATA_W-1:0] mem_req_data_o,  // write data
    output logic [DATA_W-1:0] mem_req_cas_exp_o,  // compare & swap expected value

    //----------- memory response ------------//
    (* mark_debug = "true" *) input logic mem_rsp_val_i,  // resp valid
    (* mark_debug = "true" *) output logic mem_rsp_rdy_o,  // falafel ready
    (* mark_debug = "true" *)
    input logic [DATA_W-1:0] mem_rsp_data_i  // resp data // different from original falafel
);

  typedef enum integer {
    IDLE,
    LOAD_KEY,
    LOCK_DO_CAS,
    UNLOCK_KEY,
    LOAD_SIZE,
    LOAD_NEXT_ADDR,
    STORE_UPDATED_SIZE,
    STORE_UPDATED_NEXT_ADDR,
    WAIT_RSP_FROM_MEM,
    SEND_RSP_TO_CORE
  } lsu_state_e;

  typedef enum integer {
    LSU_LOAD_KEY,
    LSU_DO_CAS,
    LSU_UNLOCK,
    LSU_LOAD_SIZE,
    LSU_LOAD_NEXT_ADDR,
    LSU_STORE_SIZE,
    LSU_STORE_NEXT_ADDR
  } lsu_op_t;

  (* mark_debug = "true" *) lsu_state_e state_q, state_d;
  header_req_t req_header_q, req_header_d;
  header_rsp_t rsp_header_q, rsp_header_d;
  lsu_op_t lsu_op_q, lsu_op_d;
  logic [DATA_W-1:0] load_addr_q, load_addr_d;

  assign mem_req_cas_exp_o = 0;

  task automatic send_mem_load_req(
      input logic [DATA_W-1:0] addr_to_send_i, output logic mem_req_val_o,
      output logic [DATA_W-1:0] mem_req_addr_o, output logic mem_req_is_write_o);
    mem_req_val_o = 1;
    mem_req_addr_o = addr_to_send_i;
    mem_req_is_write_o = 0;
  endtask

  task automatic send_mem_store_req(
      input logic [DATA_W-1:0] addr_to_send_i, input logic [DATA_W-1:0] data_to_send_i,
      output logic mem_req_val_o, output logic [DATA_W-1:0] mem_req_addr_o,
      output logic [DATA_W-1:0] mem_req_data_o, output logic mem_req_is_write_o);
    mem_req_val_o = 1;
    mem_req_addr_o = addr_to_send_i;
    mem_req_data_o = data_to_send_i;
    mem_req_is_write_o = 1;
  endtask

  always_comb begin : lsu_fsm
    state_d = state_q;
    req_header_d = req_header_q;
    rsp_header_d = rsp_header_q;
    lsu_op_d = lsu_op_q;
    lsu_ready_o = 0;
    mem_req_is_cas_o = 0;
    mem_req_val_o = 0;
    core_rsp_header_o = '0;
    load_addr_d = load_addr_q;
    mem_rsp_rdy_o = 0;
    mem_req_is_write_o = 0;
    mem_req_addr_o = '0;
    mem_req_data_o = '0;

    unique case (state_q)
      IDLE: begin
        lsu_ready_o = 1;
        if (core_req_header_i.val) begin
          req_header_d  = core_req_header_i;
          mem_rsp_rdy_o = 0;

          unique case (core_req_header_i.lsu_op)
            LOCK: begin
              state_d  = LOAD_KEY;
              lsu_op_d = LSU_LOAD_KEY;
            end
            UNLOCK: begin
              state_d  = UNLOCK_KEY;
              lsu_op_d = LSU_UNLOCK;
            end
            LOAD: begin
              state_d  = LOAD_SIZE;
              lsu_op_d = LSU_LOAD_SIZE;
            end
            EDIT_SIZE_AND_NEXT_ADDR: begin
              state_d  = STORE_UPDATED_SIZE;
              lsu_op_d = LSU_STORE_SIZE;
            end
            EDIT_NEXT_ADDR: begin
              state_d  = STORE_UPDATED_NEXT_ADDR;
              lsu_op_d = LSU_STORE_NEXT_ADDR;
            end
            default: ;
          endcase
        end
      end
      LOAD_KEY: begin
        send_mem_load_req(.addr_to_send_i(req_header_q.header.addr), .mem_req_val_o(mem_req_val_o),
                          .mem_req_addr_o(mem_req_addr_o), .mem_req_is_write_o(mem_req_is_write_o));
        mem_req_data_o = '0;
        if (mem_req_rdy_i) begin
          state_d = WAIT_RSP_FROM_MEM;
        end
      end
      LOCK_DO_CAS: begin
        mem_req_is_cas_o = 1'b1;
        mem_req_addr_o = req_header_q.header.addr;
        mem_req_data_o = req_header_q.header.size;  // TODO lock id
        mem_req_val_o = 1;
        if (mem_req_rdy_i) begin
          state_d = WAIT_RSP_FROM_MEM;
        end
      end
      LOAD_SIZE: begin
        send_mem_load_req(.addr_to_send_i(req_header_q.header.addr), .mem_req_val_o(mem_req_val_o),
                          .mem_req_addr_o(mem_req_addr_o), .mem_req_is_write_o(mem_req_is_write_o));
        if (mem_req_rdy_i) begin
          state_d = WAIT_RSP_FROM_MEM;
        end
      end
      LOAD_NEXT_ADDR: begin
        send_mem_load_req(.addr_to_send_i(req_header_q.header.addr + BLOCK_NEXT_ADDR_OFFSET),
                          .mem_req_val_o(mem_req_val_o), .mem_req_addr_o(mem_req_addr_o),
                          .mem_req_is_write_o(mem_req_is_write_o));
        if (mem_req_rdy_i) begin
          state_d = WAIT_RSP_FROM_MEM;
        end
      end
      STORE_UPDATED_SIZE: begin
        send_mem_store_req(.addr_to_send_i(req_header_q.header.addr),
                           .data_to_send_i(req_header_q.header.size), .mem_req_val_o(mem_req_val_o),
                           .mem_req_addr_o(mem_req_addr_o), .mem_req_data_o(mem_req_data_o),
                           .mem_req_is_write_o(mem_req_is_write_o));
        if (mem_req_rdy_i) begin
          state_d = WAIT_RSP_FROM_MEM;
        end
      end
      STORE_UPDATED_NEXT_ADDR: begin
        send_mem_store_req(.addr_to_send_i(req_header_q.header.addr + BLOCK_NEXT_ADDR_OFFSET),
                           .data_to_send_i(req_header_q.header.next_addr),
                           .mem_req_val_o(mem_req_val_o), .mem_req_addr_o(mem_req_addr_o),
                           .mem_req_data_o(mem_req_data_o),
                           .mem_req_is_write_o(mem_req_is_write_o));
        if (mem_req_rdy_i) begin
          state_d = WAIT_RSP_FROM_MEM;
        end
      end
      UNLOCK_KEY: begin
        send_mem_store_req(.addr_to_send_i(req_header_q.header.addr), .data_to_send_i(EMPTY_KEY),
                           .mem_req_val_o(mem_req_val_o), .mem_req_addr_o(mem_req_addr_o),
                           .mem_req_data_o(mem_req_data_o),
                           .mem_req_is_write_o(mem_req_is_write_o));
        if (mem_req_rdy_i) begin
          state_d = WAIT_RSP_FROM_MEM;
        end
      end
      WAIT_RSP_FROM_MEM: begin
        mem_rsp_rdy_o = 1;
        if (mem_rsp_val_i) begin
          rsp_header_d.val = mem_rsp_val_i;

          unique case (lsu_op_q)
            LSU_LOAD_KEY: begin
              if (lsu_op_q == LSU_LOAD_KEY) begin
                if (mem_rsp_data_i == EMPTY_KEY || mem_rsp_data_i == 1) begin
                  state_d  = LOCK_DO_CAS;
                  lsu_op_d = LSU_DO_CAS;
                end else begin
                  state_d = LOAD_KEY;
                end
              end
            end
            LSU_DO_CAS: begin
              if (mem_rsp_data_i == 0) begin
                state_d = SEND_RSP_TO_CORE;
              end else begin
                state_d  = LOAD_KEY;
                lsu_op_d = LSU_LOAD_KEY;
              end
              begin
                state_d = SEND_RSP_TO_CORE;
              end
            end
            LSU_LOAD_SIZE: begin
              rsp_header_d.header.size = mem_rsp_data_i;
              state_d = LOAD_NEXT_ADDR;
              lsu_op_d = LSU_LOAD_NEXT_ADDR;
            end
            LSU_LOAD_NEXT_ADDR: begin
              rsp_header_d.header.next_addr = mem_rsp_data_i;
              state_d = SEND_RSP_TO_CORE;
            end
            LSU_STORE_SIZE: begin
              state_d  = STORE_UPDATED_NEXT_ADDR;
              lsu_op_d = LSU_STORE_NEXT_ADDR;
            end
            LSU_STORE_NEXT_ADDR: state_d = SEND_RSP_TO_CORE;
            LSU_UNLOCK: state_d = SEND_RSP_TO_CORE;
          endcase
        end
      end

      SEND_RSP_TO_CORE: begin
        core_rsp_header_o = rsp_header_q;
        core_rsp_header_o.header.addr = req_header_q.header.addr;
        core_rsp_header_o.val = 1;
        if (core_rdy_i) begin
          lsu_ready_o = 1;
          state_d = IDLE;
        end
      end
      default: ;
    endcase
  end

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      state_q <= IDLE;
      req_header_q <= '0;
      rsp_header_q <= '0;
      lsu_op_q <= LSU_LOAD_KEY;
    end else begin
      state_q <= state_d;
      req_header_q <= req_header_d;
      rsp_header_q <= rsp_header_d;
      lsu_op_q <= lsu_op_d;
    end
  end

endmodule
