//
//  BlurScroll.swift
//  Today
//
//  Created by Ethan John Lagera on 5/29/26.
//
//  Fixed gradient stops and dynamic viewport framing for native ScrollView integration.

import SwiftUI

struct BlurScroll: ViewModifier {
    
    enum BlurPosition {
        case top
        case bottom
    }
    
    let blur: CGFloat
    let blurHeight: CGFloat // E.g. 0.15 for 15% of the screen
    let blurPosition: BlurPosition
    
    let coordinateSpaceName: String
    let viewportHeight: CGFloat
    
    @State private var scrollPosition: CGPoint = .zero
    
    func body(content: Content) -> some View {
        
        let fadeOffset = 0.1
        let safeBlurHeight = max(0.0, min(1.0, blurHeight))
        
        let topBlurGradient = LinearGradient(stops: [
            .init(color: .white, location: safeBlurHeight - fadeOffset),
            .init(color: .clear, location: safeBlurHeight)
        ], startPoint: .top, endPoint: .bottom)
        
        let bottomBlurGradient = LinearGradient(stops: [
            .init(color: .clear, location: 1.0 - safeBlurHeight),
            .init(color: .white, location: 1.0 - safeBlurHeight + fadeOffset)
        ], startPoint: .top, endPoint: .bottom)
        
        ZStack(alignment: .top) {
            // Main content
            content
            
            // Blurred overlay (copy of main content)
            content
                .blur(radius: blur)
                .mask(
                    VStack(spacing: 0) {
                        if blurPosition == .top {
                            Color.white
                            topBlurGradient.frame(height: viewportHeight)
                            Color.clear.frame(height: max(0, scrollPosition.y))
                        } else {
                            Color.clear.frame(height: max(0, -scrollPosition.y))
                            bottomBlurGradient.frame(height: viewportHeight)
                            Color.white
                        }
                    }
                        .offset(y: scrollPosition.y < 200 ? -scrollPosition.y - 256 : 0)
                        .blur(radius: 8)
                )
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        .background(
            GeometryReader { geo in
                Color.clear
                    .preference(key: BlurScrollOffsetPreferenceKey.self,
                                value: geo.frame(in: .named(coordinateSpaceName)).origin)
            }
        )
        .onPreferenceChange(BlurScrollOffsetPreferenceKey.self) { value in
            self.scrollPosition = value
        }
    }
}

// MARK: - PreferenceKey
private struct BlurScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGPoint = .zero
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) { }
}

// MARK: - Extension
extension View {
    func blurScroll(_ blur: CGFloat,
                    blurHeight: CGFloat = 0.15,
                    blurPosition: BlurScroll.BlurPosition = .top,
                    coordinateSpaceName: String,
                    viewportHeight: CGFloat) -> some View {
        
        modifier(BlurScroll(blur: blur,
                            blurHeight: blurHeight,
                            blurPosition: blurPosition,
                            coordinateSpaceName: coordinateSpaceName,
                            viewportHeight: viewportHeight))
    }
}
