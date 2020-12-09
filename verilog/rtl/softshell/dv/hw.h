#ifndef SOFTSHELL_DV_HW_H_
#define SOFTSHELL_DV_HW_H_

#include <stdint.h>
#include <stdbool.h>

extern uint32_t flashio_worker_begin;
extern uint32_t flashio_worker_end;

// Addresses.
#define GPIO_BASE_ADDR 0x20000000

// GPIO peripheral.
#define REG_GPIO_DATA (*(volatile uint32_t*)(GPIO_BASE_ADDR + 0x00))
#define REG_GPIO_ENA  (*(volatile uint32_t*)(GPIO_BASE_ADDR + 0x04))
#define REG_GPIO_PU   (*(volatile uint32_t*)(GPIO_BASE_ADDR + 0x08))
#define REG_GPIO_PD   (*(volatile uint32_t*)(GPIO_BASE_ADDR + 0x0c))

#endif  // SOFTSHELL_DV_
