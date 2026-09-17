`timescale 1ns/1ps

module async_fifo_tb;

    // ---------------------------------------------------------
    // 1. Parameters & Signal Declarations
    // ---------------------------------------------------------
    parameter DSIZE = 8;
    parameter ASIZE = 4; // Depth = 2^4 = 16 words
    
    reg [DSIZE-1:0] wdata;
    reg              winc, wclk, wrst_n;
    reg              rinc, rclk, rrst_n;
    wire [DSIZE-1:0] rdata;
    wire             wfull;
    wire             rempty;

    // ---------------------------------------------------------
    // 2. Device Under Test (DUT) Instantiation
    // ---------------------------------------------------------
    async_fifo #(.DSIZE(DSIZE), .ASIZE(ASIZE)) DUT (
        .wdata(wdata), .winc(winc), .wclk(wclk), .wrst_n(wrst_n),
        .rinc(rinc), .rclk(rclk), .rrst_n(rrst_n),
        .rdata(rdata), .wfull(wfull), .rempty(rempty)
    );

    // ---------------------------------------------------------
    // 3. Asynchronous Clock Generators
    // ---------------------------------------------------------
    // [SWAPPED CLOCKS] To test "Read Fast, Write Slow" Coverage
    // Write Domain: Slow Clock (40 MHz -> 25ns period)
    initial wclk = 0;
    always #12.5 wclk = ~wclk;

    // Read Domain: Fast Clock (100 MHz -> 10ns period)
    initial rclk = 0;
    always #5.0 rclk = ~rclk;

    // ---------------------------------------------------------
    // 4. Automated Golden Scoreboard (The Emulator Queue)
    // ---------------------------------------------------------
    logic [DSIZE-1:0] golden_queue [$]; 
    logic [DSIZE-1:0] match_data;
    int match_count = 0; 
    int errors      = 0;

    // Monitor Writes: Capture data on the write clock edge
    always @(posedge wclk) begin
        if (winc && !wfull) begin
            golden_queue.push_back(wdata);
        end
    end

  // Monitor Reads: Synchronous RAM (1-Cycle Latency) - The Negedge Trick
    always @(posedge rclk) begin
        if (rinc && !rempty) begin
            fork
                begin
                    // Wait for the next falling edge to safely sample the pipelined output!
                    // This gives the RAM time to output the data, and avoids delta-cycle races.
                    @(negedge rclk); 
                    
                    if (golden_queue.size() == 0) begin
                        $error("[ERROR] %t | Queue underflow! Read occurred but queue is empty.", $time);
                        errors++;
                    end else begin
                        match_data = golden_queue.pop_front();
                        if (rdata !== match_data) begin
                            $error("[ERROR] %t | Data Mismatch! Expected: 0x%h, Got: 0x%h", $time, match_data, rdata);
                            errors++;
                        end else begin
                            match_count++;
                        end
                    end
                end
            join_none
        end
    end
    // ---------------------------------------------------------
    // 5. Test Stimulus Sequencing (Procedural Scenarios)
    // ---------------------------------------------------------
    initial begin
        // Initialize everything to a clean state
        winc <= 0; rinc <= 0; wdata <= 0;
        wrst_n <= 0; rrst_n <= 0;

        // Apply Asynchronous Resets
        #40;
        @(posedge wclk); wrst_n <= 1;
        @(posedge rclk); rrst_n <= 1;

        // ---------------------------------------------------------
        // FIX: Give reset_sync's 2-flop chain time to actually release
        // wrst_n_sync / rrst_n_sync inside the DUT before traffic starts.
        // 2 cycles is the minimum; using 3 for safety margin.
        // ---------------------------------------------------------
        repeat (3) @(posedge wclk);
        repeat (3) @(posedge rclk);

        $display("[TB START] Resets lifted. FIFO initialized to Empty.");
        #20;

        // --- Scenario 1: Burst Write Until Full ---
        $display("[SCENARIO 1] Blasting data to fill the FIFO...");
        while (!wfull) begin
            @(posedge wclk);
            if (!wfull) begin
                winc <= 1;
                wdata <= $urandom_range(8'h10, 8'hEF);
            end
        end
        @(posedge wclk); winc <= 0; 
        $display("[SCENARIO 1] Success: Write Full Flag successfully asserted.");
        #100;

        // --- Defensive Check 1: Try writing to a Full FIFO ---
        $display("[DEFENSIVE CHECK 1] Attempting illegal write while full...");
        @(posedge wclk);
        winc <= 1; wdata <= 8'hFF; 
        @(posedge wclk);
        winc <= 0;
        #50;

        // --- Scenario 2: Burst Read Until Empty ---
        $display("[SCENARIO 2] Draining data until FIFO is empty...");
        while (!rempty) begin
            @(posedge rclk);
            if (!rempty) begin
                rinc <= 1;
            end
        end
        @(posedge rclk); rinc <= 0; 
        $display("[SCENARIO 2] Success: Read Empty Flag successfully asserted.");
        #100;

        // --- Defensive Check 2: Try reading an Empty FIFO ---
        $display("[DEFENSIVE CHECK 2] Attempting illegal read while empty...");
        @(posedge rclk);
        rinc <= 1; // ILLEGAL READ (Should be ignored by DUT)
        @(posedge rclk);
        rinc <= 0;
        #50;

        // --- Scenario 3: Simultaneous Random Read/Write Traffic ---
        $display("[SCENARIO 3] Initiating concurrent, random R/W cross-traffic...");
        fork
            // Thread A: Random Writes
            repeat (150) begin
                @(posedge wclk);
                winc  <= $urandom_range(0, 1);
                wdata <= $urandom_range(8'h00, 8'hFF);
            end
            // Thread B: Random Reads
            repeat (150) begin
                @(posedge rclk);
                rinc  <= $urandom_range(0, 1);
            end
        join

        // --- Scenario 4: Mid-Flight Reset ---
        $display("[SCENARIO 4] Triggering hardware reset during active traffic...");
        winc <= 1; rinc <= 0; wdata <= 8'hAA;
        @(posedge wclk);
        @(posedge wclk);
        
        // Assert Reset aggressively while clock is running!
        wrst_n <= 0; rrst_n <= 0; 
        
        // IMPORTANT: We must also clear our testbench Golden Queue to match hardware
        golden_queue.delete(); 
        
        #30;
        wrst_n <= 1; rrst_n <= 1;
        winc <= 0; rinc <= 0;
        $display("[SCENARIO 4] Reset complete. FIFO should be safely empty.");

        // Quiet down the lines
        winc <= 0; rinc <= 0;
        
        // Wait for final reads to clear the 1-cycle pipeline before finishing
        #200; 

        // ---------------------------------------------------------
        // 6. Verification Scorecard Summary
        // ---------------------------------------------------------
        $display("\n==================================================");
        $display("             TESTBENCH EXECUTION REPORT           ");
        $display("==================================================");
        $display(" Total Checked Operations: %d", match_count + errors);
        $display(" Total Successful Matches: %d", match_count);
        $display(" Total Scoreboard Errors:  %d", errors);
        $display("--------------------------------------------------");
        if (errors == 0 && match_count > 0) begin
            $display(" STATUS: PASSED! FIFO operates flawlessly across domains.");
        end else begin
            $display(" STATUS: FAILED! Check waveforms for data corruption.");
        end
        $display("==================================================\n");
        $finish;
    end

endmodule