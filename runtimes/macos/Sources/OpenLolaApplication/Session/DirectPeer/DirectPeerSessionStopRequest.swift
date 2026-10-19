// Carries an operator stop (SIGTERM/SIGINT) from the signal queue to a direct-peer session loop so the run ends through its normal teardown.
import COpenLolaAtomics
import Darwin
import Dispatch
import Foundation
import OpenLolaIntegrations

/// Lock-free stop flag shared by a signal handler and one direct-peer session's control/media loop.
///
/// Only the session loop thread polls it; the realtime audio callback never reads it. The same word records
/// whether the media loop has started, so a stop request and the media start are ordered against each other.
public final class DirectPeerSessionStopRequest: @unchecked Sendable {
    private static let requestedBit: UInt64 = 1 << 32
    private static let mediaStartedBit: UInt64 = 1 << 33
    private static let signalMask: UInt64 = 0xFFFF_FFFF
    private let storage: UnsafeMutablePointer<OpenLolaAtomicUInt64>

    /// Creates a flag that has not been requested.
    public init() {
        storage = .allocate(capacity: 1)
        open_lola_atomic_u64_init(storage, 0)
    }

    deinit {
        storage.deallocate()
    }

    /// Records a stop caused by `number`; only the first request is kept. Returns true for the first request.
    @discardableResult
    public func request(signal number: Int32) -> Bool {
        var expected = open_lola_atomic_u64_load(storage)
        while expected & Self.requestedBit == 0 {
            let desired = (expected & Self.mediaStartedBit) | Self.requestedBit
                | UInt64(UInt32(bitPattern: number))
            if open_lola_atomic_u64_compare_exchange(storage, &expected, desired) {
                return true
            }
        }
        return false
    }

    /// True once a stop has been requested.
    public var isRequested: Bool {
        open_lola_atomic_u64_load(storage) & Self.requestedBit != 0
    }

    /// Records that the media loop is starting; from here on a stop must go through the loop's teardown.
    public func markMediaStarted() {
        var expected = open_lola_atomic_u64_load(storage)
        while expected & Self.mediaStartedBit == 0,
              !open_lola_atomic_u64_compare_exchange(storage, &expected, expected | Self.mediaStartedBit) {}
    }

    /// True once the media loop has started.
    public var isMediaStarted: Bool {
        open_lola_atomic_u64_load(storage) & Self.mediaStartedBit != 0
    }

    /// The signal that requested the stop, or nil while the run has not been stopped.
    public var signalNumber: Int32? {
        let value = open_lola_atomic_u64_load(storage)
        guard value & Self.requestedBit != 0 else { return nil }
        return Int32(bitPattern: UInt32(truncatingIfNeeded: value & Self.signalMask))
    }

    /// Conventional name of `signalNumber`, for operator-facing notes.
    public var signalName: String? {
        signalNumber.map { ManagedProcessStopMonitor.name(for: $0) }
    }

    /// Marks a report from a stopped run: appends the stop note once and keeps the verdict at PARTIAL.
    public func annotating(_ report: DirectPeerSessionReport) -> DirectPeerSessionReport {
        guard let signalName else { return report }
        let note = "Run stopped by signal (\(signalName)) before the requested duration ended; "
            + "teardown ran normally."
        var annotated = report
        annotated.verdict = .partial
        if !annotated.notes.contains(note) {
            annotated.notes += annotated.notes.isEmpty ? note : " \(note)"
        }
        return annotated
    }
}

public extension DirectPeerSessionStopRequest {
    /// Signal observer for one session peer: the first SIGTERM/SIGINT requests the stop, and a later one exits at once.
    ///
    /// Before the media loop starts the peer is blocked in a handshake, metadata, media-start or timing-probe
    /// receive that does not poll the flag, and nothing needs restoring yet, so the first signal exits with
    /// `128 + signal` at once instead of waiting for the receive timeout. A terminal Ctrl-C reaches a supervised
    /// peer directly and is followed within milliseconds by the supervisor's own SIGTERM, so repeats inside
    /// `repeatGraceSeconds` count as the same stop request. `exit` is injectable for tests.
    func signalObserver(
        repeatGraceSeconds: Double = 0.5,
        exit: @escaping @Sendable (Int32) -> Void = { _exit($0) }
    ) -> ManagedProcessStopMonitor.SignalObserver {
        let firstSignal = DirectPeerFirstSignalTime()
        return { [self] number, isRepeat in
            if isRepeat {
                guard firstSignal.secondsSince() >= repeatGraceSeconds else { return }
                exit(128 + number)
                return
            }
            firstSignal.mark()
            request(signal: number)
            let name = ManagedProcessStopMonitor.name(for: number)
            guard isMediaStarted else {
                FileHandle.standardError.write(Data(
                    "\(name) received before media started; exiting without a report\n".utf8
                ))
                exit(128 + number)
                return
            }
            FileHandle.standardError.write(Data(
                "\(name) received; stopping the session and writing the report\n".utf8
            ))
        }
    }
}

/// Time of the first stop signal; only touched from the stop monitor's serial queue.
private final class DirectPeerFirstSignalTime: @unchecked Sendable {
    private var uptimeNanoseconds: UInt64 = 0

    func mark() {
        uptimeNanoseconds = DispatchTime.now().uptimeNanoseconds
    }

    func secondsSince() -> Double {
        Double(DispatchTime.now().uptimeNanoseconds &- uptimeNanoseconds) / 1_000_000_000
    }
}
