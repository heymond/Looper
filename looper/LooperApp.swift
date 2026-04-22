//
//  LooperApp.swift
//  Looper
//
//  Created by Jinyoung Kim on 4/13/26.
//

import SwiftUI
import AppTrackingTransparency
import GoogleMobileAds

@main
struct LooperApp: App {
    
    // 2. 초기화 로직 추가
    init() {
        // 1. 최신 버전은 GADMobileAds 대신 MobileAds를 사용합니다.
        MobileAds.shared.start(completionHandler: nil)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
