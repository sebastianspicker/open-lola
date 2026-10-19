// Turns termination signals sent to this process into an orderly stop of tracked child processes.
import Darwin
import Dispatch
import Foundation

/// Handles SIGTERM and SIGINT for a supervisor by stopping every tracked child: stdin EOF first for SSH clients, then SIGTERM, then SIGKILL.
public final class ManagedProcessStopMonitor: @unchecked Sendable {
    /// Called on the monitor's queue for each stop signal; `isRepeat` is false only for the first one.
    public typealias SignalObserver = @Sendable (_ signal: Int32, _ isRepeat: Bool) -> Void

    private let graceSeconds: TimeInterval
    private let standardInputCloseGraceSeconds: TimeInterval
    private let signals: [Int32]
    private let observer: SignalObserver?
    private let queue = DispatchQueue(label: "open-lola.managed-process-stop-monitor")
    /// Runs the blocking EOF/SIGTERM/SIGKILL sequence so `queue` stays free to deliver repeated signals.
    private let terminationQueue = DispatchQueue(label: "open-lola.managed-process-stop-monitor.terminate")
    private let lock = NSLock()
    private var sources: [any DispatchSourceSignal] = []
    private var processes: [ManagedProcess] = []
    private var firstSignal: Int32?

    /// Seconds SIGTERM gets, and then SIGKILL gets, to take effect on a tracked child unless the initializer overrides it.
    public static let defaultGraceSeconds: TimeInterval = 2

    /// Installs the signal sources; the default dispositions are replaced until `invalidate()` is called.
    ///
    /// `observer` lets a process without children, such as one session peer, turn the first signal into a
    /// stop request and a repeated signal into an immediate exit. Children that hold a standard-input pipe
    /// (SSH clients) see EOF first and get `standardInputCloseGraceSeconds` to exit before SIGTERM.
    public init(
        signals: [Int32] = [SIGTERM, SIGINT],
        graceSeconds: TimeInterval = defaultGraceSeconds,
        standardInputCloseGraceSeconds: TimeInterval = ManagedProcessRunner.defaultStandardInputCloseGraceSeconds,
        observer: SignalObserver? = nil
    ) {
        self.signals = signals
        self.graceSeconds = graceSeconds
        self.standardInputCloseGraceSeconds = standardInputCloseGraceSeconds
        self.observer = observer
        for number in signals {
            // The default action must be replaced before the dispatch source can receive the signal.
            // A no-op handler is used instead of SIG_IGN because ignored dispositions are inherited by
            // spawned children, which would then ignore the SIGTERM sent to stop them.
            signal(number) { _ in }
            let source = DispatchSource.makeSignalSource(signal: number, queue: queue)
            source.setEventHandler { [weak self, weak source] in
                // Signals that arrive before the handler runs are coalesced into one event with a count.
                self?.handle(number, deliveries: source?.data ?? 1)
            }
            source.resume()
            sources.append(source)
        }
    }

    /// The first stop signal received, or nil while the run has not been stopped.
    public var receivedSignal: Int32? {
        lock.lock()
        defer { lock.unlock() }
        return firstSignal
    }

    /// Conventional name of `receivedSignal`, for operator-facing notes.
    public var receivedSignalName: String? {
        receivedSignal.map { Self.name(for: $0) }
    }

    /// Adds a child to the stop set; a child tracked after a stop signal is terminated immediately.
    public func track(_ process: ManagedProcess) {
        lock.lock()
        processes.append(process)
        let alreadyStopped = firstSignal != nil
        lock.unlock()
        if alreadyStopped {
            terminateInBackground([process])
        }
    }

    /// Cancels the signal sources and restores the default dispositions.
    public func invalidate() {
        lock.lock()
        let active = sources
        sources = []
        lock.unlock()
        for source in active {
            source.cancel()
        }
        for number in signals {
            signal(number, SIG_DFL)
        }
    }

    private func handle(_ number: Int32, deliveries: UInt) {
        lock.lock()
        guard firstSignal == nil else {
            lock.unlock()
            observer?(number, true)
            return
        }
        firstSignal = number
        let tracked = processes
        lock.unlock()
        observer?(number, false)
        if deliveries > 1 {
            observer?(number, true)
        }
        terminateInBackground(tracked)
    }

    /// Stops `processes` off the signal queue; termination can take several grace periods, and a repeated
    /// Ctrl-C must still reach the observer (and its `_exit`) meanwhile.
    private func terminateInBackground(_ processes: [ManagedProcess]) {
        terminationQueue.async { [graceSeconds, standardInputCloseGraceSeconds] in
            ManagedProcessRunner.terminate(
                processes,
                graceSeconds: graceSeconds,
                standardInputCloseGraceSeconds: standardInputCloseGraceSeconds
            )
        }
    }

    /// Conventional name of a stop signal ("SIGTERM", "SIGINT", otherwise "signal N"), for operator-facing notes.
    public static func name(for number: Int32) -> String {
        switch number {
        case SIGTERM: "SIGTERM"
        case SIGINT: "SIGINT"
        default: "signal \(number)"
        }
    }
}
