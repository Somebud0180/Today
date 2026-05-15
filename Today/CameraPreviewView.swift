//
//  CameraPreviewView.swift
//  Today
//
//  Created by Ethan John Lagera on 5/15/26.
//

import AVFoundation
import SwiftUI

final class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let manager: VideoRecorderManager

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        manager.attachPreviewLayer(view.videoPreviewLayer)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        manager.attachPreviewLayer(uiView.videoPreviewLayer)
    }
}
