//
//  DoorView.swift
//  homebutton
//
//  Created by djordje pepic on 05/09/2021.
//  Copyright © 2021 djordje pepic. All rights reserved.
//

import SwiftUI


struct LargeRoundedButton: View {
    let fg: Color
    let bg: Color
    let text: String
    let disabled: Bool
    let action: () -> ()
    
    var body: some View {
        Button(action: action, label: {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text(self.text)
                    Spacer()
                }
                Spacer()
            }
        })
        .font(.title)
        .clipShape(Capsule())
        .foregroundColor(fg)
        .background(bg)
        .cornerRadius(15)
        .onTapGesture{UIApplication.shared.endEditing()}
            .disabled(self.disabled)
    }
}


struct DoorView: View {
    
    let openSettings: () -> ()
    @ObservedObject var state = DoorState.main
    @ObservedObject var client = DoorClient2.main
    
    init(openSettings: @escaping () -> () = {}) {
        self.openSettings = openSettings
        client.setup(state: self.state)
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            VStack(alignment: .leading) {
                TextField("username", text: $state.username, onEditingChanged: {t in self.state.saveLater() })
                    .font(.title)
                    .foregroundColor(.primary)
                
                SecureField("pin", text: $state.pin, onCommit: { self.state.saveLater() })
                    .font(.title)
                    .foregroundColor(.primary)
                    .keyboardType(.numberPad)

                Text("")
                    .font(.title)
            }
            .onTapGesture{UIApplication.shared.endEditing()}
            
            
            LargeRoundedButton(fg: .white,
                               bg: !client.paired ? Color.blue : (client.open ? Color.red : Color.green),
                               text: !client.paired ? "Pair" : (client.open ? "Close" : "Open"),
                               disabled: false)
            {
                let s: DoorMessage.State = !self.client.paired ? .pair : (self.client.open ? .close : .open)
                self.client.send(message: DoorMessage(username: self.state.username, password: self.state.pin, state: s))
            }
        }
        .onTapGesture{UIApplication.shared.endEditing()}
    }
}
