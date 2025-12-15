// Herald CORDIC Engine
// 32-bit iterative CORDIC for trig, hyperbolic, and vector operations
// IHP SG13G2 130nm - Low Power Design

package CORDIC;

import Vector::*;
import FixedPoint::*;

typedef Int#(32) Fixed32;  // 32-bit fixed point (Q16.16 format)
typedef Int#(16) Fixed16;  // 16-bit fixed point (Q8.8 format)
typedef UInt#(5) IterCount; // Iteration counter (0-31)

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
    OP_MAGNITUDE, 
    OP_MULTIPLY   
} CORDICOp deriving (Bits, Eq, FShow);

typedef struct {
    Fixed32 x;   
    Fixed32 y;        
    Fixed32 z;      
    IterCount iter;   
    CORDICMode mode; 
    Bool valid;      
} CORDICState deriving (Bits, Eq, FShow);

// Pre-computed CORDIC rotation angles: atan(2^-i) in Q16.16 format
function Vector#(32, Fixed32) rotationAngles();
    Vector#(32, Fixed32) angles = newVector;
    angles[0]  = 51471;     // atan(2^0)  = 0.7853981634  rad (45°)
    angles[1]  = 30385;     // atan(2^-1) = 0.4636476090  rad
    angles[2]  = 16054;     // atan(2^-2) = 0.2449786631  rad
    angles[3]  = 8149;      // atan(2^-3) = 0.1243549945  rad
    angles[4]  = 4091;      // atan(2^-4) = 0.0624188100  rad
    angles[5]  = 2047;      // atan(2^-5) = 0.0312398334  rad
    angles[6]  = 1024;      // atan(2^-6) = 0.0156237286  rad
    angles[7]  = 512;       // atan(2^-7) = 0.0078123410  rad
    angles[8]  = 256;       // atan(2^-8) = 0.0039062301  rad
    angles[9]  = 128;       // atan(2^-9) = 0.0019531225  rad
    angles[10] = 64;        // atan(2^-10) = 0.0009765622 rad
    angles[11] = 32;        // atan(2^-11) = 0.0004882812 rad
    angles[12] = 16;        // atan(2^-12) = 0.0002441406 rad
    angles[13] = 8;         // atan(2^-13) = 0.0001220703 rad
    angles[14] = 4;         // atan(2^-14) = 0.0000610352 rad
    angles[15] = 2;         // atan(2^-15) = 0.0000305176 rad
    angles[16] = 1;         // atan(2^-16) = 0.0000152588 rad
    angles[17] = 1;         // atan(2^-17) ≈ 0.0000076294 rad
    angles[18] = 0;         // atan(2^-18) ≈ 0.0000038147 rad
    angles[19] = 0;         // Remaining angles too small for Q16.16
    angles[20] = 0; angles[21] = 0; angles[22] = 0; angles[23] = 0;
    angles[24] = 0; angles[25] = 0; angles[26] = 0; angles[27] = 0;
    angles[28] = 0; angles[29] = 0; angles[30] = 0; angles[31] = 0;
    return angles;
endfunction

function Vector#(32, Fixed32) hyperbolicAngles();
    Vector#(32, Fixed32) angles = newVector;
    angles[0] = 147391456; angles[1] = 69254785; angles[2] = 34408521;
    angles[3] = 17119964; angles[4] = 8567219; angles[5] = 4282395;
    angles[6] = 2796722; angles[7] = 1398361; angles[8] = 699051;
    angles[9] = 349611; angles[10] = 174763; angles[11] = 87381;
    angles[12] = 43691; angles[13] = 21845; angles[14] = 10923;
    angles[15] = 5461; angles[16] = 2731; angles[17] = 1365;
    angles[18] = 683; angles[19] = 341; angles[20] = 171;
    angles[21] = 85; angles[22] = 43; angles[23] = 21;
    angles[24] = 11; angles[25] = 5; angles[26] = 2;
    angles[27] = 1; angles[28] = 0; angles[29] = 0;
    angles[30] = 0; angles[31] = 0;
    return angles;
endfunction

// CORDIC gain compensation factors in Q16.16 format
// K = prod(sqrt(1 + 2^(-2i))) for circular rotations
// After 16 iterations: K ≈ 1.646760258 -> Q16.16 = 107949 (0x1A5E1)
Fixed32 kFactorRotation = 39797;      // 1/K = 0.6072529350 in Q16.16
Fixed32 kFactorHyperbolic = 368485439;

function Fixed32 ashr(Fixed32 val, UInt#(5) shift_amt); // Arithmetic shift right
    return val >> shift_amt;  // Int#(32) >> does arithmetic shift
endfunction

function Fixed32 condNegate(Fixed32 val, Bool negate); // Conditional negate
    return negate ? (~val + 1) : val;
endfunction

interface CORDICIfc;
    method Action start(Fixed32 x_init, Fixed32 y_init, Fixed32 z_init, 
                       CORDICMode mode);
    method ActionValue#(CORDICState) getResult();
    method Bool busy();
endinterface

module mkCORDIC(CORDICIfc);
    
    Reg#(CORDICState) state <- mkReg(?);
    Reg#(Bool) busy_reg <- mkReg(False);
    
    Vector#(32, Fixed32) rot_angles = rotationAngles();
    Vector#(32, Fixed32) hyp_angles = hyperbolicAngles();

    function CORDICState cordic_iteration(CORDICState s, UInt#(5) iter);
        Fixed32 angle_lut;
        Fixed32 x_new, y_new, z_new;
        Bool do_subtract;

        if (s.mode == MODE_HYPERBOLIC)
            angle_lut = hyp_angles[iter];
        else
            angle_lut = rot_angles[iter];

        Fixed32 y_shifted = ashr(s.y, iter);
        Fixed32 x_shifted = ashr(s.x, iter);

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
        Bool done = (iter == 31);
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
    
    method Action start(Fixed32 x_init, Fixed32 y_init, Fixed32 z_init, 
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
    method Action sin_cos(Fixed32 angle);
    method Action atan2(Fixed32 y, Fixed32 x);
    method Action sqrt_magnitude(Fixed32 x, Fixed32 y);
    method Action multiply(Fixed32 a, Fixed32 b);
    
    method ActionValue#(Tuple2#(Fixed32, Fixed32)) get_sin_cos();
    method ActionValue#(Fixed32) get_atan2();
    method ActionValue#(Fixed32) get_sqrt();
    method ActionValue#(Fixed32) get_multiply();
    
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
    
    method Action sin_cos(Fixed32 angle);
        cordic.start(kFactorRotation, 0, angle, MODE_ROTATION);
        current_op <= OP_SINCOS;
        result_ready <= False;
        operation_pending <= True;
    endmethod
    
    method Action atan2(Fixed32 y, Fixed32 x);
        cordic.start(x, y, 0, MODE_VECTORING);
        current_op <= OP_ATAN2;
        result_ready <= False;
        operation_pending <= True;
    endmethod
    
    method Action sqrt_magnitude(Fixed32 x, Fixed32 y);
        cordic.start(x, y, 0, MODE_VECTORING);
        current_op <= OP_SQRT;
        result_ready <= False;
        operation_pending <= True;
    endmethod
    
    method Action multiply(Fixed32 a, Fixed32 b);
        cordic.start(a, b, 0, MODE_ROTATION);
        current_op <= OP_MULTIPLY;
        result_ready <= False;
        operation_pending <= True;
    endmethod
    
    method ActionValue#(Tuple2#(Fixed32, Fixed32)) get_sin_cos() 
            if (result_ready && current_op == OP_SINCOS);
        let res <- cordic.getResult();
        result_ready <= False;
        return tuple2(res.y, res.x); 
    endmethod
    
    method ActionValue#(Fixed32) get_atan2() 
            if (result_ready && current_op == OP_ATAN2);
        let res <- cordic.getResult();
        result_ready <= False;
        return res.z; 
    endmethod
    
    method ActionValue#(Fixed32) get_sqrt() 
            if (result_ready && current_op == OP_SQRT);
        let res <- cordic.getResult();
        result_ready <= False;
        return res.x;
    endmethod
    
    method ActionValue#(Fixed32) get_multiply() 
            if (result_ready && current_op == OP_MULTIPLY);
        let res <- cordic.getResult();
        result_ready <= False;
        return res.y; 
    endmethod
    
    method Bool busy();
        return cordic.busy();
    endmethod
    
endmodule

endpackage