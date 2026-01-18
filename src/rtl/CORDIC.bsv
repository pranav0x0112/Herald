// Herald CORDIC Engine
// 32-bit iterative CORDIC for trig, hyperbolic, and vector operations
// IHP SG13G2 130nm - Low Power Design

package CORDIC;

import Vector::*;
import FixedPoint::*;

typedef Int#(24) Fixed24;  // 24-bit fixed point (Q12.12 format)
typedef UInt#(5) IterCount; // Iteration counter (0-19) - 20 iterations for Q12.12

typedef enum {
    MODE_ROTATION,     // Rotate vector by angle
    MODE_VECTORING,    // Compute angle and magnitude
    MODE_HYPERBOLIC    // Hyperbolic functions
} CORDICMode deriving (Bits, Eq, FShow);

typedef enum {
    OP_SIN,       
    OP_COS,       
    OP_SINCOS,    
    OP_ATAN2,     
    OP_SQRT,      
    OP_MAGNITUDE
} CORDICOp deriving (Bits, Eq, FShow);

typedef struct {
    Fixed24 x;   
    Fixed24 y;        
    Fixed24 z;      
    IterCount iter;   
    CORDICMode mode; 
    Bool valid;      
} CORDICState deriving (Bits, Eq, FShow);

// Pre-computed CORDIC rotation angles: atan(2^-i) in Q12.12 format
// 20 iterations for 24-bit precision
function Vector#(20, Fixed24) rotationAngles();
    Vector#(20, Fixed24) angles = newVector;
    angles[0]  = 3217;      // atan(2^0)  = 0.7854 rad (45°) in Q12.12
    angles[1]  = 1901;      // atan(2^-1) = 0.4636 rad
    angles[2]  = 1006;      // atan(2^-2) = 0.2450 rad
    angles[3]  = 511;       // atan(2^-3) = 0.1244 rad
    angles[4]  = 256;       // atan(2^-4) = 0.0624 rad
    angles[5]  = 128;       // atan(2^-5) = 0.0312 rad
    angles[6]  = 64;        // atan(2^-6) = 0.0156 rad
    angles[7]  = 32;        // atan(2^-7) = 0.0078 rad
    angles[8]  = 16;        // atan(2^-8) = 0.0039 rad
    angles[9]  = 8;         // atan(2^-9) = 0.0020 rad
    angles[10] = 4;         // atan(2^-10) = 0.0010 rad
    angles[11] = 2;         // atan(2^-11) = 0.0005 rad
    angles[12] = 1;         // atan(2^-12) = 0.0002 rad
    angles[13] = 1;         // atan(2^-13) = 0.0001 rad (rounded)
    angles[14] = 0;         // Remaining angles too small for Q12.12
    angles[15] = 0;
    angles[16] = 0;
    angles[17] = 0;
    angles[18] = 0;
    angles[19] = 0;
    return angles;
endfunction

function Vector#(20, Fixed24) hyperbolicAngles();
    Vector#(20, Fixed24) angles = newVector;
    // Hyperbolic angles in Q12.12 (scaled from Q8.8 by ×16)
    angles[0] = 262144; angles[1] = 131072; angles[2] = 65536;
    angles[3] = 32768; angles[4] = 16384; angles[5] = 8192;
    angles[6] = 4096; angles[7] = 2048; angles[8] = 1024;
    angles[9] = 512; angles[10] = 256; angles[11] = 128;
    angles[12] = 64; angles[13] = 32; angles[14] = 16;
    angles[15] = 8; angles[16] = 4; angles[17] = 2;
    angles[18] = 1; angles[19] = 0;
    return angles;
endfunction

// CORDIC gain compensation factors in Q12.12 format
// K = prod(sqrt(1 + 2^(-2i))) for circular rotations
// After 20 iterations: K ≈ 1.6468 -> 1/K ≈ 0.6073
Fixed24 kFactorRotation = 2487;      // 1/K = 0.6073 in Q12.12 (2487/4096)
Fixed24 kFactorHyperbolic = 0;      // Placeholder for hyperbolic

function Fixed24 ashr(Fixed24 val, UInt#(5) shift_amt); // Arithmetic shift right
    return val >> shift_amt;  // Int#(24) >> does arithmetic shift
endfunction

function Fixed24 condNegate(Fixed24 val, Bool negate); // Conditional negate
    return negate ? (~val + 1) : val;
endfunction

interface CORDICIfc;
    method Action start(Fixed24 x_init, Fixed24 y_init, Fixed24 z_init, 
                       CORDICMode mode);
    method ActionValue#(CORDICState) getResult();
    method Bool busy();
endinterface

module mkCORDIC(CORDICIfc);
    
    Reg#(CORDICState) state <- mkReg(?);
    Reg#(Bool) busy_reg <- mkReg(False);
    
    Vector#(20, Fixed24) rot_angles = rotationAngles();
    Vector#(20, Fixed24) hyp_angles = hyperbolicAngles();

    function CORDICState cordic_iteration(CORDICState s, UInt#(5) iter);
        Fixed24 angle_lut;
        Fixed24 x_new, y_new, z_new;
        Bool do_subtract;

        if (s.mode == MODE_HYPERBOLIC)
            angle_lut = hyp_angles[iter];
        else
            angle_lut = rot_angles[iter];

        Fixed24 y_shifted = ashr(s.y, iter);
        Fixed24 x_shifted = ashr(s.x, iter);

        Bool rotate_cw;  
        
        if (s.mode == MODE_VECTORING)
            rotate_cw = (s.y > 0);  // Strictly positive
        else
            rotate_cw = (s.z < 0);
        
        if (rotate_cw) begin
            x_new = s.x + y_shifted;
            y_new = s.y - x_shifted;
            z_new = s.z + angle_lut;
        end else begin
            x_new = s.x - y_shifted;
            y_new = s.y + x_shifted;
            z_new = s.z - angle_lut;
        end
        
        IterCount next_iter = iter + 1;
        Bool done = (iter == 19);  // 20 iterations (0-19) for Q12.12
        return CORDICState {
            x: x_new,
            y: y_new,
            z: z_new,
            iter: next_iter,
            mode: s.mode,
            valid: done
        };
    endfunction
    
    rule do_iteration (busy_reg && !state.valid);
        let new_state = cordic_iteration(state, state.iter);
        state <= new_state;
        if (new_state.valid)
            busy_reg <= False;
    endrule
    
    method Action start(Fixed24 x_init, Fixed24 y_init, Fixed24 z_init, 
                       CORDICMode mode);
        busy_reg <= True;
        state <= CORDICState {
            x: x_init,
            y: y_init,
            z: z_init,
            iter: 0,
            mode: mode,
            valid: False
        };
    endmethod
    
    method ActionValue#(CORDICState) getResult() if (state.valid);
        return state;
    endmethod
    
    method Bool busy();
        return busy_reg;
    endmethod
    
endmodule

interface CORDICHighLevelIfc;
    method Action sin_cos(Fixed24 angle);
    method Action atan2(Fixed24 y, Fixed24 x);
    method Action sqrt_magnitude(Fixed24 x, Fixed24 y);
    
    method ActionValue#(Tuple2#(Fixed24, Fixed24)) get_sin_cos();
    method ActionValue#(Fixed24) get_atan2();
    method ActionValue#(Fixed24) get_sqrt();
    
    method Bool busy();
endinterface

module mkCORDICHighLevel(CORDICHighLevelIfc);
    
    CORDICIfc cordic <- mkCORDIC();
    Reg#(CORDICOp) current_op <- mkReg(?);
    Reg#(Bool) result_ready <- mkReg(False);
    Reg#(Bool) operation_pending <- mkReg(False);
    
    rule check_completion (operation_pending && !cordic.busy() && !result_ready);
        result_ready <= True;
        operation_pending <= False;
    endrule
    
    method Action sin_cos(Fixed24 angle);
        cordic.start(kFactorRotation, 0, angle, MODE_ROTATION);
        current_op <= OP_SINCOS;
        result_ready <= False;
        operation_pending <= True;
    endmethod
    
    method Action atan2(Fixed24 y, Fixed24 x);
        cordic.start(x, y, 0, MODE_VECTORING);
        current_op <= OP_ATAN2;
        result_ready <= False;
        operation_pending <= True;
    endmethod
    
    method Action sqrt_magnitude(Fixed24 x, Fixed24 y);
        cordic.start(x, y, 0, MODE_VECTORING);
        current_op <= OP_SQRT;
        result_ready <= False;
        operation_pending <= True;
    endmethod
    
    method ActionValue#(Tuple2#(Fixed24, Fixed24)) get_sin_cos() 
            if (result_ready && current_op == OP_SINCOS);
        let res <- cordic.getResult();
        result_ready <= False;
        return tuple2(res.y, res.x); 
    endmethod
    
    method ActionValue#(Fixed24) get_atan2() 
            if (result_ready && current_op == OP_ATAN2);
        let res <- cordic.getResult();
        result_ready <= False;
        return res.z; 
    endmethod
    
    method ActionValue#(Fixed24) get_sqrt() 
            if (result_ready && current_op == OP_SQRT);
        let res <- cordic.getResult();
        result_ready <= False;
        return res.x;
    endmethod
    
    method Bool busy();
        return cordic.busy();
    endmethod
    
endmodule

endpackage