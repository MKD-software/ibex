`include "prim_assert.sv"


module multer #(
  // Bus data width must be 32
  parameter int unsigned DataWidth = 32,
  // Bus address width
  parameter int unsigned AddressWidth = 32
) (
  input  logic                    clk_i,
  input  logic                    rst_ni,
  // Bus interface
  input  logic                    mult_req_i,
  
  input  logic [AddressWidth-1:0] mult_addr_i,
  input  logic                    mult_we_i,
  input  logic [DataWidth/8-1:0]  mult_be_i,
  input  logic [DataWidth-1:0]    mult_wdata_i,
  output logic                    mult_rvalid_o,
  output logic [DataWidth-1:0]    mult_rdata_o,
  output logic                    mult_err_o
);

// Get 32-bit data from wdata_i
// Extract 2 16-bit numbers, 1 from lower 16 bit and 1 from upper 16 bits of wdata_i
// Multiply numbers in most efficient way possible
// and store result in 32-bit register

logic [15:0]                a, b;
logic [DataWidth-1:0]       result;

// Register map
logic                 mult_we;
logic                 mmult_we;
logic [DataWidth-1:0] mult_wdata;
logic                 error_q, error_d;
logic [DataWidth-1:0] rdata_q, rdata_d;
logic                 rvalid_q;

// Global write enable for all registers
assign mult_we = mult_req_i & mult_we_i;


// Generate write data based on byte strobes
for (genvar i = 0; i < DataWidth / 8; i++) begin : gen_byte_wdata
  assign mult_wdata[(i*8)+:8]     = mult_be_i[i] ? mult_wdata_i[i*8+:8] :
                                                     result[(i*8)+:8];
end

// Generate write enables
assign mmult_we     = mult_we & (mult_addr_i == 32'h40000);

// Generate next data
assign a    = {(mmult_we     ? mult_wdata[15:0]     : 16'b0)};
assign b    = {(mmult_we     ? mult_wdata[31:16]    : 16'b0)};


always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    result <= 'b0;
  end else if (mult_we) begin
    result <= a * b;
  end
end


// Read data
always_comb begin
  rdata_d = 'b0;
  error_d = 1'b0;
  unique case (mult_addr_i)
    32'h40000:     rdata_d = result[31:0];
    default: begin
      rdata_d = 'b0;
      // Error if no address matched
      error_d = 1'b1;
    end
  endcase
end

// error_q and rdata_q are only valid when rvalid_q is high
always_ff @(posedge clk_i) begin
  if (mult_req_i) begin
    rdata_q <= rdata_d;
    error_q <= error_d;
  end
end

assign mult_rdata_o = rdata_q;

// Read data is always valid one cycle after a request
always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    rvalid_q <= 1'b0;
  end else begin
    rvalid_q <= mult_req_i;
  end
end

assign mult_rvalid_o = rvalid_q;
assign mult_err_o    = error_q;

// Assertions
`ASSERT_INIT(param_legal, DataWidth == 32)

endmodule
