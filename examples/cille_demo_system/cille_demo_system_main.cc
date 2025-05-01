// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "cille_demo_system.h"

int main(int argc, char **argv) {
  SimpleSystem cille_demo_system(
      "TOP.cille_demo_system.u_ram.u_ram.gen_generic.u_impl_generic",
      1024 * 1024);

  return cille_demo_system.Main(argc, argv);
}
