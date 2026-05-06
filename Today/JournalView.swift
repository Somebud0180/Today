//
//  JournalView.swift
//  Today
//
//  Created by Ethan John Lagera on 5/7/26.
//

import SwiftUI

struct JournalView: View {
    var body: some View {
        NavigationView {
            ZStack {
                Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
                
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.75)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                        .ignoresSafeArea()
                        .frame(maxWidth: .infinity, maxHeight: 256, alignment: .bottom)
                }
                
                VStack {
                    Spacer()
                    Text("Enter a note...")
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
            .preferredColorScheme(.dark)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                Rectangle()
                    .fill(Color.gray)
                    .ignoresSafeArea()
            }
            .navigationTitle("05/07/26")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        // Action for the button
                    }) {
                        Image(systemName: "chevron.left")
                    }
                }
            }
        }
    }
}

#Preview {
    JournalView()
}
