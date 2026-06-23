//
//  ThemePickerView.swift
//  Today
//
//  Created by Ethan John Lagera on 6/4/26.
//

import SwiftUI

struct ThemePickerView: View {
    @AppStorage("preferredColorScheme") private var preferredColorScheme: PreferredColorScheme = DefaultSettings.preferredColorTheme
    @AppStorage("selectedBackground") private var selectedBackground: String = DefaultSettings.selectedBackground
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
                            withAnimation(.snappy) {
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
                        backgroundCard("Waving Hills")
                        backgroundCard("Atmosphere")
                    }
                }
            }
        }
    }
    
    func backgroundCard(_ assetName: String) -> some View {
        let isSelected = assetName == selectedBackground
        let glassColor = isSelected ? Color.accentColor : Color.gray
        
        return Image(assetName)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: 320, maxHeight: 320)
            .mask(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(4)
            .glassEffect(
                .regular.interactive().tint(glassColor.opacity(0.5)),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .onTapGesture {
                if selectedBackground != assetName {
                    withAnimation() {
                        selectedBackground = assetName
                    }
                }
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Double-tap to set as background")
            .accessibilityValue(isSelected ? "Active" : "")
    }
}

#Preview {
    ThemePickerView()
}
