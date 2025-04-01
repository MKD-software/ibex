`include "prim_assert.sv"
parameter int unsigned COUNTER_BASE = 32'h40000;


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

  // The counter is fixed at 32 bits
  localparam int unsigned COUNTER_WIDTH = 32;

  logic [COUNTER_WIDTH-1:0] counter_q, counter_d;

  
  // Counter update logic
  always_comb begin
    if (counter_req_i && counter_we_i) begin
      counter_d = counter_wdata_i; // Write new value
    end else begin
      counter_d = counter_q + 1;   // Increment every cycle
    end
  end

  // Counter register
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      counter_q <= 'b0;
    end else begin
      counter_q <= counter_d;
    end
  end

  // Read operation
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      counter_rdata_o  <= 'b0;
      counter_rvalid_o <= 1'b0;
    end else begin
      if (counter_req_i && !counter_we_i) begin
        counter_rdata_o  <= counter_q;
        counter_rvalid_o <= 1'b1;
      end else begin
        counter_rvalid_o <= 1'b0;
      end
    end
  end


  logic [AddressWidth-1:0] local_addr;
  assign local_addr = counter_addr_i - COUNTER_BASE;
  
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      counter_err_o <= 1'b0;
    end else if (counter_req_i && local_addr != 0) begin
      counter_err_o <= 1'b1;
    end else begin
      counter_err_o <= 1'b0;
    end
  end
  

  // Assertions
  `ASSERT_INIT(param_legal, DataWidth == 32)

endmodule
