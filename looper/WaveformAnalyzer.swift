//
//  WaveformAnalyzer.swift
//  Looper
//

import AVFoundation
import Foundation

enum WaveformAnalyzer {
    nonisolated static func analyzeWaveformSamples(from url: URL) throws -> [Float] {
        let audioFile = try AVAudioFile(forReading: url)
        let format = audioFile.processingFormat
        let totalFrames = Int(audioFile.length)
        let channels = Int(format.channelCount)
        let sampleRate = format.sampleRate

        guard totalFrames > 0, channels > 0, sampleRate > 0 else { return [] }

        let audioDuration = Double(totalFrames) / sampleRate
        let waveformSampleCount = min(max(Int(audioDuration * 50), 1_200), 18_000, totalFrames)
        let waveformWindowFrames = max(Int(sampleRate * 0.012), 256)

        return try peakSamples(
            from: audioFile,
            sampleCount: waveformSampleCount,
            windowFrames: waveformWindowFrames,
            totalFrames: totalFrames,
            channels: channels,
            sampleRate: sampleRate
        )
    }

    nonisolated static func analyzeDecibelSamples(
        from url: URL,
        windowMilliseconds: Int,
        maximumDuration: TimeInterval? = nil
    ) throws -> [DecibelSample] {
        let audioFile = try AVAudioFile(forReading: url)
        let format = audioFile.processingFormat
        let totalFrames = Int(audioFile.length)
        let channels = Int(format.channelCount)
        let sampleRate = format.sampleRate

        guard totalFrames > 0, channels > 0, sampleRate > 0 else { return [] }

        let fullDuration = Double(totalFrames) / sampleRate
        let analysisDuration = min(maximumDuration ?? fullDuration, fullDuration)
        let analysisFrames = min(max(Int(analysisDuration * sampleRate), 1), totalFrames)
        let decibelSampleCount = min(max(Int(analysisDuration * 10), 300), 3_000, analysisFrames)
        let windowSeconds = Double(min(max(windowMilliseconds, 30), 500)) / 1_000
        let decibelWindowFrames = max(Int(sampleRate * windowSeconds), 512)

        return try decibelSamples(
            from: audioFile,
            sampleCount: decibelSampleCount,
            windowFrames: decibelWindowFrames,
            totalFrames: analysisFrames,
            channels: channels,
            sampleRate: sampleRate
        )
    }

    nonisolated private static func peakSamples(
        from audioFile: AVAudioFile,
        sampleCount: Int,
        windowFrames: Int,
        totalFrames: Int,
        channels: Int,
        sampleRate: Double
    ) throws -> [Float] {
        let stepFrames = max(totalFrames / sampleCount, 1)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: audioFile.processingFormat,
            frameCapacity: AVAudioFrameCount(windowFrames)
        ) else {
            throw AudioLoadError.cannotCreateBuffer
        }

        var samples: [Float] = []
        samples.reserveCapacity(sampleCount)

        for sampleIndex in 0..<sampleCount {
            try Task.checkCancellation()
            let framePosition = min(sampleIndex * stepFrames, max(totalFrames - 1, 0))
            audioFile.framePosition = AVAudioFramePosition(framePosition)
            try audioFile.read(into: buffer, frameCount: AVAudioFrameCount(windowFrames))

            guard let channelData = buffer.floatChannelData else {
                throw AudioLoadError.unsupportedAudioFormat
            }

            let framesRead = Int(buffer.frameLength)
            guard framesRead > 0 else { continue }

            var peak: Float = 0
            for frame in 0..<framesRead {
                var mixedSample: Float = 0
                for channel in 0..<channels {
                    mixedSample += abs(channelData[channel][frame])
                }
                peak = max(peak, mixedSample / Float(channels))
            }

            samples.append(min(peak, 1))
        }

        return samples
    }

    nonisolated private static func decibelSamples(
        from audioFile: AVAudioFile,
        sampleCount: Int,
        windowFrames: Int,
        totalFrames: Int,
        channels: Int,
        sampleRate: Double
    ) throws -> [DecibelSample] {
        let stepFrames = max(totalFrames / sampleCount, 1)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: audioFile.processingFormat,
            frameCapacity: AVAudioFrameCount(windowFrames)
        ) else {
            throw AudioLoadError.cannotCreateBuffer
        }

        var samples: [DecibelSample] = []
        samples.reserveCapacity(sampleCount)

        for sampleIndex in 0..<sampleCount {
            try Task.checkCancellation()
            let framePosition = min(sampleIndex * stepFrames, max(totalFrames - 1, 0))
            audioFile.framePosition = AVAudioFramePosition(framePosition)
            try audioFile.read(into: buffer, frameCount: AVAudioFrameCount(windowFrames))

            guard let channelData = buffer.floatChannelData else {
                throw AudioLoadError.unsupportedAudioFormat
            }

            let framesRead = Int(buffer.frameLength)
            guard framesRead > 0 else { continue }

            var sumSquares: Double = 0
            var measuredSampleCount = 0
            for frame in 0..<framesRead {
                for channel in 0..<channels {
                    let sample = channelData[channel][frame]
                    sumSquares += Double(sample * sample)
                    measuredSampleCount += 1
                }
            }

            samples.append(
                DecibelSample(
                    time: TimeInterval(framePosition) / sampleRate,
                    decibels: decibels(sumSquares: sumSquares, sampleCount: measuredSampleCount)
                )
            )
        }

        return samples
    }

    nonisolated private static func decibels(sumSquares: Double, sampleCount: Int) -> Double {
        let rms = sqrt(sumSquares / Double(max(sampleCount, 1)))
        return rms > 0 ? 20 * log10(rms) : -100
    }
}
