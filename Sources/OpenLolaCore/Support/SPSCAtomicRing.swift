import COpenLolaAtomics
import Darwin
import Foundation

public enum SPSCAtomicRingResult: Equatable, Sendable {
    case stored
    case empty
    case full
    case invalid
}

public final class SPSCUInt64Ring: @unchecked Sendable {
    public let capacity: Int

    private let storage: UnsafeMutableBufferPointer<UInt64>
    // Correctness depends on COpenLolaAtomics implementing release stores and acquire loads:
    // open_lola_atomic_u64_store with memory_order_release and
    // open_lola_atomic_u64_load with memory_order_acquire.
    private var readIndex: OpenLolaAtomicUInt64
    private var writeIndex: OpenLolaAtomicUInt64
    private var producerThreadID: OpenLolaAtomicUInt64
    private var consumerThreadID: OpenLolaAtomicUInt64
    private var ownerViolationCountStorage: OpenLolaAtomicUInt64

    public init(capacity: Int) {
        precondition(capacity > 0, "capacity must be positive")
        precondition(UInt64(capacity) <= UInt64.max / 2, "capacity must preserve SPSC wrap-distance ordering")
        self.capacity = capacity
        self.storage = UnsafeMutableBufferPointer<UInt64>.allocate(capacity: capacity)
        self.storage.initialize(repeating: 0)
        self.readIndex = OpenLolaAtomicUInt64()
        self.writeIndex = OpenLolaAtomicUInt64()
        self.producerThreadID = OpenLolaAtomicUInt64()
        self.consumerThreadID = OpenLolaAtomicUInt64()
        self.ownerViolationCountStorage = OpenLolaAtomicUInt64()
        open_lola_atomic_u64_init(&readIndex, 0)
        open_lola_atomic_u64_init(&writeIndex, 0)
        open_lola_atomic_u64_init(&producerThreadID, 0)
        open_lola_atomic_u64_init(&consumerThreadID, 0)
        open_lola_atomic_u64_init(&ownerViolationCountStorage, 0)
    }

    public var ownerViolationCount: Int {
        Int(open_lola_atomic_u64_load(&ownerViolationCountStorage))
    }

    deinit {
        storage.deinitialize()
        storage.deallocate()
    }

    public func push(_ value: UInt64) -> SPSCAtomicRingResult {
        guard validateSingleOwner(&producerThreadID) else {
            return .invalid
        }
        let write = open_lola_atomic_u64_load(&writeIndex)
        let read = open_lola_atomic_u64_load(&readIndex)
        // This load-check-store sequence is safe only for SPSC ownership: the producer
        // is the sole writer of writeIndex and the consumer is the sole writer of readIndex.
        // Release/acquire atomics publish storage writes before writeIndex advances and
        // publish consumed slots before readIndex advances.
        // Unsigned subtraction is intentional: capacity is bounded to less than half the UInt64 range,
        // so write-read distinguishes full from empty even as indices wrap.
        guard write - read < UInt64(capacity) else {
            return .full
        }
        storage[Int(write % UInt64(capacity))] = value
        open_lola_atomic_u64_store(&writeIndex, write &+ 1)
        return .stored
    }

    public func pop() -> UInt64? {
        guard validateSingleOwner(&consumerThreadID) else {
            return nil
        }
        let read = open_lola_atomic_u64_load(&readIndex)
        let write = open_lola_atomic_u64_load(&writeIndex)
        // The producer cannot mutate readIndex and the consumer cannot mutate writeIndex;
        // changing that ownership model would make the check/use sequence a TOCTOU race.
        guard read < write else {
            return nil
        }
        let value = storage[Int(read % UInt64(capacity))]
        open_lola_atomic_u64_store(&readIndex, read &+ 1)
        return value
    }

    private func validateSingleOwner(_ owner: inout OpenLolaAtomicUInt64) -> Bool {
        let currentThreadID = currentSPSCThreadID()
        var expected: UInt64 = 0
        if open_lola_atomic_u64_compare_exchange(&owner, &expected, currentThreadID) {
            return true
        }
        let registeredThreadID = open_lola_atomic_u64_load(&owner)
        guard registeredThreadID == currentThreadID else {
            _ = open_lola_atomic_u64_fetch_add(&ownerViolationCountStorage, 1)
            return false
        }
        return true
    }
}

private func currentSPSCThreadID() -> UInt64 {
    var threadID: UInt64 = 0
    pthread_threadid_np(nil, &threadID)
    return max(threadID, 1)
}
