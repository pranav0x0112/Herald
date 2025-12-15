# Makefile for cocotb CORDIC testbench

# Defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog

# Verilog sources
VERILOG_SOURCES = $(PWD)/../build/verilog/mkCORDICHighLevel.v $(PWD)/../build/verilog/mkCORDIC.v

# Toplevel module
TOPLEVEL = mkCORDICHighLevel

# Python test module
MODULE = test_cordic

# Waveform dump
WAVES ?= 1
ifeq ($(WAVES),1)
    COMPILE_ARGS += -DWAVES
endif

# Include cocotb makefiles
include $(shell cocotb-config --makefiles)/Makefile.sim

# Clean target
clean::
	rm -rf __pycache__ sim_build results.xml
	rm -f *.vcd *.fst
