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
else ifeq ($(TEST),wrapper)
    VERILOG_SOURCES = $(PWD)/../src/rtl/tt_um_herald.v \
                      $(PWD)/../build/verilog/mkCORDICHighLevel.v \
                      $(PWD)/../build/verilog/mkMAC.v
    TOPLEVEL = tt_um_herald
    MODULE = test_wrapper
endif

# Waveform dump
WAVES ?= 1
ifeq ($(WAVES),1)
    COMPILE_ARGS += -DWAVES
endif

# Include cocotb makefiles
include $(shell cocotb-config --makefiles)/Makefile.sim

# Convenience targets
.PHONY: cordic mac wrapper

cordic:
	$(MAKE) TEST=cordic

mac:
	$(MAKE) TEST=mac

wrapper:
	$(MAKE) TEST=wrapper

# Clean target
clean::
	rm -rf __pycache__ sim_build results.xml
	rm -f *.vcd *.fst
