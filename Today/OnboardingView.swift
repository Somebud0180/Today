//
//  OnboardingView.swift
//  Today
//
//  Created by Ethan John Lagera on 6/1/26.
//

import SwiftUI

struct OnboardingView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                VStack {
                    Text("Welcome to")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Today")
                        .font(.largeTitle)
                        .fontWeight(.heavy)
                    
                    Spacer()
                    
                    Button("Continue") {
                        // Move to next page
                    }
                    .buttonStyle(.glassProminent)
                }
                .padding(16)
            }
        }
    }
}

#Preview {
    OnboardingView()
}
