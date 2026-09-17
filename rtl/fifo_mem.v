// -----------------------------------------------------------------------------
// Module: fifo_mem
// Description: The actual dual-port memory payload buffer. Isolated from CDC.
// -----------------------------------------------------------------------------
module fifo_mem #(
    parameter DSIZE = 8, // Data width
    parameter ASIZE = 4  // Address width (Depth = 2^ASIZE)
) (
    output reg [DSIZE-1:0] rdata, // Asynchronous read data output
    input  [DSIZE-1:0] wdata, // Write data input
    input  [ASIZE-1:0] waddr, // Binary write address (N-1 bits, no extra MSB)
    input  [ASIZE-1:0] raddr, // Binary read address (N-1 bits, no extra MSB)
    input              rinc,
    input              rclk,
    input              winc,  // Write increment enable
    input              wfull, // Write full flag (prevents internal overwrite)
    input              wclk   // Write clock
);
 
    // Calculate actual memory depth (e.g., ASIZE=4 means DEPTH=16)
    localparam DEPTH = 1 << ASIZE;
    
    // The memory array. Synthesis tools will infer this as Distributed RAM or BRAM
    // depending on the DEPTH and available fabric resources.
    reg [DSIZE-1:0] mem [0:DEPTH-1];

    // Read port: Continuous assignment infers asynchronous read (Distributed RAM)
    //assign rdata = mem[raddr];
    always @(posedge rclk) begin 
        if (rinc) begin
           rdata <= mem[raddr];
        end
     end

    // Write port: Synchronous to the write clock
    always @(posedge wclk) begin
        // Only allow memory writes if a write is requested AND the FIFO is not full
        if (winc && !wfull) begin
            mem[waddr] <= wdata;
        end
    end
endmodule