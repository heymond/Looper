//
//  SubtitleParser.swift
//  Looper
//

import Foundation
import Speech

enum SubtitleParser {
    nonisolated static func segments(from segments: [SFTranscriptionSegment]) -> [SubtitleSegment] {
        var subtitles: [SubtitleSegment] = []
        var currentWords: [String] = []
        var currentStart: TimeInterval?
        var previousEnd: TimeInterval = 0

        func appendCurrentSubtitle() {
            guard let currentStart, !currentWords.isEmpty else { return }
            let text = currentWords.joined(separator: " ")
            subtitles.append(SubtitleSegment(start: currentStart, end: max(previousEnd, currentStart + 1.2), text: text))
            currentWords.removeAll()
        }

        for segment in segments {
            let word = segment.substring.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !word.isEmpty else { continue }

            let segmentStart = segment.timestamp
            let segmentEnd = segment.timestamp + segment.duration
            let currentTextLength = currentWords.joined(separator: " ").count
            let shouldStartNewSubtitle = currentStart != nil && (segmentStart - previousEnd > 0.8 || currentTextLength + word.count > 58)

            if shouldStartNewSubtitle {
                appendCurrentSubtitle()
                currentStart = segmentStart
            } else if currentStart == nil {
                currentStart = segmentStart
            }

            currentWords.append(word)
            previousEnd = segmentEnd
        }

        appendCurrentSubtitle()
        return displayExtendedSubtitles(subtitles)
    }

    nonisolated static func parse(_ content: String, fileExtension: String) -> [SubtitleSegment] {
        let lines = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        var subtitles: [SubtitleSegment] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]
            guard line.contains("-->") else {
                index += 1
                continue
            }

            let timingParts = line.components(separatedBy: "-->")
            guard timingParts.count == 2,
                  let start = subtitleTime(from: timingParts[0]),
                  let end = subtitleTime(from: timingParts[1]),
                  end > start else {
                index += 1
                continue
            }

            index += 1
            var textLines: [String] = []

            while index < lines.count {
                let textLine = lines[index]
                if textLine.contains("-->") {
                    break
                }

                if textLine.isEmpty {
                    index += 1
                    if !textLines.isEmpty {
                        break
                    }
                    continue
                }

                if textLine.uppercased().hasPrefix("WEBVTT") || textLine.allSatisfy(\.isNumber) {
                    index += 1
                    continue
                }

                textLines.append(textLine)
                index += 1
            }

            let text = textLines
                .joined(separator: " ")
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !text.isEmpty {
                subtitles.append(SubtitleSegment(start: start, end: end, text: text))
            }
        }

        return displayExtendedSubtitles(subtitles)
    }

    nonisolated private static func displayExtendedSubtitles(_ subtitles: [SubtitleSegment]) -> [SubtitleSegment] {
        let sortedSubtitles = subtitles.sorted { $0.start < $1.start }
        return sortedSubtitles.enumerated().map { index, subtitle in
            let nextStart = sortedSubtitles.indices.contains(index + 1) ? sortedSubtitles[index + 1].start : subtitle.end
            return SubtitleSegment(
                id: subtitle.id,
                start: subtitle.start,
                end: max(subtitle.end, nextStart),
                text: subtitle.text
            )
        }
    }

    nonisolated private static func subtitleTime(from rawValue: String) -> TimeInterval? {
        let timePart = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .first?
            .replacingOccurrences(of: ",", with: ".")
        guard let timePart else { return nil }

        let pieces = timePart.split(separator: ":").map(String.init)
        guard pieces.count == 2 || pieces.count == 3 else { return nil }

        let hours: Double
        let minutes: Double
        let seconds: Double

        if pieces.count == 3 {
            guard let parsedHours = Double(pieces[0]),
                  let parsedMinutes = Double(pieces[1]),
                  let parsedSeconds = Double(pieces[2]) else { return nil }
            hours = parsedHours
            minutes = parsedMinutes
            seconds = parsedSeconds
        } else {
            guard let parsedMinutes = Double(pieces[0]),
                  let parsedSeconds = Double(pieces[1]) else { return nil }
            hours = 0
            minutes = parsedMinutes
            seconds = parsedSeconds
        }

        return hours * 3_600 + minutes * 60 + seconds
    }
}
