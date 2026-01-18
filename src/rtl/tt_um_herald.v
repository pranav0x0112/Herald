`default_nettype none

module tt_um_herald (
    input  wire [7:0] ui_in,      // Data input bus
    output reg  [7:0] uo_out,     // Data output bus (bit 7 = BUSY)
    input  wire [7:0] uio_in,     // Control: [1]=RD, [0]=WR
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

  // Bidirectional pins unused
  assign uio_oe = 8'h00;
  assign uio_out = 8'h00;

  // Control signals
  wire wr_strobe = uio_in[0];
  wire rd_strobe = uio_in[1];
  
  // FSM states
  localparam IDLE          = 3'd0;
  localparam CMD_WRITE     = 3'd1;
  localparam DATA_WRITE_A  = 3'd2;
  localparam DATA_WRITE_B  = 3'd3;
  localparam EXECUTE       = 3'd4;
  localparam RESULT_READY  = 3'd5;
  
  // Command codes
  localparam CMD_CORDIC_SINCOS = 8'h10;
  localparam CMD_CORDIC_ATAN2  = 8'h11;
  localparam CMD_CORDIC_SQRT   = 8'h12;
  localparam CMD_MAC_MULTIPLY  = 8'h20;
  localparam CMD_MAC_MAC       = 8'h21;
  localparam CMD_MAC_CLEAR     = 8'h22;
  
  // Registers
  reg [2:0] state, next_state;
  reg [7:0] cmd_reg;
  reg [23:0] operand_a, operand_b;  // 24-bit operands (Q12.12)
  reg [47:0] result_reg;             // 48-bit for sin/cos results (2x 24-bit)
  reg [2:0] byte_counter;            // 3 bytes per 24-bit operand
  reg wr_prev, rd_prev;
  reg [1:0] exec_phase;  // 0=start, 1=wait_busy, 2=get_result
  
  // CORDIC wires - 24-bit operands
  wire [47:0] cordic_sin_cos;  // 2x 24-bit packed
  wire [23:0] cordic_atan2_result, cordic_sqrt_result;
  wire cordic_rdy_sin_cos, cordic_rdy_atan2, cordic_rdy_sqrt;
  wire cordic_rdy_get_sin_cos, cordic_rdy_get_atan2, cordic_rdy_get_sqrt;
  wire cordic_busy, cordic_rdy_busy;
  
  reg cordic_en_sin_cos, cordic_en_atan2, cordic_en_sqrt;
  reg cordic_en_get_sin_cos, cordic_en_get_atan2, cordic_en_get_sqrt;
  
  // CORDIC instance (HighLevel interface)
  mkCORDICHighLevel cordic_inst (
    .CLK(clk),
    .RST_N(rst_n),
    .sin_cos_angle(operand_a),
    .EN_sin_cos(cordic_en_sin_cos),
    .RDY_sin_cos(cordic_rdy_sin_cos),
    .atan2_y(operand_a),
    .atan2_x(operand_b),
    .EN_atan2(cordic_en_atan2),
    .RDY_atan2(cordic_rdy_atan2),
    .sqrt_magnitude_x(operand_a),
    .sqrt_magnitude_y(operand_b),
    .EN_sqrt_magnitude(cordic_en_sqrt),
    .RDY_sqrt_magnitude(cordic_rdy_sqrt),
    .EN_get_sin_cos(cordic_en_get_sin_cos),
    .get_sin_cos(cordic_sin_cos),
    .RDY_get_sin_cos(cordic_rdy_get_sin_cos),
    .EN_get_atan2(cordic_en_get_atan2),
    .get_atan2(cordic_atan2_result),
    .RDY_get_atan2(cordic_rdy_get_atan2),
    .EN_get_sqrt(cordic_en_get_sqrt),
    .get_sqrt(cordic_sqrt_result),
    .RDY_get_sqrt(cordic_rdy_get_sqrt),
    .busy(cordic_busy),
    .RDY_busy(cordic_rdy_busy)
  );
  
  // MAC wires - 24-bit operands
  wire [23:0] mac_multiply_result, mac_mac_result;
  wire mac_rdy_multiply, mac_rdy_get_multiply;
  wire mac_rdy_mac, mac_rdy_get_mac;
  wire mac_rdy_clear, mac_busy, mac_rdy_busy;
  
  reg mac_en_multiply, mac_en_get_multiply;
  reg mac_en_mac, mac_en_get_mac;
  reg mac_en_clear;
  
  // MAC instance
  mkMAC mac_inst (
    .CLK(clk),
    .RST_N(rst_n),
    .multiply_a(operand_a),
    .multiply_b(operand_b),
    .EN_multiply(mac_en_multiply),
    .RDY_multiply(mac_rdy_multiply),
    .EN_get_multiply(mac_en_get_multiply),
    .get_multiply(mac_multiply_result),
    .RDY_get_multiply(mac_rdy_get_multiply),
    .mac_a(operand_a),
    .mac_b(operand_b),
    .EN_mac(mac_en_mac),
    .RDY_mac(mac_rdy_mac),
    .EN_get_mac(mac_en_get_mac),
    .get_mac(mac_mac_result),
    .RDY_get_mac(mac_rdy_get_mac),
    .EN_clear_accumulator(mac_en_clear),
    .RDY_clear_accumulator(mac_rdy_clear),
    .busy(mac_busy),
    .RDY_busy(mac_rdy_busy)
  );
  
  // Edge detection for strobes
  wire wr_edge = wr_strobe && !wr_prev;
  wire rd_edge = rd_strobe && !rd_prev;
  
  // FSM and data handling
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      cmd_reg <= 8'h00;
      operand_a <= 24'h000000;
      operand_b <= 24'h000000;
      result_reg <= 48'h000000000000;
      byte_counter <= 3'd0;
      wr_prev <= 1'b0;
      rd_prev <= 1'b0;
      uo_out <= 8'h00;
      exec_phase <= 2'd0;
      
      // Clear all enable signals
      cordic_en_sin_cos <= 1'b0;
      cordic_en_atan2 <= 1'b0;
      cordic_en_sqrt <= 1'b0;
      cordic_en_get_sin_cos <= 1'b0;
      cordic_en_get_atan2 <= 1'b0;
      cordic_en_get_sqrt <= 1'b0;
      mac_en_multiply <= 1'b0;
      mac_en_get_multiply <= 1'b0;
      mac_en_mac <= 1'b0;
      mac_en_get_mac <= 1'b0;
      mac_en_clear <= 1'b0;
    end else begin
      wr_prev <= wr_strobe;
      rd_prev <= rd_strobe;
      
      // Default: clear enables
      cordic_en_sin_cos <= 1'b0;
      cordic_en_atan2 <= 1'b0;
      cordic_en_sqrt <= 1'b0;
      cordic_en_get_sin_cos <= 1'b0;
      cordic_en_get_atan2 <= 1'b0;
      cordic_en_get_sqrt <= 1'b0;
      mac_en_multiply <= 1'b0;
      mac_en_get_multiply <= 1'b0;
      mac_en_mac <= 1'b0;
      mac_en_get_mac <= 1'b0;
      mac_en_clear <= 1'b0;
      
      case (state)
        IDLE: begin
          uo_out <= 8'h00;  // BUSY=0
          byte_counter <= 3'd0;
          if (wr_edge) begin
            cmd_reg <= ui_in;
            state <= CMD_WRITE;
          end
        end
        
        CMD_WRITE: begin
          uo_out <= 8'h80;  // BUSY=1
          // MAC clear needs no operands - go straight to EXECUTE
          if (cmd_reg == CMD_MAC_CLEAR) begin
            state <= EXECUTE;
            exec_phase <= 2'd0;
          end else if (wr_edge) begin
            // Start collecting operand A (LSB first, 24-bit = 3 bytes)
            operand_a[7:0] <= ui_in;
            byte_counter <= 3'd1;
            state <= DATA_WRITE_A;
          end
        end
        
        DATA_WRITE_A: begin
          if (wr_edge) begin
            if (byte_counter == 3'd1) begin
              operand_a[15:8] <= ui_in;
            end else if (byte_counter == 3'd2) begin
              operand_a[23:16] <= ui_in;
            end
            
            if (byte_counter == 3'd2) begin
              // Check if command needs second operand
              if (cmd_reg == CMD_CORDIC_ATAN2 || cmd_reg == CMD_CORDIC_SQRT ||
                  cmd_reg == CMD_MAC_MULTIPLY || cmd_reg == CMD_MAC_MAC) begin
                byte_counter <= 3'd0;
                state <= DATA_WRITE_B;
              end else begin
                state <= EXECUTE;
                exec_phase <= 2'd0;
              end
            end else begin
              byte_counter <= byte_counter + 1;
            end
          end
        end
        
        DATA_WRITE_B: begin
          if (wr_edge) begin
            if (byte_counter == 3'd0) begin
              operand_b[7:0] <= ui_in;
            end else if (byte_counter == 3'd1) begin
              operand_b[15:8] <= ui_in;
            end else if (byte_counter == 3'd2) begin
              operand_b[23:16] <= ui_in;
            end
            
            if (byte_counter == 3'd2) begin
              state <= EXECUTE;
              exec_phase <= 2'd0;
            end else begin
              byte_counter <= byte_counter + 1;
            end
          end
        end
        
        EXECUTE: begin
          // Phase 0: Start operation
          // Phase 1: Wait for completion (!busy)
          // Phase 2: Get result
          case (cmd_reg)
            CMD_CORDIC_SINCOS: begin
              if (exec_phase == 2'd0) begin
                cordic_en_sin_cos <= 1'b1;
                exec_phase <= 2'd1;
              end else if (exec_phase == 2'd1) begin
                if (!cordic_busy) exec_phase <= 2'd2;
              end else if (exec_phase == 2'd2) begin
                cordic_en_get_sin_cos <= 1'b1;
                if (cordic_rdy_get_sin_cos) begin
                  result_reg <= cordic_sin_cos;  // 48-bit (2x 24-bit)
                  byte_counter <= 3'd0;
                  state <= RESULT_READY;
                end
              end
            end
            
            CMD_CORDIC_ATAN2: begin
              if (exec_phase == 2'd0) begin
                cordic_en_atan2 <= 1'b1;
                exec_phase <= 2'd1;
              end else if (exec_phase == 2'd1) begin
                if (!cordic_busy) exec_phase <= 2'd2;
              end else if (exec_phase == 2'd2) begin
                cordic_en_get_atan2 <= 1'b1;
                if (cordic_rdy_get_atan2) begin
                  result_reg[23:0] <= cordic_atan2_result;  // 24-bit result
                  byte_counter <= 3'd0;
                  state <= RESULT_READY;
                end
              end
            end
            
            CMD_CORDIC_SQRT: begin
              if (exec_phase == 2'd0) begin
                cordic_en_sqrt <= 1'b1;
                exec_phase <= 2'd1;
              end else if (exec_phase == 2'd1) begin
                if (!cordic_busy) exec_phase <= 2'd2;
              end else if (exec_phase == 2'd2) begin
                cordic_en_get_sqrt <= 1'b1;
                if (cordic_rdy_get_sqrt) begin
                  result_reg[23:0] <= cordic_sqrt_result;  // 24-bit result
                  byte_counter <= 3'd0;
                  state <= RESULT_READY;
                end
              end
            end
            
            CMD_MAC_MULTIPLY: begin
              if (exec_phase == 2'd0) begin
                mac_en_multiply <= 1'b1;
                exec_phase <= 2'd1;
              end else if (exec_phase == 2'd1) begin
                if (!mac_busy) exec_phase <= 2'd2;
              end else if (exec_phase == 2'd2) begin
                mac_en_get_multiply <= 1'b1;
                if (mac_rdy_get_multiply) begin
                  result_reg[23:0] <= mac_multiply_result;  // 24-bit result
                  byte_counter <= 3'd0;
                  state <= RESULT_READY;
                end
              end
            end
            
            CMD_MAC_MAC: begin
              if (exec_phase == 2'd0) begin
                mac_en_mac <= 1'b1;
                exec_phase <= 2'd1;
              end else if (exec_phase == 2'd1) begin
                if (!mac_busy) exec_phase <= 2'd2;
              end else if (exec_phase == 2'd2) begin
                mac_en_get_mac <= 1'b1;
                if (mac_rdy_get_mac) begin
                  result_reg[23:0] <= mac_mac_result;  // 24-bit result
                  byte_counter <= 3'd0;
                  state <= RESULT_READY;
                end
              end
            end
            
            CMD_MAC_CLEAR: begin
              if (exec_phase == 2'd0) begin
                mac_en_clear <= 1'b1;
                if (mac_rdy_clear) begin
                  state <= IDLE;  // Clear has no result, go straight to IDLE
                end
              end
            end
            
            default: begin
              state <= IDLE;
            end
          endcase
        end
        
        RESULT_READY: begin
          uo_out <= 8'h00;  // BUSY=0, result ready
          if (rd_edge) begin
            // Output result bytes on read strobe (LSB first)
            case (byte_counter)
              3'd0: uo_out <= result_reg[7:0];
              3'd1: uo_out <= result_reg[15:8];
              3'd2: uo_out <= result_reg[23:16];
              3'd3: uo_out <= result_reg[31:24];
              3'd4: uo_out <= result_reg[39:32];
              3'd5: uo_out <= result_reg[47:40];
              default: uo_out <= 8'h00;
            endcase
            
            // Determine max bytes based on command
            // SINCOS returns 48-bit (6 bytes), others return 24-bit (3 bytes)
            if ((cmd_reg == CMD_CORDIC_SINCOS && byte_counter == 3'd5) ||
                (cmd_reg != CMD_CORDIC_SINCOS && byte_counter == 3'd2)) begin
              state <= IDLE;
            end else begin
              byte_counter <= byte_counter + 1;
            end
          end
        end
        
        default: state <= IDLE;
      endcase
    end
  end

endmodule