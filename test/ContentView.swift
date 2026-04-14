//
//  ContentView.swift
//  test
//
//  Created by Jinyoung Kim on 4/13/26.
//

import AVFoundation
import Observation
import SwiftUI
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

                        if isRecentFilesPresented {
                            recentFilesPanel
                                .offset(y: 30)
                                .zIndex(2)
                        }
                    }

                    VStack(spacing: 0) {
                        WaveformView(model: model)
                            .frame(height: 150)

                        OverviewWaveformView(model: model)
                            .frame(height: 50)
                            .background(.white.opacity(0.1))
                    }
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    HStack {
                        Text("View: \(timeText(model.visibleStartTime)) - \(timeText(model.visibleEndTime))")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button("Show All") {
                            model.resetZoom()
                        }
                        .font(.caption)
                        .disabled(!model.hasAudio)
                    }
                }

                VStack(spacing: 12) {
                    HStack {
                        Text(timeText(model.currentTime))
                            .monospacedDigit()
                        Spacer()
                        Text(timeText(model.duration))
                            .monospacedDigit()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                    .buttonStyle(.bordered)
                    .disabled(!model.hasAudio)
                }
                .frame(maxWidth: .infinity, alignment: .center)

                VStack(alignment: .leading, spacing: 6) {
                    Label("Loop range: \(timeText(model.loopStart)) - \(timeText(model.loopEnd))", systemImage: "repeat")
                    Text("Move the A/B handles on the waveform to snap to nearby points at \(Int(model.silenceThresholdDB)) dB or lower.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()
            }
            .padding()
            .navigationTitle("Loop Player")
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
            .fileImporter(
                isPresented: $isImporterPresented,
                allowedContentTypes: [.mp3, .mpeg4Audio, .audio],
                allowsMultipleSelection: false
            ) { result in
                model.importAudio(from: result)
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
    }

    private func timeText(_ time: TimeInterval) -> String {
        let totalSeconds = max(Int(time.rounded()), 0)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var silenceControlPanel: some View {
        HStack(spacing: 10) {
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
        .frame(width: 240, alignment: .leading)
        .padding(10)
        .background(.background, in: RoundedRectangle(cornerRadius: 0.2))
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

struct WaveformView: View {
    @Bindable var model: LanguageRepeaterModel
    @State private var magnifyStartRange: ClosedRange<TimeInterval>?
    @State private var dragStartRange: ClosedRange<TimeInterval>?
    @State private var isPinching = false

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let startX = xPosition(for: model.loopStart, width: size.width)
            let endX = xPosition(for: model.loopEnd, width: size.width)
            let playX = playheadX(width: size.width)
            let clippedStartX = min(max(startX, 0), size.width)
            let clippedEndX = min(max(endX, 0), size.width)

            ZStack(alignment: .leading) {
                Canvas { context, canvasSize in
                    drawWaveform(in: &context, size: canvasSize)
                }

                if model.hasLoopStartMarker && model.hasLoopEndMarker {
                    Rectangle()
                        .fill(.blue.opacity(0.16))
                        .frame(width: max(clippedEndX - clippedStartX, 0))
                        .offset(x: clippedStartX)
                }

                if model.hasLoopStartMarker {
                    marker(x: startX, color: .blue, title: "A")
                        .gesture(handleDrag(isStart: true, width: size.width))
                }

                if model.hasLoopEndMarker {
                    marker(x: endX, color: .red, title: "B")
                        .gesture(handleDrag(isStart: false, width: size.width))
                }

                Rectangle()
                    .fill(.green)
                    .frame(width: 2)
                    .offset(x: playX)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        guard !isPinching, abs(value.translation.width) >= 4 else { return }

                        if dragStartRange == nil {
                            dragStartRange = model.visibleStartTime...model.visibleEndTime
                        }

                        if let dragStartRange {
                            model.moveVisibleRange(
                                from: dragStartRange,
                                horizontalTranslation: value.translation.width,
                                width: size.width
                            )
                        }
                    }
                    .onEnded { _ in
                        model.seekToVisibleCenter()
                        dragStartRange = nil
                    }
            )
            .simultaneousGesture(
                MagnificationGesture(minimumScaleDelta: 0.01)
                    .onChanged { magnification in
                        isPinching = true

                        if magnifyStartRange == nil {
                            magnifyStartRange = model.visibleStartTime...model.visibleEndTime
                        }

                        if let magnifyStartRange {
                            model.zoomVisibleRange(
                                from: magnifyStartRange,
                                magnification: magnification
                            )
                        }
                    }
                    .onEnded { _ in
                        magnifyStartRange = nil
                        isPinching = false
                    }
            )
            .clipped()
        }
    }

    private func drawWaveform(in context: inout GraphicsContext, size: CGSize) {
        let samples = model.waveformSamples
        guard !samples.isEmpty else {
            var path = Path()
            path.move(to: CGPoint(x: 16, y: size.height / 2))
            path.addLine(to: CGPoint(x: size.width - 16, y: size.height / 2))
            context.stroke(path, with: .color(.secondary), lineWidth: 1)
            return
        }

        let midY = size.height / 2
        let visibleSamples = renderedSamplesForVisibleRange(from: samples, width: size.width)
        let stepX = size.width / CGFloat(max(visibleSamples.count - 1, 1))
        var path = Path()

        for index in visibleSamples.indices {
            let x = CGFloat(index) * stepX
            let amplitude = CGFloat(visibleSamples[index])
            let height = max(amplitude * midY * 0.92, 1)
            path.move(to: CGPoint(x: x, y: midY - height))
            path.addLine(to: CGPoint(x: x, y: midY + height))
        }

        context.stroke(path, with: .color(.primary.opacity(0.74)), lineWidth: 1)
    }

    private func marker(x: CGFloat, color: Color, title: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 26, height: 22)
                .background(color, in: RoundedRectangle(cornerRadius: 6))

            Rectangle()
                .fill(color)
                .frame(width: 3)
        }
        .frame(width: 44)
        .offset(x: x - 22)
    }

    private func handleDrag(isStart: Bool, width: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let selectedTime = time(for: value.location.x, width: width)
                if isStart {
                    model.setLoopStart(selectedTime)
                } else {
                    model.setLoopEnd(selectedTime)
                }
            }
    }

    private func xPosition(for time: TimeInterval, width: CGFloat) -> CGFloat {
        guard model.visibleDuration > 0 else { return 0 }
        return width * CGFloat((time - model.visibleStartTime) / model.visibleDuration)
    }

    private func playheadX(width: CGFloat) -> CGFloat {
        width / 2
    }

    private func time(for x: CGFloat, width: CGFloat) -> TimeInterval {
        guard width > 0 else { return 0 }
        let progress = min(max(x / width, 0), 1)
        return model.visibleStartTime + (model.visibleDuration * TimeInterval(progress))
    }

    private func sampleIndex(for time: TimeInterval, sampleCount: Int) -> Int {
        guard model.duration > 0, sampleCount > 0 else { return 0 }
        let progress = min(max(time / model.duration, 0), 1)
        return min(max(Int(progress * Double(sampleCount - 1)), 0), sampleCount - 1)
    }

    private func renderedSamplesForVisibleRange(from samples: [Float], width: CGFloat) -> [Float] {
        let targetCount = max(Int(width * 2), 1)
        guard model.duration > 0, model.visibleDuration > 0 else { return [] }

        return (0..<targetCount).map { column in
            let bucketStartTime = model.visibleStartTime + model.visibleDuration * TimeInterval(column) / TimeInterval(targetCount)
            let bucketEndTime = model.visibleStartTime + model.visibleDuration * TimeInterval(column + 1) / TimeInterval(targetCount)
            let clippedStartTime = max(bucketStartTime, 0)
            let clippedEndTime = min(bucketEndTime, model.duration)

            guard clippedEndTime > clippedStartTime else { return 0 }

            let startIndex = sampleIndex(for: clippedStartTime, sampleCount: samples.count)
            let endIndex = sampleIndex(for: clippedEndTime, sampleCount: samples.count)
            var peak: Float = 0

            for index in startIndex...max(startIndex, endIndex) {
                peak = max(peak, samples[index])
            }

            return peak
        }
    }
}

struct OverviewWaveformView: View {
    @Bindable var model: LanguageRepeaterModel

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let visibleStartX = xPosition(for: model.visibleStartTime, width: size.width)
            let visibleEndX = xPosition(for: model.visibleEndTime, width: size.width)
            let clippedVisibleStartX = min(max(visibleStartX, 0), size.width)
            let clippedVisibleEndX = min(max(visibleEndX, 0), size.width)
            let loopStartX = xPosition(for: model.loopStart, width: size.width)
            let loopEndX = xPosition(for: model.loopEnd, width: size.width)
            let visibleWidth = max(clippedVisibleEndX - clippedVisibleStartX, 0)
            let edgeRadius: CGFloat = 8
            let leftRadius = clippedVisibleStartX <= 0.5 ? edgeRadius : 0
            let rightRadius = clippedVisibleEndX >= size.width - 0.5 ? edgeRadius : 0

            ZStack(alignment: .bottomLeading) {
                Canvas { context, canvasSize in
                    drawOverview(in: &context, size: canvasSize)
                }

                if visibleWidth > 0 {
                    EdgeMatchedRectangle(leftRadius: leftRadius, rightRadius: rightRadius)
                        .fill(.blue.opacity(0.18))
                        .frame(width: visibleWidth)
                        .offset(x: clippedVisibleStartX)

                    EdgeMatchedRectangle(leftRadius: leftRadius, rightRadius: rightRadius)
                        .stroke(.blue, lineWidth: 1)
                        .frame(width: visibleWidth)
                        .offset(x: clippedVisibleStartX)
                }

                if model.hasLoopStartMarker && model.hasLoopEndMarker {
                    Rectangle()
                        .fill(.red.opacity(0.18))
                        .frame(width: max(loopEndX - loopStartX, 4))
                        .offset(x: loopStartX)
                }

                if model.hasLoopStartMarker {
                    Rectangle()
                        .fill(.blue)
                        .frame(width: 2)
                        .offset(x: loopStartX)
                }

                if model.hasLoopEndMarker {
                    Rectangle()
                        .fill(.red)
                        .frame(width: 2)
                        .offset(x: loopEndX)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let selectedTime = time(for: value.location.x, width: size.width)
                        model.moveVisibleRangeCenter(to: selectedTime)
                    }
                    .onEnded { _ in
                        model.seekToVisibleCenter()
                    }
            )
            .clipped()
        }
    }

    private func drawOverview(in context: inout GraphicsContext, size: CGSize) {
        let samples = renderedSamples(from: model.waveformSamples, width: size.width)
        guard !samples.isEmpty else {
            var path = Path()
            path.move(to: CGPoint(x: 8, y: size.height / 2))
            path.addLine(to: CGPoint(x: size.width - 8, y: size.height / 2))
            context.stroke(path, with: .color(.secondary), lineWidth: 1)
            return
        }

        let midY = size.height / 2
        let stepX = size.width / CGFloat(max(samples.count - 1, 1))
        var path = Path()

        for index in samples.indices {
            let x = CGFloat(index) * stepX
            let amplitude = CGFloat(samples[index])
            let height = max(amplitude * midY * 0.82, 1)
            path.move(to: CGPoint(x: x, y: midY - height))
            path.addLine(to: CGPoint(x: x, y: midY + height))
        }

        context.stroke(path, with: .color(.primary.opacity(0.5)), lineWidth: 1)
    }

    private func renderedSamples(from samples: [Float], width: CGFloat) -> [Float] {
        guard !samples.isEmpty else { return [] }

        let targetCount = max(Int(width * 2), 1)
        guard samples.count > targetCount else { return samples }

        let samplesPerColumn = Double(samples.count) / Double(targetCount)

        return (0..<targetCount).map { column in
            let bucketStart = Int(Double(column) * samplesPerColumn)
            let bucketEnd = min(Int(Double(column + 1) * samplesPerColumn), samples.count - 1)
            var peak: Float = 0

            for index in bucketStart...max(bucketStart, bucketEnd) {
                peak = max(peak, samples[index])
            }

            return peak
        }
    }

    private func xPosition(for time: TimeInterval, width: CGFloat) -> CGFloat {
        guard model.duration > 0 else { return 0 }
        return width * CGFloat(min(max(time / model.duration, 0), 1))
    }

    private func time(for x: CGFloat, width: CGFloat) -> TimeInterval {
        guard width > 0 else { return 0 }
        let progress = min(max(x / width, 0), 1)
        return model.duration * TimeInterval(progress)
    }
}

struct EdgeMatchedRectangle: Shape {
    var leftRadius: CGFloat
    var rightRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let left = min(leftRadius, rect.width / 2, rect.height / 2)
        let right = min(rightRadius, rect.width / 2, rect.height / 2)
        var path = Path()

        path.move(to: CGPoint(x: rect.minX + left, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - right, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + right),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - right))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - right, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + left, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - left),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + left))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + left, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.closeSubpath()
        return path
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
    var silenceThresholdDB: Double = -35
    var hasLoopStartMarker = false
    var hasLoopEndMarker = false
    var selectedRepeatOption: RepeatOption = .infinite
    var completedLoopCount = 0
    var isPlaying = false
    var isAnalyzingAudio = false
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

    var currentDecibelText: String {
        guard let sample = amplitudeBySecond.min(by: { abs($0.time - currentTime) < abs($1.time - currentTime) }) else {
            return "-- dB"
        }

        return "\(Int(sample.decibels.rounded())) dB"
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

    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var playbackTask: Task<Void, Never>?
    @ObservationIgnored private var analysisTask: Task<Void, Never>?
    @ObservationIgnored private var loadedAudioURL: URL?
    @ObservationIgnored private var amplitudeBySecond: [DecibelSample] = []
    @ObservationIgnored private var didAttemptLastAudioLoad = false
    @ObservationIgnored private let lastAudioPathKey = "lastAudioPath"
    @ObservationIgnored private let lastAudioFileNameKey = "lastAudioFileName"

    func importAudio(from result: Result<[URL], Error>) {
        do {
            guard let selectedURL = try result.get().first else { return }
            try loadAudio(from: selectedURL)
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

    func loadAudio(from url: URL) throws {
        stop()
        analysisTask?.cancel()

        let canAccess = url.startAccessingSecurityScopedResource()
        defer {
            if canAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let localURL = try localAudioURL(for: url)
        try configureAudioSession()

        let player = try AVAudioPlayer(contentsOf: localURL)
        player.prepareToPlay()
        self.player = player

        fileName = localURL.lastPathComponent
        loadedAudioURL = localURL
        UserDefaults.standard.set(localURL.path, forKey: lastAudioPathKey)
        UserDefaults.standard.set(localURL.lastPathComponent, forKey: lastAudioFileNameKey)
        duration = player.duration
        currentTime = 0
        loopStart = 0
        loopEnd = duration
        hasLoopStartMarker = false
        hasLoopEndMarker = false
        completedLoopCount = 0
        let initialVisibleDuration = min(max(duration, 1), 30)
        visibleStartTime = -initialVisibleDuration / 2
        visibleEndTime = initialVisibleDuration / 2
        waveformSamples = []
        amplitudeBySecond = []
        isAnalyzingAudio = true

        analysisTask = Task.detached(priority: .userInitiated) { [localURL] in
            do {
                let analysis: WaveformAnalysis
                if let cachedAnalysis = try Self.loadCachedAnalysis(for: localURL) {
                    analysis = cachedAnalysis
                } else {
                    analysis = try Self.analyzeWaveform(from: localURL)
                    try Self.saveCachedAnalysis(analysis, for: localURL)
                }

                await MainActor.run { [weak self] in
                    guard let self, self.loadedAudioURL == localURL else { return }
                    self.waveformSamples = analysis.waveformSamples
                    self.amplitudeBySecond = analysis.decibelSamples
                    self.applyAutomaticLoopBounds()
                    self.isAnalyzingAudio = false
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self, self.loadedAudioURL == localURL else { return }
                    self.isAnalyzingAudio = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func togglePlayback() {
        guard let player else { return }

        if player.isPlaying {
            pause()
        } else {
            if hasLoopStartMarker && hasLoopEndMarker && (currentTime < loopStart || currentTime >= loopEnd) {
                player.currentTime = loopStart
                currentTime = loopStart
            }
            centerVisibleRange(on: currentTime)
            player.play()
            completedLoopCount = 0
            isPlaying = true
            startPlaybackMonitor()
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        playbackTask?.cancel()
    }

    func stop() {
        playbackTask?.cancel()
        player?.stop()
        player?.currentTime = 0
        currentTime = 0
        completedLoopCount = 0
        isPlaying = false
    }

    func seek(to time: TimeInterval) {
        let nextTime = min(max(time, 0), duration)
        player?.currentTime = nextTime
        currentTime = nextTime
        centerVisibleRange(on: nextTime)
    }

    func seekToVisibleCenter() {
        let centerTime = (visibleStartTime + visibleEndTime) / 2
        seek(to: centerTime)
    }

    func toggleStartMarkerAtCurrentTime() {
        if hasLoopStartMarker {
            hasLoopStartMarker = false
            completedLoopCount = 0
        } else {
            setLoopStart(currentTime)
        }
    }

    func toggleEndMarkerAtCurrentTime() {
        if hasLoopEndMarker {
            hasLoopEndMarker = false
            completedLoopCount = 0
        } else {
            setLoopEnd(currentTime)
        }
    }

    func clearLoopMarkers() {
        hasLoopStartMarker = false
        hasLoopEndMarker = false
        completedLoopCount = 0
    }

    func setLoopStart(_ time: TimeInterval) {
        let snappedTime = nearestQuietTime(to: time)
        loopStart = min(max(snappedTime, 0), max(loopEnd - 0.2, 0))
        hasLoopStartMarker = true
        completedLoopCount = 0

        if currentTime < loopStart {
            seek(to: loopStart)
        }
    }

    func setLoopEnd(_ time: TimeInterval) {
        let snappedTime = nearestQuietTime(to: time)
        loopEnd = max(min(snappedTime, duration), min(loopStart + 0.2, duration))
        hasLoopEndMarker = true
        completedLoopCount = 0

        if currentTime > loopEnd {
            seek(to: loopStart)
        }
    }

    func resetZoom() {
        visibleStartTime = 0
        visibleEndTime = duration
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
        let minimumSpan = min(max(duration / 120, 0.5), duration)
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
        let span = visibleDuration
        guard duration > 0, span > 0 else { return }

        let halfSpan = span / 2
        visibleStartTime = time - halfSpan
        visibleEndTime = time + halfSpan
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio)
        try session.setActive(true)
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

    private func audioDirectoryURL() throws -> URL {
        let documentsURL = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return documentsURL.appendingPathComponent("AudioFiles", isDirectory: true)
    }

    nonisolated private static func loadCachedAnalysis(for url: URL) throws -> WaveformAnalysis? {
        let cacheURL = try analysisCacheURL(for: url)
        guard FileManager.default.fileExists(atPath: cacheURL.path) else { return nil }
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }

        return decodeCachedAnalysis(from: data)
    }

    nonisolated private static func saveCachedAnalysis(_ analysis: WaveformAnalysis, for url: URL) throws {
        let cacheURL = try analysisCacheURL(for: url)
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

    nonisolated private static func analysisCacheURL(for url: URL) throws -> URL {
        let documentsURL = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let cacheDirectoryURL = documentsURL.appendingPathComponent("AnalysisCache", isDirectory: true)
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        let modifiedAt = ((attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0).rounded()
        let fileKey = "\(url.lastPathComponent)-\(size)-\(Int(modifiedAt))"
        let safeFileKey = fileKey.map { character in
            character.isLetter || character.isNumber ? character : "-"
        }
        .map(String.init)
        .joined()

        return cacheDirectoryURL.appendingPathComponent("\(safeFileKey).json")
    }

    nonisolated private static func analyzeWaveform(from url: URL) throws -> WaveformAnalysis {
        let audioFile = try AVAudioFile(forReading: url)
        let format = audioFile.processingFormat
        let totalFrames = Int(audioFile.length)
        let channels = Int(format.channelCount)
        let sampleRate = format.sampleRate

        guard totalFrames > 0, channels > 0, sampleRate > 0 else {
            return WaveformAnalysis(waveformSamples: [], decibelSamples: [])
        }

        let audioDuration = Double(totalFrames) / sampleRate
        let targetSamples = min(max(Int(audioDuration * 60), 1_200), 24_000, totalFrames)
        let windowFrames = max(Int(sampleRate * 0.035), 512)
        let stepFrames = max(totalFrames / targetSamples, 1)

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(windowFrames)
        ) else {
            throw AudioLoadError.cannotCreateBuffer
        }

        var waveformSamples: [Float] = []
        waveformSamples.reserveCapacity(targetSamples)
        var decibelSamples: [DecibelSample] = []
        decibelSamples.reserveCapacity(targetSamples)

        for sampleIndex in 0..<targetSamples {
            let framePosition = min(sampleIndex * stepFrames, max(totalFrames - 1, 0))
            audioFile.framePosition = AVAudioFramePosition(framePosition)
            try audioFile.read(into: buffer, frameCount: AVAudioFrameCount(windowFrames))

            guard let channelData = buffer.floatChannelData else {
                throw AudioLoadError.unsupportedAudioFormat
            }

            let framesRead = Int(buffer.frameLength)
            guard framesRead > 0 else { continue }

            var peak: Float = 0
            var sumSquares: Double = 0
            var sampleCount = 0

            for frame in 0..<framesRead {
                var mixedSample: Float = 0

                for channel in 0..<channels {
                    let sample = channelData[channel][frame]
                    mixedSample += abs(sample)
                    sumSquares += Double(sample * sample)
                    sampleCount += 1
                }

                peak = max(peak, mixedSample / Float(channels))
            }

            waveformSamples.append(min(peak, 1))
            decibelSamples.append(
                DecibelSample(
                    time: TimeInterval(framePosition) / sampleRate,
                    decibels: decibels(sumSquares: sumSquares, sampleCount: sampleCount)
                )
            )
        }

        return WaveformAnalysis(waveformSamples: waveformSamples, decibelSamples: decibelSamples)
    }

    nonisolated private static func decibels(sumSquares: Double, sampleCount: Int) -> Double {
        let rms = sqrt(sumSquares / Double(max(sampleCount, 1)))
        return rms > 0 ? 20 * log10(rms) : -100
    }

    private func applyAutomaticLoopBounds() {
        guard !amplitudeBySecond.isEmpty else { return }

        if let firstSound = amplitudeBySecond.first(where: { $0.decibels > silenceThresholdDB })?.time {
            loopStart = nearestQuietTime(to: firstSound)
        }

        if let lastSound = amplitudeBySecond.last(where: { $0.decibels > silenceThresholdDB })?.time {
            loopEnd = min(nearestQuietTime(to: lastSound), duration)
        }

        if loopEnd <= loopStart {
            loopStart = 0
            loopEnd = duration
        }
    }

    private func nearestQuietTime(to time: TimeInterval) -> TimeInterval {
        let quietSamples = amplitudeBySecond.filter { $0.decibels <= silenceThresholdDB }
        guard let nearest = quietSamples.min(by: { abs($0.time - time) < abs($1.time - time) }) else {
            return time
        }

        return nearest.time
    }

    private func startPlaybackMonitor() {
        playbackTask?.cancel()
        playbackTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(60))
                guard let self, let player = self.player else { return }

                await MainActor.run {
                    self.currentTime = player.currentTime
                    self.centerVisibleRange(on: self.currentTime)

                    if self.hasLoopEndMarker && player.currentTime >= self.loopEnd {
                        guard self.hasLoopStartMarker else {
                            player.pause()
                            player.currentTime = self.loopEnd
                            self.currentTime = self.loopEnd
                            self.isPlaying = false
                            self.playbackTask?.cancel()
                            return
                        }

                        self.completedLoopCount += 1

                        if let repeatLimit = self.selectedRepeatOption.repeatLimit,
                           self.completedLoopCount >= repeatLimit {
                            player.pause()
                            player.currentTime = self.loopEnd
                            self.currentTime = self.loopEnd
                            self.isPlaying = false
                            self.playbackTask?.cancel()
                            return
                        }

                        player.currentTime = self.loopStart
                        self.currentTime = self.loopStart
                        self.centerVisibleRange(on: self.currentTime)

                        if self.isPlaying {
                            player.play()
                        }
                    }

                    if !player.isPlaying && self.isPlaying {
                        self.isPlaying = false
                    }
                }
            }
        }
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

private struct WaveformAnalysis: Sendable {
    let waveformSamples: [Float]
    let decibelSamples: [DecibelSample]
}

private struct DecibelSample: Sendable {
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

#Preview {
    ContentView()
}
