// Resamples decoded interleaved PCM inside the reusable realtime media adapter.
import Foundation

package final class LoLaLinearPCMResampler: @unchecked Sendable {
    private let inputRate: Int
    private let outputRate: Int
    private let channels: Int
    private var input: [Float] = []
    private var position: Double = 0

    package init(inputRate: Int, outputRate: Int, channels: Int) {
        self.inputRate = max(1, inputRate)
        self.outputRate = max(1, outputRate)
        self.channels = max(1, channels)
    }

    package func append(_ samples: [Float]) {
        input.append(contentsOf: samples)
    }

    package func appendAndProduce(_ samples: [Float]) -> [Float] {
        append(samples)
        return produce()
    }

    package func reset() {
        input.removeAll(keepingCapacity: true)
        position = 0
    }

    package func produce() -> [Float] {
        let frameCount = input.count / channels
        if inputRate == outputRate {
            let sampleCount = frameCount * channels
            guard sampleCount > 0 else { return [] }
            let output = Array(input.prefix(sampleCount))
            input.removeFirst(sampleCount)
            position = 0
            return output
        }
        guard frameCount > 1 else { return [] }
        let step = Double(inputRate) / Double(outputRate)
        var output: [Float] = []
        while position + 1 < Double(frameCount) {
            let baseFrame = Int(position)
            let fraction = Float(position - Double(baseFrame))
            for channel in 0..<channels {
                let currentSample = input[baseFrame * channels + channel]
                let nextSample = input[(baseFrame + 1) * channels + channel]
                output.append(currentSample + (nextSample - currentSample) * fraction)
            }
            position += step
        }
        let consumedFrames = max(0, Int(position) - 1)
        if consumedFrames > 0 {
            input.removeFirst(consumedFrames * channels)
            position -= Double(consumedFrames)
        }
        return output
    }
}

package func interleavedFloatData(fromInt16LittleEndian data: Data) -> [Float] {
    let bytes = [UInt8](data)
    var output: [Float] = []
    output.reserveCapacity(bytes.count / 2)
    var index = 0
    while index + 1 < bytes.count {
        let raw = UInt16(bytes[index]) | (UInt16(bytes[index + 1]) << 8)
        output.append(Float(Int16(bitPattern: raw)) / 32768.0)
        index += 2
    }
    return output
}
