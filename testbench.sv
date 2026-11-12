// Self-checking testbench for sync_fifo
`timescale 1ns/1ps
module tb_sync_fifo;

    parameter DW = 8;
    parameter D  = 16;
    parameter AW = 4;

    reg           clk, rst_n, wr_en, rd_en;
    reg  [DW-1:0] din;
    wire [DW-1:0] dout;
    wire          full, empty, overflow, underflow;
    wire [AW:0]   data_count;

    // DUT
    sync_fifo #(.DATA_WIDTH(DW), .DEPTH(D), .ADDR_WIDTH(AW)) dut (
        .clk(clk), .rst_n(rst_n), .wr_en(wr_en), .rd_en(rd_en),
        .din(din), .dout(dout), .full(full), .empty(empty),
        .overflow(overflow), .underflow(underflow),
        .data_count(data_count)
    );

    // 100 MHz clock
    initial clk = 0;
    always #5 clk = ~clk;

    // Scoreboard (reference model)
    reg [DW-1:0] model [0:1023];
    integer wr_cnt, rd_cnt;
    reg [DW-1:0] exp_data;
    reg chk_data, exp_ovf, exp_unf;
    integer errors, checks;

    // Sample the request at the clock edge (before DUT updates)
    always @(posedge clk) begin
        if (rst_n) begin
            chk_data = 0;
            exp_ovf  = wr_en && full;
            exp_unf  = rd_en && empty;
            if (rd_en && !empty) begin
                exp_data = model[rd_cnt % 1024];
                rd_cnt   = rd_cnt + 1;
                chk_data = 1;
            end
            if (wr_en && !full) begin
                model[wr_cnt % 1024] = din;
                wr_cnt = wr_cnt + 1;
            end
        end
    end

    // Compare DUT outputs with model on the falling edge
    always @(negedge clk) begin
        if (rst_n) begin
            checks = checks + 1;
            if (chk_data && dout !== exp_data) begin
                errors = errors + 1;
                $display("[%0t] ERROR: dout=%0h expected=%0h", $time, dout, exp_data);
            end
            if (data_count !== (wr_cnt - rd_cnt)) begin
                errors = errors + 1;
                $display("[%0t] ERROR: data_count=%0d expected=%0d", $time,
                         data_count, wr_cnt - rd_cnt);
            end
            if (full !== ((wr_cnt - rd_cnt) == D) ||
                empty !== ((wr_cnt - rd_cnt) == 0)) begin
                errors = errors + 1;
                $display("[%0t] ERROR: flag mismatch full=%b empty=%b", $time,
                         full, empty);
            end
            if (overflow !== exp_ovf || underflow !== exp_unf) begin
                errors = errors + 1;
                $display("[%0t] ERROR: overflow=%b underflow=%b", $time,
                         overflow, underflow);
            end
        end
    end

    // Stimulus tasks (drive on falling edge)
    task write_data(input [DW-1:0] d);
        begin
            @(negedge clk); wr_en = 1; rd_en = 0; din = d;
            @(negedge clk); wr_en = 0;
        end
    endtask

    task read_data;
        begin
            @(negedge clk); rd_en = 1; wr_en = 0;
            @(negedge clk); rd_en = 0;
        end
    endtask

    integer i, err_before;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_sync_fifo);

        rst_n = 0; wr_en = 0; rd_en = 0; din = 0;
        wr_cnt = 0; rd_cnt = 0; errors = 0; checks = 0;
        exp_ovf = 0; exp_unf = 0; chk_data = 0;

        // TEST 1: Reset
        #22 rst_n = 1;
        @(negedge clk);
        $display("TEST 1 : Reset check ............ %s (empty=%b full=%b count=%0d)",
                 (empty && !full && data_count == 0) ? "PASS" : "FAIL",
                 empty, full, data_count);

        // TEST 2: Fill the FIFO
        err_before = errors;
        for (i = 0; i < D; i = i + 1)
            write_data(8'hA0 + i);
        @(negedge clk);
        $display("TEST 2 : Write till full ........ %s (full=%b count=%0d)",
                 (full && errors == err_before) ? "PASS" : "FAIL", full, data_count);

        // TEST 3: Overflow
        err_before = errors;
        @(negedge clk); wr_en = 1; din = 8'hFF;
        @(negedge clk); wr_en = 0;
        $display("TEST 3 : Overflow attempt ....... %s (overflow=%b count=%0d)",
                 (overflow && data_count == D && errors == err_before) ? "PASS" : "FAIL",
                 overflow, data_count);

        // TEST 4: Empty the FIFO and check order
        err_before = errors;
        for (i = 0; i < D; i = i + 1)
            read_data;
        @(negedge clk);
        $display("TEST 4 : Read till empty ........ %s (empty=%b last dout=%h)",
                 (empty && dout == 8'hAF && errors == err_before) ? "PASS" : "FAIL",
                 empty, dout);

        // TEST 5: Underflow
        err_before = errors;
        @(negedge clk); rd_en = 1;
        @(negedge clk); rd_en = 0;
        $display("TEST 5 : Underflow attempt ...... %s (underflow=%b count=%0d)",
                 (underflow && empty && errors == err_before) ? "PASS" : "FAIL",
                 underflow, data_count);

        // TEST 6: Simultaneous read and write
        err_before = errors;
        write_data(8'h11);
        write_data(8'h22);
        @(negedge clk); wr_en = 1; rd_en = 1; din = 8'h33;
        @(negedge clk); wr_en = 1; rd_en = 1; din = 8'h44;
        @(negedge clk); wr_en = 0; rd_en = 0;
        $display("TEST 6 : Simultaneous rd/wr ..... %s (count=%0d dout=%h)",
                 (data_count == 2 && dout == 8'h22 && errors == err_before) ? "PASS" : "FAIL",
                 data_count, dout);
        read_data; read_data;

        // TEST 7: Random traffic (write-heavy, then read-heavy)
        err_before = errors;
        for (i = 0; i < 300; i = i + 1) begin
            @(negedge clk);
            if (i < 150) begin
                wr_en = ($random % 4) != 0;   // ~75% writes
                rd_en = ($random % 4) == 0;   // ~25% reads
            end else begin
                wr_en = ($random % 4) == 0;
                rd_en = ($random % 4) != 0;
            end
            din = $random;
        end
        @(negedge clk); wr_en = 0; rd_en = 0;
        $display("TEST 7 : 300 random cycles ...... %s (total writes=%0d reads=%0d)",
                 (errors == err_before) ? "PASS" : "FAIL", wr_cnt, rd_cnt);

        // Summary
        repeat (2) @(negedge clk);
        $display("--------------------------------------------------------");
        $display("Scoreboard checks = %0d, Errors = %0d", checks, errors);
        if (errors == 0) $display("RESULT: ALL TESTS PASSED");
        else             $display("RESULT: TEST FAILED");
        $display("--------------------------------------------------------");
        $finish;
    end

endmodule
