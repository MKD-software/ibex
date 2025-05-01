// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "simple_system_common.h"
#define MULTER_ADDR ((volatile uint32_t *)0x40000)


int putchar(int c) {
  DEV_WRITE(SIM_CTRL_BASE + SIM_CTRL_OUT, (unsigned char)c);

  return c;
}

int puts(const char *str) {
  while (*str) {
    putchar(*str++);
  }

  return 0;
}

void print_int(int num) {
  char buffer[12]; // Enough for 32-bit int (-2147483648 to 2147483647)
  int i = 0, is_negative = 0;

  // Handle negative numbers
  if (num < 0) {
      is_negative = 1;
      num = -num;
  }

  // Convert digits to string (in reverse order)
  do {
      buffer[i++] = (num % 10) + '0';
      num /= 10;
  } while (num > 0);

  // Add negative sign if needed
  if (is_negative) {
      buffer[i++] = '-';
  }

  // Print in correct order
  while (i--) {
      putchar(buffer[i]);
  }
}


void puthex(uint32_t h) {
  int cur_digit;
  // Iterate through h taking top 4 bits each time and outputting ASCII of hex
  // digit for those 4 bits
  for (int i = 0; i < 8; i++) {
    cur_digit = h >> 28;

    if (cur_digit < 10)
      putchar('0' + cur_digit);
    else
      putchar('A' - 10 + cur_digit);

    h <<= 4;
  }
}

void sim_halt() { DEV_WRITE(SIM_CTRL_BASE + SIM_CTRL_CTRL, 1); }

void pcount_reset() {
  asm volatile(
      "csrw minstret,       x0\n"
      "csrw mcycle,         x0\n"
      "csrw mhpmcounter3,   x0\n"
      "csrw mhpmcounter4,   x0\n"
      "csrw mhpmcounter5,   x0\n"
      "csrw mhpmcounter6,   x0\n"
      "csrw mhpmcounter7,   x0\n"
      "csrw mhpmcounter8,   x0\n"
      "csrw mhpmcounter9,   x0\n"
      "csrw mhpmcounter10,  x0\n"
      "csrw mhpmcounter11,  x0\n"
      "csrw mhpmcounter12,  x0\n"
      "csrw mhpmcounter13,  x0\n"
      "csrw mhpmcounter14,  x0\n"
      "csrw mhpmcounter15,  x0\n"
      "csrw mhpmcounter16,  x0\n"
      "csrw mhpmcounter17,  x0\n"
      "csrw mhpmcounter18,  x0\n"
      "csrw mhpmcounter19,  x0\n"
      "csrw mhpmcounter20,  x0\n"
      "csrw mhpmcounter21,  x0\n"
      "csrw mhpmcounter22,  x0\n"
      "csrw mhpmcounter23,  x0\n"
      "csrw mhpmcounter24,  x0\n"
      "csrw mhpmcounter25,  x0\n"
      "csrw mhpmcounter26,  x0\n"
      "csrw mhpmcounter27,  x0\n"
      "csrw mhpmcounter28,  x0\n"
      "csrw mhpmcounter29,  x0\n"
      "csrw mhpmcounter30,  x0\n"
      "csrw mhpmcounter31,  x0\n"
      "csrw minstreth,      x0\n"
      "csrw mcycleh,        x0\n"
      "csrw mhpmcounter3h,  x0\n"
      "csrw mhpmcounter4h,  x0\n"
      "csrw mhpmcounter5h,  x0\n"
      "csrw mhpmcounter6h,  x0\n"
      "csrw mhpmcounter7h,  x0\n"
      "csrw mhpmcounter8h,  x0\n"
      "csrw mhpmcounter9h,  x0\n"
      "csrw mhpmcounter10h, x0\n"
      "csrw mhpmcounter11h, x0\n"
      "csrw mhpmcounter12h, x0\n"
      "csrw mhpmcounter13h, x0\n"
      "csrw mhpmcounter14h, x0\n"
      "csrw mhpmcounter15h, x0\n"
      "csrw mhpmcounter16h, x0\n"
      "csrw mhpmcounter17h, x0\n"
      "csrw mhpmcounter18h, x0\n"
      "csrw mhpmcounter19h, x0\n"
      "csrw mhpmcounter20h, x0\n"
      "csrw mhpmcounter21h, x0\n"
      "csrw mhpmcounter22h, x0\n"
      "csrw mhpmcounter23h, x0\n"
      "csrw mhpmcounter24h, x0\n"
      "csrw mhpmcounter25h, x0\n"
      "csrw mhpmcounter26h, x0\n"
      "csrw mhpmcounter27h, x0\n"
      "csrw mhpmcounter28h, x0\n"
      "csrw mhpmcounter29h, x0\n"
      "csrw mhpmcounter30h, x0\n"
      "csrw mhpmcounter31h, x0\n");
}

unsigned int get_mepc() {
  uint32_t result;
  __asm__ volatile("csrr %0, mepc;" : "=r"(result));
  return result;
}

unsigned int get_mcause() {
  uint32_t result;
  __asm__ volatile("csrr %0, mcause;" : "=r"(result));
  return result;
}

unsigned int get_mtval() {
  uint32_t result;
  __asm__ volatile("csrr %0, mtval;" : "=r"(result));
  return result;
}

void simple_exc_handler(void) {
  puts("EXCEPTION!!!\n");
  puts("============\n");
  puts("MEPC:   0x");
  puthex(get_mepc());
  puts("\nMCAUSE: 0x");
  puthex(get_mcause());
  puts("\nMTVAL:  0x");
  puthex(get_mtval());
  putchar('\n');
  sim_halt();

  while(1);
}

volatile uint64_t time_elapsed;
uint64_t time_increment;

inline static void increment_timecmp(uint64_t time_base) {
  uint64_t current_time = timer_read();
  current_time += time_base;
  timecmp_update(current_time);
}

void timer_enable(uint64_t time_base) {
  time_elapsed = 0;
  time_increment = time_base;
  // Set timer values
  increment_timecmp(time_base);
  // enable timer interrupt
  asm volatile("csrs  mie, %0\n" : : "r"(0x80));
  // enable global interrupt
  asm volatile("csrs  mstatus, %0\n" : : "r"(0x8));
}

void timer_disable(void) { asm volatile("csrc  mie, %0\n" : : "r"(0x80)); }

uint64_t timer_read(void) {
  uint32_t current_timeh;
  uint32_t current_time;
  // check if time overflowed while reading and try again
  do {
    current_timeh = DEV_READ(TIMER_BASE + TIMER_MTIMEH, 0);
    current_time = DEV_READ(TIMER_BASE + TIMER_MTIME, 0);
  } while (current_timeh != DEV_READ(TIMER_BASE + TIMER_MTIMEH, 0));
  uint64_t final_time = ((uint64_t)current_timeh << 32) | current_time;
  return final_time;
}

void timecmp_update(uint64_t new_time) {
  DEV_WRITE(TIMER_BASE + TIMER_MTIMECMP, -1);
  DEV_WRITE(TIMER_BASE + TIMER_MTIMECMPH, new_time >> 32);
  DEV_WRITE(TIMER_BASE + TIMER_MTIMECMP, new_time);
}

uint64_t get_elapsed_time(void) { return time_elapsed; }

void simple_timer_handler(void) __attribute__((interrupt));

void simple_timer_handler(void) {
  increment_timecmp(time_increment);
  time_elapsed++;
}



volatile uint32_t count_elapsed;
uint32_t count_increment;

// Enable the counter peripheral by initializing the elapsed counter,
// setting the increment value, updating the compare register, and enabling interrupts.
void counter_enable(uint32_t count_base) {
  count_elapsed = 0;
  count_increment = count_base;
}

// Read the current counter value from the memory-mapped register (32-bit)
uint32_t counter_read(void) {
  return DEV_READ(COUNTER_BASE, 0);
}

// Update the counter compare register (32-bit)
void count_update(uint32_t new_count) {
  *(volatile uint32_t*)COUNTER_BASE = new_count;
}


uint32_t multer_compute(uint16_t num1, uint16_t num2) {
  uint32_t packed_value = ((uint32_t)num2 << 16) | num1;  // Pack into 32-bit
  *MULTER_ADDR = packed_value;  // Write to multiplier
  return *MULTER_ADDR;  // Read and return the result
}


