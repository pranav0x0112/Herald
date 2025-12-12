# Herald: Arduino Math Coprocessor

## The Problem

Arduino is some of the most popular choice of beginner embedded systems for millions of makers, students, and hobbyists worldwide. But there's a painful bottleneck: **math performance**.

The Arduino Uno's ATmega328P is an 8-bit AVR microcontroller from 2005 with no floating-point unit. Common mathematical operations that modern applications need are brutally slow:

- Trigonometric functions (sin, cos, atan): Thousands of cycles in software lookup tables
- FFT operations: 500+ milliseconds for just 64 points
- Matrix operations: Impractical for real-time robotics
- Signal filtering: Too slow for audio/sensor processing

This isn't theoretical - people hit these walls constantly:
- Robot arms that can't compute inverse kinematics fast enough for smooth motion
- Audio projects that can't do real-time spectrum analysis
- Drones struggling with sensor fusion and PID control
- Navigation systems crawling through trig calculations

The result? Projects that should work don't and learning hits artificial limits.

## The Solution: Herald

Herald is a custom silicon math accelerator designed to plug into Arduino and handle the heavy numerical lifting. Think of it as a dedicated math brain that Arduino can offload to.

**Architecture:**
- Arduino sends operation code + data over SPI
- Herald computes in hardware (CORDIC + MAC units)

## What Herald Implements

### Tile 1: CORDIC Engine
A configurable CORDIC (Coordinate Rotation Digital Computer) core that implements:

**Trigonometric operations:**
- `sin(θ)`, `cos(θ)` - simultaneous computation
- `tan(θ)`
- `atan(x)`, `atan2(y, x)`

**Hyperbolic functions:**
- `sinh(x)`, `cosh(x)`, `tanh(x)`

**Vector operations:**
- `sqrt(x)` - square root
- `magnitude(x, y)` - vector length: √(x² + y²)
- Cartesian ↔ Polar conversion

**Bonus:**
- Fast multiply (as a CORDIC mode)

### Tile 2: MAC Unit + Interface
**Fast Multiply-Accumulate:**
- `MAC(a, b, c)` → `a × b + c`
- Enables: dot products, convolution, FIR/IIR filtering

**Communication & Control:**
- SPI interface for Arduino communication
- Command decoder for operation selection
- Result buffering

## Why This Matters

- Ecosystem reach: Arduino has millions of active users. Qualcomm's recent acquisition signals growing investment in the platform.

- Learning impact: Students learning embedded systems shouldn't be blocked by 20-year-old hardware limits.

- Practical enablement: Makers can build projects that actually work at useful speeds, not theoretical demos that crawl.

## Project Status

Herald is being designed for fabrication through Tiny Tapeout using Bluespec SystemVerilog (BSV). The project focuses on delivering maximum real-world impact within a 2-tile constraint.