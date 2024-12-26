import cocotb
from cocotb.triggers import FallingEdge
from cocotb.clock import Clock
from mem_rsp import send_req_to_wrapper
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

# constants
WORD_SIZE = 8
L2_SIZE = 64
BLOCK_ALIGNMENT = L2_SIZE
# ERR_NOMEM = -1 + 2**(8*WORD_SIZE)
ERR_NOMEM = 0

OPCODE_SIZE = 4
MSG_ID_SIZE = 8
REG_ADDR_SIZE = 16

# opcodes
REQ_ACCESS_REGISTER = 0
REQ_ALLOC_MEM = 1
REQ_FREE_MEM = 2

# addresses
FREE_LIST_PTR_ADDR = 0x10
LOCK_PTR_ADDR = 0x18
LOCK_ID_ADDR = 0x20


def write_config_req(req_id, addr):
    return (
        REQ_ACCESS_REGISTER
        | (req_id << OPCODE_SIZE)
        | (addr << (OPCODE_SIZE + MSG_ID_SIZE))
    )


def write_alloc_req(req_id):
    return REQ_ALLOC_MEM | (req_id << OPCODE_SIZE)


def write_free_req(req_id):
    return REQ_FREE_MEM | (req_id << OPCODE_SIZE)


async def reset_dut(dut, clk):
    await FallingEdge(clk)

    clk.value = 0
    dut.rst_ni.value = 0

    for i in range(10):
        await FallingEdge(clk)
    dut.rst_ni.value = 1

    await FallingEdge(clk)
    await FallingEdge(clk)


@cocotb.test()
async def test_simple_alloc(dut):
    print("---------------------- Start first fit test ----------------------")
    clk = dut.clk_i

    monitor_task_req_from_falafel = cocotb.start_soon(
        monitor_req_from_falafel(dut)
    )  # noqa
    monitor_task_falafel_ready = cocotb.start_soon(monitor_falafel_ready(dut))

    linked_list = LinkedList()
    linked_list.add_node(16, 160, 300)
    linked_list.add_node(300, 100, 500)
    linked_list.add_node(500, 300, 2000)
    linked_list.add_node(2000, 500, 3000)

    cocotb.start_soon(Clock(clk, CLK_PERIOD, UNITS).start())

    await reset_dut(dut, clk)
    dut.mem_req_rdy_i.setimmediatevalue(1)
    dut.mem_rsp_val_i.setimmediatevalue(0)

    free_list_ptr = 16
    lock_ptr = 0
    lock_id = 1

    # configuration
    await send_req_to_wrapper(
        dut, clk, config_data=write_config_req(0, FREE_LIST_PTR_ADDR), index=0
    )
    await send_req_to_wrapper(dut, clk, config_data=free_list_ptr, index=0)
    await send_req_to_wrapper(
        dut, clk, config_data=write_config_req(0, LOCK_PTR_ADDR), index=0
    )
    await send_req_to_wrapper(dut, clk, config_data=lock_ptr, index=0)
    await send_req_to_wrapper(
        dut, clk, config_data=write_config_req(0, LOCK_ID_ADDR), index=0
    )
    await send_req_to_wrapper(dut, clk, config_data=lock_id, index=0)

    # allocate 1st allocation
    await send_req_to_wrapper(dut, clk, write_alloc_req(0), index=0)
    await send_req_to_wrapper(dut, clk, 200, index=0)

    # Wait for the lock request
    await monitor_task_req_from_falafel
    await grant_lock(dut, clk)
    print("Granted lock")

    await monitor_task_req_from_falafel
    await monitor_task_falafel_ready
    await grant_lock(dut, clk)
    print("Granted cas")

    print("-----Start allocation-----")
    linked_list.print_list()

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
    await monitor_task_req_from_falafel
    await FallingEdge(clk)
    assert dut.mem_req_data_o == 0, int(dut.mem_req_data_o)
    await grant_lock(dut, clk)
    print("Granted release lock")
    await FallingEdge(clk)

    # checking the result
    await FallingEdge(clk)
    assert dut.resp_data_o == 500, int(dut.resp_data_o)

    for i in range(10):
        await FallingEdge(clk)
