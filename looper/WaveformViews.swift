//
//  WaveformViews.swift
//  Looper
//

import SwiftUI

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

