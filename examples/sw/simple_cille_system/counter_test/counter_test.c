// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "simple_system_common.h"
#define COUNTER_BASE_ADDR 0x40000  // Base address of the counter
#define COUNTER_OFFSET     0x0     // Offset (assuming the counter value is at base)

int main(int argc, char **argv) {
  pcount_enable(0);
  pcount_reset();
  pcount_enable(1);

  puts("\nThis is a simple test to check the implementation of the counter.sv module\n");
  puts("Check the value is correct in GTKWave on the counter_d signal\n");
  puts("Use cmd: gtkwave sim.fst in root\n");


  // volatile uint32_t *ptr = (volatile uint32_t *)COUNTER_BASE;
  // *ptr = 0x12345678;  // Try writing a test value
  // uint32_t value = *ptr;
  // puthex(value);
  

  pcount_enable(0);

  // Enable periodic timer interrupt
  // (the actual timebase is a bit meaningless in simulation)
  timer_enable(2000);

  counter_enable(0);

  
  uint32_t last_elapsed_count = counter_read();
  puts("Initial elapsed count: ");
  puthex(last_elapsed_count);

  count_update(100);  // Set the compare value to maximum
  last_elapsed_count = counter_read();
  puts("\nInitial elapsed count: ");
  puthex(last_elapsed_count);
  puts("\n");


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

  last_elapsed_time = get_elapsed_time();
  puts("Final elapsed time: ");
  puthex(last_elapsed_time);
  puts("\n");

  return 0;
}

