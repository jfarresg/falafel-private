`timescale 1ns / 1ps

module falafel_lsu
  import falafel_pkg::*;
(
    input logic clk_i,
    input logic rst_ni,

    //----------- alloc request ------------//
    input  logic        alloc_req_val_i,
    output logic        alloc_req_rdy_o,
    input  lsu_op_e     alloc_req_op_i,
    input  word_t       alloc_req_addr_i,
    input  word_t       alloc_req_word_i,
    input  word_t       alloc_req_lock_id_i,
    input  free_block_t alloc_req_block_i,

    //----------- alloc response -----------//
    output logic        alloc_rsp_val_o,
    input  logic        alloc_rsp_rdy_i,
    output word_t       alloc_rsp_word_o,
    output free_block_t alloc_rsp_block_o,

    //----------- memory request -----------//
    output logic              mem_req_val_o,       // req valid
    input  logic              mem_req_ack_i,       // mem ready
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

  typedef enum integer {
    STATE_IDLE,

    STATE_LOAD_WORD,
    STATE_WAIT_LOAD,

    STATE_STORE_WORD,
    STATE_WAIT_STORE,

    STATE_LOAD_BLOCK_SIZE,
    STATE_WAIT_BLOCK_SIZE,
    STATE_LOAD_BLOCK_PTR,
    STATE_WAIT_BLOCK_PTR,

    STATE_STORE_BLOCK_SIZE,
    STATE_STORE_BLOCK_PTR,
    STATE_WAIT_STORE_BLOCK_SIZE,
    STATE_WAIT_STORE_BLOCK_PTR,

    STATE_LOCK_LOAD_KEY,
    STATE_LOCK_WAIT_KEY,
    STATE_LOCK_DO_CAS,
    STATE_LOCK_WAIT_CAS,

    STATE_UNLOCK_UPDATE,
    STATE_UNLOCK_WAIT_UPDATE,

    STATE_RESPOND
  } lsu_state_e;

  lsu_state_e state_d, state_q;

  word_t addr_buffer_d, addr_buffer_q;
  word_t word_buffer_d, word_buffer_q;
  word_t lock_id_buffer_d, lock_id_buffer_q;
  free_block_t block_buffer_d, block_buffer_q;

  free_block_t read_block_d, read_block_q;
  word_t read_word_d, read_word_q;

  logic val_buffer_d, val_buffer_q;
  logic val_trigger;

  assign word_buffer_d = (alloc_req_val_i && alloc_req_rdy_o) ? (alloc_req_word_i) : word_buffer_q;
  assign lock_id_buffer_d = (alloc_req_val_i && alloc_req_rdy_o) ? (alloc_req_lock_id_i) : lock_id_buffer_q;
  assign block_buffer_d = (alloc_req_val_i && alloc_req_rdy_o) ? (alloc_req_block_i) : block_buffer_q;

  assign mem_req_addr_o = addr_buffer_q;
  assign alloc_rsp_word_o = read_word_q;
  assign alloc_rsp_block_o = read_block_q;

  assign mem_req_val_o = val_buffer_d & !val_buffer_q;
  assign val_buffer_d = val_trigger;

  always_comb begin
    state_d = state_q;

    alloc_req_rdy_o = 1'b0;
    alloc_rsp_val_o = 1'b0;

    mem_req_is_write_o = 1'b0;
    mem_req_is_cas_o = 1'b0;
    mem_req_cas_exp_o = '0;
    mem_req_data_o = '0;
    mem_rsp_rdy_o = 1'b0;

    val_trigger = 1'b0;

    addr_buffer_d = addr_buffer_q;
    read_block_d = read_block_q;
    read_word_d = read_word_q;

    unique case (state_q)
      STATE_IDLE: begin
        alloc_req_rdy_o = 1'b1;

        if (alloc_req_val_i) begin
          addr_buffer_d = alloc_req_addr_i;

          unique case (alloc_req_op_i)
            LSU_OP_LOAD_WORD: state_d = STATE_LOAD_WORD;
            LSU_OP_STORE_WORD: state_d = STATE_STORE_WORD;
            LSU_OP_LOAD_BLOCK: state_d = STATE_LOAD_BLOCK_SIZE;
            LSU_OP_STORE_BLOCK: state_d = STATE_STORE_BLOCK_SIZE;
            LSU_OP_LOCK: state_d = STATE_LOCK_LOAD_KEY;
            LSU_OP_UNLOCK: state_d = STATE_UNLOCK_UPDATE;
            default: assert (0);
          endcase
        end
      end

      STATE_LOAD_WORD: begin
        val_trigger = 1'b1;
        mem_req_is_write_o = 1'b0;

        if (mem_req_ack_i) begin
          state_d = STATE_WAIT_LOAD;
        end
      end

      STATE_WAIT_LOAD: begin
        mem_rsp_rdy_o = 1'b1;

        if (mem_rsp_val_i) begin
          state_d = STATE_RESPOND;
          read_word_d = mem_rsp_data_i;
        end
      end

      STATE_STORE_WORD: begin
        val_trigger = 1'b1;
        mem_req_is_write_o = 1'b1;
        mem_req_data_o = word_buffer_q;

        if (mem_req_ack_i) begin
          state_d = STATE_WAIT_STORE;
        end
      end

      STATE_WAIT_STORE: begin
        mem_rsp_rdy_o = 1'b1;

        if (mem_rsp_val_i) begin
          state_d = STATE_RESPOND;
        end
      end

      STATE_LOAD_BLOCK_SIZE: begin
        val_trigger = 1'b1;
        mem_req_is_write_o = 1'b0;

        if (mem_req_ack_i) begin
          state_d = STATE_WAIT_BLOCK_SIZE;
          addr_buffer_d = addr_buffer_q + WORD_SIZE;
        end
      end

      STATE_WAIT_BLOCK_SIZE: begin
        mem_rsp_rdy_o = 1'b1;

        if (mem_rsp_val_i) begin
          state_d = STATE_LOAD_BLOCK_PTR;
          read_block_d.size = mem_rsp_data_i;
        end
      end

      STATE_LOAD_BLOCK_PTR: begin
        val_trigger = 1'b1;
        mem_req_is_write_o = 1'b0;

        if (mem_req_ack_i) begin
          state_d = STATE_WAIT_BLOCK_PTR;
        end
      end

      STATE_WAIT_BLOCK_PTR: begin
        mem_rsp_rdy_o = 1'b1;

        if (mem_rsp_val_i) begin
          state_d = STATE_RESPOND;
          read_block_d.next_ptr = mem_rsp_data_i;
        end
      end

      STATE_STORE_BLOCK_SIZE: begin
        val_trigger = 1'b1;
        mem_req_is_write_o = 1'b1;
        mem_req_data_o = block_buffer_q.size;

        if (mem_req_ack_i) begin
          state_d = STATE_WAIT_STORE_BLOCK_SIZE;
          addr_buffer_d = addr_buffer_q + WORD_SIZE;
        end
      end

      STATE_WAIT_STORE_BLOCK_SIZE: begin
        mem_rsp_rdy_o = 1'b1;

        if (mem_rsp_val_i) begin
          state_d = STATE_STORE_BLOCK_PTR;
        end
      end

      STATE_STORE_BLOCK_PTR: begin
        val_trigger = 1'b1;
        mem_req_is_write_o = 1'b1;
        mem_req_data_o = block_buffer_q.next_ptr;

        if (mem_req_ack_i) begin
          state_d = STATE_WAIT_STORE_BLOCK_PTR;
        end
      end

      STATE_WAIT_STORE_BLOCK_PTR: begin
        mem_rsp_rdy_o = 1'b1;

        if (mem_rsp_val_i) begin
          state_d = STATE_RESPOND;
        end
      end

      STATE_LOCK_LOAD_KEY: begin
        val_trigger = 1'b1;
        mem_req_is_write_o = 1'b0;

        if (mem_req_ack_i) begin
          state_d = STATE_LOCK_WAIT_KEY;
        end
      end

      STATE_LOCK_WAIT_KEY: begin
        mem_rsp_rdy_o = 1'b1;

        if (mem_rsp_val_i) begin
          if (mem_rsp_data_i == EMPTY_KEY) state_d = STATE_LOCK_DO_CAS;
          else state_d = STATE_LOCK_LOAD_KEY;
        end
      end

      STATE_LOCK_DO_CAS: begin
        val_trigger = 1'b1;
        mem_req_is_cas_o = 1'b1;
        mem_req_data_o = lock_id_buffer_q;

        if (mem_req_ack_i) begin
          state_d = STATE_LOCK_WAIT_CAS;
        end
      end

      STATE_LOCK_WAIT_CAS: begin
        mem_rsp_rdy_o = 1'b1;

        if (mem_rsp_val_i) begin
          if (mem_rsp_data_i == 0) state_d = STATE_RESPOND;  // we have taken the key
          else state_d = STATE_LOCK_LOAD_KEY;  // someone else has taken the key
        end
      end

      STATE_UNLOCK_UPDATE: begin
        val_trigger = 1'b1;
        mem_req_is_write_o = 1'b1;
        mem_req_data_o = EMPTY_KEY;

        if (mem_req_ack_i) begin
          state_d = STATE_UNLOCK_WAIT_UPDATE;
        end
      end

      STATE_UNLOCK_WAIT_UPDATE: begin
        mem_rsp_rdy_o = 1'b1;

        if (mem_rsp_val_i) begin
          state_d = STATE_RESPOND;
        end
      end

      STATE_RESPOND: begin
        alloc_rsp_val_o = 1'b1;

        if (alloc_rsp_rdy_i) begin
          state_d = STATE_IDLE;
        end
      end

      default: assert (0);
    endcase
  end


  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      state_q <= STATE_IDLE;
      addr_buffer_q <= NULL_PTR;
      word_buffer_q <= '0;
      lock_id_buffer_q <= '0;
      block_buffer_q <= '0;
      read_block_q <= '0;
      read_word_q <= '0;
      val_buffer_q <= '0;
    end else begin
      state_q <= state_d;
      addr_buffer_q <= addr_buffer_d;
      word_buffer_q <= word_buffer_d;
      lock_id_buffer_q <= lock_id_buffer_d;
      block_buffer_q <= block_buffer_d;
      read_block_q <= read_block_d;
      read_word_q <= read_word_d;
      val_buffer_q <= val_buffer_d;
    end
  end
endmodule
