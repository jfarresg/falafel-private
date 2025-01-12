// SPDX-FileCopyrightText: © 2025 Joan Farres Garcia
//
// SPDX-License-Identifier: BSD-3-Clause


`timescale 1ns / 1ps

package falafel_pkg;
  //////////////////////////////
  // Configuration parameters //
  //////////////////////////////

  localparam unsigned DATA_W = 64;
  typedef logic [DATA_W-1:0] word_t;

  ///////////////
  // Constants //
  ///////////////

  localparam word_t NULL_PTR = '0;
  localparam word_t EMPTY_KEY = '0;
  localparam word_t WORD_SIZE = 8;
  localparam word_t BLOCK_ALIGNMENT = WORD_SIZE;

  ////////////////////////
  // Input parser types //
  ////////////////////////

  localparam word_t OPCODE_SIZE = 4;
  localparam word_t MSG_ID_SIZE = 8;
  localparam word_t REG_ADDR_SIZE = 16;

  typedef struct packed {
    logic [MSG_ID_SIZE-1:0] id;
    logic [OPCODE_SIZE-1:0] opcode;
  } base_header_t;

  typedef struct packed {
    logic [REG_ADDR_SIZE-1:0] addr;
    base_header_t base_header;
  } config_reg_header_t;

  typedef struct packed {
    logic [MSG_ID_SIZE-1:0] id;
    word_t size;
  } alloc_entry_t;

  // Opcodes
  localparam REQ_ACCESS_REGISTER = OPCODE_SIZE'(0);
  localparam REQ_ALLOC_MEM = OPCODE_SIZE'(1);
  localparam REQ_FREE_MEM = OPCODE_SIZE'(2);

  // Configuration registers addresses
  localparam FREE_LIST_PTR_ADDR = 'h10;
  localparam LOCK_PTR_ADDR = 'h18;
  localparam LOCK_ID_ADDR = 'h20;

  // Internal configuration registers
  typedef struct packed {
    // logic is_on;
    logic [DATA_W-1:0] free_list_ptr;
    logic [DATA_W-1:0] lock_ptr;
    logic [DATA_W-1:0] lock_id;
  } config_regs_t;


  ////////////////
  // Core types //
  ////////////////

  // Internal types
  typedef struct packed {
    word_t size;
    word_t next_ptr;
  } free_block_t;

  // verilator lint_off WIDTHEXPAND
  localparam word_t BLOCK_HEADER_SIZE = ($bits(free_block_t) / $bits(word_t) - 1) * WORD_SIZE;
  // verilator lint_on WIDTHEXPAND
  localparam word_t MIN_PAYLOAD_SIZE = 32;
  localparam word_t MIN_ALLOC_SIZE = BLOCK_HEADER_SIZE + MIN_PAYLOAD_SIZE;
  localparam word_t BLOCK_NEXT_PTR_OFFSET = 8;

  typedef enum {
    LSU_OP_STORE_WORD = 0,
    LSU_OP_LOAD_WORD = 1,
    LSU_OP_STORE_BLOCK = 2,
    LSU_OP_LOAD_BLOCK = 3,
    LSU_OP_LOCK = 4,
    LSU_OP_UNLOCK = 5
  } lsu_op_e;

  // Errors
  localparam ERR_NOMEM = -1;

  // Functions
  function word_t align_size(word_t size, word_t alignment);
    if (size < MIN_PAYLOAD_SIZE) size = MIN_PAYLOAD_SIZE;

    return (size + (alignment - 1)) & ~(alignment - 1);
  endfunction
endpackage
