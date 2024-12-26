import cocotb
from cocotb.triggers import ReadOnly, Timer


@cocotb.coroutine
async def monitor_req_from_falafel(
    dut, expected_addr=None, expected_data=None, expected_is_write=0
):
    while True:
        await ReadOnly()
        if dut.mem_req_val_o.value == 1:
            if expected_addr is not None:
                assert dut.mem_req_addr_o == expected_addr, int(
                    dut.mem_req_addr_o
                )  # noqa
            if expected_data is not None:
                assert dut.mem_req_data_o == expected_data, int(
                    dut.mem_req_data_o
                )  # noqa
            if expected_is_write != 0:
                assert dut.mem_req_is_write_o == 1
            break
        await Timer(1, units="ns")


@cocotb.coroutine
async def monitor_falafel_ready(dut):
    while True:
        await ReadOnly()
        if dut.mem_rsp_rdy_o.value == 1:
            break
        await Timer(1, units="ns")
