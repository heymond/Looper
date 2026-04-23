//
//  LooperModels.swift
//  Looper
//

import Foundation

struct LoopHistoryItem: Identifiable, Equatable {
    let id = UUID()
    let start: TimeInterval
    let end: TimeInterval
}

struct SubtitleSegment: Identifiable, Equatable, Sendable, Codable {
    let id: UUID
    let start: TimeInterval
    let end: TimeInterval
    let text: String

    nonisolated init(id: UUID = UUID(), start: TimeInterval, end: TimeInterval, text: String) {
        self.id = id
        self.start = start
        self.end = end
        self.text = text
    }
}

enum AudioLoadError: LocalizedError {
    case cannotCreateBuffer
    case unsupportedAudioFormat

    var errorDescription: String? {
        switch self {
        case .cannotCreateBuffer:
            "Could not create the audio buffer."
        case .unsupportedAudioFormat:
            "Unsupported audio format."
        }
    }
}

struct WaveformAnalysis: Sendable {
    let waveformSamples: [Float]
    let decibelSamples: [DecibelSample]
}

struct DecibelSample: Sendable {
    let time: TimeInterval
    let decibels: Double
}

enum RepeatOption: String, CaseIterable {
    case three
    case five
    case ten
    case infinite

    var title: String {
        switch self {
        case .three:
            "3"
        case .five:
            "5"
        case .ten:
            "10"
        case .infinite:
            "∞"
        }
    }

    var repeatLimit: Int? {
        switch self {
        case .three:
            3
        case .five:
            5
        case .ten:
            10
        case .infinite:
            nil
        }
    }
}
