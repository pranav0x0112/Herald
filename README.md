# Herald

Fixed-point DSP coprocessor for MCUs with no FPU. Hardware CORDIC and MAC units in Q12.12 format.

## Architecture

- **Format:** Q12.12 (24-bit: 12 integer, 12 fractional)
- **Clock:** 50 MHz
- **Area:** ~80k µm² (62.9% utilization)
- **Interface:** 8-bit parallel wrapper (TinyTapeout)

## Features

### CORDIC Engine
- `sin(θ)`, `cos(θ)` - simultaneous
- `atan2(y, x)` - angle computation
- `sqrt_magnitude(x, y)` - vector length
- `normalize(x, y)` - returns (x, y, magnitude)

### MAC Unit
- `multiply(a, b)` - Q12.12 multiplication
- `mac(a, b)` - multiply-accumulate (acc += a×b)
- `msu(a, b)` - multiply-subtract (acc -= a×b)
- `clear()` - reset accumulator

## Status

[x] RTL verified (Bluespec + cocotb)  
[x] GDS signoff clean (IHP SG13G2 130nm)  
[x] Timing: ~6ns worst-case setup slack @ 50MHz  
[x] Routing: 0 overflow

Full documentation coming soon :)