`timescale 1ns/1ps

module tb_ahb;

    reg CLK;
    reg RESET;

    reg [31:0] data_top;
    reg        fifo_write_en;

    reg        start_transfer;
    reg        write_transfer;

    reg [31:0] addr_top;
    reg [3:0]  beat_length;
    reg        wrap_enb;

    reg        read_fifo_pop;

    reg        test_wait_en;
    reg [3:0]  test_wait_cycles;

    reg        test_error_en;
    reg [31:0] test_error_addr;

    wire [31:0] read_data_out;

    wire fifo_empty;
    wire fifo_full;

    wire read_fifo_empty;
    wire read_fifo_full;

    wire transfer_active;
    wire transfer_error;


    ahb_system dut (
        .CLK             (CLK),
        .RESET           (RESET),

        .data_top        (data_top),
        .fifo_write_en   (fifo_write_en),

        .start_transfer  (start_transfer),
        .write_transfer  (write_transfer),

        .addr_top        (addr_top),
        .beat_length     (beat_length),
        .wrap_enb        (wrap_enb),

        .read_fifo_pop   (read_fifo_pop),

        .read_fifo_empty (read_fifo_empty),
        .read_fifo_full  (read_fifo_full),
        .read_data_out   (read_data_out),

        .fifo_empty      (fifo_empty),
        .fifo_full       (fifo_full),

        .transfer_active (transfer_active),
        .transfer_error  (transfer_error),

        .test_wait_en    (test_wait_en),
        .test_wait_cycles(test_wait_cycles),

        .test_error_en   (test_error_en),
        .test_error_addr (test_error_addr)
    );


    always #5 CLK = ~CLK;


    task push_write_data;
        input [31:0] data;
        begin
            @(negedge CLK);
            data_top = data;
            fifo_write_en = 1'b1;

            @(negedge CLK);
            fifo_write_en = 1'b0;
        end
    endtask


    task start_write;
        input [31:0] addr;
        input [3:0]  length;
        begin
            @(negedge CLK);

            addr_top = addr;
            beat_length = length;
            write_transfer = 1'b1;
            start_transfer = 1'b1;

            @(negedge CLK);
            start_transfer = 1'b0;

            wait (!transfer_active);

            @(negedge CLK);
        end
    endtask


    task start_read;
        input [31:0] addr;
        input [3:0]  length;
        begin
            @(negedge CLK);

            addr_top = addr;
            beat_length = length;
            write_transfer = 1'b0;
            start_transfer = 1'b1;

            @(negedge CLK);
            start_transfer = 1'b0;

            wait (!transfer_active);

            @(negedge CLK);
        end
    endtask


    task pop_read_data;
        input [31:0] expected;
        begin
            wait (!read_fifo_empty);

            if (read_data_out !== expected) begin
                $display("FAIL: Expected %h, got %h",
                         expected, read_data_out);
                $fatal;
            end

            @(negedge CLK);
            read_fifo_pop = 1'b1;

            @(negedge CLK);
            read_fifo_pop = 1'b0;
        end
    endtask


    initial begin

        CLK = 1'b0;
        RESET = 1'b1;

        data_top = 32'd0;
        fifo_write_en = 1'b0;

        start_transfer = 1'b0;
        write_transfer = 1'b0;

        addr_top = 32'd0;
        beat_length = 4'd0;
        wrap_enb = 1'b0;

        read_fifo_pop = 1'b0;

        test_wait_en = 1'b0;
        test_wait_cycles = 4'd0;

        test_error_en = 1'b0;
        test_error_addr = 32'd0;


        // Reset
        repeat (2) @(posedge CLK);
        RESET = 1'b0;


        // ========================================================
        // TEST 1: SINGLE WRITE
        // ========================================================

        push_write_data(32'h1234_5678);

        start_write(32'h0000_0000, 4'd1);

        if (!fifo_empty) begin
            $display("FAIL: Write FIFO not empty");
            $fatal;
        end

        $display("PASS: SINGLE WRITE");


        // ========================================================
        // TEST 2: SINGLE READ
        // ========================================================

        start_read(32'h0000_0000, 4'd1);

        pop_read_data(32'h1234_5678);

        if (!read_fifo_empty) begin
            $display("FAIL: Read FIFO did not empty");
            $fatal;
        end

        $display("PASS: SINGLE READ");


        // ========================================================
        // TEST 3: INCR4 WRITE
        // ========================================================

        push_write_data(32'hAAAA_0001);
        push_write_data(32'hAAAA_0002);
        push_write_data(32'hAAAA_0003);
        push_write_data(32'hAAAA_0004);

        start_write(32'h0000_0010, 4'd4);

        if (!fifo_empty) begin
            $display("FAIL: INCR4 write FIFO not empty");
            $fatal;
        end

        $display("PASS: INCR4 WRITE");


        // ========================================================
        // TEST 4: INCR4 READ
        // ========================================================

        start_read(32'h0000_0010, 4'd4);

        pop_read_data(32'hAAAA_0001);
        pop_read_data(32'hAAAA_0002);
        pop_read_data(32'hAAAA_0003);
        pop_read_data(32'hAAAA_0004);

        if (!read_fifo_empty) begin
            $display("FAIL: INCR4 read FIFO not empty");
            $fatal;
        end

        $display("PASS: INCR4 READ");


        // ========================================================
        // TEST 5: WAIT STATES
        // ========================================================

        test_wait_en = 1'b1;
        test_wait_cycles = 4'd2;

        push_write_data(32'h5555_AAAA);

        start_write(32'h0000_0020, 4'd1);

        test_wait_en = 1'b0;

        $display("PASS: WAIT STATE WRITE");


        // ========================================================
        // TEST 6: ERROR RESPONSE
        // ========================================================

        test_error_en = 1'b1;
        test_error_addr = 32'h0000_0030;

        @(negedge CLK);

        addr_top = 32'h0000_0030;
        beat_length = 4'd1;
        write_transfer = 1'b0;
        start_transfer = 1'b1;

        @(negedge CLK);
        start_transfer = 1'b0;

        wait (!transfer_active);
@(negedge CLK);

if (!transfer_error) begin
    $display("FAIL: Error was not detected");
    $fatal;
end

        test_error_en = 1'b0;

        $display("PASS: ERROR RESPONSE");


        // ========================================================
        // TEST 7: WRAP REJECTION
        // ========================================================

        @(negedge CLK);

        addr_top = 32'h0000_0040;
        beat_length = 4'd4;
        write_transfer = 1'b0;
        wrap_enb = 1'b1;
        start_transfer = 1'b1;

        @(negedge CLK);
        start_transfer = 1'b0;

        @(negedge CLK);

        if (!transfer_error) begin
            $display("FAIL: WRAP was not rejected");
            $fatal;
        end

        wrap_enb = 1'b0;

        $display("PASS: WRAP REJECTION");


        // ========================================================
        // TEST 8: INVALID BURST LENGTH
        // ========================================================

        @(negedge CLK);

        addr_top = 32'h0000_0050;
        beat_length = 4'd2;
        write_transfer = 1'b0;
        start_transfer = 1'b1;

        @(negedge CLK);
        start_transfer = 1'b0;

        @(negedge CLK);

        if (!transfer_error) begin
            $display("FAIL: Invalid burst length was not rejected");
            $fatal;
        end

        $display("PASS: INVALID BURST REJECTION");


        // ========================================================
        // DONE
        // ========================================================

        $display("--------------------------------");
        $display("ALL TESTS PASSED");
        $display("--------------------------------");

        #20;
        $finish;

    end

endmodule
