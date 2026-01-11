// Herald MAC Unit
// 32-bit Multiply-Accumulate for Q16.16 fixed-point
// Optimized for area efficiency

package MAC;

typedef Int#(32) Fixed32;  // Q16.16 format
typedef Int#(64) Fixed64;  // Q32.32 intermediate

// MAC operations
typedef enum {
    OP_MULTIPLY,      // Simple multiply: result = a * b
    OP_MAC,           // Multiply-accumulate: accumulator += a * b
    OP_CLEAR_ACC      // Clear accumulator
} MACOp deriving (Bits, Eq, FShow);

interface MAC;
    // Multiply: a * b -> result (Q16.16 * Q16.16 -> Q16.16)
    method Action multiply(Fixed32 a, Fixed32 b);
    method ActionValue#(Fixed32) get_multiply();
    
    // MAC: accumulator += (a * b)
    method Action mac(Fixed32 a, Fixed32 b);
    method ActionValue#(Fixed32) get_mac();
    
    // Clear accumulator
    method Action clear_accumulator();
    
    // Status
    method Bool busy();
endinterface

(* synthesize *)
module mkMAC(MAC);
    Reg#(Fixed32) accumulator <- mkReg(0);
    Reg#(Fixed32) multiply_result <- mkReg(0);  // Separate register for multiply
    Reg#(Fixed32) mac_result <- mkReg(0);       // Separate register for MAC
    Reg#(Bool) busy_multiply <- mkReg(False);   // Separate busy for multiply
    Reg#(Bool) busy_mac <- mkReg(False);        // Separate busy for MAC
    
    method Action multiply(Fixed32 a, Fixed32 b) if (!busy_multiply && !busy_mac);
        Fixed64 product = signExtend(a) * signExtend(b);
        Fixed32 scaled_result = truncate(product >> 16);
        multiply_result <= scaled_result;
        busy_multiply <= True;
    endmethod
    
    method ActionValue#(Fixed32) get_multiply() if (busy_multiply);
        busy_multiply <= False;
        return multiply_result;
    endmethod
    
    method Action mac(Fixed32 a, Fixed32 b) if (!busy_multiply && !busy_mac);
        Fixed64 product = signExtend(a) * signExtend(b);
        Fixed32 scaled_result = truncate(product >> 16);
        Fixed32 new_acc = accumulator + scaled_result;
        accumulator <= new_acc;
        mac_result <= new_acc;
        busy_mac <= True;
    endmethod
    
    method ActionValue#(Fixed32) get_mac() if (busy_mac);
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
