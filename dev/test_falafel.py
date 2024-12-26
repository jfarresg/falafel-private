import cocotb
from cocotb.triggers import FallingEdge
from cocotb.clock import Clock

from monitor import monitor_req_from_falafel, monitor_falafel_ready  # noqa
from free_list import LinkedList
from mem_rsp import (
    send_req_to_allocate,
    send_req_to_free,
    grant_lock,
    handle_loading_headers,
    handle_storing_headers,
)

CLK_PERIOD = 10
MAX_SIM_TIME = 15000
UNITS = "ns"


async def reset_dut(dut, clk):
    await FallingEdge(clk)

    clk.value = 0
    dut.rst_ni.value = 0

    for i in range(10):
        await FallingEdge(clk)
    dut.rst_ni.value = 1

    await FallingEdge(clk)
    await FallingEdge(clk)


async def sim_time_counter(dut, clk):
    counter = 0

    while counter < MAX_SIM_TIME:
        counter += 1
        await FallingEdge(clk)

    assert False, "Surpassed MAX_SIM_TIME of " + str(MAX_SIM_TIME)


@cocotb.test()
async def test_falafel_alloc_first_fit(dut):
    print("---------------------- Start first fit test ----------------------")
    clk = dut.clk_i
    cocotb.start_soon(Clock(clk, CLK_PERIOD, UNITS).start())
    dut.config_alloc_strategy_i.setimmediatevalue(0)  # first fit

    DATA_W = 64
    free_list_ptr = 12
    lock_ptr = 0
    lock_id = 0x9ABC
    packed_value = (
        (free_list_ptr << (2 * DATA_W)) | (lock_ptr << DATA_W) | lock_id
    )  # noqa
    dut.falafel_config_i = packed_value

    monitor_task_req_from_lsu = cocotb.start_soon(monitor_req_from_falafel(dut))  # noqa

    linked_list = LinkedList()
    linked_list.add_node(12, 16, 300)
    linked_list.add_node(16, 160, 300)
    linked_list.add_node(300, 100, 500)
    linked_list.add_node(500, 300, 2000)
    linked_list.add_node(2000, 500, 3000)

    await reset_dut(dut, clk)

    dut.mem_req_rdy_i.setimmediatevalue(1)
    dut.mem_rsp_val_i.setimmediatevalue(0)
    dut.result_ready_i.setimmediatevalue(1)

    for i in range(10):
        await FallingEdge(clk)

    # Send request to allocate
    # assert dut.mem_rsp_rdy_o == 1
    await send_req_to_allocate(dut, clk)
    print("Sent request to allocate")

    # Wait for the lock request
    await monitor_task_req_from_lsu
    await grant_lock(dut, clk)
    print("Granted lock")

    await monitor_task_req_from_lsu
    await grant_lock(dut, clk)
    print("Granted cas")

    print("-----Start allocation-----")
    linked_list.print_list()

    # loading free list first header address
    await handle_loading_headers(dut, clk, linked_list, expected_addresses=[12])  # noqa

    # loading first - third header
    await handle_loading_headers(
        dut, clk, linked_list, expected_addresses=[16, 300, 500]
    )  # noqa

    print("-----finish loading / finding fit-----")

    # updating the allocated block (storing size & next_addr)
    await handle_storing_headers(
        dut,
        clk,
        linked_list,
        expected_addr=500,
        expected_data=200,
        expected_next_addr=0,
    )
    print("-----Granted updating the allocated block-----")
    linked_list.print_list()

    # creating the new block (storing size & next_addr)
    await handle_storing_headers(
        dut,
        clk,
        linked_list,
        expected_addr=716,
        expected_data=100,
        expected_next_addr=2000,
    )
    print("-----Granted creating the new block-----")
    linked_list.print_list()

    # adjusting the link
    await handle_storing_headers(
        dut,
        clk,
        linked_list,
        expected_addr=308,
        expected_data=716,
        expected_next_addr=0,
    )
    print("-----Granted adjusting the link-----")
    linked_list.print_list()

    # releasing the lock
    await monitor_task_req_from_lsu
    await FallingEdge(clk)
    assert dut.mem_req_data_o == 0, int(dut.mem_req_data_o)
    await grant_lock(dut, clk)
    print("Granted release lock")
    await FallingEdge(clk)

    # checking the result
    assert dut.rsp_result_val_o == 1
    assert dut.rsp_result_is_write_o == 1
    assert dut.rsp_result_data_o == 516, int(dut.rsp_result_data_o)
    await FallingEdge(clk)


@cocotb.test()
async def test_falafel_alloc_best_fit(dut):
    print("---------------------- Start best fit test ----------------------")
    clk = dut.clk_i
    cocotb.start_soon(Clock(clk, CLK_PERIOD, UNITS).start())
    dut.config_alloc_strategy_i.setimmediatevalue(1)  # best fit

    DATA_W = 64
    free_list_ptr = 12
    lock_ptr = 0
    lock_id = 0x9ABC
    packed_value = (free_list_ptr << (2 * DATA_W)) | (lock_ptr << DATA_W) | lock_id
    dut.falafel_config_i = packed_value

    monitor_task_req_from_lsu = cocotb.start_soon(monitor_req_from_falafel(dut))
    monitor_task_falafel_ready = cocotb.start_soon(monitor_falafel_ready(dut))

    linked_list = LinkedList()
    linked_list.add_node(12, 16, 300)
    linked_list.add_node(16, 160, 300)
    linked_list.add_node(300, 100, 500)
    linked_list.add_node(500, 300, 2000)
    linked_list.add_node(2000, 299, 0)
    linked_list.print_list()

    await reset_dut(dut, clk)

    dut.mem_req_rdy_i.setimmediatevalue(1)
    dut.mem_rsp_val_i.setimmediatevalue(0)
    dut.result_ready_i.setimmediatevalue(1)

    for i in range(10):
        await FallingEdge(clk)

    # Send request to allocate
    await send_req_to_allocate(dut, clk)
    print("Sent request to allocate")

    # Wait for the lock request
    await monitor_task_req_from_lsu
    await grant_lock(dut, clk)
    print("Granted lock")

    await monitor_task_req_from_lsu
    await monitor_task_falafel_ready
    await grant_lock(dut, clk)
    print("Granted cas")

    print("-----Start allocation-----")
    linked_list.print_list()

    # loading free list first header address
    await handle_loading_headers(dut, clk, linked_list, expected_addresses=[12])  # noqa

    # loading first - forth (last) header
    await handle_loading_headers(
        dut, clk, linked_list, expected_addresses=[16, 300, 500, 2000]
    )  # noqa

    print("-----finish loading / finding fit-----")

    # updating the allocated block (storing size & next_addr)
    await handle_storing_headers(
        dut,
        clk,
        linked_list,
        expected_addr=2000,
        expected_data=200,
        expected_next_addr=0,
    )
    print("-----Granted updating the allocated block-----")
    linked_list.print_list()

    # creating the new block (storing size & next_addr)
    await handle_storing_headers(
        dut,
        clk,
        linked_list,
        expected_addr=2216,
        expected_data=99,
        expected_next_addr=0,
    )
    print("-----Granted creating the new block-----")
    linked_list.print_list()

    # adjusting the link
    await handle_storing_headers(
        dut,
        clk,
        linked_list,
        expected_addr=508,
        expected_data=2216,
        expected_next_addr=0,
    )
    print("-----Granted adjusting the link-----")
    linked_list.print_list()

    # releasing the lock
    await monitor_task_req_from_lsu
    await FallingEdge(clk)
    assert dut.mem_req_data_o == 0, int(dut.mem_req_data_o)
    await grant_lock(dut, clk)
    print("Granted release lock")
    await FallingEdge(clk)

    # checking the result
    assert dut.rsp_result_val_o == 1
    assert dut.rsp_result_is_write_o == 1
    assert dut.rsp_result_data_o == 2016, int(dut.rsp_result_data_o)
    await FallingEdge(clk)


@cocotb.test()
async def test_falafel_free_merge_right(dut):
    print("------------------ Start free merge right test ------------------")
    clk = dut.clk_i
    cocotb.start_soon(Clock(clk, CLK_PERIOD, UNITS).start())

    DATA_W = 64
    free_list_ptr = 12
    lock_ptr = 0
    lock_id = 0x9ABC
    packed_value = (free_list_ptr << (2 * DATA_W)) | (lock_ptr << DATA_W) | lock_id
    dut.falafel_config_i = packed_value

    monitor_task_req_from_lsu = cocotb.start_soon(monitor_req_from_falafel(dut))
    monitor_task_falafel_ready = cocotb.start_soon(monitor_falafel_ready(dut))

    linked_list = LinkedList()
    linked_list.add_node(12, 16, 300)
    linked_list.add_node(16, 160, 300)
    linked_list.add_node(300, 100, 500)
    linked_list.add_node(500, 300, 2216)
    linked_list.add_node(2000, 200, 0)
    linked_list.add_node(2216, 83, 0)
    linked_list.print_list()

    await reset_dut(dut, clk)

    dut.mem_req_rdy_i.setimmediatevalue(1)
    dut.mem_rsp_val_i.setimmediatevalue(0)
    dut.result_ready_i.setimmediatevalue(1)

    for i in range(10):
        await FallingEdge(clk)

    # send req to free
    await send_req_to_free(dut, clk, 2000)
    print("Sent request to free")

    # Wait for the lock request
    await monitor_task_req_from_lsu
    await grant_lock(dut, clk)
    print("Granted lock")

    await monitor_task_req_from_lsu
    await monitor_task_falafel_ready
    await grant_lock(dut, clk)
    print("Granted cas")

    print("-----Start allocation-----")
    linked_list.print_list()

    # loading free list first header address
    await handle_loading_headers(dut, clk, linked_list, expected_addresses=[12])  # noqa

    # loading first - third header
    await handle_loading_headers(
        dut, clk, linked_list, expected_addresses=[16, 300, 500]
    )  # noqa

    print("-----finding block to free-----")

    # loading the freeing header
    await handle_loading_headers(
        dut, clk, linked_list=linked_list, expected_addresses=[2000]
    )

    # loading the right header
    await handle_loading_headers(
        dut, clk, linked_list=linked_list, expected_addresses=[2216]
    )

    # updating the allocated block (storing size & next_addr)
    await handle_storing_headers(
        dut,
        clk,
        linked_list,
        expected_addr=2000,
        expected_data=299,
        expected_next_addr=0,
    )

    # adjusting the link
    await handle_storing_headers(
        dut,
        clk,
        linked_list,
        expected_addr=508,
        expected_data=2000,
        expected_next_addr=0,
    )
    print("-----Granted adjusting the link-----")
    linked_list.print_list()

    # releasing the lock
    await monitor_task_req_from_lsu
    await FallingEdge(clk)
    assert dut.mem_req_data_o == 0, int(dut.mem_req_data_o)
    await grant_lock(dut, clk)
    print("Granted release lock")
    await FallingEdge(clk)

    # checking the result
    assert dut.rsp_result_val_o == 1
    assert dut.rsp_result_is_write_o == 0
    await FallingEdge(clk)


@cocotb.test()
async def test_falafel_free_merge_left(dut):
    print("------------------ Start free merge left test ------------------")
    clk = dut.clk_i
    cocotb.start_soon(Clock(clk, CLK_PERIOD, UNITS).start())

    monitor_task_req_from_lsu = cocotb.start_soon(monitor_req_from_falafel(dut))
    monitor_task_falafel_ready = cocotb.start_soon(monitor_falafel_ready(dut))

    DATA_W = 64
    free_list_ptr = 12
    lock_ptr = 0
    lock_id = 0x9ABC
    packed_value = (free_list_ptr << (2 * DATA_W)) | (lock_ptr << DATA_W) | lock_id
    dut.falafel_config_i = packed_value

    linked_list = LinkedList()
    linked_list.add_node(12, 16, 300)
    linked_list.add_node(16, 160, 300)
    linked_list.add_node(300, 100, 500)
    linked_list.add_node(500, 284, 2000)
    linked_list.add_node(800, 500, 0)
    linked_list.add_node(2000, 299, 0)
    linked_list.print_list()

    await reset_dut(dut, clk)

    dut.mem_req_rdy_i.setimmediatevalue(1)
    dut.mem_rsp_val_i.setimmediatevalue(0)
    dut.result_ready_i.setimmediatevalue(1)

    for i in range(10):
        await FallingEdge(clk)

    # send req to free
    # assert dut.mem_rsp_rdy_o == 1
    dut.mem_rsp_rdy_o.setimmediatevalue(1)
    await send_req_to_free(dut, clk, 800)
    print("Sent request to free")

    # Wait for the lock request
    await monitor_task_req_from_lsu
    await grant_lock(dut, clk)
    print("Granted lock")

    await monitor_task_req_from_lsu
    await monitor_task_falafel_ready
    await grant_lock(dut, clk)
    print("Granted cas")

    print("-----Start freeing-----")
    linked_list.print_list()

    # loading free list first header address
    await handle_loading_headers(dut, clk, linked_list, expected_addresses=[12])  # noqa

    # loading first - third header
    await handle_loading_headers(
        dut, clk, linked_list, expected_addresses=[16, 300, 500]
    )  # noqa

    print("-----finding block to free-----")

    # loading the freeing header
    await handle_loading_headers(
        dut, clk, linked_list=linked_list, expected_addresses=[800]
    )

    # creating a new (merged) block (size & next_addr)
    await handle_storing_headers(
        dut,
        clk,
        linked_list,
        expected_addr=500,
        expected_data=800,
        expected_next_addr=2000,
    )
    print("-----Granted creating a block-----")
    linked_list.print_list()

    # releasing the lock
    await monitor_task_req_from_lsu
    await FallingEdge(clk)
    assert dut.mem_req_data_o == 0, int(dut.mem_req_data_o)
    await grant_lock(dut, clk)
    print("Granted release lock")
    await FallingEdge(clk)

    # checking the result
    assert dut.rsp_result_val_o == 1
    assert dut.rsp_result_is_write_o == 0
    await FallingEdge(clk)


@cocotb.test()
async def test_falafel_free_merge_both_sides(dut):
    print("---------------- Start free merge both sides test ----------------")
    clk = dut.clk_i
    cocotb.start_soon(Clock(clk, CLK_PERIOD, UNITS).start())

    monitor_task_req_from_lsu = cocotb.start_soon(monitor_req_from_falafel(dut))
    monitor_task_falafel_ready = cocotb.start_soon(monitor_falafel_ready(dut))

    DATA_W = 64
    free_list_ptr = 12
    lock_ptr = 0
    lock_id = 0x9ABC
    packed_value = (free_list_ptr << (2 * DATA_W)) | (lock_ptr << DATA_W) | lock_id
    dut.falafel_config_i = packed_value

    linked_list = LinkedList()
    linked_list.add_node(12, 16, 300)
    linked_list.add_node(16, 160, 300)
    linked_list.add_node(300, 100, 500)
    linked_list.add_node(500, 284, 2000)
    linked_list.add_node(800, 1184, 2000)  # TODO
    linked_list.add_node(2000, 299, 0)
    linked_list.print_list()

    await reset_dut(dut, clk)

    dut.mem_req_rdy_i.setimmediatevalue(1)
    dut.mem_rsp_val_i.setimmediatevalue(0)
    dut.result_ready_i.setimmediatevalue(1)

    for i in range(10):
        await FallingEdge(clk)

    # send req to free
    dut.mem_rsp_rdy_o.setimmediatevalue(1)
    await send_req_to_free(dut, clk, 800)
    print("Sent request to free")

    # Wait for the lock request
    await monitor_task_req_from_lsu
    await grant_lock(dut, clk)
    print("Granted lock")

    await monitor_task_req_from_lsu
    await monitor_task_falafel_ready
    await grant_lock(dut, clk)
    print("Granted cas")

    print("-----Start freeing-----")
    linked_list.print_list()

    # loading free list first header address
    await handle_loading_headers(dut, clk, linked_list, expected_addresses=[12])  # noqa

    await handle_loading_headers(
        dut, clk, linked_list, expected_addresses=[16, 300, 500]
    )  # noqa

    print("-----finding block to free-----")

    # loading the freeing header
    await handle_loading_headers(
        dut, clk, linked_list=linked_list, expected_addresses=[800]
    )

    # loading the right header
    await handle_loading_headers(
        dut, clk, linked_list=linked_list, expected_addresses=[2000]
    )

    # creating a new (merged) block (size & next_addr)
    await handle_storing_headers(
        dut,
        clk,
        linked_list,
        expected_addr=500,
        expected_data=1799,
        expected_next_addr=0,
    )
    print("-----Granted creating a block-----")
    linked_list.print_list()

    # releasing the lock
    await monitor_task_req_from_lsu
    await FallingEdge(clk)
    assert dut.mem_req_data_o == 0, int(dut.mem_req_data_o)
    await grant_lock(dut, clk)
    print("Granted release lock")
    await FallingEdge(clk)

    # checking the result
    assert dut.rsp_result_val_o == 1
    assert dut.rsp_result_is_write_o == 0
    await FallingEdge(clk)
