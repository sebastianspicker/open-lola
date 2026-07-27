/* Declares the C11 atomic ABI that keeps Swift wrappers independent of atomics details. */
#ifndef OPEN_LOLA_ATOMICS_H
#define OPEN_LOLA_ATOMICS_H

#include <stdbool.h>
#include <stdint.h>

typedef struct OpenLolaAtomicUInt64 {
    // cppcheck-suppress unusedStructMember
    _Atomic(uint64_t) value;
} OpenLolaAtomicUInt64;

/* Initialize storage before it becomes reachable by concurrent Swift code. */
void open_lola_atomic_u64_init(OpenLolaAtomicUInt64 *atomic, uint64_t value);

/* Loads use memory_order_acquire so Swift wrappers observe peer-published state. */
uint64_t open_lola_atomic_u64_load(const OpenLolaAtomicUInt64 *atomic);

/* Stores use memory_order_release so Swift wrappers publish preceding writes. */
void open_lola_atomic_u64_store(OpenLolaAtomicUInt64 *atomic, uint64_t value);

/* Read-modify-write helpers use acquire-release ordering; failed CAS loads use acquire. */
uint64_t open_lola_atomic_u64_fetch_add(OpenLolaAtomicUInt64 *atomic, uint64_t value);
/* Atomically replace the expected value while preserving Swift-visible happens-before edges. */
bool open_lola_atomic_u64_compare_exchange(
    OpenLolaAtomicUInt64 *atomic,
    uint64_t *expected,
    uint64_t desired
);

#endif
