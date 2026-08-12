module ahb_system (

    // ============================================================
    // SYSTEM
    // ============================================================

    input CLK,
    input RESET,

    // ============================================================
    // MASTER CONTROL / WRITE FIFO INPUTS
    // ============================================================

    input [31:0] data_top,
    input        fifo_write_en,

    input        start_transfer,
    input        write_transfer,

    input [31:0] addr_top,
    input [3:0]  beat_length,

    input        wrap_enb,

    // ============================================================
    // READ FIFO INTERFACE
    // ============================================================

    input        read_fifo_pop,

    output        read_fifo_empty,
    output        read_fifo_full,
    output [31:0] read_data_out,

    // ============================================================
    // WRITE FIFO STATUS
    // ============================================================

    output        fifo_empty,
    output        fifo_full,

    // ============================================================
    // MASTER STATUS
    // ============================================================

    output        transfer_active,
    output        transfer_error,

    // ============================================================
    // SLAVE TEST CONTROLS
    // ============================================================

    input        test_wait_en,
    input [3:0]  test_wait_cycles,

    input        test_error_en,
    input [31:0] test_error_addr
);


    // ============================================================
    // AHB BUS
    //
    // These wires physically connect the master and slave.
    // ============================================================

    wire [31:0] HADDR;
    wire        HWRITE;
    wire [2:0]  HSIZE;
    wire [2:0]  HBURST;
    wire [1:0]  HTRANS;
    wire [31:0] HWDATA;

    wire        HREADY;
    wire        HRESP;
    wire [31:0] HRDATA;


    // ============================================================
    // MASTER
    // ============================================================

    master_ahb_v2 master_inst (

        .CLK_MASTER       (CLK),
        .RESET_MASTER     (RESET),

        // Slave -> Master
        .HREADY           (HREADY),
        .HRESP            (HRESP),
        .HRDATA           (HRDATA),

        // Top -> Master
        .data_top         (data_top),
        .fifo_write_en    (fifo_write_en),

        .start_transfer   (start_transfer),
        .write_transfer   (write_transfer),

        .addr_top         (addr_top),
        .beat_length      (beat_length),

        .wrap_enb         (wrap_enb),

        .read_fifo_pop    (read_fifo_pop),

        // Master -> Slave
        .HADDR            (HADDR),
        .HWRITE           (HWRITE),
        .HSIZE            (HSIZE),
        .HBURST           (HBURST),
        .HTRANS          (HTRANS),
        .HWDATA           (HWDATA),

        // FIFO status
        .fifo_empty       (fifo_empty),
        .fifo_full        (fifo_full),

        .read_fifo_empty  (read_fifo_empty),
        .read_fifo_full   (read_fifo_full),
        .read_data_out    (read_data_out),

        // Status
        .transfer_active  (transfer_active),
        .transfer_error   (transfer_error)
    );


    // ============================================================
    // SLAVE
    // ============================================================

    slave_ahbyt slave_inst (

        .HCLK             (CLK),
        .HRESET           (RESET),

        // Master -> Slave
        .HADDR            (HADDR),
        .HWRITE           (HWRITE),
        .HSIZE            (HSIZE),
        .HBURST           (HBURST),
        .HTRANS           (HTRANS),
        .HWDATA           (HWDATA),

        // Test controls
        .test_wait_en     (test_wait_en),
        .test_wait_cycles (test_wait_cycles),

        .test_error_en    (test_error_en),
        .test_error_addr  (test_error_addr),

        // Slave -> Master
        .HREADY           (HREADY),
        .HRESP            (HRESP),
        .HRDATA           (HRDATA)
    );


endmodule