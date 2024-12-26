`include "falafel_pkg.sv"

module falafel_core
  import falafel_pkg::*;
(
    input logic clk_i,
    input logic rst_ni,
    input alloc_strategy_t config_alloc_strategy_i,
    (* mark_debug = "true" *) input config_regs_t falafel_config_i,
    (* mark_debug = "true" *) output logic req_alloc_ready_o,
    (* mark_debug = "true" *) input logic is_alloc_i,
    (* mark_debug = "true" *) input logic [DATA_W-1:0] size_to_allocate_i,
    input logic [DATA_W-1:0] addr_to_free_i,
    (* mark_debug = "true" *) input logic req_alloc_valid_i,
    (* mark_debug = "true" *) output logic core_ready_o,
    (* mark_debug = "true" *) input logic lsu_ready_i,
    (* mark_debug = "true" *) input header_rsp_t rsp_from_lsu_i,
    (* mark_debug = "true" *) output header_req_t req_to_lsu_o,
    (* mark_debug = "true" *) input logic result_ready_i,
    (* mark_debug = "true" *) output logic rsp_result_val_o,
    (* mark_debug = "true" *) output logic rsp_result_is_write_o,
    (* mark_debug = "true" *) output logic [DATA_W-1:0] rsp_result_data_o
);

  typedef enum integer {
    IDLE,
    REQ_ACQUIRE_LOCK,
    REQ_RELEASE_LOCK,
    REQ_LOAD_HEADER,
    ALLOC_SEARCH_POS_FIRST_FIT,
    ALLOC_SEARCH_POS_BEST_FIT,
    REQ_ADJUST_ALLOCATED_HEADER,
    FREE_SEARCH_POS,
    FREE_CHECK_NEIGHBORS,
    FREE_MERGE_NEIGHBOR,
    REQ_CREATE_NEW_HEADER,
    REQ_ADJUST_LINK,
    WAIT_RSP_FROM_LSU,
    RETURN_RESULT
  } core_state_e;

  typedef enum integer {
    CORE_ACQUIRE_LOCK,
    CORE_RELEASE,
    CORE_LOAD_FIRST_HEADER_ADDR,
    CORE_LOAD_HEADER,
    CORE_ADJUST_ALLOCATED_HEADER,
    CORE_LOAD_FREE_TARGET_HEADER,
    CORE_LOAD_RIGHT_HEADER_FOR_MERGE_BOTH_SIDES,
    CORE_LOAD_RIGHT_HEADER_FOR_MERGE_RIGHT,
    CORE_MERGE_RIGHT,
    CORE_MERGE_LEFT,
    CORE_MERGE_BOTH_SIDES,
    CORE_ADJUST_LINK,
    CORE_CREATE_NEW_HEADER
  } core_op_t;

  typedef enum integer {
    FIRST_HEADER_ADDR,
    SEARCH,
    FREE_TARGET_HEADER,
    FREE_RIGHT_HEADER
  } load_type_t;

  (* mark_debug = "true" *) core_state_e state_d, state_q;
  core_op_t core_op_d, core_op_q;
  (* mark_debug = "true" *) logic is_alloc_d, is_alloc_q;  // 1: alloc, 0: free
  (* mark_debug = "true" *) logic [DATA_W-1:0] size_to_allocate_d, size_to_allocate_q;
  logic [DATA_W-1:0] addr_to_free_d, addr_to_free_q;

  header_t header_to_get_lock;
  header_t header_from_lsu_d, header_from_lsu_q;
  header_t first_header_ptr_d, first_header_ptr_q;
  header_t load_req_header;
  load_type_t load_type_d, load_type_q;

  header_t prev_header_d, prev_header_q;
  header_t curr_header_d, curr_header_q;
  header_t first_fit_header, first_fit_header_prev;
  (* mark_debug = "true" *) header_t first_fit_header_d, first_fit_header_q;
  header_t best_fit_header_d, best_fit_header_q;
  header_t best_fit_header_prev_d, best_fit_header_prev_q;
  logic [DATA_W-1:0] smallest_diff_d, smallest_diff_q;

  (* mark_debug = "true" *) header_t alloc_target_header_d, alloc_target_header_q;
  header_t free_target_header_d, free_target_header_q;
  header_t header_to_create_d, header_to_create_q;
  header_t header_to_adjust_link_d, header_to_adjust_link_q;
  header_t adjusted_first_header_ptr;

  logic does_merge_right, does_merge_left, does_merge_both_sides;
  header_t right_header_d, right_header_q;
  header_t merged_block_header_d, merged_block_header_q;


  task automatic send_req_to_lsu(input header_t header_i, input req_lsu_op_t lsu_op_i,
                                 output header_req_t req_to_lsu_o);
    begin
      req_to_lsu_o.header = header_i;
      req_to_lsu_o.lsu_op = lsu_op_i;
      req_to_lsu_o.val = 1;
    end
  endtask

  task automatic set_headers_after_fit(
      input header_t fit_header_i, input header_t fit_header_prev_i,
      input logic [DATA_W-1:0] size_to_allocate_i, output header_t alloc_target_header_o,
      output header_t header_to_create_o, output header_t header_to_adjust_link_o,
      output core_state_e next_state_o);
    begin
      header_to_adjust_link_o.addr = fit_header_prev_i.addr;
      if (fit_header_i.size - size_to_allocate_i >= MIN_ALLOC_SIZE) begin
        next_state_o = REQ_ADJUST_ALLOCATED_HEADER;
        alloc_target_header_o.addr = fit_header_i.addr;
        alloc_target_header_o.size = size_to_allocate_i;  // TODO
        alloc_target_header_o.next_addr = '0;
        header_to_create_o.addr = fit_header_i.addr + BLOCK_HEADER_SIZE + size_to_allocate_i;
        header_to_create_o.size = fit_header_i.size - size_to_allocate_i;
        header_to_create_o.next_addr = fit_header_i.next_addr;
        header_to_adjust_link_o.next_addr = header_to_create_o.addr;
      end else begin
        alloc_target_header_o.next_addr = '0;
        header_to_adjust_link_o.next_addr = fit_header_i.next_addr;
        next_state_o = REQ_ADJUST_LINK;
      end
    end
  endtask

  always_comb begin : core_fsm
    req_to_lsu_o = '0;
    core_ready_o = 0;

    state_d = state_q;
    is_alloc_d = is_alloc_q;
    size_to_allocate_d = size_to_allocate_q;
    addr_to_free_d = addr_to_free_q;
    core_op_d = core_op_q;

    header_to_get_lock = '0;

    load_req_header = '0;
    load_type_d = load_type_q;

    prev_header_d = prev_header_q;
    curr_header_d = curr_header_q;
    header_from_lsu_d = header_from_lsu_q;
    first_fit_header = '0;
    first_fit_header_prev = '0;
    first_fit_header_d = first_fit_header_q;
    best_fit_header_d = best_fit_header_q;
    best_fit_header_prev_d = best_fit_header_prev_q;
    smallest_diff_d = smallest_diff_q;

    first_header_ptr_d = first_header_ptr_q;
    alloc_target_header_d = alloc_target_header_q;
    free_target_header_d = free_target_header_q;
    header_to_create_d = header_to_create_q;
    header_to_adjust_link_d = header_to_adjust_link_q;
    adjusted_first_header_ptr = '0;

    does_merge_left = 0;
    does_merge_right = 0;
    does_merge_both_sides = 0;
    right_header_d = right_header_q;
    merged_block_header_d = merged_block_header_q;

    rsp_result_val_o = 0;
    rsp_result_is_write_o = 0;
    rsp_result_data_o = '0;
    req_alloc_ready_o = 0;

    unique case (state_q)
      IDLE: begin
        core_ready_o = 1;

        req_alloc_ready_o = 1;
        is_alloc_d = 0;
        size_to_allocate_d = '0;
        addr_to_free_d = '0;
        core_op_d = CORE_ACQUIRE_LOCK;

        load_type_d = SEARCH;

        curr_header_d = '0;
        prev_header_d = '0;
        header_from_lsu_d = '0;
        first_fit_header_d = '0;
        best_fit_header_d = '0;
        best_fit_header_prev_d = '0;
        smallest_diff_d = {DATA_W{1'b1}};

        alloc_target_header_d = '0;
        free_target_header_d = '0;
        header_to_create_d = '0;
        header_to_adjust_link_d = '0;

        right_header_d = '0;
        merged_block_header_d = '0;

        if (req_alloc_valid_i) begin
          is_alloc_d = is_alloc_i ? 1 : 0;
          size_to_allocate_d = req_alloc_valid_i ? size_to_allocate_i : '0;
          addr_to_free_d = addr_to_free_i;
          state_d = REQ_ACQUIRE_LOCK;
          core_ready_o = 0;
        end
      end
      REQ_ACQUIRE_LOCK: begin
        header_to_get_lock.addr = falafel_config_i.lock_ptr;
        header_to_get_lock.size = falafel_config_i.lock_id;  // irregular header for lock key area
        send_req_to_lsu(.header_i(header_to_get_lock), .lsu_op_i(LOCK),
                        .req_to_lsu_o(req_to_lsu_o));
        if (lsu_ready_i) begin
          core_op_d = CORE_ACQUIRE_LOCK;
          state_d   = WAIT_RSP_FROM_LSU;
        end
      end
      REQ_LOAD_HEADER: begin
        unique case (load_type_q)
          FIRST_HEADER_ADDR: begin
            load_req_header.addr = falafel_config_i.free_list_ptr;
            core_op_d = CORE_LOAD_FIRST_HEADER_ADDR;
          end
          SEARCH: begin
            load_req_header.addr = curr_header_q.addr;
            core_op_d = CORE_LOAD_HEADER;
          end
          FREE_TARGET_HEADER: begin
            load_req_header.addr = addr_to_free_q - BLOCK_HEADER_SIZE;
            core_op_d = CORE_LOAD_FREE_TARGET_HEADER;
          end
          FREE_RIGHT_HEADER: begin
            load_req_header.addr = curr_header_q.next_addr;
            if (core_op_q == CORE_MERGE_BOTH_SIDES)
              core_op_d = CORE_LOAD_RIGHT_HEADER_FOR_MERGE_BOTH_SIDES;
            else if (core_op_q == CORE_MERGE_RIGHT)
              core_op_d = CORE_LOAD_RIGHT_HEADER_FOR_MERGE_RIGHT;
          end
          default: ;
        endcase
        send_req_to_lsu(.header_i(load_req_header), .lsu_op_i(LOAD), .req_to_lsu_o(req_to_lsu_o));
        if (lsu_ready_i) begin
          state_d = WAIT_RSP_FROM_LSU;
        end
      end
      ALLOC_SEARCH_POS_FIRST_FIT: begin
        core_ready_o = 1;
        if (header_from_lsu_q.size < size_to_allocate_q) begin
          prev_header_d = header_from_lsu_q;
          curr_header_d.addr = header_from_lsu_q.next_addr;
          state_d = REQ_LOAD_HEADER;
          load_type_d = SEARCH;
        end else begin
          first_fit_header = header_from_lsu_q;
          first_fit_header_prev = prev_header_q;
          first_fit_header_d = first_fit_header;
          set_headers_after_fit(
              .fit_header_i(first_fit_header), .fit_header_prev_i(first_fit_header_prev),
              .size_to_allocate_i(size_to_allocate_q),
              .alloc_target_header_o(alloc_target_header_d),
              .header_to_create_o(header_to_create_d),
              .header_to_adjust_link_o(header_to_adjust_link_d), .next_state_o(state_d));
        end
      end
      ALLOC_SEARCH_POS_BEST_FIT: begin
        core_ready_o = 1;
        if ((header_from_lsu_q.size >= size_to_allocate_q) &&
      ((header_from_lsu_q.size - size_to_allocate_q) < smallest_diff_q)) begin
          best_fit_header_d = header_from_lsu_q;
          best_fit_header_prev_d = prev_header_q;
          smallest_diff_d = header_from_lsu_q.size - size_to_allocate_q;
        end

        if (header_from_lsu_q.next_addr != '0) begin
          prev_header_d = header_from_lsu_q;
          curr_header_d.addr = header_from_lsu_q.next_addr;
          state_d = REQ_LOAD_HEADER;
          load_type_d = SEARCH;
        end else begin
          if (best_fit_header_d.next_addr != '0) begin
            set_headers_after_fit(
                .fit_header_i(best_fit_header_q), .fit_header_prev_i(best_fit_header_prev_q),
                .size_to_allocate_i(size_to_allocate_q),
                .alloc_target_header_o(alloc_target_header_d),
                .header_to_create_o(header_to_create_d),
                .header_to_adjust_link_o(header_to_adjust_link_d), .next_state_o(state_d));
          end else begin
            set_headers_after_fit(
                .fit_header_i(best_fit_header_d), .fit_header_prev_i(best_fit_header_prev_d),
                .size_to_allocate_i(size_to_allocate_q),
                .alloc_target_header_o(alloc_target_header_d),
                .header_to_create_o(header_to_create_d),
                .header_to_adjust_link_o(header_to_adjust_link_d), .next_state_o(state_d));
          end
        end
      end
      REQ_ADJUST_ALLOCATED_HEADER: begin
        if (lsu_ready_i) begin
          send_req_to_lsu(.header_i(alloc_target_header_q),
                          .lsu_op_i(EDIT_SIZE_AND_NEXT_ADDR),  // TODO
                          .req_to_lsu_o(req_to_lsu_o));
          state_d   = WAIT_RSP_FROM_LSU;
          core_op_d = CORE_ADJUST_ALLOCATED_HEADER;
        end
      end
      REQ_CREATE_NEW_HEADER: begin
        if (lsu_ready_i) begin
          if (is_alloc_q) begin
            send_req_to_lsu(.header_i(header_to_create_q), .lsu_op_i(EDIT_SIZE_AND_NEXT_ADDR),
                            .req_to_lsu_o(req_to_lsu_o));
            core_op_d = CORE_CREATE_NEW_HEADER;

          end else if ((core_op_q == CORE_MERGE_BOTH_SIDES) ||
              (core_op_q == CORE_MERGE_RIGHT) ||
              (core_op_q == CORE_MERGE_LEFT)) begin
            send_req_to_lsu(.header_i(merged_block_header_q), .lsu_op_i(EDIT_SIZE_AND_NEXT_ADDR),
                            .req_to_lsu_o(req_to_lsu_o));
            core_op_d = core_op_q;
          end else begin
            send_req_to_lsu(.header_i(header_to_create_q), .lsu_op_i(EDIT_NEXT_ADDR),
                            .req_to_lsu_o(req_to_lsu_o));
            core_op_d = CORE_CREATE_NEW_HEADER;
          end

          state_d = WAIT_RSP_FROM_LSU;
        end
      end
      REQ_ADJUST_LINK: begin
        if (header_to_adjust_link_q.addr == '0) begin : adjusting_first_header_ptr
          adjusted_first_header_ptr.addr = falafel_config_i.free_list_ptr;
          adjusted_first_header_ptr.size = header_to_adjust_link_q.next_addr;  // irregular header for first header ptr area
          if (lsu_ready_i) begin
            send_req_to_lsu(.header_i(adjusted_first_header_ptr),
                            .lsu_op_i(EDIT_SIZE_AND_NEXT_ADDR), .req_to_lsu_o(req_to_lsu_o));
            state_d   = WAIT_RSP_FROM_LSU;
            core_op_d = CORE_ADJUST_LINK;
          end
        end else begin
          if (lsu_ready_i) begin
            send_req_to_lsu(.header_i(header_to_adjust_link_q), .lsu_op_i(EDIT_NEXT_ADDR),
                            .req_to_lsu_o(req_to_lsu_o));
            state_d   = WAIT_RSP_FROM_LSU;
            core_op_d = CORE_ADJUST_LINK;
          end
        end

      end
      FREE_SEARCH_POS: begin
        // if ((addr_to_free_q > header_from_lsu_q.addr) &&
        // ((addr_to_free_q < header_from_lsu_q.next_addr) |
        // (header_from_lsu_q.next_addr == '0))) begin
        if (addr_to_free_q < header_from_lsu_q.addr) begin  // first header
          curr_header_d = first_header_ptr_q;
          state_d = REQ_LOAD_HEADER;
          load_type_d = FREE_TARGET_HEADER;
        end
        else if ((addr_to_free_q > header_from_lsu_q.addr) &&
        (addr_to_free_q < header_from_lsu_q.next_addr)) begin
          curr_header_d = header_from_lsu_q;
          state_d = REQ_LOAD_HEADER;
          load_type_d = FREE_TARGET_HEADER;

        end else begin
          curr_header_d.addr = header_from_lsu_q.next_addr;
          state_d = REQ_LOAD_HEADER;
          load_type_d = SEARCH;
        end
      end
      FREE_CHECK_NEIGHBORS: begin
        free_target_header_d = header_from_lsu_q;
        does_merge_right = (addr_to_free_q + free_target_header_d.size
          == curr_header_q.next_addr);
        does_merge_left = (curr_header_q.addr + BLOCK_HEADER_SIZE + curr_header_q.size
          == (addr_to_free_q - BLOCK_HEADER_SIZE));
        does_merge_both_sides = does_merge_right && does_merge_left;

        if (does_merge_both_sides) begin
          core_op_d = CORE_MERGE_BOTH_SIDES;
          state_d = REQ_LOAD_HEADER;
          load_type_d = FREE_RIGHT_HEADER;
        end else if (does_merge_right) begin
          core_op_d = CORE_MERGE_RIGHT;
          state_d = REQ_LOAD_HEADER;
          load_type_d = FREE_RIGHT_HEADER;
          header_to_adjust_link_d = curr_header_q;
          header_to_adjust_link_d.next_addr = addr_to_free_q - BLOCK_HEADER_SIZE;
        end else if (does_merge_left) begin
          core_op_d = CORE_MERGE_LEFT;
          state_d   = FREE_MERGE_NEIGHBOR;
        end else if (!does_merge_left && !does_merge_right) begin
          header_to_create_d.addr = addr_to_free_q - BLOCK_HEADER_SIZE;
          header_to_create_d.next_addr = header_from_lsu_q.next_addr;
          header_to_adjust_link_d.addr = header_from_lsu_q.addr;
          header_to_adjust_link_d.next_addr = header_to_create_d.addr;
          state_d = REQ_CREATE_NEW_HEADER;
        end
      end
      FREE_MERGE_NEIGHBOR: begin
        unique case (core_op_q)
          CORE_MERGE_BOTH_SIDES: begin
            right_header_d = header_from_lsu_q;
            merged_block_header_d.addr = curr_header_q.addr;
            merged_block_header_d.next_addr = right_header_d.next_addr;
            merged_block_header_d.size =
              curr_header_q.size + right_header_d.size + free_target_header_q.size
              + 2*BLOCK_HEADER_SIZE;
          end
          CORE_MERGE_RIGHT: begin
            right_header_d = header_from_lsu_q;
            merged_block_header_d.addr = addr_to_free_q - BLOCK_HEADER_SIZE;
            merged_block_header_d.next_addr = right_header_d.next_addr;
            merged_block_header_d.size =
              right_header_d.size + free_target_header_q.size  + BLOCK_HEADER_SIZE;
          end
          CORE_MERGE_LEFT: begin
            merged_block_header_d.addr = curr_header_q.addr;
            merged_block_header_d.next_addr = curr_header_q.next_addr;
            merged_block_header_d.size =
              curr_header_q.size + free_target_header_q.size + BLOCK_HEADER_SIZE;
          end
          default: ;
        endcase

        core_op_d = core_op_q;
        state_d   = REQ_CREATE_NEW_HEADER;
      end
      REQ_RELEASE_LOCK: begin
        if (lsu_ready_i) begin
          send_req_to_lsu(.header_i(falafel_config_i.lock_ptr), .lsu_op_i(UNLOCK),
                          .req_to_lsu_o(req_to_lsu_o));
          req_to_lsu_o.header.addr = falafel_config_i.lock_ptr;
          state_d = WAIT_RSP_FROM_LSU;
          core_op_d = CORE_RELEASE;
        end
      end
      WAIT_RSP_FROM_LSU: begin
        core_ready_o = 1;
        if (rsp_from_lsu_i.val) begin
          unique case (core_op_q)
            CORE_ACQUIRE_LOCK: begin
              state_d = REQ_LOAD_HEADER;
              load_type_d = FIRST_HEADER_ADDR;
            end
            CORE_LOAD_FIRST_HEADER_ADDR: begin
              curr_header_d.addr = rsp_from_lsu_i.header.size;  // irregular header for first header ptr area
              first_header_ptr_d.next_addr = rsp_from_lsu_i.header.size;  // irregular header for first header ptr area
              // first_header_ptr_d.addr = falafel_config_i.free_list_ptr;
              state_d = REQ_LOAD_HEADER;
              load_type_d = SEARCH;
            end
            CORE_LOAD_HEADER: begin
              header_from_lsu_d = rsp_from_lsu_i.header;
              if (is_alloc_q) begin
                if (config_alloc_strategy_i == FIRST_FIT) begin
                  state_d = ALLOC_SEARCH_POS_FIRST_FIT;
                end else if (config_alloc_strategy_i == BEST_FIT) begin
                  state_d = ALLOC_SEARCH_POS_BEST_FIT;
                end
              end else begin
                state_d = FREE_SEARCH_POS;
              end
            end
            CORE_LOAD_FREE_TARGET_HEADER: begin
              header_from_lsu_d = rsp_from_lsu_i.header;
              state_d = FREE_CHECK_NEIGHBORS;
            end
            CORE_LOAD_RIGHT_HEADER_FOR_MERGE_BOTH_SIDES: begin
              header_from_lsu_d = rsp_from_lsu_i.header;
              state_d = FREE_MERGE_NEIGHBOR;
              core_op_d = CORE_MERGE_BOTH_SIDES;
            end
            CORE_LOAD_RIGHT_HEADER_FOR_MERGE_RIGHT: begin
              header_from_lsu_d = rsp_from_lsu_i.header;
              state_d = FREE_MERGE_NEIGHBOR;
              core_op_d = CORE_MERGE_RIGHT;
            end
            CORE_MERGE_RIGHT: state_d = REQ_ADJUST_LINK;
            CORE_MERGE_LEFT: state_d = REQ_RELEASE_LOCK;
            CORE_MERGE_BOTH_SIDES: state_d = REQ_RELEASE_LOCK;
            CORE_ADJUST_LINK: state_d = REQ_RELEASE_LOCK;
            CORE_ADJUST_ALLOCATED_HEADER: state_d = REQ_CREATE_NEW_HEADER;
            CORE_CREATE_NEW_HEADER: state_d = REQ_ADJUST_LINK;
            CORE_RELEASE: state_d = RETURN_RESULT;
          endcase
        end
      end
      RETURN_RESULT: begin
        rsp_result_val_o = 1;
        if (is_alloc_q) begin
          rsp_result_is_write_o = 1;
          if (config_alloc_strategy_i == FIRST_FIT) begin
            rsp_result_data_o = first_fit_header_q.addr + BLOCK_HEADER_SIZE;
          end else begin
            rsp_result_data_o = best_fit_header_q.addr + BLOCK_HEADER_SIZE;
          end
        end else begin
          rsp_result_is_write_o = 0;
        end

        if (result_ready_i) begin
          state_d = IDLE;
        end
      end

      default: ;
    endcase
  end

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      state_q <= IDLE;
      is_alloc_q <= 0;
      size_to_allocate_q <= '0;
      addr_to_free_q <= '0;

      core_op_q <= CORE_RELEASE;
      load_type_q <= SEARCH;
      header_from_lsu_q <= '0;

      curr_header_q <= 0;
      prev_header_q <= 0;
      first_fit_header_q <= '0;
      best_fit_header_q <= '0;
      best_fit_header_prev_q <= '0;
      smallest_diff_q <= '0;

      first_header_ptr_q <= '0;
      alloc_target_header_q <= '0;
      free_target_header_q <= '0;
      header_to_create_q <= '0;
      header_to_adjust_link_q <= '0;
      right_header_q <= '0;
      merged_block_header_q <= '0;
    end else begin
      state_q <= state_d;
      is_alloc_q <= is_alloc_d;
      size_to_allocate_q <= size_to_allocate_d;
      addr_to_free_q <= addr_to_free_d;

      core_op_q <= core_op_d;
      load_type_q <= load_type_d;
      header_from_lsu_q <= header_from_lsu_d;

      curr_header_q <= curr_header_d;
      prev_header_q <= prev_header_d;
      first_fit_header_q <= first_fit_header_d;
      best_fit_header_q <= best_fit_header_d;
      best_fit_header_prev_q <= best_fit_header_prev_d;
      smallest_diff_q <= smallest_diff_d;

      first_header_ptr_q <= first_header_ptr_d;
      alloc_target_header_q <= alloc_target_header_d;
      free_target_header_q <= free_target_header_d;
      header_to_create_q <= header_to_create_d;
      header_to_adjust_link_q <= header_to_adjust_link_d;
      right_header_q <= right_header_d;
      merged_block_header_q <= merged_block_header_d;
    end
  end

endmodule
