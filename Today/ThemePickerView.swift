//
//  ThemePickerView.swift
//  Today
//
//  Created by Ethan John Lagera on 6/4/26.
//

import SwiftUI

struct ThemePickerView: View {
    @State var selectedTheme: Int = 0
    @State var gridColumns: [GridItem] = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Theme")) {
                    Picker("Select Theme", selection: $selectedTheme) {
                        Text("System").tag(0)
                        Text("Light").tag(1)
                        Text("Dark").tag(2)
                    }
                    .pickerStyle(.segmented)
                }
                
                Section(header: Text("Background")) {
                    
                    LazyVGrid(columns: gridColumns, spacing: 8) {
                        Image("Background1")
                            .resizable()
                            .scaledToFill()
                            .mask(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .padding(4)
                            .glassEffect(
                                .regular.interactive().tint(.blue.opacity(0.5)),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                    }
                }
            }
        }
    }
}

#Preview {
    ThemePickerView()
}
