//
//  VideoPlayer.swift
//  Today
//
//  Created by Ethan John Lagera on 5/7/26.
//

import SwiftUI
import AVKit

struct VideoView: View {
    @State var videoName: String = "example"
    @State private var reloadID = UUID()
    
    var body: some View {
        VideoPlayer(player: AVPlayer(url:  Bundle.main.url(forResource: videoName, withExtension: "mov")!))
            .ignoresSafeArea()
            .frame(width: .infinity, height: .infinity)
    }
}

#Preview {
    VideoView()
}
