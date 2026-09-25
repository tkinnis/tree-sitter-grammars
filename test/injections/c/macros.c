// Every register's offset.
#define REG_OFFSET (0x0004u)
#define REG_READ(base) (*(volatile unsigned *)((base) + REG_OFFSET))
#define REG_CLEAR(base) do { *(base) = 0; } while (0)

#pragma once
#pragma GCC diagnostic ignored "-Wunused-macros"
#error "unsupported target"

/* A value, not a directive. */
static const unsigned limit = REG_OFFSET;
