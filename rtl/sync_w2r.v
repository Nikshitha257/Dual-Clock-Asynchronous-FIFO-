`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 24.06.2026 13:38:17
// Design Name:
// Module Name: sync_w2r
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////
// -----------------------------------------------------------------------------
// Module: sync_w2r
// Description: Synchronizes the write pointer into the read clock domain.
//              Uses a standard 2-flop synchronizer chain to mitigate metastability.
//              Both synchronizer stages are tagged ASYNC_REG to prevent synthesis
//              from retiming/optimizing across the chain.
// -----------------------------------------------------------------------------
module sync_w2r #(parameter ASIZE = 4) (
    output [ASIZE:0] rq2_wptr, // Synchronized write pointer (to read logic)
    input  [ASIZE:0] wptr,     // Gray-coded write pointer (from write logic)
    input            rclk,     // Read clock domain
    input            rrst_n    // Read domain active-low asynchronous reset
);
    // ASYNC_REG attribute informs the synthesis tool (Vivado) that these registers
    // are part of a synchronizer. It prevents logic optimization and ensures the
    // flip-flops are placed close together on the die to reduce routing delay.
    // Applied to BOTH stages - tagging only stage 1 leaves stage 2 unprotected.
    (* ASYNC_REG = "TRUE" *) reg [ASIZE:0] rq1_wptr;
    (* ASYNC_REG = "TRUE" *) reg [ASIZE:0] rq2_wptr_int;

    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rq1_wptr     <= 0;
            rq2_wptr_int <= 0;
        end else begin
            // Stage 1: Captures asynchronous input (may go metastable)
            rq1_wptr     <= wptr;
            // Stage 2: Captures stable data from Stage 1 after a full clock cycle
            rq2_wptr_int <= rq1_wptr;
        end
    end

    assign rq2_wptr = rq2_wptr_int;

endmodule