//
//  AudioFileLoader.swift
//  Looper
//

import AVFoundation
import Foundation

enum AudioFileLoader {
    static func localAudioURL(for sourceURL: URL) throws -> URL {
        let fileManager = FileManager.default
        let audioDirectoryURL = try audioDirectoryURL()

        if sourceURL.path.hasPrefix(audioDirectoryURL.path) {
            return sourceURL
        }

        if !fileManager.fileExists(atPath: audioDirectoryURL.path) {
            try fileManager.createDirectory(at: audioDirectoryURL, withIntermediateDirectories: true)
        }

        let destinationURL = audioDirectoryURL.appendingPathComponent(sourceURL.lastPathComponent)

        if fileManager.fileExists(atPath: destinationURL.path) {
            let sourceSize = try fileManager.attributesOfItem(atPath: sourceURL.path)[.size] as? NSNumber
            let destinationSize = try fileManager.attributesOfItem(atPath: destinationURL.path)[.size] as? NSNumber

            if sourceSize == destinationSize {
                return destinationURL
            }

            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }

    static func isAudioFile(_ url: URL) -> Bool {
        ["mp3", "m4a"].contains(url.pathExtension.lowercased())
    }

    static func audioDuration(for url: URL) -> TimeInterval {
        guard let audioFile = try? AVAudioFile(forReading: url) else { return 0 }
        let sampleRate = audioFile.processingFormat.sampleRate
        guard sampleRate > 0 else { return 0 }
        return max(Double(audioFile.length) / sampleRate, 0)
    }

    static func isSubtitleFile(_ url: URL) -> Bool {
        ["srt", "vtt"].contains(url.pathExtension.lowercased())
    }

    static func copySelectedSubtitle(_ subtitleURL: URL, to audioURL: URL) throws {
        let fileManager = FileManager.default
        let audioDirectoryURL = audioURL.deletingLastPathComponent()

        if !fileManager.fileExists(atPath: audioDirectoryURL.path) {
            try fileManager.createDirectory(at: audioDirectoryURL, withIntermediateDirectories: true)
        }

        for fileExtension in ["srt", "vtt"] {
            let existingURL = audioURL.deletingPathExtension().appendingPathExtension(fileExtension)
            if fileManager.fileExists(atPath: existingURL.path) {
                try fileManager.removeItem(at: existingURL)
            }
        }

        let destinationSubtitleURL = audioURL
            .deletingPathExtension()
            .appendingPathExtension(subtitleURL.pathExtension.lowercased())
        guard subtitleURL.standardizedFileURL.path != destinationSubtitleURL.standardizedFileURL.path else { return }
        try fileManager.copyItem(at: subtitleURL, to: destinationSubtitleURL)
    }

    static func copySidecarSubtitleIfNeeded(from sourceURL: URL, to audioURL: URL) throws {
        let fileManager = FileManager.default
        let audioDirectoryURL = audioURL.deletingLastPathComponent()
        guard let sourceSubtitleURL = Self.sidecarSubtitleURL(for: sourceURL) else {
            try removeLocalSidecarSubtitles(for: audioURL)
            return
        }

        if !fileManager.fileExists(atPath: audioDirectoryURL.path) {
            try fileManager.createDirectory(at: audioDirectoryURL, withIntermediateDirectories: true)
        }

        let destinationSubtitleURL = audioURL
            .deletingPathExtension()
            .appendingPathExtension(sourceSubtitleURL.pathExtension.lowercased())
        guard sourceSubtitleURL.standardizedFileURL.path != destinationSubtitleURL.standardizedFileURL.path else { return }
        try removeLocalSidecarSubtitles(for: audioURL)
        try fileManager.copyItem(at: sourceSubtitleURL, to: destinationSubtitleURL)
    }

    private static func removeLocalSidecarSubtitles(for audioURL: URL) throws {
        let fileManager = FileManager.default
        for fileExtension in ["srt", "vtt"] {
            let subtitleURL = audioURL.deletingPathExtension().appendingPathExtension(fileExtension)
            if fileManager.fileExists(atPath: subtitleURL.path) {
                try fileManager.removeItem(at: subtitleURL)
            }
        }
    }

    static func loadSidecarSubtitles(for audioURL: URL) throws -> [SubtitleSegment]? {
        guard let subtitleURL = sidecarSubtitleURL(for: audioURL) else { return nil }
        let content = try String(contentsOf: subtitleURL, encoding: .utf8)
        let subtitles = SubtitleParser.parse(content, fileExtension: subtitleURL.pathExtension)
        return subtitles.isEmpty ? nil : subtitles
    }

    private static func sidecarSubtitleURL(for audioURL: URL) -> URL? {
        let fileManager = FileManager.default
        let baseURL = audioURL.deletingPathExtension()

        for fileExtension in ["srt", "vtt"] {
            let subtitleURL = baseURL.appendingPathExtension(fileExtension)
            if fileManager.fileExists(atPath: subtitleURL.path) {
                return subtitleURL
            }
        }

        let directoryURL = audioURL.deletingLastPathComponent()
        let baseName = baseURL.lastPathComponent.lowercased()
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        return urls.first { url in
            let extensionName = url.pathExtension.lowercased()
            return ["srt", "vtt"].contains(extensionName)
                && url.deletingPathExtension().lastPathComponent.lowercased() == baseName
        }
    }

    static func audioDirectoryURL() throws -> URL {
        let documentsURL = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return documentsURL.appendingPathComponent("AudioFiles", isDirectory: true)
    }
}
