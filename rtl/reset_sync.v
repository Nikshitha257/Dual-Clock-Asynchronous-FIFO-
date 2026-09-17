`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 26.06.2026 14:25:59
// Design Name: 
// Module Name: reset_sync
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
// Module: reset_sync
// Description: Synchronizes the de-assertion (release) of an asynchronous
//              reset into a given clock domain. Assertion remains immediate
//              (reset takes effect right away), but release is passed through
//              a 2-flop synchronizer so each domain comes out of reset cleanly
//              aligned to its own local clock. This prevents recovery/removal
//              timing violations and avoids cross-domain reset skew, which can
//              desynchronize the write/read pointers right after reset.
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// Module: reset_sync
// Description: Synchronizes the de-assertion (release) of an asynchronous
//              reset into a given clock domain. Assertion remains immediate
//              (reset takes effect right away), but release is passed through
//              a 2-flop synchronizer so each domain comes out of reset cleanly
//              aligned to its own local clock. This prevents recovery/removal
//              timing violations and avoids cross-domain reset skew, which can
//              desynchronize wptr/rptr right after reset.
// -----------------------------------------------------------------------------
module reset_sync (
    input  clk,         // Local domain clock (wclk or rclk)
    input  async_rst_n, // Raw, possibly asynchronous/glitchy reset
    output reg sync_rst_n // Clean reset, release synchronized to clk
);
    (* ASYNC_REG = "TRUE" *) reg rst_ff1;

    always @(posedge clk or negedge async_rst_n) begin
        if (!async_rst_n) begin
            // Assertion: immediate, asynchronous - both stages go low at once
            rst_ff1    <= 1'b0;
            sync_rst_n <= 1'b0;
        end else begin
            // De-assertion: released through 2-flop synchronizer chain
            rst_ff1    <= 1'b1;
            sync_rst_n <= rst_ff1;
        end
    end
endmodule