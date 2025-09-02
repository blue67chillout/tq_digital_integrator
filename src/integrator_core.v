// integrator_core.v
`timescale 1ns/1ps
module integrator_core #(
    parameter IN_W = 8,        // input sample width (signed)
    parameter ACC_W = 16        // accumulator width (signed)
) (
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  enable,      // global enable
    input  wire                  sample_strobe,// 1 cycle pulse to accept input
    input  wire signed [IN_W-1:0] sample_in,
    // config
    input  wire                  leaky_mode,  // 0: pure accum, 1: leaky
    input  wire [7:0]            decay_shift, // k -> multiplier (1 - 1/2^k) implemented as y <- y - (y>>k)
    input  wire                  sat_enable,  // saturation ON
    input  wire signed [ACC_W-1:0] sat_pos,   // positive saturation
    input  wire signed [ACC_W-1:0] sat_neg,   // negative saturation
    // status / outputs
    output reg signed [ACC_W-1:0] acc_out,
    output reg                   overflow_flag
);

    // internal next value
    reg signed [ACC_W-1:0] acc_next;
    wire signed [ACC_W-1:0] sample_ext;
    assign sample_ext = {{(ACC_W-IN_W){sample_in[IN_W-1]}}, sample_in};

    // leaky calc: y' = y - (y >> k) + x  (approx y*(1-1/2^k) + x)
    wire signed [ACC_W-1:0] y_decay;
    assign y_decay = acc_out - (acc_out >>> decay_shift);

    // always @(*) begin
    //     acc_next = acc_out;
    //     if (enable && sample_strobe) begin
    //         if (leaky_mode)
    //             acc_next = y_decay + sample_ext;
    //         else
    //             acc_next = acc_out + sample_ext;
    //     end
    //     // saturation handled in clocked process for single cycle stable behavior
    // end

    reg sample_strobe_prev;
    wire sample_strobe_rise;
    assign sample_strobe_rise = sample_strobe & ~sample_strobe_prev;

    // leaky calc as before...

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            sample_strobe_prev <= 1'b0;
        else
            sample_strobe_prev <= sample_strobe;
    end

    always @(*) begin
        acc_next = acc_out;
        if (enable && sample_strobe_rise) begin
            if (leaky_mode)
                acc_next = y_decay + sample_ext;
            else
                acc_next = acc_out + sample_ext;
        end
        // saturation handled as before...
    end


    // clocked update with saturation and overflow detection
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_out <= {ACC_W{1'b0}};
            overflow_flag <= 1'b0;
        end else begin
            if (!enable) begin
                // no change
                overflow_flag <= overflow_flag;
            end else begin
                // detect overflow if sat disabled we allow wrap
                if (sat_enable) begin
                    if (acc_next > sat_pos) begin
                        acc_out <= sat_pos;
                        overflow_flag <= 1'b1;
                    end else if (acc_next < sat_neg) begin
                        acc_out <= sat_neg;
                        overflow_flag <= 1'b1;
                    end else begin
                        acc_out <= acc_next;
                        //overflow_flag <= 1'b0;
                    end
                end else begin
                    acc_out <= acc_next; // wrap-around natural
                    overflow_flag <= ( (acc_next[ACC_W-1] != acc_out[ACC_W-1]) ? 1'b1 : 1'b0); // rough sign change check
                end
            end
        end
    end

    // always @(posedge clk) begin
    // $display("sample_in = %0d, sample_ext = %0d", sample_in, sample_ext);
    // end
    // DEBUG: Print the overflow flag state on every clock cycle
    // always @(posedge clk) begin
    //     if (enable) begin
    //         $display("Time=%t, enable=%b, sat_enable=%b, sample_strobe_rise=%b, acc_next=%d, acc_out=%d, overflow_flag=%b",
    //                  $time, enable, sat_enable, sample_strobe_rise, acc_next, acc_out, overflow_flag);
    //     end
    // end
endmodule


