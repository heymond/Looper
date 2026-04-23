//
//  ContentView.swift
//  Looper
//
//  Created by Jinyoung Kim on 4/13/26.
//

import AVFoundation
import MediaPlayer
import Observation
import Speech
import SwiftUI
import GoogleMobileAds // 👈 이 줄을 반드시 추가해야 합니다!
import UIKit
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var model = LanguageRepeaterModel()
    @State private var isImporterPresented = false
    @State private var isSilenceControlPresented = false
    @State private var isRecentFilesPresented = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    ZStack(alignment: .topLeading) {
                        HStack {
                            Button {
                                isRecentFilesPresented.toggle()
                            } label: {
                                Text(model.fileName)
                                    .font(.headline)
                                    .lineLimit(1)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Current \(model.currentDecibelText)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                
                                Button {
                                    isSilenceControlPresented.toggle()
                                } label: {
                                    Text("\(Int(model.silenceThresholdDB)) dB or lower")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)
                                .foregroundStyle(.secondary)
                                .disabled(!model.hasAudio)
                                .popover(isPresented: $isSilenceControlPresented, arrowEdge: .top) {
                                    silenceControlPanel
                                        .presentationCompactAdaptation(.popover)
                                }
                            }
                            
                            if model.isAnalyzingAudio {
                                ProgressView()
                            }
                        }
                    }
                    .zIndex(10)
                    
                    VStack(spacing: 0) {
                        WaveformView(model: model)
                            .frame(height: 150)
                        
                        OverviewWaveformView(model: model)
                            .frame(height: 50)
                            .background(.white.opacity(0.1))
                    }
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .zIndex(0)
                    
                    HStack {
                        Text("Playing: \(timeText(model.currentTime))/\(timeText(model.duration))")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Button("Default") {
                            model.resetToDefaultZoom()
                        }
                        .font(.caption)
                        .disabled(!model.hasAudio)
                    }
                    
                    subtitleView
                }
                
                
                VStack(spacing: 12) {
                    HStack {
                        Spacer()
                        
                        HStack(spacing: 10) {
                            Button("A") {
                                model.toggleStartMarkerAtCurrentTime()
                            }
                            .buttonStyle(.bordered)
                            .tint(model.hasLoopStartMarker ? .blue : .gray)
                            
                            Button("B") {
                                model.toggleEndMarkerAtCurrentTime()
                            }
                            .buttonStyle(.bordered)
                            .tint(model.hasLoopEndMarker ? .red : .gray)
                            .disabled(!model.hasLoopStartMarker)
                            
                            Button {
                                model.clearLoopMarkers()
                            } label: {
                                Image(systemName: "xmark")
                                    .frame(width: 18, height: 18)
                            }
                            .buttonStyle(.bordered)
                            .tint(.gray)
                            .disabled(!model.hasLoopStartMarker && !model.hasLoopEndMarker)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 6) {
                            repeatCountButton(.three)
                            repeatCountButton(.five)
                            repeatCountButton(.ten)
                            repeatCountButton(.infinite)
                        }
                    }
                    .disabled(!model.hasAudio)
                }
                
                HStack(spacing: 14) {
                    Button {
                        model.togglePlayback()
                    } label: {
                        Label(model.isPlaying ? "Pause" : "Play", systemImage: model.isPlaying ? "pause.fill" : "play.fill")
                            .frame(width: 110)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.hasAudio)
                    
                    Button {
                        model.stop()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                            .frame(width: 110)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(model.isPlaying ? .red : .gray)
                    .disabled(!model.hasAudio)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                
                loopHistorySection
                    .frame(maxHeight: .infinity, alignment: .top)
                
//                광고가 들어갈 자리 미리 확보 (GIMP로 만든 320x50 이미지를 넣어보세요)
//                AdBannerView()
//                    .frame(maxWidth: .infinity) // 가로는 꽉 채우고
//                    .frame(height: 60)          // 높이는 가변 대응을 위해 약간 여유 있게
                
            }
            .padding()
            .overlay(alignment: .topLeading) {
                if isRecentFilesPresented {
                    ZStack(alignment: .topLeading) {
                        Color.black.opacity(0.001)
                            .ignoresSafeArea()
                            .contentShape(Rectangle())
                            .onTapGesture {
                                isRecentFilesPresented = false
                            }

                        recentFilesPanel
                            .padding(.leading)
                            .offset(y: 46)
                            .onTapGesture { }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .navigationTitle("Loop Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button {
                    isImporterPresented = true
                } label: {
                    Label("Open Audio", systemImage: "folder")
                }
            }
            .task {
                model.loadLastAudioIfNeeded()
            }
            .sheet(isPresented: $isImporterPresented) {
                AudioDocumentPicker(
                    isPresented: $isImporterPresented,
                    initialDirectoryURL: model.lastOpenedDirectoryURL,
                    onPick: { result in
                        model.importAudio(from: result)
                    }
                )
            }
            .alert("Audio Error", isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(model.errorMessage ?? "")
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private func timeText(_ time: TimeInterval) -> String {
        let totalCentiseconds = max(Int((time * 100).rounded()), 0)
        let hours = totalCentiseconds / 360_000
        let minutes = (totalCentiseconds % 360_000) / 6_000
        let seconds = (totalCentiseconds % 6_000) / 100
        let centiseconds = totalCentiseconds % 100

        if hours > 0 {
            return String(format: "%d°%02d′%02d.%02d″", hours, minutes, seconds, centiseconds)
        }

        if minutes > 0 {
            return String(format: "%d′%02d.%02d″", minutes, seconds, centiseconds)
        }

        return String(format: "%d.%02d″", seconds, centiseconds)
    }

    private var subtitleView: some View {
        VStack(spacing: 6) {
            ScrollView(.vertical) {
                Text(model.subtitleDisplayText)
                    .font(.headline)
                    .lineLimit(nil)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .foregroundStyle(model.subtitleDisplayText.isEmpty ? .secondary : .primary)
            }
            .frame(maxWidth: .infinity, minHeight: 92, maxHeight: 92)

            if model.hasSubtitleFile {
                HStack(spacing: 8) {
                    Text("Subtitle Sync")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Button("Earlier") {
                        model.adjustSubtitleSync(by: 0.1)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)

                    Button(model.subtitleSyncText) {
                        model.resetSubtitleSync()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                    Button("Later") {
                        model.adjustSubtitleSync(by: -0.1)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private var silenceControlPanel: some View {
        VStack(alignment: .trailing, spacing: 10) {
            HStack(spacing: 10) {
                Text("Threshold")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField(
                    "dB",
                    value: Binding(
                        get: { model.silenceThresholdDB },
                        set: { model.silenceThresholdDB = min(max($0, -60), -15) }
                    ),
                    format: .number.precision(.fractionLength(0))
                )
                .keyboardType(.numbersAndPunctuation)
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)
                .frame(width: 66)

                Slider(value: $model.silenceThresholdDB, in: -60 ... -15, step: 1)
                    .frame(width: 120)

                Text("dB")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 22, alignment: .leading)
            }

            HStack(spacing: 10) {
                Text("Silence Time")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField(
                    "ms",
                    value: Binding(
                        get: { model.silenceWindowMilliseconds },
                        set: { model.updateSilenceWindowMilliseconds($0) }
                    ),
                    format: .number.precision(.fractionLength(0))
                )
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)
                .frame(width: 66)

                Slider(
                    value: Binding(
                        get: { model.silenceWindowMilliseconds },
                        set: { model.updateSilenceWindowMilliseconds($0) }
                    ),
                    in: 30 ... 500,
                    step: 10
                )
                .frame(width: 120)

                Text("ms")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 22, alignment: .leading)
            }
        }
        .padding(8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .frame(maxWidth: .infinity, alignment: .trailing)
        .disabled(!model.hasAudio)
    }

    private var recentFilesPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Files")
                .font(.caption)
                .foregroundStyle(.secondary)

            let files = model.recentAudioFiles
            if files.isEmpty {
                Text("No saved files")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(files, id: \.self) { url in
                    Button {
                        model.loadRecentAudio(from: url)
                        isRecentFilesPresented = false
                    } label: {
                        Text(url.lastPathComponent)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(width: 300, alignment: .leading)
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.black)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.gray.opacity(0.7), lineWidth: 2)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var loopHistorySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Loop History", systemImage: "repeat")
                .font(.caption)
                .foregroundStyle(.secondary)

            if model.loopHistory.isEmpty {
                Text("No loop ranges")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(model.loopHistory) { item in
                            loopHistoryRow(item)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func loopHistoryRow(_ item: LoopHistoryItem) -> some View {
        let isActive = model.activeLoopHistoryID == item.id

        return HStack(spacing: 8) {
            Button {
                model.playLoopHistory(item)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                        .foregroundStyle(isActive ? .white : .primary)
                    Text("\(timeText(item.start)) - \(timeText(item.end))")
                        .monospacedDigit()
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                model.removeLoopHistory(item)
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .font(.caption)
        .foregroundStyle(isActive ? .white : .primary)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isActive ? .red.opacity(0.78) : .secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
    }

    private func repeatCountButton(_ option: RepeatOption) -> some View {
        Button(option.title) {
            model.selectedRepeatOption = option
            model.completedLoopCount = 0
        }
        .buttonStyle(.bordered)
        .tint(model.selectedRepeatOption == option ? .red : .gray)
    }
}

@Observable
@MainActor
final class LanguageRepeaterModel {
    var fileName = "Open an MP3 or M4A file"
    var waveformSamples: [Float] = []
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var loopStart: TimeInterval = 0
    var loopEnd: TimeInterval = 0
    var visibleStartTime: TimeInterval = 0
    var visibleEndTime: TimeInterval = 0
    var silenceThresholdDB: Double = -50
    var silenceWindowMilliseconds: Double = 30
    var hasLoopStartMarker = false
    var hasLoopEndMarker = false
    var selectedRepeatOption: RepeatOption = .infinite
    var completedLoopCount = 0
    var loopHistory: [LoopHistoryItem] = []
    var activeLoopHistoryID: UUID?
    var subtitleSegments: [SubtitleSegment] = []
    var currentSubtitleID: UUID?
    var currentSubtitleText = ""
    var subtitleSyncOffset: TimeInterval = 0
    var hasSubtitleFile = false
    var isPlaying = false
    var isAnalyzingAudio = false
    var isTranscribingSubtitles = false
    var errorMessage: String?

    var hasAudio: Bool {
        player != nil
    }

    var visibleDuration: TimeInterval {
        max(visibleEndTime - visibleStartTime, 0)
    }

    var isZoomed: Bool {
        duration > 0 && visibleDuration < duration * 0.98
    }

    var defaultVisibleDuration: TimeInterval {
        min(max(duration, 1), 20)
    }

    var currentDecibelText: String {
        guard let sample = amplitudeBySecond.min(by: { abs($0.time - currentTime) < abs($1.time - currentTime) }) else {
            return "-- dB"
        }

        return "\(Int(sample.decibels.rounded())) dB"
    }

    var subtitleDisplayText: String {
        if !currentSubtitleText.isEmpty {
            return currentSubtitleText
        }

        return hasSubtitleFile ? "" : "No subtitles"
    }

    var subtitleSyncText: String {
        String(format: "%+.1fs", subtitleSyncOffset)
    }

    var lastOpenedDirectoryURL: URL? {
        guard let path = UserDefaults.standard.string(forKey: lastOpenedDirectoryPathKey) else { return nil }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return nil
        }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    var recentAudioFiles: [URL] {
        guard let directoryURL = try? audioDirectoryURL() else { return [] }
        let allowedExtensions = Set(["mp3", "m4a"])

        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return urls
            .filter { allowedExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { lhs, rhs in
                let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return lhsDate > rhsDate
            }
    }

    @ObservationIgnored private var player: AVPlayer?
    @ObservationIgnored private var playbackTask: Task<Void, Never>?
    @ObservationIgnored private var analysisTask: Task<Void, Never>?
    @ObservationIgnored private var transcriptionTask: SFSpeechRecognitionTask?
    @ObservationIgnored private var pendingSubtitleSegments: [SubtitleSegment] = []
    @ObservationIgnored private var loadedAudioURL: URL?
    @ObservationIgnored private var amplitudeBySecond: [DecibelSample] = []
    @ObservationIgnored private var shouldClearEndMarkerAfterPlayback = false
    @ObservationIgnored private var shouldResumeAfterInterruption = false
    @ObservationIgnored private var isAudioSessionInterrupted = false
    @ObservationIgnored private var interruptionObserver: NSObjectProtocol?
    @ObservationIgnored private var routeChangeObserver: NSObjectProtocol?
    @ObservationIgnored nonisolated(unsafe) private var remoteCommandTargets: [Any] = []
    @ObservationIgnored private var lastNowPlayingElapsedTime: TimeInterval = -1
    @ObservationIgnored private var didAttemptLastAudioLoad = false
    @ObservationIgnored private let lastAudioPathKey = "lastAudioPath"
    @ObservationIgnored private let lastAudioFileNameKey = "lastAudioFileName"
    @ObservationIgnored private let lastOpenedDirectoryPathKey = "lastOpenedDirectoryPath"

    init() {
        installAudioSessionObservers()
        installRemoteCommandHandlers()
    }

    deinit {
        playbackTask?.cancel()
        analysisTask?.cancel()
        transcriptionTask?.cancel()

        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
        if let routeChangeObserver {
            NotificationCenter.default.removeObserver(routeChangeObserver)
        }

        removeRemoteCommandHandlers()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func importAudio(from result: Result<[URL], Error>) {
        do {
            let selectedURLs = try result.get()
            guard let audioURL = selectedURLs.first(where: { Self.isAudioFile($0) }) else { return }
            saveLastOpenedDirectory(for: audioURL)
            let subtitleURL = selectedURLs.first(where: { Self.isSubtitleFile($0) })
            try loadAudio(from: audioURL, subtitleURL: subtitleURL)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadRecentAudio(from url: URL) {
        do {
            try loadAudio(from: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveLastOpenedDirectory(for url: URL) {
        UserDefaults.standard.set(url.deletingLastPathComponent().path, forKey: lastOpenedDirectoryPathKey)
    }

    func loadLastAudioIfNeeded() {
        guard !didAttemptLastAudioLoad else { return }
        didAttemptLastAudioLoad = true

        if let fileName = UserDefaults.standard.string(forKey: lastAudioFileNameKey),
           let url = try? audioDirectoryURL().appendingPathComponent(fileName),
           FileManager.default.fileExists(atPath: url.path) {
            do {
                try loadAudio(from: url)
            } catch {
                errorMessage = error.localizedDescription
            }
            return
        }

        guard let path = UserDefaults.standard.string(forKey: lastAudioPathKey) else {
            loadBundledDefaultAudioIfAvailable()
            return
        }

        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            UserDefaults.standard.removeObject(forKey: lastAudioPathKey)
            UserDefaults.standard.removeObject(forKey: lastAudioFileNameKey)
            loadBundledDefaultAudioIfAvailable()
            return
        }

        do {
            try loadAudio(from: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadBundledDefaultAudioIfAvailable() {
        let candidates = ["DefaultAudio", "default", "sample"]

        for name in candidates {
            if let url = Bundle.main.url(forResource: name, withExtension: "mp3") {
                do {
                    try loadAudio(from: url)
                } catch {
                    errorMessage = error.localizedDescription
                }
                return
            }
        }
    }

    func loadAudio(from url: URL, subtitleURL: URL? = nil) throws {
        stop()
        analysisTask?.cancel()
        transcriptionTask?.cancel()
        transcriptionTask = nil

        let canAccessAudio = url.startAccessingSecurityScopedResource()
        let canAccessSubtitle = subtitleURL?.startAccessingSecurityScopedResource() ?? false
        defer {
            if canAccessAudio {
                url.stopAccessingSecurityScopedResource()
            }
            if canAccessSubtitle {
                subtitleURL?.stopAccessingSecurityScopedResource()
            }
        }

        let localURL = try localAudioURL(for: url)
        if let subtitleURL {
            try copySelectedSubtitle(subtitleURL, to: localURL)
        } else {
            try copySidecarSubtitleIfNeeded(from: url, to: localURL)
        }
        try configureAudioSession()

        let playerItem = AVPlayerItem(url: localURL)
        let player = AVPlayer(playerItem: playerItem)
        player.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible
        self.player = player

        fileName = localURL.lastPathComponent
        loadedAudioURL = localURL
        UserDefaults.standard.set(localURL.path, forKey: lastAudioPathKey)
        UserDefaults.standard.set(localURL.lastPathComponent, forKey: lastAudioFileNameKey)
        duration = Self.audioDuration(for: localURL)
        currentTime = 0
        loopStart = 0
        loopEnd = duration
        hasLoopStartMarker = false
        hasLoopEndMarker = false
        shouldClearEndMarkerAfterPlayback = false
        completedLoopCount = 0
        loopHistory = []
        activeLoopHistoryID = nil
        let initialVisibleDuration = defaultVisibleDuration
        visibleStartTime = -initialVisibleDuration / 2
        visibleEndTime = initialVisibleDuration / 2
        waveformSamples = []
        amplitudeBySecond = []
        subtitleSegments = []
        pendingSubtitleSegments = []
        currentSubtitleID = nil
        currentSubtitleText = ""
        subtitleSyncOffset = 0
        hasSubtitleFile = false
        isAnalyzingAudio = true
        isTranscribingSubtitles = false
        updateNowPlayingInfo(force: true)
        if let sidecarSubtitles = try? Self.loadSidecarSubtitles(for: localURL), !sidecarSubtitles.isEmpty {
            subtitleSegments = sidecarSubtitles
            hasSubtitleFile = true
            refreshCurrentSubtitle(force: true)
        }

        startWaveformAnalysis(for: localURL)
    }

    func updateSilenceWindowMilliseconds(_ value: Double) {
        let nextValue = min(max(value, 30), 500)
        guard silenceWindowMilliseconds != nextValue else { return }

        silenceWindowMilliseconds = nextValue
        guard let loadedAudioURL else { return }
        isAnalyzingAudio = true
        startWaveformAnalysis(for: loadedAudioURL)
    }

    private func startWaveformAnalysis(for localURL: URL) {
        analysisTask?.cancel()
        let windowMilliseconds = Int(silenceWindowMilliseconds.rounded())

        analysisTask = Task.detached(priority: .userInitiated) { [localURL, windowMilliseconds] in
            do {
                try Task.checkCancellation()
                if let cachedAnalysis = try AudioAnalysisCache.loadAnalysis(for: localURL, windowMilliseconds: windowMilliseconds) {
                    try Task.checkCancellation()
                    await MainActor.run { [weak self] in
                        guard let self,
                              self.loadedAudioURL == localURL,
                              Int(self.silenceWindowMilliseconds.rounded()) == windowMilliseconds else { return }
                        self.waveformSamples = cachedAnalysis.waveformSamples
                        self.amplitudeBySecond = cachedAnalysis.decibelSamples
                        self.applyAutomaticLoopBounds()
                        self.isAnalyzingAudio = false
                    }
                    return
                }

                let waveformSamples = try WaveformAnalyzer.analyzeWaveformSamples(from: localURL)
                try Task.checkCancellation()
                await MainActor.run { [weak self] in
                    guard let self,
                          self.loadedAudioURL == localURL,
                          Int(self.silenceWindowMilliseconds.rounded()) == windowMilliseconds else { return }
                    self.waveformSamples = waveformSamples
                    self.isAnalyzingAudio = true
                }

                let initialDecibelSamples = try WaveformAnalyzer.analyzeDecibelSamples(
                    from: localURL,
                    windowMilliseconds: windowMilliseconds,
                    maximumDuration: 60
                )
                try Task.checkCancellation()
                await MainActor.run { [weak self] in
                    guard let self,
                          self.loadedAudioURL == localURL,
                          Int(self.silenceWindowMilliseconds.rounded()) == windowMilliseconds else { return }
                    self.amplitudeBySecond = initialDecibelSamples
                    self.isAnalyzingAudio = true
                }

                let decibelSamples = try WaveformAnalyzer.analyzeDecibelSamples(
                    from: localURL,
                    windowMilliseconds: windowMilliseconds
                )
                let analysis = WaveformAnalysis(waveformSamples: waveformSamples, decibelSamples: decibelSamples)
                try Task.checkCancellation()
                try AudioAnalysisCache.saveAnalysis(analysis, for: localURL, windowMilliseconds: windowMilliseconds)

                try Task.checkCancellation()
                await MainActor.run { [weak self] in
                    guard let self,
                          self.loadedAudioURL == localURL,
                          Int(self.silenceWindowMilliseconds.rounded()) == windowMilliseconds else { return }
                    self.waveformSamples = analysis.waveformSamples
                    self.amplitudeBySecond = analysis.decibelSamples
                    self.applyAutomaticLoopBounds()
                    self.isAnalyzingAudio = false
                }
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run { [weak self] in
                    guard let self,
                          self.loadedAudioURL == localURL,
                          Int(self.silenceWindowMilliseconds.rounded()) == windowMilliseconds else { return }
                    self.isAnalyzingAudio = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func transcribeEnglishSubtitles(for url: URL) {
        if let cachedSubtitles = try? AudioAnalysisCache.loadSubtitles(for: url), !cachedSubtitles.isEmpty {
            subtitleSegments = cachedSubtitles
            refreshCurrentSubtitle(force: true)
            isTranscribingSubtitles = false
            return
        }

        isTranscribingSubtitles = true

        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor [weak self] in
                guard let self, self.loadedAudioURL == url else { return }
                guard status == .authorized else {
                    self.isTranscribingSubtitles = false
                    return
                }
                guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")), recognizer.isAvailable else {
                    self.isTranscribingSubtitles = false
                    return
                }

                let request = SFSpeechURLRecognitionRequest(url: url)
                request.shouldReportPartialResults = true

                self.transcriptionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                    let subtitleSegments = result.map { SubtitleParser.segments(from: $0.bestTranscription.segments) } ?? []
                    let isFinished = error != nil || result?.isFinal == true

                    Task { @MainActor [weak self, subtitleSegments, isFinished] in
                        guard let self, self.loadedAudioURL == url else { return }

                        if !subtitleSegments.isEmpty {
                            self.pendingSubtitleSegments = subtitleSegments
                        }

                        guard isFinished else { return }

                        let finalSubtitles = subtitleSegments.isEmpty ? self.pendingSubtitleSegments : subtitleSegments
                        if !finalSubtitles.isEmpty {
                            self.subtitleSegments = finalSubtitles
                            self.refreshCurrentSubtitle(force: true)
                            try? AudioAnalysisCache.saveSubtitles(finalSubtitles, for: url)
                        }
                        self.pendingSubtitleSegments = []
                        self.isTranscribingSubtitles = false
                        self.transcriptionTask = nil
                    }
                }
            }
        }
    }

    private func refreshCurrentSubtitle(force: Bool = false) {
        let subtitleTime = min(max(currentTime + subtitleSyncOffset, 0), duration)

        if let subtitle = subtitleSegments.last(where: { subtitleTime >= $0.start && subtitleTime < $0.end }) {
            currentSubtitleID = subtitle.id
            currentSubtitleText = subtitle.text
        } else {
            currentSubtitleID = nil
            currentSubtitleText = ""
        }
    }

    func adjustSubtitleSync(by amount: TimeInterval) {
        subtitleSyncOffset = min(max(subtitleSyncOffset + amount, -5), 5)
        refreshCurrentSubtitle(force: true)
    }

    func resetSubtitleSync() {
        subtitleSyncOffset = 0
        refreshCurrentSubtitle(force: true)
    }

    func togglePlayback() {
        guard player != nil else { return }

        if isPlayerPlaying {
            pause()
        } else {
            if hasLoopStartMarker && hasLoopEndMarker && (currentTime < loopStart || currentTime >= loopEnd) {
                seekPlayer(to: loopStart)
                currentTime = loopStart
            }
            refreshCurrentSubtitle(force: true)
            centerVisibleRange(on: currentTime)
            playCurrentAudio()
            completedLoopCount = 0
            isPlaying = true
            startPlaybackMonitor()
        }
    }

    func pause() {
        shouldResumeAfterInterruption = false
        player?.pause()
        isPlaying = false
        playbackTask?.cancel()
        updateNowPlayingInfo(force: true)
    }

    func stop() {
        shouldResumeAfterInterruption = false
        playbackTask?.cancel()
        player?.pause()
        let stopTime = preferredStopTime()
        seekPlayer(to: stopTime)
        currentTime = stopTime
        refreshCurrentSubtitle(force: true)
        centerVisibleRange(on: stopTime)
        completedLoopCount = 0
        isPlaying = false
        updateNowPlayingInfo(force: true)
    }

    private func preferredStopTime() -> TimeInterval {
        if hasLoopStartMarker {
            return loopStart
        }

        return 0
    }

    func seek(to time: TimeInterval) {
        let nextTime = min(max(time, 0), duration)
        seekPlayer(to: nextTime)
        currentTime = nextTime
        refreshCurrentSubtitle(force: true)
        centerVisibleRange(on: nextTime)
        updateNowPlayingInfo(force: true)
    }

    func seekToVisibleCenter() {
        let centerTime = (visibleStartTime + visibleEndTime) / 2
        seek(to: centerTime)
    }

    private func synchronizedCurrentTime() -> TimeInterval {
        let nextTime = min(max(currentPlayerTime(), 0), duration)
        currentTime = nextTime
        return nextTime
    }

    func toggleStartMarkerAtCurrentTime() {
        let markerTime = synchronizedCurrentTime()

        if hasLoopStartMarker {
            hasLoopStartMarker = false
            activeLoopHistoryID = nil
            completedLoopCount = 0

            if hasLoopEndMarker && isPlaying && markerTime < loopEnd {
                shouldClearEndMarkerAfterPlayback = true
            } else {
                hasLoopEndMarker = false
                shouldClearEndMarkerAfterPlayback = false
            }
        } else {
            setLoopStart(markerTime)
            recordCurrentLoopRangeIfComplete()
        }
    }

    func toggleEndMarkerAtCurrentTime() {
        guard hasLoopStartMarker else { return }
        let markerTime = synchronizedCurrentTime()

        if hasLoopEndMarker {
            hasLoopEndMarker = false
            shouldClearEndMarkerAfterPlayback = false
            completedLoopCount = 0
        } else {
            setLoopEnd(markerTime)
            recordCurrentLoopRangeIfComplete()
        }
    }

    func clearLoopMarkers() {
        hasLoopStartMarker = false
        hasLoopEndMarker = false
        shouldClearEndMarkerAfterPlayback = false
        activeLoopHistoryID = nil
        completedLoopCount = 0
    }

    func playLoopHistory(_ item: LoopHistoryItem) {
        guard player != nil else { return }
        loopStart = item.start
        loopEnd = item.end
        hasLoopStartMarker = true
        hasLoopEndMarker = true
        shouldClearEndMarkerAfterPlayback = false
        activeLoopHistoryID = item.id
        completedLoopCount = 0
        seekPlayer(to: item.start)
        currentTime = item.start
        refreshCurrentSubtitle(force: true)
        centerVisibleRange(on: item.start)
        playCurrentAudio()
        isPlaying = true
        startPlaybackMonitor()
    }

    func removeLoopHistory(_ item: LoopHistoryItem) {
        loopHistory.removeAll { $0.id == item.id }
        if activeLoopHistoryID == item.id {
            activeLoopHistoryID = nil
        }
    }

    private func recordCurrentLoopRangeIfComplete() {
        guard hasLoopStartMarker, hasLoopEndMarker, loopEnd > loopStart else { return }
        let roundedStart = (loopStart * 10).rounded() / 10
        let roundedEnd = (loopEnd * 10).rounded() / 10

        loopHistory.removeAll { existing in
            abs(existing.start - roundedStart) < 0.1 && abs(existing.end - roundedEnd) < 0.1
        }
        loopHistory.insert(LoopHistoryItem(start: roundedStart, end: roundedEnd), at: 0)
    }

    func setLoopStart(_ time: TimeInterval) {
        let snappedTime = quietTimeBeforeOrAt(time)
        let maximumStart = hasLoopEndMarker ? max(loopEnd - 0.2, 0) : duration
        loopStart = min(max(snappedTime, 0), maximumStart)
        hasLoopStartMarker = true
        shouldClearEndMarkerAfterPlayback = false
        completedLoopCount = 0

        if currentTime < loopStart {
            seek(to: loopStart)
        }
    }

    func setLoopEnd(_ time: TimeInterval) {
        let snappedTime = quietTimeAfterOrAt(time)
        loopEnd = max(min(snappedTime, duration), min(loopStart + 0.2, duration))
        hasLoopEndMarker = true
        shouldClearEndMarkerAfterPlayback = false
        completedLoopCount = 0

        if currentTime > loopEnd {
            seek(to: loopStart)
        }
    }

    func resetToDefaultZoom() {
        setVisibleRange(centeredOn: currentTime, span: defaultVisibleDuration)
    }

    func moveVisibleRangeCenter(to time: TimeInterval) {
        centerVisibleRange(on: min(max(time, 0), duration))
    }

    func moveVisibleRange(
        from startRange: ClosedRange<TimeInterval>,
        horizontalTranslation: CGFloat,
        width: CGFloat
    ) {
        guard duration > 0, width > 0 else { return }

        let span = startRange.upperBound - startRange.lowerBound
        guard span > 0, span < duration else { return }

        let timeOffset = TimeInterval(horizontalTranslation / width) * span
        setVisibleRange(start: startRange.lowerBound - timeOffset, span: span)
    }

    func zoomVisibleRange(from startRange: ClosedRange<TimeInterval>, magnification: CGFloat) {
        guard duration > 0, magnification > 0 else { return }

        let startSpan = startRange.upperBound - startRange.lowerBound
        let minimumSpan = min(20, duration)
        let nextSpan = min(max(startSpan / TimeInterval(magnification), minimumSpan), duration)
        let center = (startRange.lowerBound + startRange.upperBound) / 2
        let halfSpan = nextSpan / 2

        var nextStart = center - halfSpan
        var nextEnd = center + halfSpan

        if nextStart < 0 {
            nextEnd -= nextStart
            nextStart = 0
        }

        if nextEnd > duration {
            nextStart -= nextEnd - duration
            nextEnd = duration
        }

        visibleStartTime = max(nextStart, 0)
        visibleEndTime = min(nextEnd, duration)
    }

    private func setVisibleRange(start: TimeInterval, span: TimeInterval) {
        guard duration > 0, span > 0 else { return }

        let clampedSpan = min(span, duration)
        let halfSpan = clampedSpan / 2
        let minimumStart = -halfSpan
        let maximumStart = duration - halfSpan
        let nextStart = min(max(start, minimumStart), maximumStart)

        visibleStartTime = nextStart
        visibleEndTime = nextStart + clampedSpan
    }

    private func centerVisibleRange(on time: TimeInterval) {
        setVisibleRange(centeredOn: time, span: visibleDuration)
    }

    private func setVisibleRange(centeredOn time: TimeInterval, span: TimeInterval) {
        guard duration > 0, span > 0 else { return }

        let clampedSpan = min(span, duration)
        let halfSpan = clampedSpan / 2
        visibleStartTime = time - halfSpan
        visibleEndTime = time + halfSpan
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, policy: .longFormAudio)
        try session.setActive(true)
    }

    private func installRemoteCommandHandlers() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.stopCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.isEnabled = true

        remoteCommandTargets = [
            commandCenter.playCommand.addTarget { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, !self.isPlayerPlaying else { return }
                    self.togglePlayback()
                }
                return .success
            },
            commandCenter.pauseCommand.addTarget { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.pause()
                }
                return .success
            },
            commandCenter.stopCommand.addTarget { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.stop()
                }
                return .success
            },
            commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.togglePlayback()
                }
                return .success
            }
        ]
    }

    nonisolated private func removeRemoteCommandHandlers() {
        let commandCenter = MPRemoteCommandCenter.shared()
        let commands = [
            commandCenter.playCommand,
            commandCenter.pauseCommand,
            commandCenter.stopCommand,
            commandCenter.togglePlayPauseCommand
        ]

        for (command, target) in zip(commands, remoteCommandTargets) {
            command.removeTarget(target)
        }
        remoteCommandTargets = []
    }

    private func installAudioSessionObservers() {
        let center = NotificationCenter.default
        interruptionObserver = center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            Task { @MainActor [weak self] in
                self?.handleAudioSessionInterruption(typeValue: typeValue)
            }
        }

        routeChangeObserver = center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleAudioRouteChange()
            }
        }
    }

    private func handleAudioSessionInterruption(typeValue: UInt?) {
        guard let typeValue,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            isAudioSessionInterrupted = true
            shouldResumeAfterInterruption = isPlaying
            playbackTask?.cancel()
        case .ended:
            isAudioSessionInterrupted = false
            try? AVAudioSession.sharedInstance().setActive(true)

            guard shouldResumeAfterInterruption else { return }
            shouldResumeAfterInterruption = false
            resumePlaybackAfterAudioSessionEvent()
        @unknown default:
            break
        }
    }

    private func handleAudioRouteChange() {
        guard !isAudioSessionInterrupted, isPlaying else { return }
        try? AVAudioSession.sharedInstance().setActive(true)

        if player != nil && !isPlayerPlaying {
            resumePlaybackAfterAudioSessionEvent()
        }
    }

    private func resumePlaybackAfterAudioSessionEvent() {
        guard player != nil, !hasReachedPlaybackEnd(currentPlayerTime()) else {
            isPlaying = false
            updateNowPlayingInfo(force: true)
            return
        }

        playCurrentAudio()
        isPlaying = true
        startPlaybackMonitor()
    }

    @discardableResult
    private func playCurrentAudio() -> Bool {
        try? AVAudioSession.sharedInstance().setActive(true)
        player?.play()
        updateNowPlayingInfo(force: true)
        return player != nil
    }

    private func hasReachedPlaybackEnd(_ time: TimeInterval) -> Bool {
        let playbackEnd = hasLoopStartMarker && hasLoopEndMarker ? loopEnd : duration
        return playbackEnd > 0 && time >= playbackEnd - 0.05
    }

    private var isPlayerPlaying: Bool {
        guard let player else { return false }
        return player.rate != 0 || player.timeControlStatus == .playing
    }

    private func currentPlayerTime() -> TimeInterval {
        guard let seconds = player?.currentTime().seconds, seconds.isFinite else {
            return currentTime
        }
        return seconds
    }

    private func seekPlayer(to time: TimeInterval) {
        let cmTime = CMTime(seconds: min(max(time, 0), duration), preferredTimescale: 600)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func updateNowPlayingInfo(force: Bool = false) {
        guard loadedAudioURL != nil else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        let elapsedTime = min(max(currentTime, 0), duration)
        guard force || abs(elapsedTime - lastNowPlayingElapsedTime) >= 1 else { return }
        lastNowPlayingElapsedTime = elapsedTime

        MPNowPlayingInfoCenter.default().playbackState = isPlayerPlaying ? .playing : .paused
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: fileName,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsedTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlayerPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0
        ]
    }

    private func localAudioURL(for sourceURL: URL) throws -> URL {
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

    nonisolated private static func isAudioFile(_ url: URL) -> Bool {
        ["mp3", "m4a"].contains(url.pathExtension.lowercased())
    }

    nonisolated private static func audioDuration(for url: URL) -> TimeInterval {
        guard let audioFile = try? AVAudioFile(forReading: url) else { return 0 }
        let sampleRate = audioFile.processingFormat.sampleRate
        guard sampleRate > 0 else { return 0 }
        return max(Double(audioFile.length) / sampleRate, 0)
    }

    nonisolated private static func isSubtitleFile(_ url: URL) -> Bool {
        ["srt", "vtt"].contains(url.pathExtension.lowercased())
    }

    private func copySelectedSubtitle(_ subtitleURL: URL, to audioURL: URL) throws {
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

    private func copySidecarSubtitleIfNeeded(from sourceURL: URL, to audioURL: URL) throws {
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

    private func removeLocalSidecarSubtitles(for audioURL: URL) throws {
        let fileManager = FileManager.default
        for fileExtension in ["srt", "vtt"] {
            let subtitleURL = audioURL.deletingPathExtension().appendingPathExtension(fileExtension)
            if fileManager.fileExists(atPath: subtitleURL.path) {
                try fileManager.removeItem(at: subtitleURL)
            }
        }
    }

    nonisolated private static func loadSidecarSubtitles(for audioURL: URL) throws -> [SubtitleSegment]? {
        guard let subtitleURL = sidecarSubtitleURL(for: audioURL) else { return nil }
        let content = try String(contentsOf: subtitleURL, encoding: .utf8)
        let subtitles = SubtitleParser.parse(content, fileExtension: subtitleURL.pathExtension)
        return subtitles.isEmpty ? nil : subtitles
    }

    nonisolated private static func sidecarSubtitleURL(for audioURL: URL) -> URL? {
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

    private func audioDirectoryURL() throws -> URL {
        let documentsURL = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return documentsURL.appendingPathComponent("AudioFiles", isDirectory: true)
    }

    private func applyAutomaticLoopBounds() {
        guard !amplitudeBySecond.isEmpty else { return }

        if let firstSound = amplitudeBySecond.first(where: { $0.decibels > silenceThresholdDB })?.time {
            loopStart = quietTimeBeforeOrAt(firstSound)
        }

        if let lastSound = amplitudeBySecond.last(where: { $0.decibels > silenceThresholdDB })?.time {
            loopEnd = min(quietTimeAfterOrAt(lastSound), duration)
        }

        if loopEnd <= loopStart {
            loopStart = 0
            loopEnd = duration
        }
    }

    private func quietTimeBeforeOrAt(_ time: TimeInterval) -> TimeInterval {
        let quietSamples = amplitudeBySecond.filter {
            $0.time <= time && $0.decibels <= silenceThresholdDB
        }
        return quietSamples.max(by: { $0.time < $1.time })?.time ?? time
    }

    private func quietTimeAfterOrAt(_ time: TimeInterval) -> TimeInterval {
        let quietSamples = amplitudeBySecond.filter {
            $0.time >= time && $0.decibels <= silenceThresholdDB
        }
        return quietSamples.min(by: { $0.time < $1.time })?.time ?? time
    }

    private func startPlaybackMonitor() {
        playbackTask?.cancel()
        playbackTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(16))
                guard let self, self.player != nil else { return }

                self.currentTime = self.currentPlayerTime()
                self.refreshCurrentSubtitle()
                self.centerVisibleRange(on: self.currentTime)
                self.updateNowPlayingInfo()

                if self.shouldClearEndMarkerAfterPlayback && self.hasLoopEndMarker && self.currentTime >= self.loopEnd {
                    self.player?.pause()
                    self.seekPlayer(to: self.loopEnd)
                    self.currentTime = self.loopEnd
                    self.hasLoopEndMarker = false
                    self.shouldClearEndMarkerAfterPlayback = false
                    self.completedLoopCount = 0
                    self.activeLoopHistoryID = nil
                    self.refreshCurrentSubtitle(force: true)
                    self.centerVisibleRange(on: self.currentTime)
                    self.isPlaying = false
                    self.updateNowPlayingInfo(force: true)
                    self.playbackTask?.cancel()
                    return
                } else if self.hasLoopStartMarker && self.hasLoopEndMarker && self.currentTime >= self.loopEnd {
                    self.completedLoopCount += 1

                    if let repeatLimit = self.selectedRepeatOption.repeatLimit,
                       self.completedLoopCount >= repeatLimit {
                        self.player?.pause()
                        self.seekPlayer(to: self.loopEnd)
                        self.currentTime = self.loopEnd
                        self.refreshCurrentSubtitle(force: true)
                        self.isPlaying = false
                        self.updateNowPlayingInfo(force: true)
                        self.playbackTask?.cancel()
                        return
                    }

                    self.seekPlayer(to: self.loopStart)
                    self.currentTime = self.loopStart
                    self.refreshCurrentSubtitle(force: true)
                    self.centerVisibleRange(on: self.currentTime)

                    if self.isPlaying {
                        self.playCurrentAudio()
                    }
                }

                if !self.isPlayerPlaying && self.isPlaying {
                    self.isPlaying = false
                    self.updateNowPlayingInfo(force: true)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
