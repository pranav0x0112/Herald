import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, ClockCycles

def to_fixed(val):
    """Convert float to Q12.12 fixed point"""
    return int(val * 4096) & 0xFFFFFF

def from_fixed(val):
    """Convert Q12.12 fixed point to float"""
    if val & 0x800000:
        val = val - 0x1000000
    return val / 4096.0

def to_signed_24(val):
    """Convert unsigned 24-bit to signed"""
    if val & 0x800000:
        return val - 0x1000000
    return val

async def reset_dut(dut):
    """Reset the DUT"""
    dut.rst_n.value = 0
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0  # WR=0, RD=0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)

async def write_byte(dut, byte_val):
    """Write a byte using WR strobe"""
    dut.ui_in.value = byte_val & 0xFF
    await Timer(1, unit='ns')
    dut.uio_in.value = 0x01  # WR=1
    await RisingEdge(dut.clk)
    await Timer(1, unit='ns')
    dut.uio_in.value = 0x00  # WR=0
    await RisingEdge(dut.clk)

async def read_byte(dut):
    """Read a byte using RD strobe"""
    dut.uio_in.value = 0x02  # RD=1
    await RisingEdge(dut.clk)
    await Timer(1, unit='ns')
    result = int(dut.uo_out.value) & 0xFF
    dut.uio_in.value = 0x00  # RD=0
    await RisingEdge(dut.clk)
    return result

async def write_24bit(dut, value):
    """Write 24-bit value as 3 bytes (LSB first)"""
    await write_byte(dut, (value >>  0) & 0xFF)
    await write_byte(dut, (value >>  8) & 0xFF)
    await write_byte(dut, (value >> 16) & 0xFF)

async def read_24bit(dut):
    """Read 24-bit value as 3 bytes (LSB first)"""
    b0 = await read_byte(dut)
    b1 = await read_byte(dut)
    b2 = await read_byte(dut)
    return (b2 << 16) | (b1 << 8) | b0

async def read_48bit(dut):
    """Read 48-bit value as 6 bytes (LSB first) - for sincos"""
    b0 = await read_byte(dut)
    b1 = await read_byte(dut)
    b2 = await read_byte(dut)
    b3 = await read_byte(dut)
    b4 = await read_byte(dut)
    b5 = await read_byte(dut)
    return (b5 << 40) | (b4 << 32) | (b3 << 24) | (b2 << 16) | (b1 << 8) | b0



async def wait_not_busy(dut, timeout=100):
    """Wait for BUSY flag to go low"""
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if (int(dut.uo_out.value) & 0x80) == 0:
            return
    raise TimeoutError("Timeout waiting for BUSY=0")

@cocotb.test()
async def test_wrapper_mac_multiply(dut):
    """Test MAC multiply operation through wrapper"""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    # Test: 2 * 3 = 6
    a = to_fixed(2)
    b = to_fixed(3)
    expected = to_fixed(6)
    
    # Write command
    await write_byte(dut, 0x20)  # CMD_MAC_MULTIPLY
    
    # Write operands
    await write_24bit(dut, a)
    await write_24bit(dut, b)
    
    # Wait for computation
    await wait_not_busy(dut)
    
    # Read result
    result = await read_24bit(dut)
    result_signed = to_signed_24(result)
    
    dut._log.info(f"MAC multiply: 2 * 3 = {from_fixed(result_signed):.4f} (expected 6.0)")
    dut._log.info(f"  Raw: result={result_signed}, expected={expected}")
    
    assert abs(result_signed - expected) < 100, f"Expected {expected}, got {result_signed}"

@cocotb.test()
async def test_wrapper_mac_accumulate(dut):
    """Test MAC accumulate operation through wrapper"""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    # First MAC: 0 + (2*3) = 6
    await write_byte(dut, 0x21)  # CMD_MAC_MAC
    await write_24bit(dut, to_fixed(2))
    await write_24bit(dut, to_fixed(3))
    await wait_not_busy(dut)
    result1 = await read_24bit(dut)
    
    dut._log.info(f"MAC: 0 + (2*3) = {from_fixed(to_signed_24(result1)):.4f}")
    
    # Second MAC: 6 + (4*5) = 26
    await write_byte(dut, 0x21)  # CMD_MAC_MAC
    await write_24bit(dut, to_fixed(4))
    await write_24bit(dut, to_fixed(5))
    await wait_not_busy(dut)
    result2 = await read_24bit(dut)
    
    dut._log.info(f"MAC: 6 + (4*5) = {from_fixed(to_signed_24(result2)):.4f}")
    
    expected = to_fixed(26)
    assert abs(to_signed_24(result2) - expected) < 100, f"Expected {expected}, got {to_signed_24(result2)}"

@cocotb.test()
async def test_wrapper_mac_clear(dut):
    """Test MAC clear operation"""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    # Accumulate: 0 + (2*3) = 6
    await write_byte(dut, 0x21)
    await write_24bit(dut, to_fixed(2))
    await write_24bit(dut, to_fixed(3))
    await wait_not_busy(dut)
    await read_24bit(dut)
    
    # Clear accumulator
    await write_byte(dut, 0x22)  # CMD_MAC_CLEAR
    await wait_not_busy(dut)
    
    # New accumulation: 0 + (5*5) = 25
    await write_byte(dut, 0x21)
    await write_24bit(dut, to_fixed(5))
    await write_24bit(dut, to_fixed(5))
    await wait_not_busy(dut)
    result = await read_24bit(dut)
    
    dut._log.info(f"After clear: 0 + (5*5) = {from_fixed(to_signed_24(result)):.4f}")
    
    expected = to_fixed(25)
    assert abs(to_signed_24(result) - expected) < 100

@cocotb.test()
async def test_wrapper_cordic_sincos(dut):
    """Test CORDIC sin/cos operation through wrapper"""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    # Test: sin/cos(pi/4)
    angle = 3217  # pi/4 in Q12.12 (823549 / 4096)
    
    # Write command
    await write_byte(dut, 0x10)  # CMD_CORDIC_SINCOS
    
    # Write angle
    await write_24bit(dut, angle)
    
    # Wait for computation (CORDIC takes ~20 iterations)
    await wait_not_busy(dut, timeout=200)
    
    # Read 48-bit result (sin in low 24, cos in high 24)
    result_48 = await read_48bit(dut)
    sin_result = to_signed_24(result_48 & 0xFFFFFF)
    cos_result = to_signed_24((result_48 >> 24) & 0xFFFFFF)
    
    dut._log.info(f"CORDIC sin/cos(pi/4):")
    dut._log.info(f"  sin = {from_fixed(sin_result):.6f}")
    dut._log.info(f"  cos = {from_fixed(cos_result):.6f}")
    
    # pi/4 -> sin ≈ 0.707, cos ≈ 0.707
    expected_sin = 2896  # 0.707 in Q12.12 (2896 / 4096)
    expected_cos = 2896
    
    assert abs(sin_result - expected_sin) < 160, f"Sin mismatch: {sin_result} vs {expected_sin}"
    assert abs(cos_result - expected_cos) < 160, f"Cos mismatch: {cos_result} vs {expected_cos}"

@cocotb.test()
async def test_wrapper_cordic_atan2(dut):
    """Test CORDIC atan2 operation through wrapper"""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    # Test: atan2(1, 1) = pi/4
    y = to_fixed(1)
    x = to_fixed(1)
    
    await write_byte(dut, 0x11)  # CMD_CORDIC_ATAN2
    await write_24bit(dut, y)
    await write_24bit(dut, x)
    
    await wait_not_busy(dut, timeout=200)
    
    result = await read_24bit(dut)
    result_signed = to_signed_24(result)
    
    dut._log.info(f"CORDIC atan2(1,1) = {from_fixed(result_signed):.6f} rad")
    
    expected = 3217  # pi/4 in Q12.12 (823551 / 4096)
    assert abs(result_signed - expected) < 160

@cocotb.test()
async def test_wrapper_reset(dut):
    """Test that wrapper resets properly"""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    # After reset, should be in IDLE state, BUSY=0
    await ClockCycles(dut.clk, 2)
    status = int(dut.uo_out.value)
    
    dut._log.info(f"Status after reset: {status:02x} (BUSY={status >> 7})")
    assert (status & 0x80) == 0, "Expected BUSY=0 after reset"