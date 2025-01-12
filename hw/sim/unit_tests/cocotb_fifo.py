# SPDX-FileCopyrightText: © 2025 Joan Farres Garcia
#
# SPDX-License-Identifier: BSD-3-Clause


# import cocotb
# from cocotb.triggers import Timer, RisingEdge, FallingEdge, ReadOnly, NextTimeStep
# from cocotb.clock import Clock

# from collections import deque

# from falafel_bus import FalafelFifoReadBus, FalafelFifoWriteBus, FalafelFifoReadSlave, FalafelFifoWriteSlave

# CLK_PERIOD = 10
# MAX_SIM_TIME = 1000
# NUM_ENTRIES = 64
# UNITS = 'ns'


# async def reset_dut(dut):
#     await FallingEdge(dut.clk_i)

#     dut.clk_i.value = 0
#     dut.rst_ni.value = 0

#     dut.read_i.value = 0
#     dut.write_i.value = 0
#     dut.din_i.value = 0

#     for i in range(10):
#         await RisingEdge(dut.clk_i)
#     dut.rst_ni.value = 1

#     await FallingEdge(dut.clk_i)
#     await FallingEdge(dut.clk_i)


# async def sim_time_counter(dut):
#     counter = 0

#     while counter < MAX_SIM_TIME:
#         counter += 1
#         await FallingEdge(dut.clk_i)

#     assert False, "Surpassed MAX_SIM_TIME of " + str(MAX_SIM_TIME)


# async def write_val(dut, val):
#     await RisingEdge(dut.clk_i)
#     await ReadOnly()

#     while dut.full_o.value:
#         await RisingEdge(dut.clk_i)
#         await ReadOnly()

#     await NextTimeStep()

#     dut.write_i.value = 1
#     dut.din_i.value = val

#     write_queue.append(val)

#     await RisingEdge(dut.clk_i)
#     await NextTimeStep()
#     dut.write_i.value = 0


# async def read_val(dut):
#     await RisingEdge(dut.clk_i)
#     await ReadOnly()

#     while dut.empty_o.value:
#         await RisingEdge(dut.clk_i)
#         await ReadOnly()

#     await NextTimeStep()

#     dut.read_i.value = 1

#     await RisingEdge(dut.clk_i)
#     await ReadOnly()
#     read_queue.append(int(dut.dout_o.value))
#     # print('read value', int(dut.dout_o.value))

#     await RisingEdge(dut.clk_i)
#     await NextTimeStep()
#     dut.read_i.value = 0


# async def read_write(dut, val):
#     await RisingEdge(dut.clk_i)
#     await NextTimeStep()

#     dut.read_i.value = 1
#     dut.write_i.value = 1
#     dut.din_i.value = val

#     await RisingEdge(dut.clk_i)
#     await ReadOnly()

#     if not dut.full_o.value:
#         write_queue.append(val)

#     if not dut.empty_o.value:
#         read_queue.append(int(dut.dout_o.value))

#     await RisingEdge(dut.clk_i)
#     await NextTimeStep()
#     dut.read_i.value = 0
#     dut.write_i.value = 0


# async def read_remaining_entryes(dut):
#     while not is_empty(dut):
#         await read_val(dut)

#     assert len(write_queue) == 0, "FIFO still has entries"


# def is_full(dut):
#     # print('is full', int(dut.full_o.value))
#     return int(dut.full_o.value) == 1


# def is_empty(dut):
#     # print('is empty', int(dut.empty_o.value))
#     return int(dut.empty_o.value) == 1


# async def monitor_outputs(dut):
#     await FallingEdge(dut.clk_i)

#     while True:
#         await FallingEdge(dut.clk_i)

#         if dut.rst_ni.value == 0:
#             continue

#         if len(read_queue) > 0:
#             assert read_queue.popleft() == write_queue.popleft(
#             ), "Read and write values dont match"


# @cocotb.test()
# async def test_short_sequence(dut):
#     """Short sequence"""

#     global write_queue, read_queue
#     write_queue = deque()
#     read_queue = deque()

#     clk = dut.clk_i
#     cocotb.start_soon(Clock(clk, CLK_PERIOD, units=UNITS).start())

#     fifo_read_bus = FalafelFifoReadBus(
#         dut, "", {'read': 'read_i', 'dout': 'dout_o', 'empty': 'empty_o'})

#     fifo_write_bus = FalafelFifoWriteBus(
#         dut, "", {'write': 'write_i', 'din': 'din_i', 'full': 'full_o'})


#     fifo_read_slave = FalafelFifoReadSlave(fifo_read_bus, clk)
#     fifo_write_slave = FalafelFifoWriteSlave(fifo_write_bus, clk)

#     await reset_dut(dut)

#     await cocotb.start(sim_time_counter(dut))
#     await cocotb.start(monitor_outputs(dut))



#     await Timer(10, units='ns')




# import cocotb
# from cocotb.triggers import Timer, RisingEdge, FallingEdge, ReadOnly, ReadWrite, NextTimeStep
# from cocotb.clock import Clock

# from collections import deque

# CLK_PERIOD = 10
# MAX_SIM_TIME = 1000
# NUM_ENTRIES = 64


# async def reset_dut(dut):
#     await FallingEdge(dut.clk_i)

#     dut.clk_i.value = 0
#     dut.rst_ni.value = 0

#     dut.read_i.value = 0
#     dut.write_i.value = 0
#     dut.din_i.value = 0

#     for i in range(10):
#         await RisingEdge(dut.clk_i)
#     dut.rst_ni.value = 1

#     await FallingEdge(dut.clk_i)
#     await FallingEdge(dut.clk_i)


# async def sim_time_counter(dut):
#     counter = 0

#     while counter < MAX_SIM_TIME:
#         counter += 1
#         await FallingEdge(dut.clk_i)

#     assert False, "Surpassed MAX_SIM_TIME of " + str(MAX_SIM_TIME)


# async def write_val(dut, val):
#     await ReadOnly()

#     while dut.full_o.value:
#         await RisingEdge(dut.clk_i)
#         await ReadOnly()

#     await FallingEdge(dut.clk_i)

#     dut.write_i.value = 1
#     dut.din_i.value = val

#     await ReadOnly()
#     write_queue.append(val)

#     await RisingEdge(dut.clk_i)
#     dut.write_i.value = 0


# async def read_val(dut):
#     await ReadOnly()

#     while dut.empty_o.value:
#         await RisingEdge(dut.clk_i)
#         await ReadOnly()

#     await FallingEdge(dut.clk_i)
#     dut.read_i.value = 1
#     await ReadOnly()
#     read_queue.append(int(dut.dout_o.value))

#     await RisingEdge(dut.clk_i)
#     dut.read_i.value = 0


# async def read_write(dut, val):
#     await FallingEdge(dut.clk_i)
#     dut.read_i.value = 1
#     dut.write_i.value = 1
#     dut.din_i.value = val

#     await ReadOnly()

#     if not dut.full_o.value:
#         write_queue.append(val)

#     if not dut.empty_o.value:
#         read_queue.append(int(dut.dout_o.value))

#     await RisingEdge(dut.clk_i)
#     dut.read_i.value = 0
#     dut.write_i.value = 0


# async def read_remaining_entryes(dut):
#     while not is_empty(dut):
#         await read_val(dut)

#     assert len(write_queue) == 0, "FIFO still has entries"


# async def is_full(dut):
#     await ReadOnly()
#     return int(dut.full_o.value) == 1


# async def is_empty(dut):
#     await ReadOnly()
#     return int(dut.empty_o.value) == 1


# async def monitor_outputs(dut):
#     await FallingEdge(dut.clk_i)

#     while True:
#         await RisingEdge(dut.clk_i)

#         if dut.rst_ni.value == 0:
#             continue

#         if len(read_queue) > 0:
#             assert read_queue.popleft() == write_queue.popleft(
#             ), "Read and write values dont match"


# @cocotb.test()
# async def test_short_sequence(dut):
#     """Short sequence"""

#     global write_queue, read_queue
#     write_queue = deque()
#     read_queue = deque()

#     cocotb.start_soon(Clock(dut.clk_i, CLK_PERIOD, units="ns").start())
#     await reset_dut(dut)

#     await cocotb.start(sim_time_counter(dut))
#     await cocotb.start(monitor_outputs(dut))

#     assert await is_empty(dut)
#     assert not await is_full(dut)

#     await write_val(dut, 2)
#     assert not await is_empty(dut)
#     await read_val(dut)
#     assert await is_empty(dut)

#     await read_remaining_entryes(dut)
#     await Timer(10, units='ns')


# @cocotb.test()
# async def test_fifo_fills_up(dut):
#     """Fifo fills up"""

#     global write_queue, read_queue
#     write_queue = deque()
#     read_queue = deque()

#     cocotb.start_soon(Clock(dut.clk_i, CLK_PERIOD, units="ns").start())
#     await reset_dut(dut)

#     await cocotb.start(sim_time_counter(dut))
#     await cocotb.start(monitor_outputs(dut))

#     assert await is_empty(dut)
#     assert not await is_full(dut)

#     for i in range(NUM_ENTRIES):
#         await write_val(dut, i)

#     await read_val(dut)
#     assert not await is_full(dut)

#     await write_val(dut, 5)
#     await read_write(dut, 6)
#     assert not await is_full(dut)

#     await read_remaining_entryes(dut)
#     await Timer(10, units='ns')


# @cocotb.test()
# async def test_simulataneous_read_write(dut):
#     """Simultaneous read write"""

#     global write_queue, read_queue
#     write_queue = deque()
#     read_queue = deque()

#     cocotb.start_soon(Clock(dut.clk_i, CLK_PERIOD, units="ns").start())
#     await reset_dut(dut)

#     await cocotb.start(sim_time_counter(dut))
#     await cocotb.start(monitor_outputs(dut))

#     assert await is_empty(dut)
#     assert not await is_full(dut)

#     await write_val(dut, 5)
#     assert not await is_empty(dut)
#     await read_write(dut, 6)
#     assert not await is_empty(dut)
#     await read_val(dut)
#     assert await is_empty(dut)

#     await read_remaining_entryes(dut)
#     await Timer(10, units='ns')
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock

from collections import deque

CLK_PERIOD = 10
MAX_SIM_TIME = 1000
NUM_ENTRIES = 64


async def reset_dut(dut):
    await FallingEdge(dut.clk_i)

    dut.clk_i.value = 0
    dut.rst_ni.value = 0

    dut.read_i.value = 0
    dut.write_i.value = 0
    dut.din_i.value = 0

    for i in range(10):
        await FallingEdge(dut.clk_i)
    dut.rst_ni.value = 1

    await FallingEdge(dut.clk_i)
    await FallingEdge(dut.clk_i)


async def sim_time_counter(dut):
    counter = 0

    while counter < MAX_SIM_TIME:
        counter += 1
        await FallingEdge(dut.clk_i)

    assert False, "Surpassed MAX_SIM_TIME of " + str(MAX_SIM_TIME)


async def write_val(dut, val):
    while dut.full_o.value:
        await FallingEdge(dut.clk_i)

    dut.write_i.value = 1
    dut.din_i.value = val

    write_queue.append(val)

    await FallingEdge(dut.clk_i)
    dut.write_i.value = 0


async def read_val(dut):
    while dut.empty_o.value:
        await FallingEdge(dut.clk_i)

    dut.read_i.value = 1

    await Timer(1, units='ns')
    read_queue.append(int(dut.dout_o.value))
    # print('read value', int(dut.dout_o.value))

    await FallingEdge(dut.clk_i)
    dut.read_i.value = 0


async def read_write(dut, val):
    dut.read_i.value = 1
    dut.write_i.value = 1
    dut.din_i.value = val

    if not dut.full_o.value:
        write_queue.append(val)

    await Timer(1, units='ns')

    if not dut.empty_o.value:
        read_queue.append(int(dut.dout_o.value))

    await FallingEdge(dut.clk_i)
    dut.read_i.value = 0
    dut.write_i.value = 0


async def read_remaining_entryes(dut):
    while not is_empty(dut):
        await read_val(dut)

    assert len(write_queue) == 0, "FIFO still has entries"


def is_full(dut):
    # print('is full', int(dut.full_o.value))
    return int(dut.full_o.value) == 1


def is_empty(dut):
    # print('is empty', int(dut.empty_o.value))
    return int(dut.empty_o.value) == 1


async def monitor_outputs(dut):
    await FallingEdge(dut.clk_i)

    while True:
        await FallingEdge(dut.clk_i)

        if dut.rst_ni.value == 0:
            continue

        if len(read_queue) > 0:
            assert read_queue.popleft() == write_queue.popleft(
            ), "Read and write values dont match"


@cocotb.test()
async def test_short_sequence(dut):
    """Short sequence"""

    global write_queue, read_queue
    write_queue = deque()
    read_queue = deque()

    cocotb.start_soon(Clock(dut.clk_i, CLK_PERIOD, units="ns").start())
    await reset_dut(dut)

    await cocotb.start(sim_time_counter(dut))
    await cocotb.start(monitor_outputs(dut))

    assert is_empty(dut)
    assert not is_full(dut)

    await write_val(dut, 2)
    assert not is_empty(dut)
    await read_val(dut)
    assert is_empty(dut)

    await read_remaining_entryes(dut)
    await Timer(10, units='ns')


@cocotb.test()
async def test_fifo_fills_up(dut):
    """Fifo fills up"""

    global write_queue, read_queue
    write_queue = deque()
    read_queue = deque()

    cocotb.start_soon(Clock(dut.clk_i, CLK_PERIOD, units="ns").start())
    await reset_dut(dut)

    await cocotb.start(sim_time_counter(dut))
    await cocotb.start(monitor_outputs(dut))

    assert is_empty(dut)
    assert not is_full(dut)

    for i in range(NUM_ENTRIES):
        await write_val(dut, i)

    await read_val(dut)
    assert not is_full(dut)

    await write_val(dut, 5)
    await read_write(dut, 6)
    assert not is_full(dut)

    await read_remaining_entryes(dut)
    await Timer(10, units='ns')


@cocotb.test()
async def test_simulataneous_read_write(dut):
    """Simultaneous read write"""

    global write_queue, read_queue
    write_queue = deque()
    read_queue = deque()

    cocotb.start_soon(Clock(dut.clk_i, CLK_PERIOD, units="ns").start())
    await reset_dut(dut)

    await cocotb.start(sim_time_counter(dut))
    await cocotb.start(monitor_outputs(dut))

    assert is_empty(dut)
    assert not is_full(dut)

    await write_val(dut, 5)
    assert not is_empty(dut)
    await read_write(dut, 6)
    assert not is_empty(dut)
    await read_val(dut)
    assert is_empty(dut)

    await read_remaining_entryes(dut)
 
