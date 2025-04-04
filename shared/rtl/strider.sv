`include "prim_assert.sv"


module strider #(
  // Bus data width must be 32
  parameter int unsigned DataWidth = 32,
  // Bus address width
  parameter int unsigned AddressWidth = 32
) (
  input  logic                    clk_i,
  input  logic                    rst_ni,
  // Bus interface
  input  logic                    stride_req_i,
  
  input  logic [AddressWidth-1:0] stride_addr_i,
  input  logic                    stride_we_i,
  input  logic [DataWidth/8-1:0]  stride_be_i,
  input  logic [DataWidth-1:0]    stride_wdata_i,
  output logic                    stride_rvalid_o,
  output logic [DataWidth-1:0]    stride_rdata_o,
  output logic                    stride_err_o
);

// Get 32-bit data from wdata_i
// Extract 2 16-bit numbers, 1 from lower 16 bit and 1 from upper 16 bits of wdata_i
// strideiply numbers in most efficient way possible
// and store result in 32-bit register

localparam bit [31:0] c_stride = 32'h00002;
localparam bit [31:0] r_stride = 32'h00002;
localparam bit [31:0] base = 32'h40000;

logic [15:0]                i, j;
logic [DataWidth-1:0]       result_addr;

// Register map
logic                 stride_we;
logic                 mstride_we;
logic [DataWidth-1:0] stride_wdata;
logic                 error_q, error_d;
logic [DataWidth-1:0] rdata_q, rdata_d;
logic                 rvalid_q;

// Global write enable for all registers
assign stride_we = stride_req_i & stride_we_i;


// Generate write data based on byte strobes
for (genvar q = 0; q < DataWidth / 8; q++) begin : gen_byte_wdata
  assign stride_wdata[(q*8)+:8]     = stride_be_i[q] ? stride_wdata_i[q*8+:8] :
                                              result_addr[(q*8)+:8];
end

// Generate write enables
assign mstride_we     = stride_we & (stride_addr_i == 32'h40000);

// Generate next data
assign i    = {(mstride_we     ? stride_wdata[15:0]     : 16'b0)};
assign j    = {(mstride_we     ? stride_wdata[31:16]    : 16'b0)};


always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    result_addr <= 'b0;
  end else if (stride_we) begin
    result_addr <= base + i * r_stride + j * c_stride;
  end
end


// Read data
always_comb begin
  rdata_d = 'b0;
  error_d = 1'b0;
  unique case (stride_addr_i)
    32'h40000:     rdata_d = result_addr[31:0];
    default: begin
      rdata_d = 'b0;
      // Error if no address matched
      error_d = 1'b1;
    end
  endcase
end

// error_q and rdata_q are only valid when rvalid_q is high
always_ff @(posedge clk_i) begin
  if (stride_req_i) begin
    rdata_q <= rdata_d;
    error_q <= error_d;
  end
end

assign stride_rdata_o = rdata_q;

// Read data is always valid one cycle after a request
always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    rvalid_q <= 1'b0;
  end else begin
    rvalid_q <= stride_req_i;
  end
end

assign stride_rvalid_o = rvalid_q;
assign stride_err_o    = error_q;

// Assertions
`ASSERT_INIT(param_legal, DataWidth == 32)

endmodule
