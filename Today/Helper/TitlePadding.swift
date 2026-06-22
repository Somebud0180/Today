//
//  TitlePadding.swift
//  Today
//
//  Created by Ethan John Lagera on 6/22/26.
//

import SwiftUI

struct TitlePadding {
    static func top(_ proxy: GeometryProxy, isPad: Bool) -> CGFloat {
        if isPad {
            return proxy.safeAreaInsets.top
        } else {
            if proxy.size.width > proxy.size.height {
                return proxy.safeAreaInsets.top + 16
            } else {
                return proxy.safeAreaInsets.top
            }
        }
    }
    
    static func horizontal(_ proxy: GeometryProxy, isPad: Bool) -> CGFloat {
        if isPad {
            return proxy.containerCornerInsets.topLeading.width + 16
        } else {
            if proxy.size.width > proxy.size.height {
                return proxy.safeAreaInsets.leading / 2 + 16
            } else {
                return 24
            }
        }
    }
}
