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

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(model.fileName)
                        .font(.headline)
                        .lineLimit(1)

                    WaveformView(model: model)
                        .frame(height: 220)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
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

                    Slider(
                        value: Binding(
                            get: { model.currentTime },
                            set: { model.seek(to: $0) }
                        ),
                        in: 0...max(model.duration, 0.1)
                    )
                    .disabled(!model.hasAudio)
                }

                VStack(spacing: 12) {
                    HStack {
                        Text("무음 기준")
                        Spacer()
                        Text("\(Int(model.silenceThresholdDB)) dB 이하")
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $model.silenceThresholdDB, in: -60 ... -15, step: 1) {
                        Text("무음 기준")
                    }
                    .disabled(!model.hasAudio)

                    HStack(spacing: 10) {
                        Button("시작점을 현재 위치로") {
                            model.setStartNearCurrentTime()
                        }
                        .buttonStyle(.bordered)

                        Button("끝점을 현재 위치로") {
                            model.setEndNearCurrentTime()
                        }
                        .buttonStyle(.bordered)
                    }
                    .disabled(!model.hasAudio)
                }

                HStack(spacing: 14) {
                    Button {
                        model.togglePlayback()
                    } label: {
                        Label(model.isPlaying ? "일시정지" : "재생", systemImage: model.isPlaying ? "pause.fill" : "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.hasAudio)

                    Button {
                        model.stop()
                    } label: {
                        Label("정지", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!model.hasAudio)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Label("반복 구간: \(timeText(model.loopStart)) - \(timeText(model.loopEnd))", systemImage: "repeat")
                    Text("파형의 시작/끝 핸들을 움직이면 \(Int(model.silenceThresholdDB)) dB 이하의 가까운 지점으로 자동 보정됩니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()
            }
            .padding()
            .navigationTitle("어학 반복기")
            .toolbar {
                Button {
                    isImporterPresented = true
                } label: {
                    Label("오디오 열기", systemImage: "folder")
                }
            }
            .fileImporter(
                isPresented: $isImporterPresented,
                allowedContentTypes: [.mp3, .mpeg4Audio, .audio],
                allowsMultipleSelection: false
            ) { result in
                model.importAudio(from: result)
            }
            .alert("오디오 오류", isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )) {
                Button("확인", role: .cancel) { }
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
}

struct WaveformView: View {
    @Bindable var model: LanguageRepeaterModel

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let startX = xPosition(for: model.loopStart, width: size.width)
            let endX = xPosition(for: model.loopEnd, width: size.width)
            let playX = xPosition(for: model.currentTime, width: size.width)

            ZStack(alignment: .leading) {
                Canvas { context, canvasSize in
                    drawWaveform(in: &context, size: canvasSize)
                }

                Rectangle()
                    .fill(.blue.opacity(0.16))
                    .frame(width: max(endX - startX, 0))
                    .offset(x: startX)

                marker(x: startX, color: .blue, title: "A")
                    .gesture(handleDrag(isStart: true, width: size.width))

                marker(x: endX, color: .red, title: "B")
                    .gesture(handleDrag(isStart: false, width: size.width))

                Rectangle()
                    .fill(.green)
                    .frame(width: 2)
                    .offset(x: playX)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        model.seek(to: time(for: value.location.x, width: size.width))
                    }
            )
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
        let stepX = size.width / CGFloat(max(samples.count - 1, 1))
        var path = Path()

        for index in samples.indices {
            let x = CGFloat(index) * stepX
            let amplitude = CGFloat(samples[index])
            let height = max(amplitude * midY * 0.92, 1)
            path.move(to: CGPoint(x: x, y: midY - height))
            path.addLine(to: CGPoint(x: x, y: midY + height))
        }

        context.stroke(path, with: .color(.primary.opacity(0.74)), lineWidth: max(stepX, 1))
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
        guard model.duration > 0 else { return 0 }
        return width * CGFloat(time / model.duration)
    }

    private func time(for x: CGFloat, width: CGFloat) -> TimeInterval {
        guard width > 0 else { return 0 }
        let progress = min(max(x / width, 0), 1)
        return model.duration * TimeInterval(progress)
    }
}

@Observable
final class LanguageRepeaterModel {
    var fileName = "MP3 또는 M4A 파일을 열어주세요"
    var waveformSamples: [Float] = []
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var loopStart: TimeInterval = 0
    var loopEnd: TimeInterval = 0
    var silenceThresholdDB: Double = -35
    var isPlaying = false
    var errorMessage: String?

    var hasAudio: Bool {
        player != nil
    }

    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var playbackTask: Task<Void, Never>?
    @ObservationIgnored private var amplitudeBySecond: [(time: TimeInterval, decibels: Double)] = []

    func importAudio(from result: Result<[URL], Error>) {
        do {
            guard let selectedURL = try result.get().first else { return }
            try loadAudio(from: selectedURL)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadAudio(from url: URL) throws {
        stop()

        let canAccess = url.startAccessingSecurityScopedResource()
        defer {
            if canAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        try configureAudioSession()

        let player = try AVAudioPlayer(contentsOf: url)
        player.prepareToPlay()
        self.player = player

        fileName = url.lastPathComponent
        duration = player.duration
        currentTime = 0
        loopStart = 0
        loopEnd = duration

        try analyzeWaveform(from: url)
        applyAutomaticLoopBounds()
    }

    func togglePlayback() {
        guard let player else { return }

        if player.isPlaying {
            pause()
        } else {
            if currentTime < loopStart || currentTime >= loopEnd {
                player.currentTime = loopStart
                currentTime = loopStart
            }
            player.play()
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
        isPlaying = false
    }

    func seek(to time: TimeInterval) {
        let nextTime = min(max(time, 0), duration)
        player?.currentTime = nextTime
        currentTime = nextTime
    }

    func setStartNearCurrentTime() {
        setLoopStart(currentTime)
    }

    func setEndNearCurrentTime() {
        setLoopEnd(currentTime)
    }

    func setLoopStart(_ time: TimeInterval) {
        let snappedTime = nearestQuietTime(to: time)
        loopStart = min(max(snappedTime, 0), max(loopEnd - 0.2, 0))

        if currentTime < loopStart {
            seek(to: loopStart)
        }
    }

    func setLoopEnd(_ time: TimeInterval) {
        let snappedTime = nearestQuietTime(to: time)
        loopEnd = max(min(snappedTime, duration), min(loopStart + 0.2, duration))

        if currentTime > loopEnd {
            seek(to: loopStart)
        }
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio)
        try session.setActive(true)
    }

    private func analyzeWaveform(from url: URL) throws {
        let audioFile = try AVAudioFile(forReading: url)
        let format = audioFile.processingFormat
        let frameCount = AVAudioFrameCount(audioFile.length)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw AudioLoadError.cannotCreateBuffer
        }

        try audioFile.read(into: buffer)

        guard let channelData = buffer.floatChannelData else {
            throw AudioLoadError.unsupportedAudioFormat
        }

        let channels = Int(format.channelCount)
        let frames = Int(buffer.frameLength)
        let sampleRate = format.sampleRate

        waveformSamples = makeWaveformSamples(channelData: channelData, channels: channels, frames: frames)
        amplitudeBySecond = makeDecibelSamples(channelData: channelData, channels: channels, frames: frames, sampleRate: sampleRate)
    }

    private func makeWaveformSamples(channelData: UnsafePointer<UnsafeMutablePointer<Float>>, channels: Int, frames: Int) -> [Float] {
        guard frames > 0 else { return [] }

        let targetSamples = min(1_200, frames)
        let framesPerSample = max(frames / targetSamples, 1)

        return stride(from: 0, to: frames, by: framesPerSample).map { startFrame in
            let endFrame = min(startFrame + framesPerSample, frames)
            var peak: Float = 0

            for frame in startFrame..<endFrame {
                var mixedSample: Float = 0

                for channel in 0..<channels {
                    mixedSample += abs(channelData[channel][frame])
                }

                peak = max(peak, mixedSample / Float(channels))
            }

            return min(peak, 1)
        }
    }

    private func makeDecibelSamples(
        channelData: UnsafePointer<UnsafeMutablePointer<Float>>,
        channels: Int,
        frames: Int,
        sampleRate: Double
    ) -> [(time: TimeInterval, decibels: Double)] {
        guard frames > 0, sampleRate > 0 else { return [] }

        let windowFrames = max(Int(sampleRate * 0.08), 1)

        return stride(from: 0, to: frames, by: windowFrames).map { startFrame in
            let endFrame = min(startFrame + windowFrames, frames)
            var sumSquares: Double = 0
            var sampleCount = 0

            for frame in startFrame..<endFrame {
                for channel in 0..<channels {
                    let sample = Double(channelData[channel][frame])
                    sumSquares += sample * sample
                    sampleCount += 1
                }
            }

            let rms = sqrt(sumSquares / Double(max(sampleCount, 1)))
            let decibels = rms > 0 ? 20 * log10(rms) : -100
            return (time: TimeInterval(startFrame) / sampleRate, decibels: decibels)
        }
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
                    currentTime = player.currentTime

                    if player.currentTime >= loopEnd {
                        player.currentTime = loopStart
                        currentTime = loopStart

                        if isPlaying {
                            player.play()
                        }
                    }

                    if !player.isPlaying && isPlaying {
                        isPlaying = false
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
            "오디오 버퍼를 만들 수 없습니다."
        case .unsupportedAudioFormat:
            "지원하지 않는 오디오 형식입니다."
        }
    }
}

#Preview {
    ContentView()
}
