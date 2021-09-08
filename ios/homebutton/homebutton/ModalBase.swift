//
//  ModalBase.swift
//  homebutton
//
//  Created by djordje pepic on 04/09/2021.
//  Copyright © 2021 djordje pepic. All rights reserved.
//

import SwiftUI


struct ModalBase<Content: View>: View {
    
    @Environment(\.colorScheme) var colorScheme
    
    @Binding var showModal: Bool
    let content: Content
    
    init(@ViewBuilder content: () -> Content, showModal: Binding<Bool>) {
        self.content = content()
        self._showModal = showModal
    }
    
    var body: some View {
        ZStack {
            HStack {
                VStack {
                    if showModal {
                        self.content
                    }
                }
            }
        }
        .background(colorScheme == .dark ? Color.black : Color.white)
        .offset(x: 0, y: showModal ? 0 : UIApplication.shared.windows.filter { $0.isKeyWindow }.first?.safeAreaInsets.top ?? 0 )
    }
}
