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
    @State private var gridColumns: [GridItem] = [GridItem(.adaptive(minimum: 120, maximum: 360), spacing: 8)]

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
                        backgroundCard("Viola")
                        backgroundCard("Sunset")
                        backgroundCard("Skywards")
                    }
                }
            }
        }
    }

    func backgroundCard(_ assetName: String) -> some View {
        let isSelected = assetName == selectedBackground
        let glassColor = isSelected ? Color.accentColor : Color.gray

        return ZStack {
            if preferredColorScheme == .system {
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        splitBackgroundImage(
                            assetName,
                            colorScheme: .light,
                            alignment: .leading,
                            geometry: geometry
                        )
                        
                        splitBackgroundImage(
                            assetName,
                            colorScheme: .dark,
                            alignment: .trailing,
                            geometry: geometry
                        )
                    }
                }
            } else {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 320)
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

    private func splitBackgroundImage(_ assetName: String, colorScheme: ColorScheme, alignment: Alignment, geometry: GeometryProxy) -> some View {
        return Image(assetName)
            .resizable()
            .scaledToFill()
            .colorScheme(colorScheme)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .frame(width: geometry.size.width / 2, alignment: alignment)
            .clipped()
    }
}

#Preview {
    ThemePickerView()
}
