`default_nettype none

module tt_um_braun_tpu (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,

    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,

    input  wire clk,
    input  wire rst_n,
    input  wire ena
);

wire rst = ~rst_n;

// protocol
wire we    = uio_in[0];   // write enable
wire start = uio_in[1];   // start compute

// avoid unused
wire _unused = &{uio_in[7:2],1'b0};

//////////////// MEMORY //////////////////

reg [7:0] mem [0:7];
reg [2:0] addr = 0;

always @(posedge clk) begin
    if (rst) begin
        addr <= 0;
    end else if (ena && we) begin
        mem[addr] <= ui_in;
        addr <= addr + 1;
    end
end

//////////////// COMPUTE //////////////////

reg [2:0] cycle = 0;
reg busy = 0;

reg [15:0] c00=0,c01=0,c10=0,c11=0;

always @(posedge clk) begin
    if (rst) begin
        busy <= 0;
        cycle <= 0;
        c00<=0; c01<=0; c10<=0; c11<=0;
    end else if (ena) begin

        // start computation
        if (start && !busy) begin
            busy <= 1;
            cycle <= 0;

            // clear accumulators
            c00<=0; c01<=0; c10<=0; c11<=0;
        end

        if (busy) begin
            case (cycle)
            0: begin
                c00 <= mem[0]*mem[4];
                c01 <= mem[0]*mem[5];
                c10 <= mem[2]*mem[4];
                c11 <= mem[2]*mem[5];
            end
            1: begin
                c00 <= c00 + mem[1]*mem[6];
                c01 <= c01 + mem[1]*mem[7];
                c10 <= c10 + mem[3]*mem[6];
                c11 <= c11 + mem[3]*mem[7];
            end
            2: begin
                busy <= 0;
            end
            endcase

            cycle <= cycle + 1;
        end
    end
end

//////////////// OUTPUT //////////////////

reg [7:0] out_reg = 0;
reg done = 0;

always @(posedge clk) begin
    if (rst) begin
        out_reg <= 0;
        done <= 0;
    end else if (ena) begin
        done <= 0;

        if (busy && cycle==2) begin
            out_reg <= c00[7:0]; // output one result (can extend)
            done <= 1;
        end
    end
end

assign uo_out  = out_reg;
assign uio_out = {7'd0, done};
assign uio_oe  = 8'hFF;

endmodule
