"""
Cocotb testbench for Herald CORDIC module
Comprehensive testing matching CORDIC_TB.bsv test suite
Uses mkCORDICHighLevel wrapper for cleaner interface
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.types import LogicArray

# CORDIC modes
MODE_ROTATION = 0
MODE_VECTORING = 1

# Golden model - exact match to RTL implementation (16 iterations, Q8.8 format)
ANGLES = [
    201, 118, 62, 31, 15, 7, 4, 2,
    1, 0, 0, 0, 0, 0, 0, 0
]

K_FACTOR = 155  # 1/K = 0.607 in Q8.8 format

def sign_extend_16(val):
    """Sign extend to 16-bit signed integer"""
    val = val & 0xFFFF
    if val & 0x8000:
        return val - 0x10000
    return val

def to_unsigned_16(val):
    """Convert signed to unsigned 16-bit"""
    if val < 0:
        return (val + 0x10000) & 0xFFFF
    return val & 0xFFFF

def cordic_rotation(angle):
    """CORDIC rotation mode: compute sin/cos"""
    x = K_FACTOR
    y = 0
    z = angle
    
    for i in range(16):  # Reduced to 16 iterations
        angle_i = ANGLES[i]
        rotate_cw = (z < 0)
        
        x_shifted = x >> i
        y_shifted = y >> i
        
        if rotate_cw:
            x_new = x + y_shifted
            y_new = y - x_shifted
            z_new = z + angle_i
        else:
            x_new = x - y_shifted
            y_new = y + x_shifted
            z_new = z - angle_i
        
        x = sign_extend_16(x_new)
        y = sign_extend_16(y_new)
        z = sign_extend_16(z_new)
    
    return (y, x)  # Return (sin, cos)

def cordic_vectoring(x_in, y_in):
    """CORDIC vectoring mode: compute atan2"""
    x = x_in
    y = y_in
    z = 0
    
    for i in range(16):  # Reduced to 16 iterations
        angle_i = ANGLES[i]
        rotate_cw = (y > 0)
        
        x_shifted = x >> i
        y_shifted = y >> i
        
        if rotate_cw:
            x_new = x + y_shifted
            y_new = y - x_shifted
            z_new = z + angle_i
        else:
            x_new = x - y_shifted
            y_new = y + x_shifted
            z_new = z - angle_i
        
        x = sign_extend_16(x_new)
        y = sign_extend_16(y_new)
        z = sign_extend_16(z_new)
    
    return z

async def reset_dut(dut):
    """Reset the DUT"""
    cordic = dut.user_project.cordic_inst
    dut.rst_n.value = 0
    cordic.EN_sin_cos.value = 0
    cordic.EN_atan2.value = 0
    cordic.EN_sqrt_magnitude.value = 0
    cordic.EN_get_sin_cos.value = 0
    cordic.EN_get_atan2.value = 0
    cordic.EN_get_sqrt.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 1)

async def cordic_sin_cos(dut, angle):
    """Start CORDIC sin/cos operation"""
    cordic = dut.user_project.cordic_inst
    await RisingEdge(dut.clk)
    cordic.sin_cos_angle.value = to_unsigned_16(angle)
    cordic.EN_sin_cos.value = 1
    await RisingEdge(dut.clk)
    cordic.EN_sin_cos.value = 0

async def cordic_atan2(dut, y, x):
    """Start CORDIC atan2 operation"""
    cordic = dut.user_project.cordic_inst
    await RisingEdge(dut.clk)
    cordic.atan2_y.value = to_unsigned_16(y)
    cordic.atan2_x.value = to_unsigned_16(x)
    cordic.EN_atan2.value = 1
    await RisingEdge(dut.clk)
    cordic.EN_atan2.value = 0

async def wait_cordic_done(dut):
    """Wait for CORDIC to complete and result to be ready"""
    cordic = dut.user_project.cordic_inst
    # Wait for busy to go low
    timeout = 0
    while cordic.busy.value == 1:
        await RisingEdge(dut.clk)
        timeout += 1
        if timeout > 100:
            raise Exception("CORDIC timeout - busy stuck high")

async def get_sin_cos(dut):
    """Get sin/cos result"""
    cordic = dut.user_project.cordic_inst
    # Wait for result to be ready
    timeout = 0
    while cordic.RDY_get_sin_cos.value != 1:
        await RisingEdge(dut.clk)
        timeout += 1
        if timeout > 50:
            # Debug: print signals
            dut._log.error(f"RDY_get_sin_cos stuck low after {timeout} cycles")
            dut._log.error(f"  busy={cordic.busy.value}")
            dut._log.error(f"  RDY_get_sin_cos={cordic.RDY_get_sin_cos.value}")
            raise Exception("get_sin_cos timeout - RDY stuck low")
    
    # Enable get and read on same cycle
    cordic.EN_get_sin_cos.value = 1
    await RisingEdge(dut.clk)
    cordic.EN_get_sin_cos.value = 0
    
    result = int(cordic.get_sin_cos.value)
    
    # Tuple2(sin, cos) packs as {sin[15:0], cos[15:0]} for 16-bit
    sin_val = sign_extend_16((result >> 16) & 0xFFFF)
    cos_val = sign_extend_16(result & 0xFFFF)
    return sin_val, cos_val

async def get_atan2(dut):
    """Get atan2 result"""
    cordic = dut.user_project.cordic_inst
    # Wait for result to be ready
    timeout = 0
    while cordic.RDY_get_atan2.value != 1:
        await RisingEdge(dut.clk)
        timeout += 1
        if timeout > 50:
            # Debug: print signals
            dut._log.error(f"RDY_get_atan2 stuck low after {timeout} cycles")
            dut._log.error(f"  busy={cordic.busy.value}")
            dut._log.error(f"  RDY_get_atan2={cordic.RDY_get_atan2.value}")
            raise Exception("get_atan2 timeout - RDY stuck low")
    
    # Enable get and read on same cycle
    cordic.EN_get_atan2.value = 1
    await RisingEdge(dut.clk)
    cordic.EN_get_atan2.value = 0
    
    result = sign_extend_16(int(cordic.get_atan2.value))
    
    return result

@cocotb.test()
async def test_cordic_comprehensive(dut):
    """Comprehensive CORDIC test - all 10 test cases from CORDIC_TB.bsv"""
    
    # Start clock
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    await reset_dut(dut)
    
    dut._log.info("=" * 60)
    dut._log.info("HERALD CORDIC VALIDATION TEST SUITE")
    dut._log.info("=" * 60)
    
    # Test parameters matching CORDIC_TB.bsv (converted to Q8.8 format)
    tests = [
        ("Test 1: sin/cos(0)", "rotation", 0, None, None),
        ("Test 2: sin/cos(pi/6)", "rotation", 134, None, None),  # 34308 / 256
        ("Test 3: sin/cos(pi/4)", "rotation", 201, None, None),  # 51472 / 256
        ("Test 4: sin/cos(pi/3)", "rotation", 268, None, None),  # 68616 / 256
        ("Test 5: sin/cos(pi/2)", "rotation", 402, None, None),  # 102944 / 256
        ("Test 6: atan2(1,1)", "vectoring", None, 256, 256),  # 65536 / 256
        ("Test 7: atan2(0,1)", "vectoring", None, 0, 256),  # 10->0, 65536 / 256
        ("Test 8: atan2(3,4)", "vectoring", None, 768, 1024),  # 196608/256, 262144/256
        ("Test 9: atan2(1,2)", "vectoring", None, 256, 512),  # 65536/256, 131072/256
        ("Test 10: sin/cos(0.1 rad)", "rotation", 26, None, None),  # 6554 / 256
    ]
    
    pass_count = 0
    
    for test_name, mode, angle, y_in, x_in in tests:
        dut._log.info(f"\n{test_name}")
        
        if mode == "rotation":
            # Start rotation mode operation
            await cordic_sin_cos(dut, angle)
            
            # Compute expected result
            expected_sin, expected_cos = cordic_rotation(angle)
            
        else:  # vectoring
            # Start vectoring mode operation
            await cordic_atan2(dut, y_in, x_in)
            
            # Compute expected result (note: x and y swapped internally)
            expected_angle = cordic_vectoring(x_in, y_in)
        
        # Wait for completion
        await wait_cordic_done(dut)
        
        # Get result
        if mode == "rotation":
            sin_res, cos_res = await get_sin_cos(dut)
            
            dut._log.info(f"  RTL: sin={sin_res:11d} cos={cos_res:11d}")
            dut._log.info(f"  Expected: sin={expected_sin:11d} cos={expected_cos:11d}")
            
            # Allow ±10 tolerance for Q8.8 precision
            sin_delta = abs(sin_res - expected_sin)
            cos_delta = abs(cos_res - expected_cos)
            if sin_delta <= 10 and cos_delta <= 10:
                dut._log.info(f"  ✓ PASS (Δsin={sin_delta}, Δcos={cos_delta})")
                pass_count += 1
            else:
                error_msg = f"  ✗ MISMATCH: Δsin={sin_delta}, Δcos={cos_delta}"
                dut._log.error(error_msg)
                assert False, error_msg
        
        else:  # vectoring
            angle_res = await get_atan2(dut)
            
            dut._log.info(f"  RTL: angle={angle_res:11d}")
            dut._log.info(f"  Expected: angle={expected_angle:11d}")
            
            # Allow ±10 tolerance for Q8.8 precision
            angle_delta = abs(angle_res - expected_angle)
            if angle_delta <= 10:
                dut._log.info(f"  ✓ PASS (Δangle={angle_delta})")
                pass_count += 1
            else:
                error_msg = f"  ✗ MISMATCH: Δangle={angle_delta}"
                dut._log.error(error_msg)
                assert False, error_msg
    
    dut._log.info("=" * 60)
    dut._log.info(f"Completed: {pass_count}/10 tests passed")
    dut._log.info("=" * 60)
    
    assert pass_count == 10, f"Only {pass_count}/10 tests passed"

@cocotb.test()
async def test_cordic_basic(dut):
    """Basic sanity test - sin/cos(pi/4)"""
    
    # Start clock
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    await reset_dut(dut)
    
    dut._log.info("Basic test: sin/cos(pi/4)")
    
    # Start operation - angle in Q8.8 format (51472 / 256 = 201)
    await cordic_sin_cos(dut, 201)
    
    # Wait for completion
    await wait_cordic_done(dut)
    
    # Get result
    sin_res, cos_res = await get_sin_cos(dut)
    
    # Expected values in Q8.8 format (Q16.16 / 256)
    expected_sin = 181  # 46342 / 256
    expected_cos = 181  # 46341 / 256
    
    dut._log.info(f"sin={sin_res}, cos={cos_res}")
    dut._log.info(f"Expected: sin={expected_sin}, cos={expected_cos}")
    
    # Allow ±5 tolerance for Q8.8 precision
    assert abs(sin_res - expected_sin) <= 5, f"sin mismatch: {sin_res} != {expected_sin}"
    assert abs(cos_res - expected_cos) <= 5, f"cos mismatch: {cos_res} != {expected_cos}"
    
    dut._log.info("✓ Basic test passed")