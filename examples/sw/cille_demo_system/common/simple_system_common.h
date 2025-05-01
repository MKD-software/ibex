// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef SIMPLE_SYSTEM_COMMON_H__
#define COUNTER_BASE ((volatile uint32_t *)0x40000)
#include <stdint.h>

#include "simple_system_regs.h"

#define DEV_WRITE(addr, val) (*((volatile uint32_t *)(addr)) = val)
#define DEV_READ(addr, val) (*((volatile uint32_t *)(addr)))
#define PCOUNT_READ(name, dst) asm volatile("csrr %0, " #name ";" : "=r"(dst))

/**
 * Writes character to simulator out log. Signature matches c stdlib function
 * of the same name.
 *
 * @param c Character to output
 * @returns Character output (never fails so no EOF ever returned)
 */
int putchar(int c);

/**
 * Writes string to simulator out log.  Signature matches c stdlib function of
 * the same name.
 *
 * @param str String to output
 * @returns 0 always (never fails so no error)
 */
int puts(const char *str);

/**
 * Writes ASCII hex representation of number to simulator out log.
 *
 * @param h Number to output in hex
 */
void puthex(uint32_t h);

/**
 * Immediately halts the simulation
 */
void sim_halt();

/**
 * Enables/disables performance counters.  This effects mcycle and minstret as
 * well as the mhpmcounterN counters.
 *
 * @param enable if non-zero enables, otherwise disables
 */
static inline void pcount_enable(int enable) {
  // Note cycle is disabled with everything else
  unsigned int inhibit_val = enable ? 0x0 : 0xFFFFFFFF;
  // CSR 0x320 was called `mucounteren` in the privileged spec v1.9.1, it was
  // then dropped in v1.10, and then re-added in v1.11 with the name
  // `mcountinhibit`. Unfortunately, the version of binutils we use only allows
  // the old name, and LLVM only supports the new name (though this is changed
  // on trunk to support both), so we use the numeric value here for maximum
  // compatibility.
  asm volatile("csrw  0x320, %0\n" : : "r"(inhibit_val));
}

/**
 * Resets all performance counters.  This effects mcycle and minstret as well
 * as the mhpmcounterN counters.
 */
void pcount_reset();

/**
 * Enables timer interrupt
 *
 * @param time_base Number of time ticks to count before interrupt
 */
void timer_enable(uint64_t time_base);

/**
 * Returns current mtime value
 */
uint64_t timer_read(void);

/**
 * Set a new timer value
 *
 * @param new_time New value for time
 */
void timecmp_update(uint64_t new_time);

/**
 * Disables timer interrupt
 */
void timer_disable(void);

/**
 * Returns current global time value
 */
uint64_t get_elapsed_time(void);



// /* Counter functions -----------------*/

// Enable the counter peripheral by initializing the elapsed counter,
// setting the increment value, updating the compare register, and enabling interrupts.
void counter_enable(uint32_t count_base);

// Read the current counter value from the memory-mapped register (32-bit)
uint32_t counter_read(void);

// Update the counter compare register (32-bit)
void count_update(uint32_t new_count);


// Function to write two 16-bit numbers to the multiplier and read the result
uint32_t multer_compute(uint16_t num1, uint16_t num2);


/**
 * Enables/disables the instruction cache. This has no effect on Ibex
 * configurations that do not have an instruction cache and in particular is
 * safe to execute on those configurations.
 *
 * @param enable if non-zero enables, otherwise disables
 */
static inline void icache_enable(int enable) {
  if (enable) {
    // Set icache enable bit in CPUCTRLSTS
    asm volatile("csrs 0x7c0, 1");
  } else {
    // Clear icache enable bit in CPUCTRLSTS
    asm volatile("csrc 0x7c0, 1");
  }
}

#endif
