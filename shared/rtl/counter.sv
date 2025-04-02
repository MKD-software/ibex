`include "prim_assert.sv"


module counter #(
  // Bus data width must be 32
  parameter int unsigned DataWidth = 32,
  // Bus address width
  parameter int unsigned AddressWidth = 32
) (
  input  logic                    clk_i,
  input  logic                    rst_ni,
  // Bus interface
  input  logic                    counter_req_i,
  
  input  logic [AddressWidth-1:0] counter_addr_i,
  input  logic                    counter_we_i,
  input  logic [DataWidth/8-1:0]  counter_be_i,
  input  logic [DataWidth-1:0]    counter_wdata_i,
  output logic                    counter_rvalid_o,
  output logic [DataWidth-1:0]    counter_rdata_o,
  output logic                    counter_err_o
);

  // The counters are always 32 bits
localparam int unsigned TW = 32;
// Register map

logic                 counter_we;
logic                 mcount_we;
logic [DataWidth-1:0] mcount_wdata;
logic [TW-1:0]        mcount_q, mcount_d, mcount_inc;
logic                 error_q, error_d;
logic [DataWidth-1:0] rdata_q, rdata_d;
logic                 rvalid_q;

// Global write enable for all registers
assign counter_we = counter_req_i & counter_we_i;

// mcount increments every cycle
assign mcount_inc = mcount_q + 32'd1;

// Generate write data based on byte strobes
for (genvar b = 0; b < DataWidth / 8; b++) begin : gen_byte_wdata

  assign mcount_wdata[(b*8)+:8]     = counter_be_i[b] ? counter_wdata_i[b*8+:8] :
                                                     mcount_q[(b*8)+:8];
end

// Generate write enables
assign mcount_we     = counter_we & (counter_addr_i == 32'h40000);

// Generate next data
assign mcount_d    = {(mcount_we     ? mcount_wdata     : mcount_inc[31:0])};

// Generate registers
always_ff @(posedge clk_i or negedge rst_ni) begin
  if (~rst_ni) begin
    mcount_q <= 'b0;
  end else begin
    mcount_q <= mcount_d;
  end
end

// Read data
always_comb begin
  rdata_d = 'b0;
  error_d = 1'b0;
  unique case (counter_addr_i)
    32'h40000:     rdata_d = mcount_q[31:0];
    default: begin
      rdata_d = 'b0;
      // Error if no address matched
      error_d = 1'b1;
    end
  endcase
end

// error_q and rdata_q are only valid when rvalid_q is high
always_ff @(posedge clk_i) begin
  if (counter_req_i) begin
    rdata_q <= rdata_d;
    error_q <= error_d;
  end
end

assign counter_rdata_o = rdata_q;

// Read data is always valid one cycle after a request
always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    rvalid_q <= 1'b0;
  end else begin
    rvalid_q <= counter_req_i;
  end
end

assign counter_rvalid_o = rvalid_q;
assign counter_err_o    = error_q;

// Assertions
`ASSERT_INIT(param_legal, DataWidth == 32)

endmodule
