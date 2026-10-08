// Bounds video work against the audio cadence and paces diagnostic capture like a device callback.

/// Gives video at most one quarter of an audio packet period per send or receive
/// burst. Check between datagrams; even very short periods allow one to progress.
func directPeerVideoWorkBudgetNanoseconds(audioPacketIntervalNanoseconds: UInt64) -> UInt64 {
    max(1, min(250_000, audioPacketIntervalNanoseconds / 4))
}

/// Synthetic capture runs once per negotiated packet period. Network wakes and
/// video fragment bursts must not create extra audio samples.
func directPeerNextSyntheticAudioTime(nowNanoseconds: UInt64, intervalNanoseconds: UInt64) -> UInt64 {
    let next = nowNanoseconds.addingReportingOverflow(max(1, intervalNanoseconds))
    return next.overflow ? UInt64.max : next.partialValue
}
