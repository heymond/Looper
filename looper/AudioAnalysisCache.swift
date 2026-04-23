//
//  AudioAnalysisCache.swift
//  Looper
//

import Foundation

enum AudioAnalysisCache {
    nonisolated static func loadAnalysis(for url: URL, windowMilliseconds: Int) throws -> WaveformAnalysis? {
        let cacheURL = try analysisCacheURL(for: url, windowMilliseconds: windowMilliseconds)
        guard FileManager.default.fileExists(atPath: cacheURL.path) else { return nil }
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }

        return decodeCachedAnalysis(from: data)
    }

    nonisolated static func loadSubtitles(for url: URL) throws -> [SubtitleSegment]? {
        let cacheURL = try subtitlesCacheURL(for: url)
        guard FileManager.default.fileExists(atPath: cacheURL.path) else { return nil }
        let data = try Data(contentsOf: cacheURL)
        return try JSONDecoder().decode([SubtitleSegment].self, from: data)
    }

    nonisolated static func saveSubtitles(_ subtitles: [SubtitleSegment], for url: URL) throws {
        let cacheURL = try subtitlesCacheURL(for: url)
        let cacheDirectoryURL = cacheURL.deletingLastPathComponent()

        if !FileManager.default.fileExists(atPath: cacheDirectoryURL.path) {
            try FileManager.default.createDirectory(at: cacheDirectoryURL, withIntermediateDirectories: true)
        }

        let data = try JSONEncoder().encode(subtitles)
        try data.write(to: cacheURL, options: [.atomic])
    }

    nonisolated static func saveAnalysis(_ analysis: WaveformAnalysis, for url: URL, windowMilliseconds: Int) throws {
        let cacheURL = try analysisCacheURL(for: url, windowMilliseconds: windowMilliseconds)
        let cacheDirectoryURL = cacheURL.deletingLastPathComponent()

        if !FileManager.default.fileExists(atPath: cacheDirectoryURL.path) {
            try FileManager.default.createDirectory(at: cacheDirectoryURL, withIntermediateDirectories: true)
        }

        let data = encodeCachedAnalysis(analysis)
        try data.write(to: cacheURL, options: [.atomic])
    }

    nonisolated private static func encodeCachedAnalysis(_ analysis: WaveformAnalysis) -> Data {
        var data = Data()
        appendUInt32(0x4C_50_43_32, to: &data)
        appendUInt32(UInt32(analysis.waveformSamples.count), to: &data)
        appendUInt32(UInt32(analysis.decibelSamples.count), to: &data)

        for sample in analysis.waveformSamples {
            appendUInt32(sample.bitPattern, to: &data)
        }

        for sample in analysis.decibelSamples {
            appendUInt64(sample.time.bitPattern, to: &data)
            appendUInt64(sample.decibels.bitPattern, to: &data)
        }

        return data
    }

    nonisolated private static func decodeCachedAnalysis(from data: Data) -> WaveformAnalysis? {
        var offset = 0
        guard readUInt32(from: data, offset: &offset) == 0x4C_50_43_32,
              let waveformCount = readUInt32(from: data, offset: &offset),
              let decibelCount = readUInt32(from: data, offset: &offset) else {
            return nil
        }

        var waveformSamples: [Float] = []
        waveformSamples.reserveCapacity(Int(waveformCount))

        for _ in 0..<waveformCount {
            guard let bitPattern = readUInt32(from: data, offset: &offset) else { return nil }
            waveformSamples.append(Float(bitPattern: bitPattern))
        }

        var decibelSamples: [DecibelSample] = []
        decibelSamples.reserveCapacity(Int(decibelCount))

        for _ in 0..<decibelCount {
            guard let timeBitPattern = readUInt64(from: data, offset: &offset),
                  let decibelBitPattern = readUInt64(from: data, offset: &offset) else {
                return nil
            }

            decibelSamples.append(
                DecibelSample(
                    time: Double(bitPattern: timeBitPattern),
                    decibels: Double(bitPattern: decibelBitPattern)
                )
            )
        }

        return WaveformAnalysis(waveformSamples: waveformSamples, decibelSamples: decibelSamples)
    }

    nonisolated private static func appendUInt32(_ value: UInt32, to data: inout Data) {
        var littleEndianValue = value.littleEndian
        withUnsafeBytes(of: &littleEndianValue) { data.append(contentsOf: $0) }
    }

    nonisolated private static func appendUInt64(_ value: UInt64, to data: inout Data) {
        var littleEndianValue = value.littleEndian
        withUnsafeBytes(of: &littleEndianValue) { data.append(contentsOf: $0) }
    }

    nonisolated private static func readUInt32(from data: Data, offset: inout Int) -> UInt32? {
        let size = MemoryLayout<UInt32>.size
        guard offset + size <= data.count else { return nil }
        let value = data[offset..<(offset + size)].enumerated().reduce(UInt32(0)) { result, element in
            result | (UInt32(element.element) << UInt32(element.offset * 8))
        }
        offset += size
        return value
    }

    nonisolated private static func readUInt64(from data: Data, offset: inout Int) -> UInt64? {
        let size = MemoryLayout<UInt64>.size
        guard offset + size <= data.count else { return nil }
        let value = data[offset..<(offset + size)].enumerated().reduce(UInt64(0)) { result, element in
            result | (UInt64(element.element) << UInt64(element.offset * 8))
        }
        offset += size
        return value
    }

    nonisolated private static func analysisCacheURL(for url: URL, windowMilliseconds: Int) throws -> URL {
        try cacheURL(for: url, directoryName: "AnalysisCache", cacheVariant: "analysis-v6-window-\(windowMilliseconds)ms")
    }

    nonisolated private static func subtitlesCacheURL(for url: URL) throws -> URL {
        try cacheURL(for: url, directoryName: "SubtitlesCache")
    }

    nonisolated private static func cacheURL(for url: URL, directoryName: String, cacheVariant: String? = nil) throws -> URL {
        let documentsURL = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let cacheDirectoryURL = documentsURL.appendingPathComponent(directoryName, isDirectory: true)
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        let modifiedAt = ((attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0).rounded()
        let cacheVariant = cacheVariant.map { "-\($0)" } ?? ""
        let fileKey = "\(url.lastPathComponent)-\(size)-\(Int(modifiedAt))\(cacheVariant)"
        let safeFileKey = fileKey.map { character in
            character.isLetter || character.isNumber ? character : "-"
        }
        .map(String.init)
        .joined()

        return cacheDirectoryURL.appendingPathComponent("\(safeFileKey).json")
    }

}
