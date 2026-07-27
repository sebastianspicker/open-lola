/* Implements the C11 atomic ABI used by Swift across the concurrency boundary. */
#include "include/OpenLolaAtomics.h"

#include <stdatomic.h>

void open_lola_atomic_u64_init(OpenLolaAtomicUInt64 *atomic, uint64_t value) {
    /* Initialization happens before publication, so no inter-thread ordering is needed. */
    atomic_init(&atomic->value, value);
}

uint64_t open_lola_atomic_u64_load(const OpenLolaAtomicUInt64 *atomic) {
    return atomic_load_explicit(&atomic->value, memory_order_acquire);
}

void open_lola_atomic_u64_store(OpenLolaAtomicUInt64 *atomic, uint64_t value) {
    atomic_store_explicit(&atomic->value, value, memory_order_release);
}

uint64_t open_lola_atomic_u64_fetch_add(OpenLolaAtomicUInt64 *atomic, uint64_t value) {
    return atomic_fetch_add_explicit(&atomic->value, value, memory_order_acq_rel);
}

bool open_lola_atomic_u64_compare_exchange(
    OpenLolaAtomicUInt64 *atomic,
    uint64_t *expected,
    uint64_t desired
) {
    /*
     * On compare-exchange failure C only loads the current value into
     * `expected`; acquire ordering is the strongest valid failure ordering
     * needed by the Swift wrapper, while success publishes the desired value.
     */
    return atomic_compare_exchange_strong_explicit(
        &atomic->value,
        expected,
        desired,
        memory_order_acq_rel,
        memory_order_acquire
    );
}
