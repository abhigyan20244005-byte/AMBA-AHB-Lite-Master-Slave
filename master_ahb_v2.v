module master_ahb_v2 (

    input         CLK_MASTER,
    input         RESET_MASTER,

    // ============================================================
    // AHB slave -> master
    // ============================================================

    input         HREADY,
    input         HRESP,
    input  [31:0] HRDATA,

    // ============================================================
    // Top-level -> master
    // ============================================================

    input  [31:0] data_top,
    input         fifo_write_en,

    input         start_transfer,
    input         write_transfer,

    input  [31:0] addr_top,
    input  [3:0]  beat_length,

    input         wrap_enb,

    // Read FIFO consumer
    input         read_fifo_pop,

    // ============================================================
    // AHB master -> slave
    // ============================================================

    output reg [31:0] HADDR,
    output reg        HWRITE,
    output reg [2:0]  HSIZE,
    output reg [2:0]  HBURST,
    output reg [1:0]  HTRANS,
    output reg [31:0] HWDATA,

    // ============================================================
    // Write FIFO status
    // ============================================================

    output            fifo_empty,
    output            fifo_full,

    // ============================================================
    // Read FIFO status/data
    // ============================================================

    output            read_fifo_empty,
    output            read_fifo_full,
    output     [31:0] read_data_out,

    // ============================================================
    // Master status
    // ============================================================

    output            transfer_active,
    output reg        transfer_error
);


    // ============================================================
    // WRITE FIFO
    // ============================================================

    reg [31:0] write_fifo [0:15];

    reg [3:0] wr_ptr;
    reg [3:0] rd_ptr;

    reg [4:0] write_count;


    // ============================================================
    // READ FIFO
    // ============================================================

    reg [31:0] read_fifo [0:15];

    reg [3:0] read_wr_ptr;
    reg [3:0] read_rd_ptr;

    reg [4:0] read_count;


    integer i;


    // ============================================================
    // WRITE FIFO STATUS
    // ============================================================

    assign fifo_empty = (write_count == 5'd0);
    assign fifo_full  = (write_count == 5'd16);


    // ============================================================
    // READ FIFO STATUS
    // ============================================================

    assign read_fifo_empty = (read_count == 5'd0);
    assign read_fifo_full  = (read_count == 5'd16);

    assign read_data_out = read_fifo[read_rd_ptr];


    // ============================================================
    // MASTER STATES
    // ============================================================

    localparam ST_IDLE   = 2'b00;
    localparam ST_ACTIVE = 2'b01;
    localparam ST_ERROR  = 2'b10;

    reg [1:0] state;


    // ============================================================
    // TRANSACTION REGISTERS
    // ============================================================

    // Address currently being presented on HADDR
    reg [31:0] addr_reg;

    // Write data associated with the current address phase
    reg [31:0] addr_data_reg;

    // Write data currently in the AHB data phase
    reg [31:0] data_phase_reg;

    // FIFO word currently being issued
    reg [3:0] issue_ptr;

    // Current burst beat
    reg [3:0] beat_count;

    // Latched transaction information
    reg [3:0] beat_length_reg;
    reg       write_reg;

    // Indicates whether an address phase exists
    reg addr_valid;

    // Indicates whether a data phase exists
    reg data_valid;


    // ============================================================
    // MASTER ACTIVE STATUS
    // ============================================================

    assign transfer_active = (state != ST_IDLE);


    // ============================================================
    // VALID BURST LENGTH
    // ============================================================

    wire valid_burst_length;

    assign valid_burst_length =
            (beat_length == 4'd1) ||
            (beat_length == 4'd4);


    // ============================================================
    // ENOUGH WRITE DATA?
    // ============================================================

    wire enough_write_data;

    assign enough_write_data =
            (write_count >= beat_length);


    // ============================================================
    // ENOUGH READ FIFO SPACE?
    // ============================================================

    wire enough_read_space;

    assign enough_read_space =
            ((read_count + beat_length) <= 5'd16);


    // ============================================================
    // SUCCESSFUL WRITE DATA PHASE
    //
    // A FIFO word is consumed only when its AHB data phase
    // successfully completes.
    // ============================================================

    wire write_fifo_pop;

    assign write_fifo_pop =
            (state == ST_ACTIVE) &&
            data_valid &&
            HREADY &&
            !HRESP &&
            write_reg;


    // ============================================================
    // SUCCESSFUL READ DATA PHASE
    //
    // HRDATA enters the read FIFO only after a successful
    // completed read transfer.
    // ============================================================

    wire read_fifo_push;

    assign read_fifo_push =
            (state == ST_ACTIVE) &&
            data_valid &&
            HREADY &&
            !HRESP &&
            !write_reg;


    // ============================================================
    // WRITE FIFO
    // ============================================================

    always @(posedge CLK_MASTER) begin

        if (RESET_MASTER) begin

            wr_ptr      <= 4'd0;
            write_count <= 5'd0;

            for (i = 0; i < 16; i = i + 1)
                write_fifo[i] <= 32'd0;

        end

        else begin

            // ----------------------------------------------------
            // Push new top-level data into write FIFO
            // ----------------------------------------------------

            if (fifo_write_en && !fifo_full) begin

                write_fifo[wr_ptr] <= data_top;

                wr_ptr <= wr_ptr + 1'b1;

            end


            // ----------------------------------------------------
            // Update FIFO count
            // ----------------------------------------------------

            case ({(fifo_write_en && !fifo_full), write_fifo_pop})

                2'b10:
                    write_count <= write_count + 1'b1;

                2'b01:
                    write_count <= write_count - 1'b1;

                2'b11:
                    write_count <= write_count;

                default:
                    write_count <= write_count;

            endcase

        end

    end


    // ============================================================
    // READ FIFO
    // ============================================================

    always @(posedge CLK_MASTER) begin

        if (RESET_MASTER) begin

            read_wr_ptr <= 4'd0;
            read_rd_ptr <= 4'd0;
            read_count  <= 5'd0;
            

            for (i = 0; i < 16; i = i + 1)
                read_fifo[i] <= 32'd0;

        end

        else begin

            // ----------------------------------------------------
            // Store successfully returned AHB read data
            // ----------------------------------------------------

            if (read_fifo_push) begin

                read_fifo[read_wr_ptr] <= HRDATA;

                read_wr_ptr <= read_wr_ptr + 1'b1;

            end


            // ----------------------------------------------------
            // External logic consumes read FIFO data
            // ----------------------------------------------------

            if (read_fifo_pop && !read_fifo_empty) begin

                read_rd_ptr <= read_rd_ptr + 1'b1;

            end


            // ----------------------------------------------------
            // Read FIFO count
            // ----------------------------------------------------

            case ({read_fifo_push,
                   (read_fifo_pop && !read_fifo_empty)})

                2'b10:
                    read_count <= read_count + 1'b1;

                2'b01:
                    read_count <= read_count - 1'b1;

                2'b11:
                    read_count <= read_count;

                default:
                    read_count <= read_count;

            endcase

        end

    end


    // ============================================================
    // MASTER CONTROL
    // ============================================================

    always @(posedge CLK_MASTER) begin

        if (RESET_MASTER) begin

            state           <= ST_IDLE;

            addr_reg        <= 32'd0;
            addr_data_reg   <= 32'd0;
            data_phase_reg  <= 32'd0;

            rd_ptr          <= 4'd0;
            issue_ptr       <= 4'd0;
            beat_count      <= 4'd0;

            beat_length_reg <= 4'd0;

            write_reg       <= 1'b0;

            addr_valid      <= 1'b0;
            data_valid      <= 1'b0;

            transfer_error  <= 1'b0;

        end

        else begin

            case (state)

                // =================================================
                // IDLE
                // =================================================

                ST_IDLE: begin

                    addr_valid <= 1'b0;
                    data_valid <= 1'b0;


                    // ------------------------------------------------
                    // Request to start a transaction
                    // ------------------------------------------------

                    if (start_transfer) begin

                        transfer_error <= 1'b0;


                        // ------------------------------------------------
                        // Unsupported burst length
                        // ------------------------------------------------

                        if (!valid_burst_length) begin

                            transfer_error <= 1'b1;

                        end


                        // ------------------------------------------------
                        // WRAP not implemented
                        // ------------------------------------------------

                        else if (wrap_enb) begin

                            transfer_error <= 1'b1;

                        end


                        // ------------------------------------------------
                        // Write FIFO doesn't contain enough data
                        // ------------------------------------------------

                        else if (write_transfer &&
                                 !enough_write_data) begin

                            transfer_error <= 1'b1;

                        end


                        // ------------------------------------------------
                        // Read FIFO doesn't have enough space
                        // ------------------------------------------------

                        else if (!write_transfer &&
                                 !enough_read_space) begin

                            transfer_error <= 1'b1;

                        end


                        // ------------------------------------------------
                        // Valid transaction
                        // ------------------------------------------------

                        else begin

                            state <= ST_ACTIVE;


                            // Capture transaction configuration
                            addr_reg        <= addr_top;

                            beat_length_reg <= beat_length;

                            beat_count      <= 4'd0;

                            write_reg       <= write_transfer;


                            // Start from the current FIFO read pointer
                            issue_ptr <= rd_ptr;


                            // Preload first write word
                            if (write_transfer)
                                addr_data_reg <= write_fifo[rd_ptr];
                            else
                                addr_data_reg <= 32'd0;


                            // First address phase exists
                            addr_valid <= 1'b1;

                            // First data phase hasn't happened yet
                            data_valid <= 1'b0;

                        end

                    end

                end


                // =================================================
                // ACTIVE
                // =================================================

                ST_ACTIVE: begin


                    // ------------------------------------------------
                    // FIRST ERROR RESPONSE CYCLE
                    //
                    // HRESP = 1
                    // HREADY = 0
                    // ------------------------------------------------

                    if (HRESP && !HREADY) begin

                        state <= ST_ERROR;

                        // Cancel the pipelined next address
                        addr_valid <= 1'b0;

                        // Do not consume FIFO data
                        // Do not advance counters

                    end


                    // ------------------------------------------------
                    // HREADY = 1
                    //
                    // Current data phase / address phase can advance.
                    // ------------------------------------------------

                    else if (HREADY) begin


                        // =================================================
                        // ERROR COMPLETION
                        // =================================================

                        if (HRESP) begin

                            state <= ST_IDLE;

                            addr_valid <= 1'b0;
                            data_valid <= 1'b0;

                            transfer_error <= 1'b1;

                            // IMPORTANT:
                            // rd_ptr does NOT advance.
                            //
                            // The failed FIFO word remains unconsumed.

                        end


                        // =================================================
                        // SUCCESSFUL TRANSFER
                        // =================================================

                        else begin


                            // ------------------------------------------------
                            // Current DATA phase completed
                            // ------------------------------------------------

                            if (data_valid) begin

                                if (write_reg) begin

                                    // ------------------------------------------------
                                    // IMPORTANT:
                                    //
                                    // issue_ptr identifies the FIFO word
                                    // whose data phase has just completed.
                                    //
                                    // Therefore rd_ptr moves to the NEXT
                                    // FIFO location.
                                    // ------------------------------------------------

                                    rd_ptr <= issue_ptr + 1'b1;

                                end

                            end


                            // ------------------------------------------------
                            // Current ADDRESS phase completed
                            // ------------------------------------------------

                            if (addr_valid) begin

                                // The address phase now has a data phase
                                data_valid <= 1'b1;


                                // ------------------------------------------------
                                // For writes, move the data associated with
                                // this address into the actual data-phase
                                // register.
                                // ------------------------------------------------

                                if (write_reg) begin

                                    data_phase_reg <= addr_data_reg;

                                end


                                // ------------------------------------------------
                                // FINAL ADDRESS BEAT
                                // ------------------------------------------------

                                if (beat_count ==
                                    beat_length_reg - 1'b1) begin

                                    // No more address phases
                                    addr_valid <= 1'b0;

                                end


                                // ------------------------------------------------
                                // MORE ADDRESS BEATS REMAIN
                                // ------------------------------------------------

                                else begin

                                    beat_count <= beat_count + 1'b1;

                                    addr_reg <= addr_reg + 32'd4;

                                    issue_ptr <= issue_ptr + 1'b1;


                                    // Prepare next write data
                                    if (write_reg) begin

                                        addr_data_reg <=
                                            write_fifo[issue_ptr + 1'b1];

                                    end

                                end

                            end


                            // ------------------------------------------------
                            // FINAL DATA PHASE
                            //
                            // There is no address phase remaining.
                            // ------------------------------------------------

                            else begin

                                data_valid <= 1'b0;

                                state <= ST_IDLE;

                                beat_count <= 4'd0;

                            end

                        end

                    end

                    // ------------------------------------------------
                    // HREADY = 0, HRESP = 0
                    //
                    // WAIT STATE
                    //
                    // Intentionally no assignments here.
                    //
                    // All transaction registers retain their values.
                    // ------------------------------------------------

                end


                // =================================================
                // ERROR RESPONSE
                // =================================================

                ST_ERROR: begin

                    // ------------------------------------------------
                    // We reached here after:
                    //
                    // HRESP = 1
                    // HREADY = 0
                    //
                    // The next address phase has been cancelled.
                    //
                    // Wait for the second error-response cycle.
                    // ------------------------------------------------

                    if (HREADY) begin

                        state <= ST_IDLE;

                        addr_valid <= 1'b0;
                        data_valid <= 1'b0;

                        transfer_error <= 1'b1;

                        beat_count <= 4'd0;

                    end

                end


                // =================================================
                // SAFETY DEFAULT
                // =================================================

                default: begin

                    state <= ST_IDLE;

                    addr_valid <= 1'b0;
                    data_valid <= 1'b0;

                    beat_count <= 4'd0;

                end

            endcase

        end

    end


    // ============================================================
    // AHB OUTPUT LOGIC
    // ============================================================

    always @(*) begin

        // --------------------------------------------------------
        // Defaults
        // --------------------------------------------------------

        HADDR  = addr_reg;

        HWRITE = 1'b0;

        // 32-bit transfer
        HSIZE  = 3'b010;

        // Default = SINGLE
        HBURST = 3'b000;

        // Default = IDLE
        HTRANS = 2'b00;

        HWDATA = 32'd0;


        // --------------------------------------------------------
        // ADDRESS PHASE
        // --------------------------------------------------------

        if ((state == ST_ACTIVE) &&
            addr_valid) begin

            HADDR  = addr_reg;

            HWRITE = write_reg;


            // First beat
            if (beat_count == 4'd0)
                HTRANS = 2'b10;       // NONSEQ

            // Subsequent beats
            else
                HTRANS = 2'b11;       // SEQ


            // Burst type
            if (beat_length_reg == 4'd4)
                HBURST = 3'b011;      // INCR4

            else
                HBURST = 3'b000;      // SINGLE

        end


        // --------------------------------------------------------
        // DATA PHASE
        //
        // This data corresponds to the address phase captured by
        // the slave on the previous clock.
        // --------------------------------------------------------

        if ((state == ST_ACTIVE) &&
            data_valid &&
            write_reg) begin

            HWDATA = data_phase_reg;

        end

    end

endmodule