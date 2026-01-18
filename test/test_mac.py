"""
Cocotb testbench for MAC (Multiply-Accumulate) unit
Tests multiply, mac, and clear_accumulator operations
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.types import LogicArray


def to_fixed(val):
    """Convert integer to Q8.8 fixed-point"""
    return int(val * 256)


def from_fixed(fixed_val):
    """Convert Q8.8 fixed-point to float"""
    # Handle signed 16-bit values
    if fixed_val >= 2**15:
        fixed_val = fixed_val - 2**16
    return fixed_val / 256.0


def to_signed_16(val):
    """Convert to signed 16-bit representation"""
    val = val & 0xFFFF
    if val >= 2**15:
        return val - 2**16
    return val


async def reset_dut(dut):
    """Reset the DUT"""
    dut.rst_n.value = 0
    await Timer(20, unit='ns')
    dut.rst_n.value = 1
    await Timer(20, unit='ns')


async def wait_ready(dut):
    """Wait for MAC to be ready (not busy)"""
    mac = dut.user_project.mac_inst
    timeout = 100
    for _ in range(timeout):
        if mac.busy.value == 0:
            return
        await RisingEdge(dut.clk)
    raise TimeoutError(f"MAC still busy after {timeout} cycles")


async def multiply(dut, a, b):
    """Perform multiply operation"""
    mac = dut.user_project.mac_inst
    # Set inputs and wait for them to propagate
    mac.multiply_a.value = a & 0xFFFF
    mac.multiply_b.value = b & 0xFFFF
    await Timer(1, unit='ns')  # Let input values propagate
    
    # Now assert EN_multiply
    mac.EN_multiply.value = 1
    
    await RisingEdge(dut.clk)
    await Timer(1, unit='ns')  # Let values settle
    mac.EN_multiply.value = 0
    
    # Wait one more cycle for result_reg to be updated
    await RisingEdge(dut.clk)
    await Timer(1, unit='ns')
    
    # Read result immediately (enable the ActionValue method)
    mac.EN_get_multiply.value = 1
    await RisingEdge(dut.clk)
    await Timer(1, unit='ns')  # Let values settle
    result = int(mac.get_multiply.value)
    mac.EN_get_multiply.value = 0
    
    return to_signed_16(result)


async def mac_op(dut, a, b):
    """Perform MAC (multiply-accumulate) operation"""
    mac = dut.user_project.mac_inst
    # Set inputs
    mac.mac_a.value = a & 0xFFFF
    mac.mac_b.value = b & 0xFFFF
    mac.EN_mac.value = 1
    
    await RisingEdge(dut.clk)
    await Timer(1, unit='ns')  # Let values settle
    mac.EN_mac.value = 0
    
    # Wait one more cycle for result_reg to be updated
    await RisingEdge(dut.clk)
    await Timer(1, unit='ns')
    
    # Read result immediately (enable the ActionValue method)
    mac.EN_get_mac.value = 1
    await RisingEdge(dut.clk)
    await Timer(1, unit='ns')  # Let values settle
    result = int(mac.get_mac.value)
    mac.EN_get_mac.value = 0
    
    return to_signed_16(result)


async def clear_accumulator(dut):
    """Clear the accumulator"""
    mac = dut.user_project.mac_inst
    mac.EN_clear_accumulator.value = 1
    await RisingEdge(dut.clk)
    mac.EN_clear_accumulator.value = 0
    # Clear is instantaneous, no need to wait for busy


@cocotb.test()
async def test_multiply_basic(dut):
    """Test basic multiplication: 2 * 3 = 6"""
    
    # Start clock
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    # Initialize all enable signals to 0
    mac = dut.user_project.mac_inst
    mac.EN_multiply.value = 0
    mac.EN_get_multiply.value = 0
    mac.EN_get_mac.value = 0
    mac.EN_mac.value = 0
    mac.EN_clear_accumulator.value = 0
    
    await reset_dut(dut)
    
    # Test: 2 * 3 = 6
    a = to_fixed(2)
    b = to_fixed(3)
    result = await multiply(dut, a, b)
    expected = to_fixed(6)
    
    dut._log.info(f"2 * 3 = {from_fixed(result):.4f} (expected 6.0)")
    dut._log.info(f"  Raw: result={result}, expected={expected}")
    
    assert abs(result - expected) < 100, f"Expected {expected}, got {result}"


@cocotb.test()
async def test_multiply_large(dut):
    """Test larger multiplication: 10 * 10 = 100"""
    
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    mac = dut.user_project.mac_inst
    mac.EN_multiply.value = 0
    mac.EN_get_multiply.value = 0
    mac.EN_get_mac.value = 0
    mac.EN_mac.value = 0
    mac.EN_clear_accumulator.value = 0
    
    await reset_dut(dut)
    
    # Test: 10 * 10 = 100
    a = to_fixed(10)
    b = to_fixed(10)
    result = await multiply(dut, a, b)
    expected = to_fixed(100)
    
    dut._log.info(f"10 * 10 = {from_fixed(result):.4f} (expected 100.0)")
    
    assert abs(result - expected) < 100, f"Expected {expected}, got {result}"


@cocotb.test()
async def test_multiply_negative(dut):
    """Test negative multiplication: -5 * 2 = -10"""
    
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    mac = dut.user_project.mac_inst
    mac.EN_multiply.value = 0
    mac.EN_get_multiply.value = 0
    mac.EN_get_mac.value = 0
    mac.EN_mac.value = 0
    mac.EN_clear_accumulator.value = 0
    
    await reset_dut(dut)
    
    # Test: -5 * 2 = -10
    a = to_fixed(-5)
    b = to_fixed(2)
    result = await multiply(dut, a, b)
    expected = to_fixed(-10)
    
    dut._log.info(f"-5 * 2 = {from_fixed(result):.4f} (expected -10.0)")
    
    assert abs(result - expected) < 100, f"Expected {expected}, got {result}"


@cocotb.test()
async def test_multiply_zero(dut):
    """Test zero multiplication: 0 * 100 = 0"""
    
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    mac = dut.user_project.mac_inst
    mac.EN_multiply.value = 0
    mac.EN_get_multiply.value = 0
    mac.EN_get_mac.value = 0
    mac.EN_mac.value = 0
    mac.EN_clear_accumulator.value = 0
    
    await reset_dut(dut)
    
    # Test: 0 * 100 = 0
    a = to_fixed(0)
    b = to_fixed(100)
    result = await multiply(dut, a, b)
    expected = 0
    
    dut._log.info(f"0 * 100 = {from_fixed(result):.4f} (expected 0.0)")
    
    assert abs(result - expected) < 100, f"Expected {expected}, got {result}"


@cocotb.test()
async def test_mac_accumulate(dut):
    """Test MAC accumulation: 0 + (2*3) + (4*5) = 6 + 20 = 26"""
    
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    mac = dut.user_project.mac_inst
    mac.EN_multiply.value = 0
    mac.EN_get_multiply.value = 0
    mac.EN_get_mac.value = 0
    mac.EN_mac.value = 0
    mac.EN_clear_accumulator.value = 0
    
    await reset_dut(dut)
    await clear_accumulator(dut)
    
    # Clear accumulator first
    await clear_accumulator(dut)
    
    # First MAC: 0 + (2*3) = 6
    a1 = to_fixed(2)
    b1 = to_fixed(3)
    result1 = await mac_op(dut, a1, b1)
    expected1 = to_fixed(6)
    
    dut._log.info(f"MAC: 0 + (2*3) = {from_fixed(result1):.4f} (expected 6.0)")
    assert abs(result1 - expected1) < 100, f"Expected {expected1}, got {result1}"
    
    # Second MAC: 6 + (4*5) = 26
    a2 = to_fixed(4)
    b2 = to_fixed(5)
    result2 = await mac_op(dut, a2, b2)
    expected2 = to_fixed(26)
    
    dut._log.info(f"MAC: 6 + (4*5) = {from_fixed(result2):.4f} (expected 26.0)")
    assert abs(result2 - expected2) < 100, f"Expected {expected2}, got {result2}"


@cocotb.test()
async def test_mac_clear(dut):
    """Test MAC clear: accumulate then clear, then accumulate again"""
    
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    mac = dut.user_project.mac_inst
    mac.EN_multiply.value = 0
    mac.EN_get_multiply.value = 0
    mac.EN_get_mac.value = 0
    mac.EN_mac.value = 0
    mac.EN_clear_accumulator.value = 0
    
    await reset_dut(dut)
    await clear_accumulator(dut)
    
    # Clear accumulator
    await clear_accumulator(dut)
    
    # MAC: 0 + (2*3) = 6
    result1 = await mac_op(dut, to_fixed(2), to_fixed(3))
    dut._log.info(f"MAC: 0 + (2*3) = {from_fixed(result1):.4f}")
    
    # Clear accumulator
    await clear_accumulator(dut)
    
    # MAC after clear: 0 + (5*5) = 25
    result2 = await mac_op(dut, to_fixed(5), to_fixed(5))
    expected = to_fixed(25)
    
    dut._log.info(f"MAC after clear: 0 + (5*5) = {from_fixed(result2):.4f} (expected 25.0)")
    assert abs(result2 - expected) < 100, f"Expected {expected}, got {result2}"


@cocotb.test()
async def test_fractional_multiply(dut):
    """Test fractional multiplication: 0.5 * 4 = 2"""
    
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    mac = dut.user_project.mac_inst
    mac.EN_multiply.value = 0
    mac.EN_get_multiply.value = 0
    mac.EN_get_mac.value = 0
    mac.EN_mac.value = 0
    mac.EN_clear_accumulator.value = 0
    
    await reset_dut(dut)
    
    # Test: 0.5 * 4 = 2
    a = to_fixed(0.5)
    b = to_fixed(4)
    result = await multiply(dut, a, b)
    expected = to_fixed(2)
    
    dut._log.info(f"0.5 * 4 = {from_fixed(result):.4f} (expected 2.0)")
    
    assert abs(result - expected) < 100, f"Expected {expected}, got {result}"