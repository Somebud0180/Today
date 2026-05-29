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
    let topSafeInset: CGFloat
    
    @State private var scrollPosition: CGPoint = .zero
    
    func body(content: Content) -> some View {
        
        let fadeOffset = 0.05 // 5% smooth transition zone
        let safeBlurHeight = max(0.0, min(1.0, blurHeight))
        
        // --- Explicit Top Gradients ---
        let topSharpGradient = LinearGradient(stops: [
            .init(color: .clear, location: safeBlurHeight - fadeOffset),
            .init(color: .white, location: safeBlurHeight)
        ], startPoint: .top, endPoint: .bottom)
        
        let topBlurGradient = LinearGradient(stops: [
            .init(color: .white, location: safeBlurHeight - fadeOffset),
            .init(color: .clear, location: safeBlurHeight)
        ], startPoint: .top, endPoint: .bottom)
        
        // --- Explicit Bottom Gradients ---
        let bottomSharpGradient = LinearGradient(stops: [
            .init(color: .white, location: 1.0 - safeBlurHeight),
            .init(color: .clear, location: 1.0 - safeBlurHeight + fadeOffset)
        ], startPoint: .top, endPoint: .bottom)
        
        let bottomBlurGradient = LinearGradient(stops: [
            .init(color: .clear, location: 1.0 - safeBlurHeight),
            .init(color: .white, location: 1.0 - safeBlurHeight + fadeOffset)
        ], startPoint: .top, endPoint: .bottom)
        
        ZStack(alignment: .top) {
            // Layer 1: Sharp Content View
            content
                .mask(
                    VStack(spacing: 0) {
                        if blurPosition == .top {
                            Color.clear.frame(height: max(0, -scrollPosition.y))
                            topSharpGradient.frame(height: viewportHeight)
                            Color.white // Keep the rest of the list visible
                        } else {
                            Color.white.frame(height: max(0, -scrollPosition.y))
                            bottomSharpGradient.frame(height: viewportHeight)
                            Color.clear
                        }
                    }
                    // Pulls the mask up if the user elastically overscrolls at the edges
                        .offset(y: scrollPosition.y > 0 ? -scrollPosition.y : 0)
                )
            
            // Layer 2: Photographic Focus-Blur View
            content
                .blur(radius: blur)
                .mask(
                    VStack(spacing: 0) {
                        if blurPosition == .top {
                            Color.white.frame(height: max(0, -scrollPosition.y))
                            topBlurGradient.frame(height: viewportHeight)
                            Color.clear
                        } else {
                            Color.clear.frame(height: max(0, -scrollPosition.y))
                            bottomBlurGradient.frame(height: viewportHeight)
                            Color.white
                        }
                    }
                        .offset(y: scrollPosition.y > 0 ? -scrollPosition.y : 0)
                )
                .allowsHitTesting(false) // Prevents the blurred layer from intercepting your taps
            
            VStack {
                Text("Today")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text(Date().formatted(date: .long, time: .omitted))
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .padding(.leading, 24)
            .padding(.top, topSafeInset / 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .ignoresSafeArea(edges: .top)
        }
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
                    viewportHeight: CGFloat,
                    topSafeInset: CGFloat) -> some View {
        
        modifier(
            BlurScroll(
                blur: blur,
                blurHeight: blurHeight,
                blurPosition: blurPosition,
                coordinateSpaceName: coordinateSpaceName,
                viewportHeight: viewportHeight,
                topSafeInset: topSafeInset
            )
        )
    }
}
