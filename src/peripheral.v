/*
 * Copyright (c) 2025 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// Change the name of this module to something that reflects its functionality and includes your name for uniqueness
// For example tqvp_yourname_spi for an SPI peripheral.
// Then edit tt_wrapper.v line 38 and change tqvp_example to your chosen module name.
`default_nettype none

module tqvp_integrator (
    input         clk,          // Clock - normally 64MHz
    input         rst_n,        // Active-low reset

    input  [7:0]  ui_in,        // Input PMOD (could be used as input sample source)
    output [7:0]  uo_out,       // Output PMOD (low 8 bits of accumulator for demo)

    input  [3:0]  address,      // Address within this peripheral's address space
    input         data_write,   // Write strobe
    input  [7:0]  data_in,      // Data written
    output [7:0]  data_out      // Data read
);

    // -------------------------------------------------
    // Internal Registers (8-bit each for TinyQV template)
    // -------------------------------------------------
    reg [7:0] CTRL;       // addr 0x0
    reg [7:0] STATUS;     // addr 0x1 (read-only flags)
    reg [7:0] INPUT_REG;  // addr 0x2
    reg [7:0] ACC_LOW;    // addr 0x3 (read-only, accumulator LSB)
    reg [7:0] ACC_HIGH;   // addr 0x4 (read-only, accumulator MSB[15:8])
    reg [7:0] THRESH;     // addr 0x5 (simple threshold for interrupt/flag)
    reg [7:0] DECAY_SHIFT;// addr 0x6

    // -------------------------------------------------
    // Integrator core instance (16-bit in, 16-bit accum)
    // -------------------------------------------------
    wire signed [15:0] acc_out;
    wire overflow_flag;

        // UI_IN usage:
    // bit7 = external strobe, bit6 = external enable, bits[5:0] = external data
    wire ext_enable = ui_in[6];
    wire ext_strobe = ui_in[7];
    wire signed [7:0] ext_sample = {2'b00, ui_in[5:0]}; // pack into 8-bit

    // Select source of input (CTRL[4] = 1 => external mode)
    wire use_ext = CTRL[4];
    wire sample_strobe = (use_ext ? ext_strobe : CTRL[1]);
    wire enable_core   = (use_ext ? ext_enable : CTRL[0]);
    wire signed [7:0] sample_in  = (use_ext ? ext_sample : INPUT_REG);

    // Connect to integrator core
    integrator_core #(
        .IN_W(8), .ACC_W(16)
    ) core (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable_core),
        .sample_strobe(sample_strobe),
        .sample_in(sample_in),
        .leaky_mode(CTRL[2]),
        .decay_shift(DECAY_SHIFT),
        .sat_enable(CTRL[3]),
        .sat_pos(16'sh7FFF),
        .sat_neg(-16'sh8000),
        .acc_out(acc_out),
        .overflow_flag(overflow_flag)
    );


    // -------------------------------------------------
    // Register write logic
    // -------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            CTRL        <= 8'h0;
            INPUT_REG   <= 8'h0;
            THRESH      <= 8'h0;
            DECAY_SHIFT <= 8'd4; // default decay shift
        end else if (data_write) begin
            case (address)
                4'h0: CTRL        <= data_in;
                4'h2: INPUT_REG   <= data_in;
                4'h5: THRESH      <= data_in;
                4'h6: DECAY_SHIFT <= data_in;
                default: ;
            endcase
        end
    end

    // -------------------------------------------------
    // Status register update
    // -------------------------------------------------
    always @(*) begin
        STATUS = 8'h0;
        STATUS[0] = overflow_flag;
        STATUS[1] = (acc_out[7:0] > THRESH); // simple threshold flag
    end

    // -------------------------------------------------
    // Memory-mapped readback
    // -------------------------------------------------
    assign data_out = (address == 4'h0) ? CTRL :
                      (address == 4'h1) ? STATUS :
                      (address == 4'h2) ? INPUT_REG :
                      (address == 4'h3) ? acc_out[7:0] :
                      (address == 4'h4) ? acc_out[15:8] :
                      (address == 4'h5) ? THRESH :
                      (address == 4'h6) ? DECAY_SHIFT :
                      8'h0;

    // -------------------------------------------------
    // Output pins (demo: low 8 bits of accumulator)
    // -------------------------------------------------
    assign uo_out = acc_out[7:0];

endmodule
