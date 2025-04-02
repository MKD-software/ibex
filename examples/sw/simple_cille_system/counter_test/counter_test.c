// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "simple_system_common.h"
#define COUNTER_BASE_ADDR 0x40000  // Base address of the counter
#define COUNTER_OFFSET     0x0     // Offset (assuming the counter value is at base)
#define TARGET_ADDR ((volatile uint32_t *)0x40000)

int main(int argc, char **argv) {
  pcount_enable(0);
  pcount_reset();
  pcount_enable(1);

  puts("\nThis is a simple test to check the implementation of the counter.sv module\n");
  puts("Check the value is correct in GTKWave on the counter_d signal\n");
  puts("Use cmd: gtkwave sim.fst in root\n");


  uint16_t a = 3, b = 4;
  uint32_t result = multer_compute(a, b);
  
  puts("Multer value: ");
  puthex(result);
  puts("\n");

  pcount_enable(0);

  timer_enable(2000);
  
  timecmp_update(1000);  // Set the compare value

  uint64_t last_elapsed_time = get_elapsed_time();

  // Loop until a specific time (for example, 4 time units)
  while (last_elapsed_time <= 4) {
    uint64_t cur_time = get_elapsed_time();
    if (cur_time != last_elapsed_time) {
      last_elapsed_time = cur_time;

      // Toggle between "Tick!" and "Tock!" based on elapsed time
      if (last_elapsed_time & 1) {
        puts("Tick!\n");
      } else {
        puts("Tock!\n");
      }
    }
    asm volatile("wfi");  // Wait for interrupt (simulation purpose)
  }

  return 0;
}

