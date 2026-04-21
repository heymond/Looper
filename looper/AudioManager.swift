//
//  AudioManager.swift
//  Looper
//
//  Created by Jinyoung Kim on 4/21/26.
//


import AVFoundation
import Foundation

/// 오디오 콘텐츠의 로딩, 준비, 재생 및 관리를 담당하는 매니저 클래스입니다.
class AudioManager: NSObject {
    
    private var audioPlayer: AVAudioPlayer?
    
    /// AudioManager가 초기화됩니다.
    override init() {
        super.init()
    }
    
    /**
     지정된 파일 경로에서 오디오 데이터를 로드하고 재생 준비를 완료합니다.
     - Parameter filePath: 오디오 파일의 파일 시스템 경로.
     - Returns: 성공적으로 로드되었는지 여부를 나타내는 Bool 값.
     */
    func loadAudio(from filePath: String) -> Bool {
        guard let url = URL(string: filePath) else {
            print("에러: 유효하지 않은 파일 경로가 제공되었습니다.")
            return false
        }
        
        do {
            // 1. 이전 플레이어 자원 해제 (메모리 누수 방지)
            self.audioPlayer?.stop()
            self.audioPlayer = nil
            
            // 2. 새로운 오디오 플레이어 초기화 및 설정
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self // 델리게이트 설정: 재생 완료 이벤트를 받기 위함
            player.prepareToPlay() // 오디오 데이터를 미리 준비 (필수)
            self.audioPlayer = player
            print("성공: 오디오가 로드되고 준비되었습니다.")
            return true
        } catch {
            print("에러: \(filePath) 에서 오디오를 로드하거나 준비하는 중 문제가 발생했습니다: \(error.localizedDescription)")
            self.audioPlayer = nil
            return false
        }
    }
    
    /**
     현재 로드된 오디오 콘텐츠를 재생합니다.
     - Parameter loop: 오디오를 무한 루프 할지 여부 (기본값: false).
     */
    func playAudio(loop: Bool = false) {
        guard let player = self.audioPlayer else {
            print("재생 불가: 로드된 오디오가 없습니다.")
            return
        }
        
        if loop {
            player.numberOfLoops = -1 // -1은 무한 루프를 의미
        } else {
            player.numberOfLoops = 0 // 0은 한 번 재생을 의미
        }
        
        player.play()
        print("재생 시작.")
    }
    
    /**
     오디오 재생을 중지합니다.
     */
    func stopAudio() {
        self.audioPlayer?.stop()
        print("재생 중지됨.")
    }
    
    /**
     오디오 플레이어의 모든 자원을 완전히 해제합니다. 오디오 컨텍스트가 끝났을 때 호출해야 합니다.
     */
    func cleanup() {
        stopAudio()
        self.audioPlayer = nil
        print("AudioManager가 정리되었습니다.")
    }
}

// MARK: - AVAudioPlayerDelegate (핵심!)

extension AudioManager: AVAudioPlayerDelegate {
    
    // 오디오 재생이 정상적으로 완료되었을 때 호출되는 필수 델리게이트 메소드입니다.
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("✅ 재생 완료: 성공 여부 \(flag)입니다.")
        
        // 재생이 끝났다면 루프 횟수를 초기화하여 다음 재생 시 오류를 방지합니다.
        self.audioPlayer?.numberOfLoops = 0 
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("⚠️ 오디오 디코딩 에러가 발생했습니다: \(error?.localizedDescription ?? "알 수 없는 오류")")
    }
}

// MARK: - 사용 예시 (Usage Example)

/*
// 1. Manager 인스턴스 생성
let manager = AudioManager()
let audioPath = "/path/to/your/soundfile.mp3" 

// 2. 오디오 로드 시도 (오류 처리 포함)
if manager.loadAudio(from: audioPath) {
    
    // 3. 오디오 재생 시작 (예: 반복하지 않는 짧은 효과음)
    manager.playAudio(loop: false)
    
    // 4. 일정 시간이 지난 후 (예: 10초 후)
    DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
        // 5. 자원 정리
        manager.stopAudio()
        manager.cleanup()
    }
}
*/
