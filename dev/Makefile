SIM ?= verilator
TOPLEVEL_LANG ?= verilog

VERILOG_SOURCES += falafel.sv

TOPLEVEL = falafel

MODULE = test_falafel

EXTRA_ARGS += --trace-fst --trace-structs

include $(shell cocotb-config --makefiles)/Makefile.sim

PYTHON=$(shell poetry run which python)
