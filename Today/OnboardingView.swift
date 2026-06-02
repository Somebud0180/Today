//
//  OnboardingView.swift
//  Today
//
//  Created by Ethan John Lagera on 6/1/26.
//

import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) var dismiss
    @State var currentStep: Int = 0
    @State var animateGlyph: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [.black.opacity(0.25), .black.opacity(0.0), .black.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack {
                    switch currentStep {
                    case 0:
                        Text("Welcome to")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Today")
                            .font(.largeTitle)
                            .fontWeight(.heavy)
                        
                        Spacer()
                        
                        Button("Continue") {
                            currentStep += 1
                        }
                        .buttonStyle(RoundGlassButton())
                        .font(.title2)
                        .fontWeight(.semibold)
                        
                    case 1:
                        Text("Journal your everyday life")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Pick between audio and video entries")
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Image(systemName: animateGlyph ? "video.badge.waveform" : "waveform.mid")
                            .resizable()
                            .scaledToFit()
                            .contentTransition(.symbolEffect(.replace))
                            .symbolEffect(.variableColor.iterative.dimInactiveLayers.nonReversing, options: .repeat(.continuous))
                            .padding(32)
                            .task {
                                try? await Task.sleep(nanoseconds: 3_000_000_000)
                                withAnimation(.bouncy){
                                    animateGlyph.toggle()
                                }
                            }
                        
                        
                        Spacer()
                        
                        Button("Continue") {
                            currentStep += 1
                        }
                        .buttonStyle(RoundGlassButton())
                        .font(.title2)
                        .fontWeight(.semibold)
                        
                    default:
                        Text("Let's get started!")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Button("Continue") {
                            dismiss()
                        }
                        .buttonStyle(RoundGlassButton())
                        .font(.title2)
                        .fontWeight(.semibold)
                    }
                }
                .padding(16)
                .animation(.easeInOut(duration: 0.5), value: currentStep)
            }
            .background(
                Image("OnboardingBackground")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            )
        }
    }
}

struct RoundGlassButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 44)
            .glassEffect(
                .regular.interactive().tint(.green.opacity(0.5)),
                in: Capsule()
            )
    }
}

#Preview {
    OnboardingView()
}
