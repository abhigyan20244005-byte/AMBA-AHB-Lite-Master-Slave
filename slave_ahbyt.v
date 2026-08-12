module slave_ahbyt (

    input         HCLK,
    input         HRESET,

    // ============================================================
    // AHB INPUTS
    // ============================================================

    input  [31:0] HADDR,
    input         HWRITE,
    input  [2:0]  HSIZE,
    input  [2:0]  HBURST,
    input  [1:0]  HTRANS,
    input  [31:0] HWDATA,

    // ============================================================
    // TEST / DEBUG CONTROLS
    // ============================================================

    // Enable wait-state generation
    input         test_wait_en,

    // Number of wait cycles to insert
    input  [3:0]  test_wait_cycles,

    // Enable ERROR generation
    input         test_error_en,

    // Address at which ERROR should occur
    input  [31:0] test_error_addr,

    // ============================================================
    // AHB OUTPUTS
    // ============================================================

    output reg        HREADY,
    output reg        HRESP,
    output reg [31:0] HRDATA
);


    // ============================================================
    // SLAVE MEMORY
    //
    // 16 locations × 32 bits
    //
    // 0x00 -> mem[0]
    // 0x04 -> mem[1]
    // 0x08 -> mem[2]
    // ...
    // 0x3C -> mem[15]
    // ============================================================

    reg [31:0] mem [0:15];

    integer i;


    // ============================================================
    // CAPTURED ADDRESS-PHASE INFORMATION
    //
    // These registers describe the transfer whose DATA PHASE
    // is currently being handled.
    // ============================================================

    reg [31:0] addr_d;
    reg        write_d;
    reg [2:0]  size_d;
    reg [2:0]  burst_d;

    // Indicates that addr_d contains a valid transfer
    reg        valid_d;


    // ============================================================
    // SLAVE STATES
    // ============================================================

    localparam ST_IDLE = 3'b000;
    localparam ST_WAIT = 3'b001;
    localparam ST_ERR1 = 3'b010;
    localparam ST_ERR2 = 3'b011;

    reg [2:0] state;


    // ============================================================
    // WAIT STATE COUNTER
    // ============================================================

    reg [3:0] wait_count;


    // ============================================================
    // VALID AHB TRANSFER
    //
    // NONSEQ = 2'b10
    // SEQ    = 2'b11
    //
    // Both have HTRANS[1] = 1.
    // ============================================================

    wire incoming_transfer_valid;

    assign incoming_transfer_valid = HTRANS[1];


    // ============================================================
    // CURRENT TRANSFER ERROR CHECKS
    // ============================================================

    // Only 32-bit transfers are supported.
    //
    // HSIZE = 010 -> 32-bit
    wire current_size_error;

    assign current_size_error =
        (size_d != 3'b010);


    // Our memory contains only 64 bytes.
    //
    // Valid addresses:
    // 0x00, 0x04, 0x08, ... 0x3C
    //
    // HADDR[31:6] must therefore be zero.
    // HADDR[1:0] must be zero because accesses are word aligned.
    wire current_address_error;

    assign current_address_error =
        (addr_d[31:6] != 26'd0) ||
        (addr_d[1:0] != 2'b00);


    // Testbench-controlled ERROR
    wire injected_error;

    assign injected_error =
        test_error_en &&
        (addr_d == test_error_addr);


    // Combined error condition
    wire current_error;

    assign current_error =
        current_size_error ||
        current_address_error ||
        injected_error;


    // ============================================================
    // AHB OUTPUT LOGIC
    // ============================================================

    always @(*) begin

        // --------------------------------------------------------
        // NORMAL DEFAULT
        // --------------------------------------------------------

        HREADY = 1'b1;
        HRESP  = 1'b0;
        HRDATA = 32'b0;


        // --------------------------------------------------------
        // WAIT STATE
        //
        // HREADY = 0 extends the current DATA phase.
        // --------------------------------------------------------

        if (state == ST_WAIT) begin

            HREADY = 1'b0;
            HRESP  = 1'b0;

        end


        // --------------------------------------------------------
        // ERROR RESPONSE - FIRST CYCLE
        //
        // HREADY = 0
        // HRESP  = 1
        // --------------------------------------------------------

        else if (state == ST_ERR1) begin

            HREADY = 1'b0;
            HRESP  = 1'b1;

        end


        // --------------------------------------------------------
        // ERROR RESPONSE - SECOND CYCLE
        //
        // HREADY = 1
        // HRESP  = 1
        // --------------------------------------------------------

        else if (state == ST_ERR2) begin

            HREADY = 1'b1;
            HRESP  = 1'b1;

        end


        // --------------------------------------------------------
        // READ DATA
        //
        // addr_d is the address belonging to the CURRENT DATA
        // PHASE, not the address currently being presented by the
        // master.
        // --------------------------------------------------------

        if (valid_d && !write_d) begin

            HRDATA = mem[addr_d[5:2]];

        end

    end


    // ============================================================
    // SLAVE CONTROL
    // ============================================================

    always @(posedge HCLK) begin

        // ========================================================
        // RESET
        // ========================================================

        if (HRESET) begin

            state <= ST_IDLE;

            addr_d  <= 32'b0;
            write_d <= 1'b0;
            size_d  <= 3'b010;
            burst_d <= 3'b000;

            valid_d <= 1'b0;

            wait_count <= 4'd0;


            // Clear slave memory
            for (i = 0; i < 16; i = i + 1)
                mem[i] <= 32'b0;

        end


        // ========================================================
        // NORMAL OPERATION
        // ========================================================

        else begin

            case (state)


                // =================================================
                // IDLE
                // =================================================

                ST_IDLE: begin

                    // ------------------------------------------------
                    // HREADY is HIGH in this state.
                    //
                    // Therefore the master may present a new
                    // NONSEQ or SEQ address phase.
                    // ------------------------------------------------

                    if (incoming_transfer_valid) begin

                        // --------------------------------------------
                        // Capture address-phase information
                        // --------------------------------------------

                        addr_d  <= HADDR;
                        write_d <= HWRITE;
                        size_d  <= HSIZE;
                        burst_d <= HBURST;

                        valid_d <= 1'b1;


                        // --------------------------------------------
                        // ERROR?
                        // --------------------------------------------

                        if (
                            (HSIZE != 3'b010) ||
                            (HADDR[31:6] != 26'd0) ||
                            (HADDR[1:0] != 2'b00) ||
                            (test_error_en &&
                             (HADDR == test_error_addr))
                           ) begin

                            state <= ST_ERR1;

                        end


                        // --------------------------------------------
                        // WAIT STATE?
                        // --------------------------------------------

                        else if (test_wait_en &&
                                 (test_wait_cycles != 4'd0)) begin

                            wait_count <= test_wait_cycles;

                            state <= ST_WAIT;

                        end


                        // --------------------------------------------
                        // NORMAL TRANSFER
                        //
                        // Stay in IDLE because HREADY remains HIGH.
                        //
                        // The address captured above now belongs to
                        // the DATA PHASE occurring in the next cycle.
                        // --------------------------------------------

                        else begin

                            state <= ST_IDLE;

                        end

                    end

                    else begin

                        // No valid address phase
                        valid_d <= 1'b0;

                    end

                end


                // =================================================
                // WAIT STATE
                // =================================================

                ST_WAIT: begin

                    // ------------------------------------------------
                    // HREADY remains LOW.
                    //
                    // Therefore the current transfer is NOT complete.
                    //
                    // addr_d, write_d, size_d, etc. remain unchanged.
                    // ------------------------------------------------

                    if (wait_count > 1) begin

                        wait_count <= wait_count - 1'b1;

                    end

                    else begin

                        wait_count <= 4'd0;

                        // Return to normal operation.
                        // HREADY becomes HIGH in the following cycle.
                        state <= ST_IDLE;

                    end

                end


                // =================================================
                // ERROR RESPONSE - FIRST CYCLE
                // =================================================

                ST_ERR1: begin

                    // ------------------------------------------------
                    // Current outputs:
                    //
                    // HREADY = 0
                    // HRESP  = 1
                    //
                    // Move to second ERROR cycle.
                    // ------------------------------------------------

                    state <= ST_ERR2;

                end


                // =================================================
                // ERROR RESPONSE - SECOND CYCLE
                // =================================================

                ST_ERR2: begin

                    // ------------------------------------------------
                    // Current outputs:
                    //
                    // HREADY = 1
                    // HRESP  = 1
                    //
                    // ERROR response is now complete.
                    // ------------------------------------------------

                    valid_d <= 1'b0;

                    state <= ST_IDLE;

                end


                // =================================================
                // SAFETY DEFAULT
                // =================================================

                default: begin

                    state <= ST_IDLE;

                    valid_d <= 1'b0;

                    wait_count <= 4'd0;

                end

            endcase

        end

    end


    // ============================================================
    // MEMORY WRITE
    //
    // A write occurs only when:
    //
    // 1. A valid DATA phase exists
    // 2. The transfer is a WRITE
    // 3. HREADY = 1
    // 4. HRESP = 0
    //
    // Therefore a wait state or ERROR cannot accidentally modify
    // memory.
    // ============================================================

    always @(posedge HCLK) begin

        if (!HRESET) begin

            if (valid_d &&
                write_d &&
                HREADY &&
                !HRESP &&
                !current_error) begin

                mem[addr_d[5:2]] <= HWDATA;

            end

        end

    end

endmodule