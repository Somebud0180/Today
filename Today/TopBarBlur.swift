import SwiftUI

struct TopBarBlur: View {
    let height: CGFloat
    var fadeHeight: CGFloat = 24
    var material: Material = .ultraThinMaterial

    var body: some View {
        Rectangle()
            .fill(material)
            .frame(height: max(0, height) + max(0, fadeHeight))
            .mask(maskView)
            .ignoresSafeArea(.all)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var maskView: some View {
        ZStack(alignment: .top) {
            Color.white
                .frame(height: max(0, height / 2))
            
            VStack(spacing: 0) {
                Color.white
                    .frame(height: max(0, height))
                
                LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: max(0, fadeHeight))
            }
            .blur(radius: 6)
        }
    }
}
