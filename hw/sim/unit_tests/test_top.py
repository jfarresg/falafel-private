import sys
import os
from cocotb_test.simulator import run

PROJECT_ROOT = os.environ["FALAFEL_PROJECT_ROOT"]
RTL_DIR = os.environ["FALAFEL_RTL_DIR"]
SIM_DIR = PROJECT_ROOT + '/hw/sim'
INCLUDE_DIR = RTL_DIR + "/include/"

WRAPPER_DIR = SIM_DIR + '/unit_tests/sv_wrappers'

sys.path.insert(0, SIM_DIR + '/cocotb_common')


# def test_falafel_fifo():
#     run(
#         includes=[INCLUDE_DIR],
#         verilog_sources=[
#             INCLUDE_DIR + "/fifos/falafel_fifo_internal.sv",
#             INCLUDE_DIR + "/fifos/falafel_fifo.sv"],
#         toplevel="falafel_fifo",
#         module="cocotb_fifo",
#         sim_build="sim_build/falafel_fifo",
#     )


# def test_falafel_input_parser():
#     run(
#         includes=[INCLUDE_DIR],
#         verilog_sources=[INCLUDE_DIR + "/falafel_pkg.sv",
#                          INCLUDE_DIR + "/fifos/falafel_fifo_internal.sv",
#                          INCLUDE_DIR + "/fifos/falafel_fifo.sv",
#                          RTL_DIR + "/falafel_input_parser.sv",
#                          WRAPPER_DIR + "/falafel_input_parser_wrapper.sv"],
#         toplevel="falafel_input_parser_wrapper",
#         module="cocotb_input_parser",
#         sim_build="sim_build/falafel_input_parser",
#     )


# def test_falafel_lsu():
#     run(
#         includes=[INCLUDE_DIR],
#         verilog_sources=[INCLUDE_DIR + "/falafel_pkg.sv",
#                          RTL_DIR + "/falafel_lsu.sv",
#                          WRAPPER_DIR + "/falafel_lsu_wrapper.sv"],
#         toplevel="falafel_lsu_wrapper",
#         module="cocotb_falafel_lsu",
#         sim_build="sim_build/falafel_lsu",
#     )


def test_falafel_core():
    run(
        includes=[INCLUDE_DIR],
        verilog_sources=[INCLUDE_DIR + "/falafel_pkg.sv",
                         RTL_DIR + "/falafel_lsu.sv",
                         RTL_DIR + "/core/falafel_block_parser.sv",
                         RTL_DIR + "/core/falafel_core.sv",
                         WRAPPER_DIR + "/falafel_core_wrapper.sv"],
        toplevel="falafel_core_wrapper",
        module="cocotb_falafel_core",
        sim_build="sim_build/falafel_core",
    )
