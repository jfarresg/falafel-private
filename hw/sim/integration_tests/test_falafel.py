# import sys
# import os

# PROJECT_ROOT = os.environ["FALAFEL_PROJECT_ROOT"]
# RTL_DIR = os.environ["FALAFEL_RTL_DIR"]
# SIM_DIR = PROJECT_ROOT + '/hw/sim'
# INCLUDE_DIR = RTL_DIR + "/include/"
# sys.path.insert(0, SIM_DIR + '/cocotb_common')

# from collections import deque
# from cocotb.clock import Clock
# from cocotb.triggers import Timer, RisingEdge, FallingEdge
# import cocotb

# from falafel_bus import FalafelMemRequestBus, FalafelMemRequestMonitor, FalafelMemResponseBus, FalafelMemResponseDriver
# from falafel_bus import FalafelValRdyBus, FalafelValRdyDriver, FalafelValRdyMonitor
# import falafel_block
# from falafel_block import Block
# from falafel_pkg import *

# CLK_PERIOD = 10
# MAX_SIM_TIME = 1000
# UNITS = 'ns'

# NUM_HEADER_QUEUES = 2
# NUM_ALLOC_QUEUES  = 2
# NUM_FREE_QUEUES   = 2


# async def reset_dut(dut, clk):
#     await FallingEdge(clk)

#     clk.value = 0
#     dut.rst_ni.value = 0

#     for i in range(10):
#         await FallingEdge(clk)
#     dut.rst_ni.value = 1

#     await FallingEdge(clk)
#     await FallingEdge(clk)


# async def sim_time_counter(dut, clk):
#     counter = 0

#     while counter < MAX_SIM_TIME:
#         counter += 1
#         await FallingEdge(clk)

#     assert False, "Surpassed MAX_SIM_TIME of " + str(MAX_SIM_TIME)


# async def mem_monitor(dut, clk, mem):
#     mem_req_bus = FalafelMemRequestBus(dut, "mem_req", {'val': 'val_o', 'rdy': 'rdy_i', 'is_write': 'is_write_o',
#                                                         'is_cas': 'is_cas_o', 'cas_exp': 'cas_exp_o',
#                                                         'addr': 'addr_o', 'data': 'data_o'})
#     mem_rsp_bus = FalafelMemResponseBus(
#         dut, "mem_resp", {'val': 'val_i', 'rdy': 'rdy_o', 'data': 'data_i'})

#     mem_req_monitor = FalafelMemRequestMonitor(mem_req_bus, clk)
#     mem_rsp_driver = FalafelMemResponseDriver(mem_rsp_bus, clk)

#     print('mem', mem)

#     await RisingEdge(clk)

#     while True:
#         (is_write, is_cas, addr, data, cas_exp) = await mem_req_monitor.recv()
#         # print((is_write, is_cas, addr, data, cas_exp))

#         norm_addr = addr//WORD_SIZE
#         # print('norm_addr', norm_addr)

#         if is_cas:
#             if mem[norm_addr] == cas_exp:
#                 mem[norm_addr] = data
#                 data = 0
#             else:
#                 data = 1
#         elif is_write:
#             mem[norm_addr] = data
#         else:
#             assert norm_addr in mem, "Accessed uninitialized mem[{}]".format(
#                 norm_addr)
#             data = mem[norm_addr]

#         await mem_rsp_driver.send(data)


# @cocotb.test()
# async def test_simple_alloc(dut):
#     """Test simple allocations"""

#     clk = dut.clk_i

#     cocotb.start_soon(Clock(clk, CLK_PERIOD, units=UNITS).start())

#     request_bus = FalafelValRdyBus(
#         dut, "req", {'val': 'val_i', 'rdy': 'rdy_o', 'data': 'data_i'})

#     response_bus = FalafelValRdyBus(
#         dut, "resp", {'val': 'val_o', 'rdy': 'rdy_i', 'data': 'data_o'})

#     req_driver = FalafelValRdyDriver(request_bus, clk)
#     resp_monitor = FalafelValRdyMonitor(response_bus, clk)

#     free_list_ptr = 0x20
#     lock_ptr = 0x28
#     lock_id = 1

#     mem = {}
#     mem[lock_ptr//WORD_SIZE] = 0

#     blocks = [
#         Block(192, 64),
#         Block(448, 192),
#         Block(1024, 64),
#         Block(1792, 192)
#     ]

#     falafel_block.list_to_mem(free_list_ptr, blocks, mem)

#     await reset_dut(dut, clk)
#     await cocotb.start(sim_time_counter(dut, clk))
#     await cocotb.start(mem_monitor(dut, clk, mem))

#     await Timer(20, units=UNITS)

#     print('initial list', end=' ')
#     falafel_block.print_list(blocks)


#     # Configure internal registers
#     await req_driver.sendi(0, write_config_req(0, FREE_LIST_PTR_ADDR))
#     await req_driver.sendi(0, free_list_ptr)
#     await req_driver.sendi(0, write_config_req(0, LOCK_PTR_ADDR))
#     await req_driver.sendi(0, lock_ptr)
#     await req_driver.sendi(0, write_config_req(0, LOCK_ID_ADDR))
#     await req_driver.sendi(0, lock_id)

#     # Send 1st allocation
#     await req_driver.sendi(0, write_alloc_req(0))
#     await req_driver.sendi(0, 35)
#     ptr = await resp_monitor.recv()
#     print('ptr', ptr)
#     assert ptr == 256

#     # Print state
#     await Timer(200, units=UNITS)
#     print('after first alloc', end=' ')
#     falafel_block.print_list(falafel_block.mem_to_list(free_list_ptr, mem))

#     # Allocate 2nd block through alloc queue
#     await req_driver.sendi(2, 35)
#     ptr = await resp_monitor.recv()
#     print('ptr', ptr)
#     assert ptr == 512

#     # Print state
#     await Timer(500, units=UNITS)
#     print('after second alloc', end=' ')
#     falafel_block.print_list(falafel_block.mem_to_list(free_list_ptr, mem))

#     # Free first allocation through free queue
#     await req_driver.sendi(4, 256)

#     await Timer(500, units=UNITS)
#     print('after first free', end=' ')
#     falafel_block.print_list(falafel_block.mem_to_list(free_list_ptr, mem))

#     # Free second allocation through free queue
#     await req_driver.sendi(0, write_free_req(0))
#     await req_driver.sendi(0, 512)

#     # Print state
#     await Timer(500, units=UNITS)
#     print('after second free', end=' ')
#     falafel_block.print_list(falafel_block.mem_to_list(free_list_ptr, mem))

#     # Allocate 1st block again
#     await req_driver.sendi(0, write_alloc_req(0))
#     await req_driver.sendi(0, 35)
#     ptr = await resp_monitor.recv()
#     print('ptr', ptr)
#     assert ptr == 256

#     # Print state
#     await Timer(500, units=UNITS)
#     print('first alloc', end=' ')
#     falafel_block.print_list(falafel_block.mem_to_list(free_list_ptr, mem))

#     # Allocate 2nd block again
#     await req_driver.sendi(0, write_alloc_req(0))
#     await req_driver.sendi(0, 35)
#     ptr = await resp_monitor.recv()
#     print('ptr', ptr)
#     assert ptr == 512

#     # Print state
#     await Timer(500, units=UNITS)
#     print('second alloc', end=' ')
#     falafel_block.print_list(falafel_block.mem_to_list(free_list_ptr, mem))

#     await Timer(100, units=UNITS)
