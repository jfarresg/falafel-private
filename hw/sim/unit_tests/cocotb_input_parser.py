# SPDX-FileCopyrightText: © 2025 Joan Farres Garcia
#
# SPDX-License-Identifier: BSD-3-Clause


import cocotb
from cocotb.triggers import Timer, FallingEdge
from cocotb.clock import Clock

from collections import deque
from falafel_pkg import *

CLK_PERIOD = 10
MAX_SIM_TIME = 1000


async def reset_dut(dut):
    dut.clk_i.value = 0
    dut.rst_ni.value = 0

    dut.req_val_i.value = 0
    dut.req_data_i.value = 0
    dut.alloc_fifo_full_i.value = 0
    dut.free_fifo_full_i.value = 0

    for i in range(10):
        await FallingEdge(dut.clk_i)
    dut.rst_ni.value = 1


async def sim_time_counter(dut):
    counter = 0

    while counter < MAX_SIM_TIME:
        counter += 1
        await FallingEdge(dut.clk_i)

    assert False, "Surpassed MAX_SIM_TIME of " + str(MAX_SIM_TIME)


async def write_flit(dut, data):
    while not dut.req_rdy_o.value:
        await FallingEdge(dut.clk_i)

    dut.req_val_i.value = 1
    dut.req_data_i.value = data

    await FallingEdge(dut.clk_i)
    dut.req_val_i.value = 0


async def write_config(dut, addr, val):
    await write_flit(dut, write_config_req(0, addr))
    await write_flit(dut, val)


async def req_alloc(dut, val):
    global alloc_queue
    alloc_queue.append(val)

    await write_flit(dut, REQ_ALLOC_MEM)
    await write_flit(dut, val)


async def req_free(dut, val):
    global free_queue
    free_queue.append(val)

    await write_flit(dut, REQ_FREE_MEM)
    await write_flit(dut, val)


async def monitor_alloc_fifo_write(dut):
    dut.alloc_fifo_full_i.value = 0

    while True:
        await FallingEdge(dut.clk_i)
        await Timer(1, units='ns')

        if dut.alloc_fifo_write_o.value:
            alloc_data = dut.alloc_fifo_din_o.value

            assert len(
                alloc_queue) > 0, 'received alloc fifo write without request'
            assert alloc_queue.popleft() == alloc_data, "alloc fifo data doesn't match"


async def monitor_free_fifo_write(dut):
    dut.free_fifo_full_i.value = 0

    while True:
        await FallingEdge(dut.clk_i)
        await Timer(1, units='ns')

        if dut.free_fifo_write_o.value:
            free_data = dut.free_fifo_din_o.value

            assert len(
                free_queue) > 0, 'received free fifo write without request'
            assert free_queue.popleft() == free_data, "free fifo data doesn't match"


@ cocotb.test()
async def test_write_config_registers(dut):
    """Write Config Registers"""

    cocotb.start_soon(Clock(dut.clk_i, CLK_PERIOD, units="ns").start())
    await reset_dut(dut)

    await cocotb.start(sim_time_counter(dut))

    await write_config(dut, FREE_LIST_PTR_ADDR, 0x1024)

    await FallingEdge(dut.clk_i)
    await FallingEdge(dut.clk_i)

    assert int(
        dut.free_list_ptr_o.value) == 0x1024, 'Free list ptr register not written correctly'

    await Timer(10, units='ns')


@ cocotb.test()
async def test_short_sequence(dut):
    """Alloc and free data sequence"""

    global alloc_queue, free_queue
    alloc_queue = deque()
    free_queue = deque()

    cocotb.start_soon(Clock(dut.clk_i, CLK_PERIOD, units="ns").start())
    await reset_dut(dut)

    await cocotb.start(sim_time_counter(dut))
    await cocotb.start(monitor_alloc_fifo_write(dut))
    await cocotb.start(monitor_free_fifo_write(dut))

    await req_alloc(dut, 8)
    await req_alloc(dut, 10)
    await req_free(dut, 3)

    await FallingEdge(dut.clk_i)
    await FallingEdge(dut.clk_i)

    assert len(alloc_queue) == 0, 'not all requests have been allocated'
    assert len(free_queue) == 0, 'not all requests have been freed'

    await Timer(10, units='ns')
