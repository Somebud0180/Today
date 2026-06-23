//
//  ViewLayoutMetrics.swift
//  Today
//
//  Created by Ethan John Lagera on 6/23/26.
//

import SwiftUI

struct ViewLayoutMetrics {
    public var availableWidth: CGFloat = 0
    public var columns: [GridItem] = []
    public var cardSize: CGSize = .zero
    public var spacing: CGFloat = 0
    // These paddings are optional and can be ignored by users that don't need them
    public var titleTopPadding: CGFloat = 0
    public var titleHorizontalPadding: CGFloat = 0

    public init(availableWidth: CGFloat = 0,
                columns: [GridItem] = [],
                cardSize: CGSize = .zero,
                spacing: CGFloat = 0,
                titleTopPadding: CGFloat = 0,
                titleHorizontalPadding: CGFloat = 0) {
        self.availableWidth = availableWidth
        self.columns = columns
        self.cardSize = cardSize
        self.spacing = spacing
        self.titleTopPadding = titleTopPadding
        self.titleHorizontalPadding = titleHorizontalPadding
    }
}
