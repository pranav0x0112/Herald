# make              # Run CORDIC test (default)
# make cordic_test  # Test CORDIC
# make cordic_verilog  # Generate Verilog
# make check        # Syntax check only
# make clean        # Clean build

# Config
BSC = bsc
export PATH := /usr/bin:$(PATH)
SRC_DIR = src/rtl
TB_DIR = tb
BUILD_DIR = build
BSIM_DIR = $(BUILD_DIR)/bsim
VERILOG_DIR = $(BUILD_DIR)/verilog

BSC_FLAGS = -check-assert -aggressive-conditions
BSC_SIM_FLAGS = -sim -bdir $(BSIM_DIR) -simdir $(BSIM_DIR) -info-dir $(BSIM_DIR)
BSC_VERILOG_FLAGS = -verilog -vdir $(VERILOG_DIR) -bdir $(VERILOG_DIR) -info-dir $(VERILOG_DIR)
BSC_PATH = -p +:$(SRC_DIR):$(TB_DIR)

.PHONY: all clean test cordic_test cordic_verilog dirs

all: cordic_test

dirs:
	@mkdir -p $(BSIM_DIR) $(VERILOG_DIR)

# CORDIC test (direct testbench)
cordic_test: dirs
	@echo "[BSC] Compiling CORDIC testbench..."
	$(BSC) $(BSC_FLAGS) $(BSC_SIM_FLAGS) $(BSC_PATH) -g mkCORDIC_TB -u $(TB_DIR)/CORDIC_TB.bsv
	$(BSC) $(BSC_FLAGS) $(BSC_SIM_FLAGS) $(BSC_PATH) -e mkCORDIC_TB -o $(BSIM_DIR)/cordic_tb
	@echo "[SIM] Running..."
	@cd $(BSIM_DIR) && ./cordic_tb

# MAC test
mac_test: dirs
	@echo "[BSC] Compiling MAC testbench..."
	$(BSC) $(BSC_FLAGS) $(BSC_SIM_FLAGS) $(BSC_PATH) -g mkMAC_TB -u $(TB_DIR)/MAC_TB.bsv
	$(BSC) $(BSC_FLAGS) $(BSC_SIM_FLAGS) $(BSC_PATH) -e mkMAC_TB -o $(BSIM_DIR)/mac_tb
	@echo "[SIM] Running..."
	@cd $(BSIM_DIR) && ./mac_tb

# Generate Verilog
cordic_verilog: dirs
	@echo "[BSC] Generating Verilog..."
	$(BSC) $(BSC_FLAGS) $(BSC_VERILOG_FLAGS) $(BSC_PATH) -g mkCORDIC $(SRC_DIR)/CORDIC.bsv
	$(BSC) $(BSC_FLAGS) $(BSC_VERILOG_FLAGS) $(BSC_PATH) -g mkCORDICHighLevel $(SRC_DIR)/CORDIC.bsv
	@echo "[INFO] Verilog in $(VERILOG_DIR)/"

# Generate MAC Verilog
mac_verilog: dirs
	@echo "[BSC] Generating MAC Verilog..."
	$(BSC) $(BSC_FLAGS) $(BSC_VERILOG_FLAGS) $(BSC_PATH) -g mkMAC $(SRC_DIR)/MAC.bsv
	@echo "[INFO] Verilog in $(VERILOG_DIR)/"

# Generate all Verilog
verilog: cordic_verilog mac_verilog

# Syntax check
check: dirs
	@echo "[BSC] Checking syntax..."
	$(BSC) $(BSC_FLAGS) $(BSC_PATH) $(SRC_DIR)/CORDIC.bsv
	@echo "[OK] Syntax check passed"

# Run all tests
test: cordic_test mac_test

# Clean
clean:
	@rm -rf $(BUILD_DIR) *.bo *.ba *.so *.o *.h
	@echo "[CLEAN] Done"
