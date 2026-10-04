//
//  HomePagedInteraction.swift
//  Today
//
//  Created by Ethan John Lagera on 10/4/26.
//

import Foundation
import SwiftUI

struct HomePagedInteraction: UIViewRepresentable {
    var isEnabled: Bool

    func makeUIView(context: Context) -> UIView { UIView() }

    func updateUIView(_ view: UIView, context: Context) {
        DispatchQueue.main.async {
            var ancestor = view.superview
            while let current = ancestor {
                if let pager = current as? UIScrollView {
                    pager.bounces = false
                    pager.isScrollEnabled = isEnabled
                    return
                }
                ancestor = current.superview
            }
        }
    }
}
