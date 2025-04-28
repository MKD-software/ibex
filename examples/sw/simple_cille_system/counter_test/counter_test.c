// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "simple_system_common.h"
#define SLAVE_ADDR ((volatile uint32_t *)0x40000)

int main(int argc, char **argv) {
  pcount_enable(0);
  pcount_reset();
  pcount_enable(1);

  puts("\nThis is a simple test to check the implementation of the strider.sv module\n");
  puts("Use cmd: gtkwave sim.fst in root\n\n");

  puts("Base adress before stride: ");
  puthex(*SLAVE_ADDR);
  puts("\n");

  puts("\nApplying window at the adress......\n");
  puts("Move window 3 down and 4 right with stride of 2\n");


  uint16_t a = 3, b = 4;
  uint32_t result = multer_compute(a, b);
  
  puts("Calculated adress after stride: ");
  puthex(result);
  puts("\n");
  puts("\nApplying window at the new adress......\n");
  puts("Move window 3 down and 4 right with stride of 2\n");

  a = 6;
  b = 8;
  result = multer_compute(a, b);
  
  puts("Calculated adress after stride: ");
  puthex(result);
  puts("\n");
  puts("\nApplying window at the new adress......\n");


  pcount_enable(0);

  timer_enable(2000);
  
  timecmp_update(1000);  // Set the compare value

  //uint64_t last_elapsed_time = get_elapsed_time();

  // // Loop until a specific time (for example, 4 time units)
  // while (last_elapsed_time <= 4) {
  //   uint64_t cur_time = get_elapsed_time();
  //   if (cur_time != last_elapsed_time) {
  //     last_elapsed_time = cur_time;

  //     // Toggle between "Tick!" and "Tock!" based on elapsed time
  //     if (last_elapsed_time & 1) {
  //       puts("Tick!\n");
  //     } else {
  //       puts("Tock!\n");
  //     }
  //   }
  //   asm volatile("wfi");  // Wait for interrupt (simulation purpose)
  // }

  puts("Simulation finished\n");

  return 0;
}

