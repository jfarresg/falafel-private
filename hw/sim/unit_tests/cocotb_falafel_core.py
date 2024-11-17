import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock

from falafel_bus import FalafelMemRequestBus, FalafelMemRequestMonitor, FalafelMemResponseBus, FalafelMemResponseDriver
from falafel_bus import FalafelFifoReadBus, FalafelFifoWriteBus, FalafelFifoReadSlave, FalafelFifoWriteSlave

import falafel_block
from falafel_block import Block
from falafel_pkg import *


CLK_PERIOD = 10
MAX_SIM_TIME = 15000
UNITS = 'ns'


async def reset_dut(dut, clk):
    await FallingEdge(clk)

    clk.setimmediatevalue(0)
    dut.rst_ni.setimmediatevalue(0)

    for i in range(10):
        await FallingEdge(clk)
    dut.rst_ni.setimmediatevalue(1)

    await FallingEdge(clk)
    await FallingEdge(clk)


async def sim_time_counter(dut, clk):
    counter = 0

    while counter < MAX_SIM_TIME:
        counter += 1
        await FallingEdge(clk)

    assert False, "Surpassed MAX_SIM_TIME of " + str(MAX_SIM_TIME)


def mem_print(inst, val):
    (is_write, is_cas, addr, data, cas_exp) = inst


    if is_cas:
        print('CAS', 'addr:', addr, ' exp', cas_exp, ' data', data)
    elif is_write:
        print('WR ', 'addr:', addr, ' data', data)
    else:
        print('RD ', 'addr:', addr, ' -->', val)


async def mem_monitor(dut, clk, mem):
    mem_req_bus = MinimalBus(dut, {'val': 'mem_req_val_o', 'rdy': 'mem_req_rdy_i', 'is_write': 'mem_req_is_write_o',
                                                        'is_cas': 'mem_req_is_cas_o', 'cas_exp': 'mem_req_cas_exp_o',
                                                        'addr': 'mem_req_addr_o', 'data': 'mem_req_data_o'})
    mem_rsp_bus = MinimalBus(
        dut, {'val': 'mem_rsp_val_i', 'rdy': 'mem_rsp_rdy_o', 'data': 'mem_rsp_data_i'})

    mem_req_monitor = FalafelMemRequestMonitor(mem_req_bus, clk)
    mem_rsp_driver = FalafelMemResponseDriver(mem_rsp_bus, clk)

    await RisingEdge(clk)

    while True:
        (is_write, is_cas, addr, data, cas_exp) = await mem_req_monitor.recv()
        # print((is_write, is_cas, addr, data, cas_exp))

        norm_addr = addr//WORD_SIZE
        write_data = data
        # print('norm_addr', norm_addr)

        if is_cas:
            if mem[norm_addr] == cas_exp:
                mem[norm_addr] = data
                data = 0
            else:
                data = 1
        elif is_write:
            mem[norm_addr] = data
        else:
            assert norm_addr in mem, "Accessed uninitialized mem[{}]".format(
                norm_addr)
            data = mem[norm_addr]

        # mem_print((is_write, is_cas, addr, write_data, cas_exp), data)
        await mem_rsp_driver.send(data)


class MinimalBus:
    def __init__(self, entity, signals):
        self._entity = entity
        self._signals = {name: getattr(entity, signal) for name, signal in signals.items()}

@cocotb.test()
async def test_simple_alloc(dut):
    """Test simple allocations"""

    clk = dut.clk_i

    cocotb.start_soon(Clock(clk, CLK_PERIOD, units=UNITS).start())

    alloc_fifo_bus = MinimalBus(
        dut, {'empty': 'alloc_fifo_empty_i', 'read': 'alloc_fifo_read_o', 'dout': 'alloc_fifo_dout_i'})

    free_fifo_bus = MinimalBus(
        dut, {'empty': 'free_fifo_empty_i', 'read': 'free_fifo_read_o', 'dout': 'free_fifo_dout_i'})

    resp_fifo_bus = MinimalBus(
        dut, {'full': 'resp_fifo_full_i', 'write': 'resp_fifo_write_o', 'din': 'resp_fifo_din_o'})

    alloc_fifo_driver = FalafelFifoReadSlave(alloc_fifo_bus, clk)
    free_fifo_driver = FalafelFifoReadSlave(free_fifo_bus, clk)
    resp_fifo_driver = FalafelFifoWriteSlave(resp_fifo_bus, clk)

    free_list_ptr = 0x20
    lock_ptr = 0x28
    lock_id = 1
    dut.falafel_config_free_list_ptr.setimmediatevalue(free_list_ptr)
    dut.falafel_config_lock_ptr.setimmediatevalue(lock_ptr)
    dut.falafel_config_lock_id.setimmediatevalue(lock_id)
    mem = {}
    mem[lock_ptr//WORD_SIZE] = 0

    blocks = [
        Block(192, 64),
        Block(448, 192),
        Block(1024, 64),
        Block(1792, 192)
    ]

    falafel_block.list_to_mem(free_list_ptr, blocks, mem)

    await reset_dut(dut, clk)
    await cocotb.start(sim_time_counter(dut, clk))
    await cocotb.start(mem_monitor(dut, clk, mem))
    await cocotb.start(alloc_fifo_driver.monitor())
    await cocotb.start(free_fifo_driver.monitor())
    await cocotb.start(resp_fifo_driver.monitor())

    await Timer(20, units=UNITS)

    print('initial list', end=' ')
    falafel_block.print_list(blocks)

    await alloc_fifo_driver.push(35)
    await alloc_fifo_driver.push(32)
    await alloc_fifo_driver.push(200)
    await alloc_fifo_driver.push(80)
    await alloc_fifo_driver.push(32)
    await alloc_fifo_driver.push(64)
    await alloc_fifo_driver.push(32)
    print("Queue contents:", alloc_fifo_driver.queue)
    print("Queue contents:", resp_fifo_driver.queue)  # 出力例: Queue contents: [42, 7]

    ptr = await resp_fifo_driver.pop()
    # assert ptr == 256, 'ptrs dont match'
    # ptr = await resp_fifo_driver.pop()
    # assert ptr == 512, 'ptrs dont match'
    # ptr = await resp_fifo_driver.pop()
    # assert ptr == ERR_NOMEM, 'ptrs dont match'
    # ptr = await resp_fifo_driver.pop()
    # assert ptr == 640, 'ptrs dont match'
    # ptr = await resp_fifo_driver.pop()
    # assert ptr == 1088, 'ptrs dont match'
    # ptr = await resp_fifo_driver.pop()
    # assert ptr == 1792, 'ptrs dont match'
    # ptr = await resp_fifo_driver.pop()
    # assert ptr == ERR_NOMEM, 'ptrs dont match'

    # await Timer(100, units=UNITS)
    # print('final list', end=' ')
    # falafel_block.print_list(falafel_block.mem_to_list(free_list_ptr, mem))

    # await Timer(100, units=UNITS)


# @cocotb.test()
# async def test_simple_frees(dut):
#     """Test simple frees"""

#     clk = dut.clk_i

#     cocotb.start_soon(Clock(clk, CLK_PERIOD, units=UNITS).start())

#     alloc_fifo_bus = FalafelFifoReadBus(
#         dut, "alloc_fifo", {'empty': 'empty_i', 'read': 'read_o', 'dout': 'dout_i'})

#     free_fifo_bus = FalafelFifoReadBus(
#         dut, "free_fifo", {'empty': 'empty_i', 'read': 'read_o', 'dout': 'dout_i'})

#     resp_fifo_bus = FalafelFifoWriteBus(
#         dut, "resp_fifo", {'full': 'full_i', 'write': 'write_o', 'din': 'din_o'})

#     alloc_fifo_driver = FalafelFifoReadSlave(alloc_fifo_bus, clk)
#     free_fifo_driver = FalafelFifoReadSlave(free_fifo_bus, clk)
#     resp_fifo_driver = FalafelFifoWriteSlave(resp_fifo_bus, clk)

#     free_list_ptr = 0x20
#     lock_ptr = 0x28
#     lock_id = 1
#     dut.falafel_config_free_list_ptr.value = free_list_ptr
#     dut.falafel_config_lock_ptr.value = lock_ptr
#     dut.falafel_config_lock_id.value = lock_id

#     mem = {}
#     mem[lock_ptr//WORD_SIZE] = 0

#     blocks = [
#         Block(160, 32),
#         Block(320, 128),
#         Block(1000, 32),
#         Block(2000, 56)
#     ]

#     falafel_block.list_to_mem(free_list_ptr, blocks, mem)

#     await reset_dut(dut, clk)
#     await cocotb.start(sim_time_counter(dut, clk))
#     await cocotb.start(mem_monitor(dut, clk, mem))
#     await cocotb.start(alloc_fifo_driver.monitor())
#     await cocotb.start(free_fifo_driver.monitor())
#     await cocotb.start(resp_fifo_driver.monitor())

#     await Timer(20, units=UNITS)

#     print('initial list', end=' ')
#     falafel_block.print_list(blocks)

#     await alloc_fifo_driver.push(35)
#     await alloc_fifo_driver.push(32)

#     ptr0 = await resp_fifo_driver.pop()
#     assert ptr0 == 328, 'ptrs dont match'
#     ptr1 = await resp_fifo_driver.pop()
#     assert ptr1 == 168, 'ptrs dont match'

#     await Timer(100, units=UNITS)

#     print('after allocations list', end=' ')
#     falafel_block.print_list(falafel_block.mem_to_list(free_list_ptr, mem))

#     await free_fifo_driver.push(ptr0)
#     print('after first free', end=' ')
#     await Timer(3000, units=UNITS)
#     falafel_block.print_list(falafel_block.mem_to_list(free_list_ptr, mem))

#     await free_fifo_driver.push(ptr1)
#     print('after second free', end=' ')
#     await Timer(3000, units=UNITS)
#     falafel_block.print_list(falafel_block.mem_to_list(free_list_ptr, mem))

#     await Timer(800, units=UNITS)

#     await alloc_fifo_driver.push(35)
#     await alloc_fifo_driver.push(32)

#     ptr0 = await resp_fifo_driver.pop()
#     assert ptr0 == 328, 'ptrs dont match'
#     ptr1 = await resp_fifo_driver.pop()
#     assert ptr1 == 168, 'ptrs dont match'

#     print('final list', end=' ')
#     falafel_block.print_list(falafel_block.mem_to_list(free_list_ptr, mem))

#     await Timer(100, units=UNITS)


# @cocotb.test()
# async def test_free_only_block(dut):
#     """Test freeing the only block"""

#     clk = dut.clk_i

#     cocotb.start_soon(Clock(clk, CLK_PERIOD, units=UNITS).start())

#     alloc_fifo_bus = FalafelFifoReadBus(
#         dut, "alloc_fifo", {'empty': 'empty_i', 'read': 'read_o', 'dout': 'dout_i'})

#     free_fifo_bus = FalafelFifoReadBus(
#         dut, "free_fifo", {'empty': 'empty_i', 'read': 'read_o', 'dout': 'dout_i'})

#     resp_fifo_bus = FalafelFifoWriteBus(
#         dut, "resp_fifo", {'full': 'full_i', 'write': 'write_o', 'din': 'din_o'})

#     alloc_fifo_driver = FalafelFifoReadSlave(alloc_fifo_bus, clk)
#     free_fifo_driver = FalafelFifoReadSlave(free_fifo_bus, clk)
#     resp_fifo_driver = FalafelFifoWriteSlave(resp_fifo_bus, clk)

#     free_list_ptr = 0x20
#     lock_ptr = 0x28
#     lock_id = 1
#     dut.falafel_config_free_list_ptr.value = free_list_ptr
#     dut.falafel_config_lock_ptr.value = lock_ptr
#     dut.falafel_config_lock_id.value = lock_id

#     mem = {}
#     mem[lock_ptr//WORD_SIZE] = 0

#     blocks = [
#         Block(160, 32)
#     ]

#     falafel_block.list_to_mem(free_list_ptr, blocks, mem)

#     await reset_dut(dut, clk)
#     await cocotb.start(sim_time_counter(dut, clk))
#     await cocotb.start(mem_monitor(dut, clk, mem))
#     await cocotb.start(alloc_fifo_driver.monitor())
#     await cocotb.start(free_fifo_driver.monitor())
#     await cocotb.start(resp_fifo_driver.monitor())

#     await Timer(20, units=UNITS)

#     await alloc_fifo_driver.push(32)
#     ptr = await resp_fifo_driver.pop()
#     assert ptr == 168, 'ptrs dont match'

#     await free_fifo_driver.push(ptr)
#     await Timer(3000, units=UNITS)
#     # falafel_block.print_list(falafel_block.mem_to_list(free_list_ptr, mem))

#     await alloc_fifo_driver.push(32)
#     ptr = await resp_fifo_driver.pop()
#     assert ptr == 168, 'ptrs dont match'
#     # falafel_block.print_list(falafel_block.mem_to_list(free_list_ptr, mem))

#     await Timer(100, units=UNITS)


# @cocotb.test()
# async def test_free_both_blocks(dut):
#     """Test freeing the first block and the last block"""

#     clk = dut.clk_i

#     cocotb.start_soon(Clock(clk, CLK_PERIOD, units=UNITS).start())

#     alloc_fifo_bus = FalafelFifoReadBus(
#         dut, "alloc_fifo", {'empty': 'empty_i', 'read': 'read_o', 'dout': 'dout_i'})

#     free_fifo_bus = FalafelFifoReadBus(
#         dut, "free_fifo", {'empty': 'empty_i', 'read': 'read_o', 'dout': 'dout_i'})

#     resp_fifo_bus = FalafelFifoWriteBus(
#         dut, "resp_fifo", {'full': 'full_i', 'write': 'write_o', 'din': 'din_o'})

#     alloc_fifo_driver = FalafelFifoReadSlave(alloc_fifo_bus, clk)
#     free_fifo_driver = FalafelFifoReadSlave(free_fifo_bus, clk)
#     resp_fifo_driver = FalafelFifoWriteSlave(resp_fifo_bus, clk)

#     free_list_ptr = 0x20
#     lock_ptr = 0x28
#     lock_id = 1
#     dut.falafel_config_free_list_ptr.value = free_list_ptr
#     dut.falafel_config_lock_ptr.value = lock_ptr
#     dut.falafel_config_lock_id.value = lock_id

#     mem = {}
#     mem[lock_ptr//WORD_SIZE] = 0

#     blocks = [
#         Block(160, 32),
#         Block(320, 40)
#     ]

#     falafel_block.list_to_mem(free_list_ptr, blocks, mem)

#     await reset_dut(dut, clk)
#     await cocotb.start(sim_time_counter(dut, clk))
#     await cocotb.start(mem_monitor(dut, clk, mem))
#     await cocotb.start(alloc_fifo_driver.monitor())
#     await cocotb.start(free_fifo_driver.monitor())
#     await cocotb.start(resp_fifo_driver.monitor())

#     await Timer(20, units=UNITS)

#     await alloc_fifo_driver.push(40)
#     ptr_last = await resp_fifo_driver.pop()
#     assert ptr_last == 328, 'ptrs dont match'

#     await alloc_fifo_driver.push(32)
#     ptr_first = await resp_fifo_driver.pop()
#     assert ptr_first == 168, 'ptrs dont match'

#     await free_fifo_driver.push(ptr_last)
#     await Timer(3000, units=UNITS)

#     await free_fifo_driver.push(ptr_first)
#     await Timer(3000, units=UNITS)

#     await alloc_fifo_driver.push(32)
#     ptr_first = await resp_fifo_driver.pop()
#     assert ptr_first == 168, 'ptrs dont match'

#     await alloc_fifo_driver.push(40)
#     ptr_last = await resp_fifo_driver.pop()
#     assert ptr_last == 328, 'ptrs dont match'

#     await Timer(100, units=UNITS)
