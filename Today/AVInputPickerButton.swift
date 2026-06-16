//
//  AVInputPickerButton.swift
//  Today
//
//  Created by Ethan John Lagera on 6/16/26.
//

import SwiftUI
import AVKit

struct AVInputPickerButton<Content: View>: UIViewRepresentable {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .custom)
        button.backgroundColor = .clear
        
        // Host the SwiftUI content inside a UIKit controller
        let hostingController = UIHostingController(rootView: content)
        hostingController.view.backgroundColor = .clear
        hostingController.view.isUserInteractionEnabled = false // Let touches pass through to the button
        
        // Save a reference to the hosting controller in the coordinator for size calculations
        context.coordinator.hostingController = hostingController
        
        // Add the hosting view as a subview of the button
        let hostedView = hostingController.view!
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(hostedView)
        
        // Pin the hosted view bounds tightly to the UIKit button layout
        NSLayoutConstraint.activate([
            hostedView.topAnchor.constraint(equalTo: button.topAnchor),
            hostedView.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            hostedView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: button.trailingAnchor)
        ])
        
        // Attach the system picker interaction
        let interaction = AVInputPickerInteraction()
        button.addInteraction(interaction)
        context.coordinator.interaction = interaction
        
        button.addTarget(context.coordinator, action: #selector(Coordinator.handleTap), for: .touchUpInside)
        
        return button
    }
    
    func updateUIView(_ uiView: UIButton, context: Context) {
        // Update the root view configuration smoothly using our saved reference
        context.coordinator.hostingController?.rootView = content
    }
    
    // This communicates the intrinsic size of your SwiftUI content back to the parent layout engine
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIButton, context: Context) -> CGSize? {
        guard let hostingController = context.coordinator.hostingController else { return nil }
        
        // Convert SwiftUI's proposed size into standard UIKit dimensions
        let targetWidth = proposal.width ?? UIView.layoutFittingExpandedSize.width
        let targetHeight = proposal.height ?? UIView.layoutFittingCompressedSize.height
        
        // Ask the hosting controller to calculate the ideal size of its internal SwiftUI view tree
        return hostingController.sizeThatFits(in: CGSize(width: targetWidth, height: targetHeight))
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        var interaction: AVInputPickerInteraction?
        var hostingController: UIHostingController<Content>?
        
        @objc func handleTap() {
            interaction?.present()
        }
    }
}
