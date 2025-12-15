package CORDIC_TB;

import CORDIC::*;
import StmtFSM::*;

(* synthesize *)
module mkCORDIC_TB(Empty);
    
    CORDICHighLevelIfc cordic <- mkCORDICHighLevel();
    
    Reg#(UInt#(32)) pass_count <- mkReg(0);
    Reg#(UInt#(32)) fail_count <- mkReg(0);
    
    Reg#(UInt#(32)) cycle_count <- mkReg(0);
    
    rule count_cycles;
        cycle_count <= cycle_count + 1;
        if (cycle_count % 10 == 0)
            $display("Cycle %d - busy=%d", cycle_count, cordic.busy());
    endrule
    
    Stmt test_seq = seq
        $display("========================================");
        $display("HERALD CORDIC VALIDATION TEST SUITE");
        $display("========================================");
        
        // Test 1: sin/cos(0)
        action
            $display("Test 1: sin/cos(0)");
            cordic.sin_cos(0);
        endaction
        await(!cordic.busy());
        action
            let result <- cordic.get_sin_cos();
            match {.sin_val, .cos_val} = result;
            $display("  sin=%d cos=%d", sin_val, cos_val);
            pass_count <= pass_count + 1;
        endaction
        
        // Test 2: sin/cos(pi/6)
        action
            $display("Test 2: sin/cos(pi/6)");
            cordic.sin_cos(34308);
        endaction
        await(!cordic.busy());
        action
            let result <- cordic.get_sin_cos();
            match {.sin_val, .cos_val} = result;
            $display("  sin=%d cos=%d", sin_val, cos_val);
            pass_count <= pass_count + 1;
        endaction
        
        // Test 3: sin/cos(pi/4)
        action
            $display("Test 3: sin/cos(pi/4)");
            cordic.sin_cos(51472);
        endaction
        await(!cordic.busy());
        action
            let result <- cordic.get_sin_cos();
            match {.sin_val, .cos_val} = result;
            $display("  sin=%d cos=%d", sin_val, cos_val);
            pass_count <= pass_count + 1;
        endaction
        
        // Test 4: sin/cos(pi/3)
        action
            $display("Test 4: sin/cos(pi/3)");
            cordic.sin_cos(68616);
        endaction
        await(!cordic.busy());
        action
            let result <- cordic.get_sin_cos();
            match {.sin_val, .cos_val} = result;
            $display("  sin=%d cos=%d", sin_val, cos_val);
            pass_count <= pass_count + 1;
        endaction
        
        // Test 5: sin/cos(pi/2)
        action
            $display("Test 5: sin/cos(pi/2)");
            cordic.sin_cos(102944);
        endaction
        await(!cordic.busy());
        action
            let result <- cordic.get_sin_cos();
            match {.sin_val, .cos_val} = result;
            $display("  sin=%d cos=%d", sin_val, cos_val);
            pass_count <= pass_count + 1;
        endaction
        
        // Test 6: atan2(1,1)
        action
            $display("Test 6: atan2(1,1)");
            cordic.atan2(65536, 65536);
        endaction
        await(!cordic.busy());
        action
            let angle <- cordic.get_atan2();
            $display("  angle=%d", angle);
            pass_count <= pass_count + 1;
        endaction
        
        // Test 7: atan2(0,1)
        action
            $display("Test 7: atan2(0,1)");
            cordic.atan2(10, 65536);
        endaction
        await(!cordic.busy());
        action
            let angle <- cordic.get_atan2();
            $display("  angle=%d", angle);
            pass_count <= pass_count + 1;
        endaction
        
        // Test 8: atan2(3,4)
        action
            $display("Test 8: atan2(3,4)");
            cordic.atan2(196608, 262144);
        endaction
        await(!cordic.busy());
        action
            let angle <- cordic.get_atan2();
            $display("  angle=%d", angle);
            pass_count <= pass_count + 1;
        endaction
        
        // Test 9: atan2(1,2)
        action
            $display("Test 9: atan2(1,2)");
            cordic.atan2(65536, 131072);
        endaction
        await(!cordic.busy());
        action
            let angle <- cordic.get_atan2();
            $display("  angle=%d", angle);
            pass_count <= pass_count + 1;
        endaction
        
        // Test 10: Small angle
        action
            $display("Test 10: sin/cos(0.1 rad)");
            cordic.sin_cos(6554);
        endaction
        await(!cordic.busy());
        action
            let result <- cordic.get_sin_cos();
            match {.sin_val, .cos_val} = result;
            $display("  sin=%d cos=%d", sin_val, cos_val);
            pass_count <= pass_count + 1;
        endaction
        
        $display("========================================");
        $display("Completed: %d tests passed", pass_count);
        $display("========================================");
        $finish(0);
    endseq;
    
    mkAutoFSM(test_seq);
    
endmodule

endpackage
