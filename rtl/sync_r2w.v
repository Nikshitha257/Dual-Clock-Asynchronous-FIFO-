// -----------------------------------------------------------------------------
// Module: sync_r2w
// Description: Synchronizes the read pointer into the write clock domain.
//              Uses a standard 2-flop synchronizer chain to mitigate metastability.
//              Both synchronizer stages are tagged ASYNC_REG to prevent synthesis
//              from retiming/optimizing across the chain.
// -----------------------------------------------------------------------------
module sync_r2w #(parameter ASIZE = 4) (
    output [ASIZE:0] wq2_rptr, // Synchronized read pointer (to write logic)
    input  [ASIZE:0] rptr,     // Gray-coded read pointer (from read logic)
    input            wclk,     // Write clock domain
    input            wrst_n    // Write domain active-low asynchronous reset
);
    // ASYNC_REG attribute for placement and timing analysis protection
    // Applied to BOTH synchronizer stages - a single missing tag leaves
    // the second flop free to be retimed/merged, breaking the synchronizer.
    (* ASYNC_REG = "TRUE" *) reg [ASIZE:0] wq1_rptr;
    (* ASYNC_REG = "TRUE" *) reg [ASIZE:0] wq2_rptr_int;

    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wq1_rptr     <= 0;
            wq2_rptr_int <= 0;
        end else begin
            // Stage 1: Captures asynchronous input (may go metastable)
            wq1_rptr     <= rptr;
            // Stage 2: Outputs clean, synchronized pointer
            wq2_rptr_int <= wq1_rptr;
        end
    end

    assign wq2_rptr = wq2_rptr_int;

endmodule