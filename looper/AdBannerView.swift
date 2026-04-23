//
//  AdBannerView.swift
//  Looper
//

import GoogleMobileAds
import SwiftUI
import UIKit

struct AdBannerView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> BannerAdViewController {
        BannerAdViewController()
    }
    
    func updateUIViewController(_ uiViewController: BannerAdViewController, context: Context) {
        uiViewController.reloadBannerIfNeeded()
    }
    
    final class BannerAdViewController: UIViewController {
        private var bannerView: BannerView?
        private var currentWidth: CGFloat = 0
        
        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            reloadBannerIfNeeded()
        }
        
        func reloadBannerIfNeeded() {
            let screenWidth = view.window?.windowScene?.screen.bounds.width
            let viewWidth = view.bounds.width > 0 ? view.bounds.width : (screenWidth ?? 320)
            guard viewWidth > 0, abs(viewWidth - currentWidth) > 0.5 else { return }
            currentWidth = viewWidth
            
            bannerView?.removeFromSuperview()
            
            let adSize = adSizeFor(cgSize: CGSize(width: viewWidth, height: 50))
            let bannerView = BannerView(adSize: adSize)
            
            bannerView.adUnitID = "ca-app-pub-3940256099942544/2435281174"
            bannerView.rootViewController = self
            view.addSubview(bannerView)
            
            bannerView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                bannerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                bannerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                bannerView.widthAnchor.constraint(equalToConstant: viewWidth)
            ])
            
            bannerView.load(Request())
            self.bannerView = bannerView
        }
    }
}






