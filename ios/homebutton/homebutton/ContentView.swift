//
//  ContentView.swift
//  homebutton
//
//  Created by djordje pepic on 04/09/2021.
//  Copyright © 2021 djordje pepic. All rights reserved.
//

import SwiftUI


extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct StatusIcon: View {
    @ObservedObject var client = DoorClient2.main
    
    var body: some View {
        Image(systemName: "circle.fill")
            .foregroundColor(Color(client.connected ? .green : .red))
    }
}


struct ContentView: View {
    
    @State var isSettingsOpen: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(alignment: .leading) {
                    Text("")
                        .navigationBarTitle("homebutton")
                        .navigationBarItems(leading: StatusIcon(), trailing: Button(action: {
                                withAnimation {
                                    self.isSettingsOpen.toggle()
                                    UIApplication.shared.endEditing()
                                }
                            }) {
                                Image(systemName: "gear").imageScale(.large)
                            }
                        )
                        .onTapGesture{UIApplication.shared.endEditing()}
                    
                    DoorView {
                        self.isSettingsOpen.toggle()
                    }
                }
                    .padding(.horizontal, 20)
                    .onTapGesture{UIApplication.shared.endEditing()}
            
                ModalBase(content: {
                    SettingsView()
                }, showModal: $isSettingsOpen)
            }
            .onTapGesture{UIApplication.shared.endEditing()}
        }
        .onTapGesture{UIApplication.shared.endEditing()}
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}


/*
struct GrowingButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title)
            .frame(minWidth: 0, maxWidth: .infinity)
//            .frame(minHeight: 0, maxHeight: .infinity)
            .padding()
//            .background(Color.blue)
            .foregroundColor(.white)
            .contentShape(Rectangle())
            .scaledToFit()
//            .clipShape(Capsule())
//            .scaleEffect(configuration.isPressed ? 1.075 : 1.0)
//            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
//            .cornerRadius(40)
    }
}
*/
