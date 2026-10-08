// Routes deterministic test injection through the same independently owned callback storage.
import CoreAudio

extension DirectPeerRealtimeAudioGraph {
    func captureInputForTesting(input: UnsafePointer<AudioBufferList>, hostTimeNanoseconds: UInt64) {
        callbackState.captureInputForTesting(input: input, hostTimeNanoseconds: hostTimeNanoseconds)
    }

    func renderPlayoutForTesting(output: UnsafeMutablePointer<AudioBufferList>) {
        callbackState.renderPlayoutForTesting(output: output)
    }

    #if DEBUG
    func setIOProcRunningForTesting(_ running: Bool) {
        callbackState.setIOProcRunningForTesting(running)
    }
    #endif
}
