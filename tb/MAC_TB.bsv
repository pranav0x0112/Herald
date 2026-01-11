package MAC_TB;

import MAC::*;
import StmtFSM::*;

// Helper function to convert integer to Q16.16
function Fixed32 toFixed(Integer val);
    return fromInteger(val * 65536);
endfunction

// Convert fractional value (numerator/denominator) to Q16.16
function Fixed32 toFixedFrac(Integer num, Integer denom);
    Integer scaled = (num * 65536) / denom;
    return fromInteger(scaled);
endfunction

// Display Q16.16 value in readable format (shows integer part)
function Action showResult(String label, Fixed32 val);
    action
        $display("[PASS] %s", label);
    endaction
endfunction

(* synthesize *)
module mkMAC_TB();
    MAC mac <- mkMAC();
    Reg#(UInt#(32)) test_count <- mkReg(0);
    Reg#(UInt#(32)) pass_count <- mkReg(0);
    
    Stmt test_seq = seq
        $display("=== MAC Unit Test Suite ===\n");
        
        // Basic multiply tests
        $display("--- Basic Multiplication Tests ---");
        
        // Test: 2 * 3 = 6
        action
            mac.multiply(toFixed(2), toFixed(3));
        endaction
        await(!mac.busy());
        action
            Fixed32 result <- mac.get_multiply();
            Fixed32 expected = toFixed(6);
            test_count <= test_count + 1;
            if (result == expected) begin
                pass_count <= pass_count + 1;
                $display("[PASS] 2 * 3 = 6");
            end else begin
                $display("[FAIL] 2 * 3: got %d, expected %d", result, expected);
            end
        endaction
        
        // Test: 10 * 10 = 100
        action
            mac.multiply(toFixed(10), toFixed(10));
        endaction
        await(!mac.busy());
        action
            Fixed32 result <- mac.get_multiply();
            Fixed32 expected = toFixed(100);
            test_count <= test_count + 1;
            if (result == expected) begin
                pass_count <= pass_count + 1;
                $display("[PASS] 10 * 10 = 100");
            end else begin
                $display("[FAIL] 10 * 10: got %d, expected %d", result, expected);
            end
        endaction
        
        // Test: -5 * 2 = -10
        action
            mac.multiply(toFixed(-5), toFixed(2));
        endaction
        await(!mac.busy());
        action
            Fixed32 result <- mac.get_multiply();
            Fixed32 expected = toFixed(-10);
            test_count <= test_count + 1;
            if (result == expected) begin
                pass_count <= pass_count + 1;
                $display("[PASS] -5 * 2 = -10");
            end else begin
                $display("[FAIL] -5 * 2: got %d, expected %d", result, expected);
            end
        endaction
        
        // Test: 0 * 100 = 0
        action
            mac.multiply(toFixed(0), toFixed(100));
        endaction
        await(!mac.busy());
        action
            Fixed32 result <- mac.get_multiply();
            Fixed32 expected = toFixed(0);
            test_count <= test_count + 1;
            if (result == expected) begin
                pass_count <= pass_count + 1;
                $display("[PASS] 0 * 100 = 0");
            end else begin
                $display("[FAIL] 0 * 100: got %d, expected %d", result, expected);
            end
        endaction
        
        // MAC tests
        $display("\n--- MAC (Multiply-Accumulate) Tests ---");
        
        // Clear accumulator
        action
            mac.clear_accumulator();
        endaction
        await(!mac.busy());
        
        // Test 1: acc = 0 + (2 * 3) = 6
        action
            mac.mac(toFixed(2), toFixed(3));
        endaction
        await(!mac.busy());
        action
            Fixed32 r1 <- mac.get_mac();
            Fixed32 exp1 = toFixed(6);
            if (r1 == exp1) begin
                $display("[PASS] MAC: 0 + (2*3) = 6 (raw: %d)", r1);
                pass_count <= pass_count + 1;
            end else begin
                $display("[FAIL] MAC test 1: got %d, expected 6", r1);
            end
            test_count <= test_count + 1;
        endaction
        
        // Test 2: acc = 6 + (4 * 5) = 26
        action
            mac.mac(toFixed(4), toFixed(5));
        endaction
        await(!mac.busy());
        action
            Fixed32 r2 <- mac.get_mac();
            Fixed32 exp2 = toFixed(26);
            if (r2 == exp2) begin
                $display("[PASS] MAC: 6 + (4*5) = 26 (raw: %d)", r2);
                pass_count <= pass_count + 1;
            end else begin
                $display("[FAIL] MAC test 2: got %d, expected 26", r2);
            end
            test_count <= test_count + 1;
        endaction
        
        // Clear and test again
        action
            mac.clear_accumulator();
        endaction
        await(!mac.busy());
        action
            mac.mac(toFixed(5), toFixed(5));
        endaction
        await(!mac.busy());
        action
            Fixed32 r <- mac.get_mac();
            test_count <= test_count + 1;
            Fixed32 expected = toFixed(25);
            if (r == expected) begin
                $display("[PASS] MAC: Clear then 5*5 = 25 (raw: %d)", r);
                pass_count <= pass_count + 1;
            end else begin
                $display("[FAIL] Clear then MAC: got %d (expected %d)", r, expected);
            end
        endaction
        
        // Final results
        $display("\n=== Test Summary ===");
        $display("Tests run: %0d", test_count);
        $display("Tests passed: %0d", pass_count);
        $display("Tests failed: %0d", test_count - pass_count);
        
        if (pass_count == test_count)
            $display("\n*** ALL TESTS PASSED ***\n");
        else
            $display("\n*** SOME TESTS FAILED ***\n");
        
        $finish(0);
    endseq;
    
    mkAutoFSM(test_seq);
endmodule

endpackage
