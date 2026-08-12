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
        .CLK                (CLK),
        .RESET              (RESET),

        .data_top           (data_top),
        .fifo_write_en      (fifo_write_en),

        .start_transfer     (start_transfer),
        .write_transfer     (write_transfer),

        .addr_top           (addr_top),
        .beat_length        (beat_length),
        .wrap_enb           (wrap_enb),

        .read_fifo_pop      (read_fifo_pop),

        .read_fifo_empty    (read_fifo_empty),
        .read_fifo_full     (read_fifo_full),
        .read_data_out      (read_data_out),

        .fifo_empty         (fifo_empty),
        .fifo_full          (fifo_full),

        .transfer_active    (transfer_active),
        .transfer_error     (transfer_error),

        .test_wait_en       (test_wait_en),
        .test_wait_cycles   (test_wait_cycles),

        .test_error_en      (test_error_en),
        .test_error_addr    (test_error_addr)
    );


    always #5 CLK = ~CLK;


    initial begin

        CLK = 0;
        RESET = 1;

        data_top = 0;
        fifo_write_en = 0;

        start_transfer = 0;
        write_transfer = 0;

        addr_top = 0;
        beat_length = 0;
        wrap_enb = 0;

        read_fifo_pop = 0;

        test_wait_en = 0;
        test_wait_cycles = 0;

        test_error_en = 0;
        test_error_addr = 0;


        // Reset
        #10;
        RESET = 0;


        // Write data to FIFO
        data_top = 32'h1234_5678;
        fifo_write_en = 1;

        #10;
        fifo_write_en = 0;


        // SINGLE WRITE to address 0
        addr_top = 32'h0000_0000;
        beat_length = 1;
        write_transfer = 1;
        start_transfer = 1;

        #10;
        start_transfer = 0;


        // Wait for write to finish
        #30;


        // SINGLE READ from address 0
        addr_top = 32'h0000_0000;
        beat_length = 1;
        write_transfer = 0;
        start_transfer = 1;

        #10;
        start_transfer = 0;


        // Wait for read to finish
        #40;

        $finish;

    end

endmodule