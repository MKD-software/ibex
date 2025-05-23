// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// VCS does not support overriding enum and string parameters via command line. Instead, a `define
// is used that can be set from the command line. If no value has been specified, this gives a
// default. Other simulators don't take the detour via `define and can override the corresponding
// parameters directly.
`ifndef RV32M
  `define RV32M ibex_pkg::RV32MFast
`endif

`ifndef RV32B
  `define RV32B ibex_pkg::RV32BNone
`endif

`ifndef RegFile
  `define RegFile ibex_pkg::RegFileFF
`endif

/**
 * Ibex simple system
 *
 * This is a basic system consisting of an ibex, a 1 MB sram for instruction/data
 * and a small memory mapped control module for outputting ASCII text and
 * controlling/halting the simulation from the software running on the ibex.
 *
 * It is designed to be used with verilator but should work with other
 * simulators, a small amount of work may be required to support the
 * simulator_ctrl module.
 */

module cille_demo_system (
  input IO_CLK,
  input IO_RST_N
);

  localparam logic [31:0] MEM_SIZE   = 1024*1024; // 1 MB
  localparam logic [31:0] MEM_START     = 32'h00100000;
  localparam logic [31:0] MEM_MASK      = ~32'hFFFFF;

  localparam logic [31:0] SIMCTRL_BASE = 32'h20000;
  localparam logic [31:0] SIMCTRL_MASK = ~32'h3FF; // 1 kB

  localparam logic [31:0] TIMER_BASE   = 32'h30000;
  localparam logic [31:0] TIMER_MASK   = ~32'h3FF; // 1 kB

  localparam logic [31:0] STRIDER_BASE = 32'h40000;
  localparam logic [31:0] STRIDER_MASK = ~32'h3FF; // 1 kB

  localparam logic [31:0] COUNTER_BASE = 32'h50000;
  localparam logic [31:0] COUNTER_MASK = ~32'h3FF; // 1 kB

  localparam logic [31:0] MULTER_BASE = 32'h60000;
  localparam logic [31:0] MULTER_MASK = ~32'h3FF; // 1 kB

  // localparam logic [31:0] UART_BASE = 32'h70000;
  // localparam logic [31:0] UART_MASK = ~32'h3FF; // 1 kB


  parameter bit                 SecureIbex               = 1'b0;
  parameter bit                 ICacheScramble           = 1'b0;
  parameter bit                 PMPEnable                = 1'b0;
  parameter int unsigned        PMPGranularity           = 0;
  parameter int unsigned        PMPNumRegions            = 4;
  parameter int unsigned        MHPMCounterNum           = 0;
  parameter int unsigned        MHPMCounterWidth         = 40;
  parameter bit                 RV32E                    = 1'b0;
  parameter ibex_pkg::rv32m_e   RV32M                    = `RV32M;
  parameter ibex_pkg::rv32b_e   RV32B                    = `RV32B;
  parameter ibex_pkg::regfile_e RegFile                  = `RegFile;
  parameter bit                 BranchTargetALU          = 1'b0;
  parameter bit                 WritebackStage           = 1'b0;
  parameter bit                 ICache                   = 1'b0;
  parameter bit                 DbgTriggerEn             = 1'b0;
  parameter bit                 ICacheECC                = 1'b0;
  parameter bit                 BranchPredictor          = 1'b0;
  parameter                     SRAMInitFile             = "";

  logic clk_sys = 1'b0, rst_sys_n;

  typedef enum logic {
    CoreD
  } bus_host_e;

  typedef enum int {
    Ram,
    SimCtrl,
    Timer,
    Strider,
    Counter,
    Multer
    // UART
  } bus_device_e;

  localparam int NrDevices = 6;
  localparam int NrHosts = 1;

  // interrupts
  logic timer_irq;

  // host and device signals
  logic           host_req    [NrHosts];
  logic           host_gnt    [NrHosts];
  logic [31:0]    host_addr   [NrHosts];
  logic           host_we     [NrHosts];
  logic [ 3:0]    host_be     [NrHosts];
  logic [31:0]    host_wdata  [NrHosts];
  logic           host_rvalid [NrHosts];
  logic [31:0]    host_rdata  [NrHosts];
  logic           host_err    [NrHosts];

  logic [6:0]     data_rdata_intg;
  logic [6:0]     instr_rdata_intg;

  // devices (slaves)
  logic           device_req    [NrDevices];
  logic [31:0]    device_addr   [NrDevices];
  logic           device_we     [NrDevices];
  logic [ 3:0]    device_be     [NrDevices];
  logic [31:0]    device_wdata  [NrDevices];
  logic           device_rvalid [NrDevices];
  logic [31:0]    device_rdata  [NrDevices];
  logic           device_err    [NrDevices];

  // Device address mapping
  logic [31:0] cfg_device_addr_base [NrDevices];
  logic [31:0] cfg_device_addr_mask [NrDevices];

  assign cfg_device_addr_base[Ram]     =      MEM_START;
  assign cfg_device_addr_mask[Ram]     =      MEM_MASK; // 1 MB
  assign cfg_device_addr_base[SimCtrl] =  SIMCTRL_BASE;
  assign cfg_device_addr_mask[SimCtrl] =  SIMCTRL_MASK; // 1 kB
  assign cfg_device_addr_base[Timer]    =    TIMER_BASE;
  assign cfg_device_addr_mask[Timer]    =    TIMER_MASK; // 1 kB
  assign cfg_device_addr_base[Strider] =  STRIDER_BASE;
  assign cfg_device_addr_mask[Strider] =  STRIDER_MASK; // 1 kB
  assign cfg_device_addr_base[Counter] =  COUNTER_BASE;
  assign cfg_device_addr_mask[Counter] =  COUNTER_MASK; // 1 kB
  assign cfg_device_addr_base[Multer] =   MULTER_BASE;
  assign cfg_device_addr_mask[Multer] =   MULTER_MASK; // 1 kB

  // Instruction fetch signals
  logic instr_req;
  logic instr_gnt;
  logic instr_rvalid;
  logic [31:0] instr_addr;
  logic [31:0] instr_rdata;
  logic instr_err;

  assign instr_gnt = instr_req;
  assign instr_err = '0;

  `ifdef VERILATOR
    assign clk_sys = IO_CLK;
    assign rst_sys_n = IO_RST_N;
  `else
    initial begin
      rst_sys_n = 1'b0;
      #8
      rst_sys_n = 1'b1;
    end
    always begin
      #1 clk_sys = 1'b0;
      #1 clk_sys = 1'b1;
    end
  `endif

  // Tie-off unused error signals
  assign device_err[Ram] = 1'b0;
  assign device_err[SimCtrl] = 1'b0;

  bus #(
    .NrDevices    ( NrDevices ),  // Number of devices connected to the bus
    .NrHosts      ( NrHosts   ),  // Number of hosts (masters) connected to the bus
    .DataWidth    ( 32        ),  // Data bus width in bits
    .AddressWidth ( 32        )   // Address bus width in bits
  ) u_bus (
    .clk_i               (clk_sys),    // System clock
    .rst_ni              (rst_sys_n),  // Active-low system reset

    // Host (Master) Interface
    .host_req_i          (host_req     ), // Host requests access to the bus
    .host_gnt_o          (host_gnt     ), // Bus grants access to the requesting host
    .host_addr_i         (host_addr    ), // Address from the host
    .host_we_i           (host_we      ), // Write enable signal from the host
    .host_be_i           (host_be      ), // Byte enable for partial writes
    .host_wdata_i        (host_wdata   ), // Write data from the host
    .host_rvalid_o       (host_rvalid  ), // Read data valid signal to the host
    .host_rdata_o        (host_rdata   ), // Read data output to the host
    .host_err_o          (host_err     ), // Error signal to indicate a transaction failure

    // Device (Slave) Interface
    .device_req_o        (device_req   ), // Device request signal (indicating an active transaction)
    .device_addr_o       (device_addr  ), // Address sent to the device
    .device_we_o         (device_we    ), // Write enable signal for the device
    .device_be_o         (device_be    ), // Byte enable for writes to the device
    .device_wdata_o      (device_wdata ), // Write data to the device
    .device_rvalid_i     (device_rvalid), // Read data valid signal from the device
    .device_rdata_i      (device_rdata ), // Read data from the device
    .device_err_i        (device_err   ), // Error signal from the device

    // Configuration Signals
    .cfg_device_addr_base, // Base address for each device
    .cfg_device_addr_mask // Address mask for device selection
  );


  if (SecureIbex) begin : g_mem_rdata_ecc
    logic [31:0] unused_data_rdata;
    logic [31:0] unused_instr_rdata;

    prim_secded_inv_39_32_enc u_data_rdata_intg_gen (
      .data_i (host_rdata[CoreD]),
      .data_o ({data_rdata_intg, unused_data_rdata})
    );

    prim_secded_inv_39_32_enc u_instr_rdata_intg_gen (
      .data_i (instr_rdata),
      .data_o ({instr_rdata_intg, unused_instr_rdata})
    );
  end else begin : g_no_mem_rdata_ecc
    assign data_rdata_intg = '0;
    assign instr_rdata_intg = '0;
  end

  ibex_top_tracing #(
      .SecureIbex      ( SecureIbex       ),
      .ICacheScramble  ( ICacheScramble   ),
      .PMPEnable       ( PMPEnable        ),
      .PMPGranularity  ( PMPGranularity   ),
      .PMPNumRegions   ( PMPNumRegions    ),
      .MHPMCounterNum  ( MHPMCounterNum   ),
      .MHPMCounterWidth( MHPMCounterWidth ),
      .RV32E           ( RV32E            ),
      .RV32M           ( RV32M            ),
      .RV32B           ( RV32B            ),
      .RegFile         ( RegFile          ),
      .BranchTargetALU ( BranchTargetALU  ),
      .ICache          ( ICache           ),
      .ICacheECC       ( ICacheECC        ),
      .WritebackStage  ( WritebackStage   ),
      .BranchPredictor ( BranchPredictor  ),
      .DbgTriggerEn    ( DbgTriggerEn     ),
      .DmBaseAddr      ( 32'h00100000     ),
      .DmAddrMask      ( 32'h00000003     ),
      .DmHaltAddr      ( 32'h00100000     ),
      .DmExceptionAddr ( 32'h00100000     )
    ) u_top (
      .clk_i                  (clk_sys),
      .rst_ni                 (rst_sys_n),

      .test_en_i              (1'b0),
      .scan_rst_ni            (1'b1),
      .ram_cfg_i              (prim_ram_1p_pkg::RAM_1P_CFG_DEFAULT),

      .hart_id_i              (32'b0),
      // First instruction executed is at 0x0 + 0x80
      .boot_addr_i            (32'h00100000),

      .instr_req_o            (instr_req),
      .instr_gnt_i            (instr_gnt),
      .instr_rvalid_i         (instr_rvalid),
      .instr_addr_o           (instr_addr),
      .instr_rdata_i          (instr_rdata),
      .instr_rdata_intg_i     (instr_rdata_intg),
      .instr_err_i            (instr_err),

      .data_req_o             (host_req[CoreD]),
      .data_gnt_i             (host_gnt[CoreD]),
      .data_rvalid_i          (host_rvalid[CoreD]),
      .data_we_o              (host_we[CoreD]),
      .data_be_o              (host_be[CoreD]),
      .data_addr_o            (host_addr[CoreD]),
      .data_wdata_o           (host_wdata[CoreD]),
      .data_wdata_intg_o      (),
      .data_rdata_i           (host_rdata[CoreD]),
      .data_rdata_intg_i      (data_rdata_intg),
      .data_err_i             (host_err[CoreD]),

      .irq_software_i         (1'b0),
      .irq_timer_i            (timer_irq),
      .irq_external_i         (1'b0),
      .irq_fast_i             (15'b0),
      .irq_nm_i               (1'b0),

      .scramble_key_valid_i   ('0),
      .scramble_key_i         ('0),
      .scramble_nonce_i       ('0),
      .scramble_req_o         (),

      .debug_req_i            (1'b0),
      .crash_dump_o           (),
      .double_fault_seen_o    (),

      .fetch_enable_i         (ibex_pkg::IbexMuBiOn),
      .alert_minor_o          (),
      .alert_major_internal_o (),
      .alert_major_bus_o      (),
      .core_sleep_o           ()
    );


    
  // SRAM block for instruction and data storage
  ram_2p #(
      .Depth(MEM_SIZE / 4),
      .MemInitFile(SRAMInitFile)
    ) u_ram (
      .clk_i       (clk_sys),
      .rst_ni      (rst_sys_n),

      .a_req_i     (device_req[Ram]),
      .a_we_i      (device_we[Ram]),
      .a_be_i      (device_be[Ram]),
      .a_addr_i    (device_addr[Ram]),
      .a_wdata_i   (device_wdata[Ram]),
      .a_rvalid_o  (device_rvalid[Ram]),
      .a_rdata_o   (device_rdata[Ram]),

      .b_req_i     (instr_req),
      .b_we_i      (1'b0),
      .b_be_i      (4'b0),
      .b_addr_i    (instr_addr),
      .b_wdata_i   (32'b0),
      .b_rvalid_o  (instr_rvalid),
      .b_rdata_o   (instr_rdata)
    );

  simulator_ctrl #(
    .LogName("cille_demo_system.log")
    ) u_simulator_ctrl (
      .clk_i     (clk_sys),
      .rst_ni    (rst_sys_n),

      .req_i     (device_req[SimCtrl]),
      .we_i      (device_we[SimCtrl]),
      .be_i      (device_be[SimCtrl]),
      .addr_i    (device_addr[SimCtrl]),
      .wdata_i   (device_wdata[SimCtrl]),
      .rvalid_o  (device_rvalid[SimCtrl]),
      .rdata_o   (device_rdata[SimCtrl])
    );

  timer #(
    .DataWidth    (32),
    .AddressWidth (32)
    ) u_timer (
      .clk_i          (clk_sys),
      .rst_ni         (rst_sys_n),

      .timer_req_i    (device_req[Timer]),
      .timer_we_i     (device_we[Timer]),
      .timer_be_i     (device_be[Timer]),
      .timer_addr_i   (device_addr[Timer]),
      .timer_wdata_i  (device_wdata[Timer]),
      .timer_rvalid_o (device_rvalid[Timer]),
      .timer_rdata_o  (device_rdata[Timer]),
      .timer_err_o    (device_err[Timer]),
      .timer_intr_o   (timer_irq)
    );

    // uart_if #(
    //   .DATA_WIDTH(8)
    // ) u_uart (
    //   .sig(device_req[UART]),
    //   .data(device_wdata[UART]),
    //   .valid(device_we[UART]),
    //   .ready(device_rvalid[UART])
    // );

    strider #(
      .DataWidth    (32),
      .AddressWidth (32)
    ) u_strider (
        .clk_i          (clk_sys),
        .rst_ni         (rst_sys_n),
  
        .stride_req_i    (device_req[Strider]),
        .stride_we_i     (device_we[Strider]),
        .stride_be_i     (device_be[Strider]),
        .stride_addr_i   (device_addr[Strider]),
        .stride_wdata_i  (device_wdata[Strider]),
        .stride_rvalid_o (device_rvalid[Strider]),
        .stride_rdata_o  (device_rdata[Strider]),
        .stride_err_o    (device_err[Strider])
  );
  

  multer #(
    .DataWidth    (32),
    .AddressWidth (32)
    ) u_multer (
      .clk_i          (clk_sys),
      .rst_ni         (rst_sys_n),

      .mult_req_i    (device_req[Multer]),
      .mult_we_i     (device_we[Multer]),
      .mult_be_i     (device_be[Multer]),
      .mult_addr_i   (device_addr[Multer]),
      .mult_wdata_i  (device_wdata[Multer]),
      .mult_rvalid_o (device_rvalid[Multer]),
      .mult_rdata_o  (device_rdata[Multer]),
      .mult_err_o    (device_err[Multer])
);

  counter #(
    .DataWidth    (32),
    .AddressWidth (32)
    ) u_counter (
      .clk_i          (clk_sys),
      .rst_ni         (rst_sys_n),

      .counter_req_i    (device_req[Counter]),
      .counter_we_i     (device_we[Counter]),
      .counter_be_i     (device_be[Counter]),
      .counter_addr_i   (device_addr[Counter]),
      .counter_wdata_i  (device_wdata[Counter]),
      .counter_rvalid_o (device_rvalid[Counter]),
      .counter_rdata_o  (device_rdata[Counter]),
      .counter_err_o    (device_err[Counter])
);



  export "DPI-C" function mhpmcounter_num;

  function automatic int unsigned mhpmcounter_num();
    return u_top.u_ibex_top.u_ibex_core.cs_registers_i.MHPMCounterNum;
  endfunction

  export "DPI-C" function mhpmcounter_get;

  function automatic longint unsigned mhpmcounter_get(int index);
    return u_top.u_ibex_top.u_ibex_core.cs_registers_i.mhpmcounter[index];
  endfunction

endmodule
