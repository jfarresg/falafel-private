import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock

from falafel_bus import FalafelMemRequestBus, FalafelMemRequestMonitor, FalafelMemResponseBus, FalafelMemResponseDriver
from falafel_bus import FalafelLsuRequestBus, FalafelLsuResponseBus, FalafelLsuRequestDriver, FalafelLsuResponseMonitor

from falafel_pkg import *

CLK_PERIOD = 10
MAX_SIM_TIME = 10000
UNITS = 'ns'


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


async def mem_monitor(dut, clk, mem = {}):
    mem_req_bus = FalafelMemRequestBus(dut, "mem_req", {'val': 'val_o', 'rdy': 'rdy_i', 'is_write': 'is_write_o',
                                                        'is_cas': 'is_cas_o', 'cas_exp': 'cas_exp_o',
                                                        'addr': 'addr_o', 'data': 'data_o'})
    mem_rsp_bus = FalafelMemResponseBus(
        dut, "mem_rsp", {'val': 'val_i', 'rdy': 'rdy_o', 'data': 'data_i'})

    mem_req_monitor = FalafelMemRequestMonitor(mem_req_bus, clk)
    mem_rsp_driver = FalafelMemResponseDriver(mem_rsp_bus, clk)

    await RisingEdge(clk)

    while True:
        (is_write, is_cas, addr, data, cas_exp) = await mem_req_monitor.recv()
        # print((is_write, is_cas, addr, data, cas_exp))

        norm_addr = addr//WORD_SIZE
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

        await mem_rsp_driver.send(data)


@cocotb.test()
async def test_load_store_words(dut):
    """Test loading and storing words"""

    clk = dut.clk_i

    cocotb.start_soon(Clock(clk, CLK_PERIOD, units=UNITS).start())

    lsu_req_bus = FalafelLsuRequestBus(
        dut, "alloc_req", {'val': 'val_i', 'rdy': 'rdy_o', 'op': 'op_i',
                           'addr': 'addr_i', 'word': 'word_i', 'lock_id': 'lock_id_i', 'block_size':
                           'block_size_i', 'block_next_ptr': 'block_next_ptr_i'})

    lsu_rsp_bus = FalafelLsuResponseBus(
        dut, "alloc_rsp", {'val': 'val_o', 'rdy': 'rdy_i', 'word': 'word_o',
                           'block_size': 'block_size_o', 'block_next_ptr':
                           'block_next_ptr_o'})

    lsu_req_driver = FalafelLsuRequestDriver(lsu_req_bus, clk)
    lsu_rsp_monitor = FalafelLsuResponseMonitor(lsu_rsp_bus, clk)

    await reset_dut(dut, clk)

    await cocotb.start(sim_time_counter(dut, clk))
    await cocotb.start(mem_monitor(dut, clk, {}))

    SIZE = 10
    addr = [(i+5)*WORD_SIZE for i in range(SIZE)]
    data = [(i+1)*WORD_SIZE for i in range(SIZE)]

    for (a, d) in zip(addr, data):
        await lsu_req_driver.store_word(a, d)
        await lsu_rsp_monitor.recv()

    for (a, d) in zip(addr, data):
        await lsu_req_driver.load_word(a)
        (w, _) = await lsu_rsp_monitor.recv()

        assert w == d, "values don't match"

    await Timer(100, units=UNITS)


# @cocotb.test()
# async def test_load_store_blocks(dut):
#     """Test loading and storing blocks"""

#     clk = dut.clk_i

#     cocotb.start_soon(Clock(clk, CLK_PERIOD, units=UNITS).start())

#     lsu_req_bus = FalafelLsuRequestBus(
#         dut, "alloc_req", {'val': 'val_i', 'rdy': 'rdy_o', 'op': 'op_i',
#                            'addr': 'addr_i', 'word': 'word_i', 'lock_id': 'lock_id_i', 'block_size':
#                            'block_size_i', 'block_next_ptr': 'block_next_ptr_i'})

#     lsu_rsp_bus = FalafelLsuResponseBus(
#         dut, "alloc_rsp", {'val': 'val_o', 'rdy': 'rdy_i', 'word': 'word_o',
#                            'block_size': 'block_size_o', 'block_next_ptr':
#                            'block_next_ptr_o'})

#     lsu_req_driver = FalafelLsuRequestDriver(lsu_req_bus, clk)
#     lsu_rsp_monitor = FalafelLsuResponseMonitor(lsu_rsp_bus, clk)

#     await reset_dut(dut, clk)

#     await cocotb.start(sim_time_counter(dut, clk))
#     await cocotb.start(mem_monitor(dut, clk, {}))

#     SIZE = 10
#     addr = [16*i for i in range(SIZE)]
#     data = [(i, 2*i) for i in range(SIZE)]

#     for (a, d) in zip(addr, data):
#         await lsu_req_driver.store_block(a, d)
#         await lsu_rsp_monitor.recv()

#     for (a, d) in zip(addr, data):
#         await lsu_req_driver.load_block(a)
#         (_, b) = await lsu_rsp_monitor.recv()

#         assert b == d, "values don't match"

#     await Timer(100, units=UNITS)



# @cocotb.test()
# async def test_mix_words_blocks(dut):
#     """Test mixing words and blocks"""

#     clk = dut.clk_i
#     cocotb.start_soon(Clock(clk, CLK_PERIOD, units=UNITS).start())

#     lsu_req_bus = FalafelLsuRequestBus(
#         dut, "alloc_req", {'val': 'val_i', 'rdy': 'rdy_o', 'op': 'op_i',
#                            'addr': 'addr_i', 'word': 'word_i', 'lock_id': 'lock_id_i', 'block_size':
#                            'block_size_i', 'block_next_ptr': 'block_next_ptr_i'})

#     lsu_rsp_bus = FalafelLsuResponseBus(
#         dut, "alloc_rsp", {'val': 'val_o', 'rdy': 'rdy_i', 'word': 'word_o',
#                            'block_size': 'block_size_o', 'block_next_ptr':
#                            'block_next_ptr_o'})

#     lsu_req_driver = FalafelLsuRequestDriver(lsu_req_bus, clk)
#     lsu_rsp_monitor = FalafelLsuResponseMonitor(lsu_rsp_bus, clk)

#     await reset_dut(dut, clk)

#     await cocotb.start(sim_time_counter(dut, clk))
#     await cocotb.start(mem_monitor(dut, clk, {}))

#     await lsu_req_driver.store_block(0, (3, 4))
#     await lsu_rsp_monitor.recv()

#     await lsu_req_driver.store_word(16, 5)
#     await lsu_rsp_monitor.recv()

#     await lsu_req_driver.store_block(24, (6, 7))
#     await lsu_rsp_monitor.recv()

#     await lsu_req_driver.store_word(40, 8)
#     await lsu_rsp_monitor.recv()

#     await lsu_req_driver.load_block(24)
#     (_, b) = await lsu_rsp_monitor.recv()
#     assert b == (6, 7), "values don't match"

#     await lsu_req_driver.load_word(16)
#     (w, _) = await lsu_rsp_monitor.recv()
#     assert w == 5, "values don't match"

#     await lsu_req_driver.load_block(0)
#     (_, b) = await lsu_rsp_monitor.recv()
#     assert b == (3, 4), "values don't match"

#     await lsu_req_driver.load_word(40)
#     (w, _) = await lsu_rsp_monitor.recv()
#     assert w == 8, "values don't match"

#     await Timer(100, units=UNITS)


# @cocotb.test()
# async def test_lock_unlock(dut):
#     """Test locking and unlocking"""

#     clk = dut.clk_i
#     cocotb.start_soon(Clock(clk, CLK_PERIOD, units=UNITS).start())

#     lsu_req_bus = FalafelLsuRequestBus(
#         dut, "alloc_req", {'val': 'val_i', 'rdy': 'rdy_o', 'op': 'op_i',
#                            'addr': 'addr_i', 'word': 'word_i', 'lock_id': 'lock_id_i', 'block_size':
#                            'block_size_i', 'block_next_ptr': 'block_next_ptr_i'})

#     lsu_rsp_bus = FalafelLsuResponseBus(
#         dut, "alloc_rsp", {'val': 'val_o', 'rdy': 'rdy_i', 'word': 'word_o',
#                            'block_size': 'block_size_o', 'block_next_ptr':
#                            'block_next_ptr_o'})

#     lsu_req_driver = FalafelLsuRequestDriver(lsu_req_bus, clk)
#     lsu_rsp_monitor = FalafelLsuResponseMonitor(lsu_rsp_bus, clk)

#     LOCK_ID = 1
#     LOCK_ADDR = 1024

#     init_mem = {}
#     init_mem[LOCK_ADDR//WORD_SIZE] = LOCK_ID+1

#     await reset_dut(dut, clk)

#     await cocotb.start(sim_time_counter(dut, clk))
#     await cocotb.start(mem_monitor(dut, clk, init_mem))

#     await lsu_req_driver.lock(LOCK_ADDR, LOCK_ID)

#     # check that lsu doesn't attempt to overwrite the taken lock
#     for _i in range(50):
#         await FallingEdge(clk)
#         assert init_mem[LOCK_ADDR//8] == LOCK_ID+1

#     init_mem[LOCK_ADDR//8] = 0

#     for _i in range(20):
#         await FallingEdge(clk)

#     assert init_mem[LOCK_ADDR//8] == LOCK_ID
#     await lsu_rsp_monitor.recv()

#     assert init_mem[LOCK_ADDR//8] == LOCK_ID

#     await lsu_req_driver.unlock(LOCK_ADDR)
#     await lsu_rsp_monitor.recv()

#     await Timer(CLK_PERIOD*20, units=UNITS)

#     assert init_mem[LOCK_ADDR//8] == 0

#     await Timer(100, units=UNITS)
