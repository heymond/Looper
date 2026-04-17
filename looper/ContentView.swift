//
//  ContentView.swift
//  Looper
//
//  Created by Jinyoung Kim on 4/13/26.
//

import AVFoundation
import Observation
import Speech
import SwiftUI
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

                if model.hasLoopStartMarker || model.hasLoopEndMarker {
                    let highlightStartX = model.hasLoopStartMarker ? clippedStartX : playX
                    let highlightEndX = model.hasLoopEndMarker ? clippedEndX : playX
                    Rectangle()
                        .fill(.blue.opacity(0.26))
                        .frame(width: max(highlightEndX - highlightStartX, 0))
                        .offset(x: highlightStartX)
                }

                Rectangle()
                    .fill(.green)
                    .frame(width: 2)
                    .offset(x: playX)

                if model.hasLoopStartMarker {
                    marker(x: startX, color: .blue, title: "A")
                        .gesture(handleDrag(isStart: true, width: size.width))
                }

                if model.hasLoopEndMarker {
                    marker(x: endX, color: .red, title: "B")
                        .gesture(handleDrag(isStart: false, width: size.width))
                }
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
        let visibleSamples = renderedSamplesForVisibleRange(from: samples, width: size.width, prefersFastRender: isPinching)
        let stepX = size.width / CGFloat(max(visibleSamples.count - 1, 1))
        let lineWidth = min(0.45, max(stepX * 0.25, 0.2))
        var path = Path()

        for index in visibleSamples.indices {
            let x = CGFloat(index) * stepX
            let amplitude = CGFloat(visibleSamples[index])
            let height = max(amplitude * midY * 0.92, 0.5)
            path.move(to: CGPoint(x: x, y: midY - height))
            path.addLine(to: CGPoint(x: x, y: midY + height))
        }

        context.stroke(path, with: .color(.primary.opacity(1)), lineWidth: lineWidth)
    }

    private func marker(x: CGFloat, color: Color, title: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 26, height: 22)
                .background(color, in: RoundedRectangle(cornerRadius: 6))

            Spacer(minLength: 0)
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

    private func renderedSamplesForVisibleRange(from samples: [Float], width: CGFloat, prefersFastRender: Bool) -> [Float] {
        let minimumBarSpacing: CGFloat = 1.5
        let targetCount = max(Int(width / minimumBarSpacing), 1)
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

            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let selectedTime = time(for: value.location.x, width: size.width)
                        model.seek(to: selectedTime)
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
                peak = max(peak, abs(samples[index]))
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

private extension UTType {
    static let mp3Audio = UTType(filenameExtension: "mp3", conformingTo: .audio) ?? .mp3
    static let m4aAudio = UTType(filenameExtension: "m4a", conformingTo: .audio) ?? .mpeg4Audio
    static let srtSubtitle = UTType(filenameExtension: "srt", conformingTo: .plainText) ?? .plainText
    static let webVTTSubtitle = UTType(filenameExtension: "vtt", conformingTo: .plainText) ?? .plainText
}

struct AudioDocumentPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let initialDirectoryURL: URL?
    let onPick: (Result<[URL], Error>) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.mp3Audio, .m4aAudio, .srtSubtitle, .webVTTSubtitle],
            asCopy: false
        )
        picker.allowsMultipleSelection = true
        picker.directoryURL = initialDirectoryURL
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented, onPick: onPick)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        @Binding private var isPresented: Bool
        private let onPick: (Result<[URL], Error>) -> Void

        init(isPresented: Binding<Bool>, onPick: @escaping (Result<[URL], Error>) -> Void) {
            _isPresented = isPresented
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            isPresented = false
            onPick(.success(urls))
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            isPresented = false
        }
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

    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var playbackTask: Task<Void, Never>?
    @ObservationIgnored private var analysisTask: Task<Void, Never>?
    @ObservationIgnored private var transcriptionTask: SFSpeechRecognitionTask?
    @ObservationIgnored private var pendingSubtitleSegments: [SubtitleSegment] = []
    @ObservationIgnored private var loadedAudioURL: URL?
    @ObservationIgnored private var amplitudeBySecond: [DecibelSample] = []
    @ObservationIgnored private var shouldClearEndMarkerAfterPlayback = false
    @ObservationIgnored private var didAttemptLastAudioLoad = false
    @ObservationIgnored private let lastAudioPathKey = "lastAudioPath"
    @ObservationIgnored private let lastAudioFileNameKey = "lastAudioFileName"
    @ObservationIgnored private let lastOpenedDirectoryPathKey = "lastOpenedDirectoryPath"

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
                if let cachedAnalysis = try Self.loadCachedAnalysis(for: localURL, windowMilliseconds: windowMilliseconds) {
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

                let waveformSamples = try Self.analyzeWaveformSamples(from: localURL)
                try Task.checkCancellation()
                await MainActor.run { [weak self] in
                    guard let self,
                          self.loadedAudioURL == localURL,
                          Int(self.silenceWindowMilliseconds.rounded()) == windowMilliseconds else { return }
                    self.waveformSamples = waveformSamples
                    self.isAnalyzingAudio = true
                }

                let initialDecibelSamples = try Self.analyzeDecibelSamples(
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

                let decibelSamples = try Self.analyzeDecibelSamples(
                    from: localURL,
                    windowMilliseconds: windowMilliseconds
                )
                let analysis = WaveformAnalysis(waveformSamples: waveformSamples, decibelSamples: decibelSamples)
                try Task.checkCancellation()
                try Self.saveCachedAnalysis(analysis, for: localURL, windowMilliseconds: windowMilliseconds)

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
        if let cachedSubtitles = try? Self.loadCachedSubtitles(for: url), !cachedSubtitles.isEmpty {
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
                    let subtitleSegments = result.map { Self.subtitleSegments(from: $0.bestTranscription.segments) } ?? []
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
                            try? Self.saveCachedSubtitles(finalSubtitles, for: url)
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

    nonisolated private static func subtitleSegments(from segments: [SFTranscriptionSegment]) -> [SubtitleSegment] {
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

    func adjustSubtitleSync(by amount: TimeInterval) {
        subtitleSyncOffset = min(max(subtitleSyncOffset + amount, -5), 5)
        refreshCurrentSubtitle(force: true)
    }

    func resetSubtitleSync() {
        subtitleSyncOffset = 0
        refreshCurrentSubtitle(force: true)
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
            refreshCurrentSubtitle(force: true)
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
        let stopTime = preferredStopTime()
        player?.currentTime = stopTime
        currentTime = stopTime
        refreshCurrentSubtitle(force: true)
        centerVisibleRange(on: stopTime)
        completedLoopCount = 0
        isPlaying = false
    }

    private func preferredStopTime() -> TimeInterval {
        if hasLoopStartMarker {
            return loopStart
        }

        return 0
    }

    func seek(to time: TimeInterval) {
        let nextTime = min(max(time, 0), duration)
        player?.currentTime = nextTime
        currentTime = nextTime
        refreshCurrentSubtitle(force: true)
        centerVisibleRange(on: nextTime)
    }

    func seekToVisibleCenter() {
        let centerTime = (visibleStartTime + visibleEndTime) / 2
        seek(to: centerTime)
    }

    private func synchronizedCurrentTime() -> TimeInterval {
        let nextTime = min(max(player?.currentTime ?? currentTime, 0), duration)
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
        guard let player else { return }
        loopStart = item.start
        loopEnd = item.end
        hasLoopStartMarker = true
        hasLoopEndMarker = true
        shouldClearEndMarkerAfterPlayback = false
        activeLoopHistoryID = item.id
        completedLoopCount = 0
        player.currentTime = item.start
        currentTime = item.start
        refreshCurrentSubtitle(force: true)
        centerVisibleRange(on: item.start)
        player.play()
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

    nonisolated private static func isAudioFile(_ url: URL) -> Bool {
        ["mp3", "m4a"].contains(url.pathExtension.lowercased())
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
        let subtitles = parseSubtitleContent(content, fileExtension: subtitleURL.pathExtension)
        return subtitles.isEmpty ? nil : subtitles
    }

    nonisolated private static func sidecarSubtitleURL(for audioURL: URL) -> URL? {
        let directoryURL = audioURL.deletingLastPathComponent()
        let baseName = audioURL.deletingPathExtension().lastPathComponent.lowercased()
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        return urls.first { url in
            let extensionName = url.pathExtension.lowercased()
            return ["vtt", "srt"].contains(extensionName)
                && url.deletingPathExtension().lastPathComponent.lowercased() == baseName
        }
    }

    nonisolated private static func parseSubtitleContent(_ content: String, fileExtension: String) -> [SubtitleSegment] {
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

    private func audioDirectoryURL() throws -> URL {
        let documentsURL = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return documentsURL.appendingPathComponent("AudioFiles", isDirectory: true)
    }

    nonisolated private static func loadCachedAnalysis(for url: URL, windowMilliseconds: Int) throws -> WaveformAnalysis? {
        let cacheURL = try analysisCacheURL(for: url, windowMilliseconds: windowMilliseconds)
        guard FileManager.default.fileExists(atPath: cacheURL.path) else { return nil }
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }

        return decodeCachedAnalysis(from: data)
    }

    nonisolated private static func loadCachedSubtitles(for url: URL) throws -> [SubtitleSegment]? {
        let cacheURL = try subtitlesCacheURL(for: url)
        guard FileManager.default.fileExists(atPath: cacheURL.path) else { return nil }
        let data = try Data(contentsOf: cacheURL)
        return try JSONDecoder().decode([SubtitleSegment].self, from: data)
    }

    nonisolated private static func saveCachedSubtitles(_ subtitles: [SubtitleSegment], for url: URL) throws {
        let cacheURL = try subtitlesCacheURL(for: url)
        let cacheDirectoryURL = cacheURL.deletingLastPathComponent()

        if !FileManager.default.fileExists(atPath: cacheDirectoryURL.path) {
            try FileManager.default.createDirectory(at: cacheDirectoryURL, withIntermediateDirectories: true)
        }

        let data = try JSONEncoder().encode(subtitles)
        try data.write(to: cacheURL, options: [.atomic])
    }

    nonisolated private static func saveCachedAnalysis(_ analysis: WaveformAnalysis, for url: URL, windowMilliseconds: Int) throws {
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

    nonisolated private static func analyzeWaveformSamples(from url: URL) throws -> [Float] {
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

    nonisolated private static func analyzeDecibelSamples(
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
        playbackTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(16))
                guard let self, let player = self.player else { return }

                await MainActor.run {
                    self.currentTime = player.currentTime
                    self.refreshCurrentSubtitle()
                    self.centerVisibleRange(on: self.currentTime)

                    if self.shouldClearEndMarkerAfterPlayback && self.hasLoopEndMarker && player.currentTime >= self.loopEnd {
                        player.pause()
                        player.currentTime = self.loopEnd
                        self.currentTime = self.loopEnd
                        self.hasLoopEndMarker = false
                        self.shouldClearEndMarkerAfterPlayback = false
                        self.completedLoopCount = 0
                        self.activeLoopHistoryID = nil
                        self.refreshCurrentSubtitle(force: true)
                        self.centerVisibleRange(on: self.currentTime)
                        self.isPlaying = false
                        self.playbackTask?.cancel()
                        return
                    } else if self.hasLoopStartMarker && self.hasLoopEndMarker && player.currentTime >= self.loopEnd {
                        self.completedLoopCount += 1

                        if let repeatLimit = self.selectedRepeatOption.repeatLimit,
                           self.completedLoopCount >= repeatLimit {
                            player.pause()
                            player.currentTime = self.loopEnd
                            self.currentTime = self.loopEnd
                            self.refreshCurrentSubtitle(force: true)
                            self.isPlaying = false
                            self.playbackTask?.cancel()
                            return
                        }

                        player.currentTime = self.loopStart
                        self.currentTime = self.loopStart
                        self.refreshCurrentSubtitle(force: true)
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
