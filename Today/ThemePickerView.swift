//
//  ThemePickerView.swift
//  Today
//
//  Created by Ethan John Lagera on 6/4/26.
//

import SwiftUI

struct ThemePickerView: View {
    @AppStorage("preferredColorScheme") private var preferredColorScheme: PreferredColorScheme = DefaultSettings.preferredColorTheme
    @State var gridColumns: [GridItem] = [GridItem(.adaptive(minimum: 240, maximum: 360), spacing: 8)]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Theme")) {
                    Picker(
                        "Select Theme",
                        selection: Binding(get: {
                            preferredColorScheme
                        }, set: { newValue, _ in
                            withAnimation(.easeInOut(duration: 0.5)) {
                                preferredColorScheme = newValue
                            }
                        })
                    ) {
                        ForEach(PreferredColorScheme.allCases) { scheme in
                            Text(scheme.title).tag(scheme)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section(header: Text("Background")) {
                    
                    LazyVGrid(columns: gridColumns, spacing: 8) {
                        Image("Background1")
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: 320, maxHeight: 320)
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
