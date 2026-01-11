# Makefile for cocotb testbenches

# Defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog

# Test target selection
TEST ?= cordic

# Conditional configuration based on test target
ifeq ($(TEST),cordic)
    VERILOG_SOURCES = $(PWD)/../build/verilog/mkCORDICHighLevel.v
    TOPLEVEL = mkCORDICHighLevel
    MODULE = test_cordic
else ifeq ($(TEST),mac)
    VERILOG_SOURCES = $(PWD)/../build/verilog/mkMAC.v
    TOPLEVEL = mkMAC
    MODULE = test_mac
endif

# Waveform dump
WAVES ?= 1
ifeq ($(WAVES),1)
    COMPILE_ARGS += -DWAVES
endif

# Include cocotb makefiles
include $(shell cocotb-config --makefiles)/Makefile.sim

# Convenience targets
.PHONY: cordic mac

cordic:
	$(MAKE) TEST=cordic

mac:
	$(MAKE) TEST=mac

# Clean target
clean::
	rm -rf __pycache__ sim_build results.xml
	rm -f *.vcd *.fst
