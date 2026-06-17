//
//  AVInputPickerButton.swift
//  Today
//
//  Created by Ethan John Lagera on 6/16/26.
//

import SwiftUI
import AVKit

struct AVInputPickerButton<Content: View>: UIViewRepresentable {
    @Binding var isPresented: Bool
    let content: Content
    
    init(isPresented: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self._isPresented = isPresented
        self.content = content()
    }
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView(frame: .zero)
        containerView.backgroundColor = .clear
        
        let hostingController = UIHostingController(rootView: content)
        hostingController.view.backgroundColor = .clear
        hostingController.view.isUserInteractionEnabled = false
        
        context.coordinator.hostingController = hostingController
        
        let hostedView = hostingController.view!
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(hostedView)
        
        NSLayoutConstraint.activate([
            hostedView.topAnchor.constraint(equalTo: containerView.topAnchor),
            hostedView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            hostedView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
        ])
        
        let interaction = AVInputPickerInteraction()
        containerView.addInteraction(interaction)
        context.coordinator.interaction = interaction
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.hostingController?.rootView = content
        
        guard let interaction = context.coordinator.interaction else { return }
        
        // Match the interaction state to the SwiftUI binding state
        if isPresented && !interaction.isPresented {
            interaction.present()
        } else if !isPresented && interaction.isPresented {
            interaction.dismiss()
        }
    }
    
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIView, context: Context) -> CGSize? {
        guard let hostingController = context.coordinator.hostingController else { return nil }
        let targetWidth = proposal.width ?? UIView.layoutFittingExpandedSize.width
        let targetHeight = proposal.height ?? UIView.layoutFittingCompressedSize.height
        return hostingController.sizeThatFits(in: CGSize(width: targetWidth, height: targetHeight))
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented)
    }
    
    class Coordinator: NSObject {
        var interaction: AVInputPickerInteraction?
        var hostingController: UIHostingController<Content>?
        var isPresented: Binding<Bool>
        
        init(isPresented: Binding<Bool>) {
            self.isPresented = isPresented
            super.init()
            
            // Watch for changes on the interaction state if needed, or polling if required.
            // Ideally, the system dismisses it via physical tap outs, so we monitor it.
            Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
                guard let self = self, let interaction = self.interaction else { return }
                if self.isPresented.wrappedValue != interaction.isPresented {
                    DispatchQueue.main.async {
                        self.isPresented.wrappedValue = interaction.isPresented
                    }
                }
            }
        }
    }
}
