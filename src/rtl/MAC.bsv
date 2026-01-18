// Herald MAC Unit
// 16-bit Multiply-Accumulate for Q8.8 fixed-point
// Optimized for area efficiency

package MAC;

typedef Int#(16) Fixed16;  // Q8.8 format
typedef Int#(32) Fixed32;  // Q16.16 intermediate

// MAC operations
typedef enum {
    OP_MULTIPLY,      // Simple multiply: result = a * b
    OP_MAC,           // Multiply-accumulate: accumulator += a * b
    OP_CLEAR_ACC      // Clear accumulator
} MACOp deriving (Bits, Eq, FShow);

interface MAC;
    // Multiply: a * b -> result (Q8.8 * Q8.8 -> Q8.8)
    method Action multiply(Fixed16 a, Fixed16 b);
    method ActionValue#(Fixed16) get_multiply();
    
    // MAC: accumulator += (a * b)
    method Action mac(Fixed16 a, Fixed16 b);
    method ActionValue#(Fixed16) get_mac();
    
    // Clear accumulator
    method Action clear_accumulator();
    
    // Status
    method Bool busy();
endinterface

(* synthesize *)
module mkMAC(MAC);
    Reg#(Fixed16) accumulator <- mkReg(0);
    Reg#(Fixed16) multiply_result <- mkReg(0);  // Separate register for multiply
    Reg#(Fixed16) mac_result <- mkReg(0);       // Separate register for MAC
    Reg#(Bool) busy_multiply <- mkReg(False);   // Separate busy for multiply
    Reg#(Bool) busy_mac <- mkReg(False);        // Separate busy for MAC
    
    method Action multiply(Fixed16 a, Fixed16 b) if (!busy_multiply && !busy_mac);
        Fixed32 product = signExtend(a) * signExtend(b);
        Fixed16 scaled_result = truncate(product >> 8);  // Q8.8 * Q8.8 -> shift by 8
        multiply_result <= scaled_result;
        busy_multiply <= True;
    endmethod
    
    method ActionValue#(Fixed16) get_multiply() if (busy_multiply);
        busy_multiply <= False;
        return multiply_result;
    endmethod
    
    method Action mac(Fixed16 a, Fixed16 b) if (!busy_multiply && !busy_mac);
        Fixed32 product = signExtend(a) * signExtend(b);
        Fixed16 scaled_result = truncate(product >> 8);  // Q8.8 * Q8.8 -> shift by 8
        Fixed16 new_acc = accumulator + scaled_result;
        accumulator <= new_acc;
        mac_result <= new_acc;
        busy_mac <= True;
    endmethod
    
    method ActionValue#(Fixed16) get_mac() if (busy_mac);
        busy_mac <= False;
        return mac_result;
    endmethod
    
    method Action clear_accumulator() if (!busy_multiply && !busy_mac);
        accumulator <= 0;
        mac_result <= 0;
    endmethod
    
    method Bool busy();
        return busy_multiply || busy_mac;
    endmethod
endmodule

endpackage
