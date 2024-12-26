`timescale 1ns / 1ps

`ifndef FALAFEL_PKG
`define FALAFEL_PKG
package falafel_pkg;

  typedef enum integer {
    FIRST_FIT,
    BEST_FIT
  } alloc_strategy_t;

  typedef enum integer {
    LOCK,
    UNLOCK,
    LOAD,
    EDIT_SIZE_AND_NEXT_ADDR,
    EDIT_NEXT_ADDR
  } req_lsu_op_t;

  localparam unsigned DATA_W = 64;

  typedef struct packed {
    logic [DATA_W-1:0] addr;
    logic [DATA_W-1:0] size;
    logic [DATA_W-1:0] next_addr;
  } header_t;

  typedef struct packed {
    logic [DATA_W-1:0] size;
    logic [DATA_W-1:0] next_addr;
  } header_net_t;

  typedef struct packed {
    header_t header;
    logic val;
    req_lsu_op_t lsu_op;
  } header_req_t;

  typedef struct packed {
    header_t header;
    logic val;
  } header_rsp_t;

  localparam logic [DATA_W-1:0] BLOCK_NEXT_ADDR_OFFSET = DATA_W / 8;
  localparam logic [DATA_W-1:0] EMPTY_KEY = '0;
  localparam logic [DATA_W-1:0] BLOCK_HEADER_SIZE = 64'($bits(header_net_t)) / 64'd8;
  localparam logic [DATA_W-1:0] MIN_PAYLOAD_SIZE = 0;  // TODO
  localparam logic [DATA_W-1:0] MIN_ALLOC_SIZE = BLOCK_HEADER_SIZE + MIN_PAYLOAD_SIZE;

  localparam [DATA_W-1:0] OPCODE_SIZE = 4;
  localparam [DATA_W-1:0] MSG_ID_SIZE = 8;
  localparam [DATA_W-1:0] REG_ADDR_SIZE = 16;

typedef struct packed {
    logic [MSG_ID_SIZE-1:0] id;
    logic [DATA_W-1:0] size;
  } alloc_entry_t;

  // Internal configuration registers
  typedef struct packed {
    // logic is_on;
    logic [DATA_W-1:0] free_list_ptr;
    logic [DATA_W-1:0] lock_ptr;
    logic [DATA_W-1:0] lock_id;
  } config_regs_t;

  typedef struct packed {
    logic [MSG_ID_SIZE-1:0] id;
    logic [OPCODE_SIZE-1:0] opcode;
  } base_header_t;

  typedef struct packed {
    logic [REG_ADDR_SIZE-1:0] addr;
    base_header_t base_header;
  } config_reg_header_t;

  // Configuration registers addresses
  localparam FREE_LIST_PTR_ADDR = 'h10;
  localparam LOCK_PTR_ADDR = 'h18;
  localparam LOCK_ID_ADDR = 'h20;

  // Opcodes
  localparam REQ_ACCESS_REGISTER = OPCODE_SIZE'(0);
  localparam REQ_ALLOC_MEM = OPCODE_SIZE'(1);
  localparam REQ_FREE_MEM = OPCODE_SIZE'(2);

endpackage
`endif
