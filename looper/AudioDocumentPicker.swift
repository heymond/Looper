//
//  AudioDocumentPicker.swift
//  Looper
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

private extension UTType {
    static let mp3Audio = UTType(filenameExtension: "mp3") ?? .mp3
    static let m4aAudio = UTType(filenameExtension: "m4a") ?? .mpeg4Audio
    static let srtSubtitle = UTType(filenameExtension: "srt") ?? .plainText
    static let webVTTSubtitle = UTType(filenameExtension: "vtt") ?? .plainText
}

struct AudioDocumentPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let initialDirectoryURL: URL?
    let onPick: (Result<[URL], Error>) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.mp3Audio, .m4aAudio, .srtSubtitle, .webVTTSubtitle, .audio, .plainText, .text],
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

