//
//  SettingsView.swift
//  homebutton
//
//  Created by djordje pepic on 05/09/2021.
//  Copyright © 2021 djordje pepic. All rights reserved.
//

import SwiftUI


struct IPPort: View {
    
    @Binding var ip: String
    @Binding var port: String
    let ipHint: String
    let onChange: () -> Void
    
    
    init(ip: Binding<String>, port: Binding<String>, ipHint: String, onChange: @escaping () -> Void) {
        self._ip = ip
        self._port = port
        self.ipHint = ipHint
        self.onChange = onChange
    }
    
    var body: some View {
        HStack {
            TextField(ipHint, text: $ip, onEditingChanged: {t in self.onChange() })
                .font(.headline)
                .foregroundColor(.primary)
            
            TextField("port", text: $port, onEditingChanged: {t in self.onChange() })
                .keyboardType(.numberPad)
                .font(.headline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
    }
}


struct SettingsView: View {
    
    @ObservedObject var state = DoorState.main
    @ObservedObject var client = PiClient.main
    @ObservedObject var door = DoorClient2.main
    @State var runDisabled = false
    @State var pairDisabled = false
    
    var body: some View {
        VStack {
            IPPort(ip: $state.globalHost, port: $state.globalPort, ipHint: "global host", onChange: { self.onIpChange() })
            
            IPPort(ip: $state.localHost, port: $state.localPort, ipHint: "local host", onChange: { self.onIpChange() })
            
            if (state.isAdmin()) {
                TextField("pi username", text: $state.piUsername, onEditingChanged: {t in self.state.saveLater() })
                    .font(.headline)
                    .foregroundColor(.primary)

                SecureField("pi password", text: $state.piPassword, onCommit: { self.state.saveLater() })
                    .font(.headline)
                    .foregroundColor(.primary)
                
                TextField("directory", text: $state.targetDir, onEditingChanged: {t in self.state.saveLater() })
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Text("")
                    .font(.title)
                
                LargeRoundedButton(fg: .white,
                                   bg: (client.running || door.connected) ? Color.red : Color.green,
                                   text: (client.running || door.connected) ? "Stop" : "Run",
                                   disabled: runDisabled)
                {
                    self.runDisabled = true
                    if (self.client.running || self.door.connected) {
                        DispatchQueue.global().asyncAfter(deadline: .now() + 10.0) { self.runDisabled = false }
                        self.client.stop() { self.runDisabled = false }
                    }
                    else {
                        self.client.update { self.client.run() { self.runDisabled = false } }
                    }
                }
                
                Spacer()
                
                LargeRoundedButton(fg: .white, bg: Color.blue, text: "Pair", disabled: pairDisabled) {
                    self.pairDisabled = true
                    DispatchQueue.global().asyncAfter(deadline: .now() + 35.0) { self.pairDisabled = false }
                    self.client.pair() { self.pairDisabled = false }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onTapGesture{UIApplication.shared.endEditing()}
    }
    
    private func onIpChange() {
        door.setup(state: state)
        state.saveLater()
    }
}
