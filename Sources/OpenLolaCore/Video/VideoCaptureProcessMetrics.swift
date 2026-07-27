// Manages VideoCaptureProcessMetrics resource handling, keeping file-descriptor and process lifetime details out of calling workflows.
#if canImport(Darwin)
import Darwin
#endif

func currentVideoCaptureProcessCpu() -> VideoProcessCpuMetrics? {
    #if canImport(Darwin)
    var info = rusage()
    guard getrusage(RUSAGE_SELF, &info) == 0 else {
        return nil
    }
    let user = Double(info.ru_utime.tv_sec) + Double(info.ru_utime.tv_usec) / 1_000_000
    let system = Double(info.ru_stime.tv_sec) + Double(info.ru_stime.tv_usec) / 1_000_000
    return VideoProcessCpuMetrics(userSeconds: user, systemSeconds: system)
    #else
    return nil
    #endif
}

func videoCaptureProcessCpuDelta(
    from start: VideoProcessCpuMetrics?,
    to end: VideoProcessCpuMetrics?
) -> VideoProcessCpuMetrics? {
    guard let start, let end else {
        return end
    }
    return VideoProcessCpuMetrics(
        userSeconds: max(0, end.userSeconds - start.userSeconds),
        systemSeconds: max(0, end.systemSeconds - start.systemSeconds)
    )
}

func currentVideoCaptureProcessMemory() -> VideoProcessMemoryMetrics? {
    #if canImport(Darwin)
    var info = rusage()
    guard getrusage(RUSAGE_SELF, &info) == 0 else {
        return nil
    }
    return VideoProcessMemoryMetrics(residentPeakBytes: UInt64(max(0, info.ru_maxrss)))
    #else
    return nil
    #endif
}
