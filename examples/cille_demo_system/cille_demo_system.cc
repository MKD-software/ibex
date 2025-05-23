// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include <cassert>
#include <fstream>
#include <iostream>

#include "Vcille_demo_system__Syms.h"
#include "ibex_pcounts.h"
#include "cille_demo_system.h"
#include "verilated_toplevel.h"
#include "verilator_memutil.h"
#include "verilator_sim_ctrl.h"

SimpleSystem::SimpleSystem(const char *ram_hier_path, int ram_size_words)
    : _ram(ram_hier_path, ram_size_words, 4) {}

int SimpleSystem::Main(int argc, char **argv) {
  bool exit_app;
  int ret_code = Setup(argc, argv, exit_app);

  if (exit_app) {
    return ret_code;
  }

  Run();

  if (!Finish()) {
    return 1;
  }

  return 0;
}

std::string SimpleSystem::GetIsaString() const {
  const Vcille_demo_system &top = _top;
  assert(top.cille_demo_system);

  std::string base = top.cille_demo_system->RV32E ? "rv32e" : "rv32i";

  std::string extensions;
  if (top.cille_demo_system->RV32M)
    extensions += "m";

  extensions += "c";

  switch (top.cille_demo_system->RV32B) {
    case 0:  // RV32BNone
      break;

    case 1:  // RV32BBalanced
      extensions += "_Zba_Zbb_Zbs_XZbf_XZbt";
      break;

    case 2:  // RV32BOTEarlGrey
      extensions += "_Zba_Zbb_Zbc_Zbs_XZbf_XZbp_XZbr_XZbt";
      break;

    case 3:  // RV32BFull
      extensions += "_Zba_Zbb_Zbc_Zbs_XZbe_XZbf_XZbp_XZbr_XZbt";
      break;
  }

  return base + extensions;
}

int SimpleSystem::Setup(int argc, char **argv, bool &exit_app) {
  VerilatorSimCtrl &simctrl = VerilatorSimCtrl::GetInstance();

  simctrl.SetTop(&_top, &_top.IO_CLK, &_top.IO_RST_N,
                 VerilatorSimCtrlFlags::ResetPolarityNegative);

  _memutil.RegisterMemoryArea("ram", 0x0, &_ram);
  simctrl.RegisterExtension(&_memutil);

  exit_app = false;
  return simctrl.ParseCommandArgs(argc, argv, exit_app);
}

void SimpleSystem::Run() {
  VerilatorSimCtrl &simctrl = VerilatorSimCtrl::GetInstance();

  std::cout << "Simulation of Ibex" << std::endl
            << "==================" << std::endl
            << std::endl;

  simctrl.RunSimulation();
}

bool SimpleSystem::Finish() {
  VerilatorSimCtrl &simctrl = VerilatorSimCtrl::GetInstance();

  if (!simctrl.WasSimulationSuccessful()) {
    return false;
  }

  // Set the scope to the root scope, the ibex_pcount_string function otherwise
  // doesn't know the scope itself. Could be moved to ibex_pcount_string, but
  // would require a way to set the scope name from here, similar to MemUtil.
  svSetScope(svGetScopeFromName("TOP.cille_demo_system"));

  std::cout << "\nPerformance Counters" << std::endl
            << "====================" << std::endl;
  std::cout << ibex_pcount_string(false);

  std::ofstream pcount_csv("cille_demo_system_pcount.csv");
  pcount_csv << ibex_pcount_string(true);

  return true;
}
