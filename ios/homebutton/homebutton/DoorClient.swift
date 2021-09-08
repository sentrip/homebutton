//
//  DoorClient.swift
//  homebutton
//
//  Created by djordje pepic on 05/09/2021.
//  Copyright © 2021 djordje pepic. All rights reserved.
//

import Foundation


class DoorState: Codable, ObservableObject {
    
    static var main = DoorState.load()
    
    @Published var username: String = ""
    @Published var pin: String = ""
    @Published var globalHost: String = ""
    @Published var globalPort: String = "4000"
    @Published var localHost: String = "192.168.0.172"
    @Published var localPort: String = "6000"
    @Published var piUsername: String = ""
    @Published var piPassword: String = ""
    @Published var targetDir: String = ""
    @Published var pairHistory = Set<String>()
    
    required init() {}
    
    func isPaired() -> Bool { pairHistory.contains(username) }
    func isAdmin() -> Bool { username.lowercased() == "admin" }
    
    // Save/load
    
    func saveLater() {
        let old = DoorState.saveCountdown
        DoorState.saveCountdown = 10
        if old == 0 {
            doSaveLater()
        }
    }
    
    private static let UserDefaultsKey = "homebuttonState"
    
    func save() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: DoorState.UserDefaultsKey)
        }
    }
    
    static func load() -> DoorState {
        if let data = UserDefaults.standard.data(forKey: UserDefaultsKey) {
            if let decoded = try? JSONDecoder().decode(DoorState.self, from: data) {
                return decoded
            }
        }
        return DoorState()
    }


    private static var saveCountdown = 0
    private func doSaveLater() {
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
            DispatchQueue.main.sync {
                DoorState.saveCountdown -= 1
                if DoorState.saveCountdown == 0 {
                    self.save()
                }
                else {
                    self.doSaveLater()
                }
            }
        }
    }
    
    // Codable

    enum Keys: CodingKey {
        case username, pin, globalHost, globalPort, localHost, localPort, piUsername, piPassword, targetDir, pairHistory
    }
    
    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        username = try c.decode(type(of: username), forKey: Keys.username)
        pin = try c.decode(type(of: pin), forKey: Keys.pin)
        globalHost = try c.decode(type(of: globalHost), forKey: Keys.globalHost)
        globalPort = try c.decode(type(of: globalPort), forKey: Keys.globalPort)
        localHost = try c.decode(type(of: localHost), forKey: Keys.localHost)
        localPort = try c.decode(type(of: localPort), forKey: Keys.localPort)
        piUsername = try c.decode(type(of: piUsername), forKey: Keys.piUsername)
        piPassword = try c.decode(type(of: piPassword), forKey: Keys.piPassword)
        targetDir = try c.decode(type(of: targetDir), forKey: Keys.targetDir)
        pairHistory = try c.decode(type(of: pairHistory), forKey: Keys.pairHistory)
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(username, forKey: Keys.username)
        try c.encode(pin, forKey: Keys.pin)
        try c.encode(globalHost, forKey: Keys.globalHost)
        try c.encode(globalPort, forKey: Keys.globalPort)
        try c.encode(localHost, forKey: Keys.localHost)
        try c.encode(localPort, forKey: Keys.localPort)
        try c.encode(piUsername, forKey: Keys.piUsername)
        try c.encode(piPassword, forKey: Keys.piPassword)
        try c.encode(targetDir, forKey: Keys.targetDir)
        try c.encode(pairHistory, forKey: Keys.pairHistory)
    }
}


struct DoorMessage {
    enum State {
        case close,
             open,
             pair
    }
    
    let username: String
    let password: String
    let state: State
    
    func toData() -> Data? {
        let st = state == .close ? "0" : (state == .open ? "1" : "2")
        return Data("\(username),\(password),\(st)".utf8).base64EncodedData()
    }
    
    static func fromData(data: Data) -> DoorMessage? {
        guard let s = String(data: data, encoding: .utf8) else {
            return nil
        }
        guard let decoded = Data(base64Encoded: s) else {
            return nil
        }
        guard let ds = String(data: decoded, encoding: .utf8) else {
            return nil
        }
        let parts = ds.split(separator: ",")
        guard parts.count == 3 && (parts[2] == "0" || parts[2] == "1" || parts[2] == "2") else {
            return nil
        }
        let state: State = parts[2] == "2" ? .pair : (parts[2] == "1" ? .open : .close)
        return DoorMessage(username: String(parts[0]), password: String(parts[1]), state: state)
    }
}



protocol DoorSocketDelegate {
    func doorSocketDidConnect()
    func doorSocketDidDisconnect()
    func doorSocketDidReceive(data: Data)
}

class DoorSocket2: NSObject, URLSessionWebSocketDelegate {
    
    var delegate: DoorSocketDelegate?
    
    override init() {
        url = URL(string: "ws://localhost:6000")!
        super.init()
    }
    
    func isConnected() -> Bool {
        return connected
    }
    
    func setUrl(url: URL) {
        if (url == self.url) { return }
        if (task != nil) { disconnect() }
        self.url = url
        connect()
        let wasRunning = running
        running = true
        if (!wasRunning) { receiveReconnect() }
    }
    
    func disconnect() {
        task?.cancel(with: .goingAway, reason: "Closing connection".data(using: .utf8))
        task = nil
        running = false
    }
    
    func send(message: DoorMessage) {
        if let data = message.toData() {
            task?.send(.data(data)) { error in
                if (error != nil) { self.connected = false }
            }
        }
    }
    
    // URLSessionWebSocketDelegate
    
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        connected = false
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        connected = false
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        connected = true
        delegate?.doorSocketDidConnect()
        timeUntilNextUpdate = minTimeUntilNextUpdate
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?)
    {
        connected = false
    }
    
    private func connect() {
        task = session.webSocketTask(with: url)
        task!.resume()
    }
    
    private func receive() {
        task?.receive { result in
            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    self.delegate?.doorSocketDidReceive(data: data)
                default:
                    return
            }
            case .failure:
                return
            }
        }
    }
   
    private func receiveReconnect() {
        if (!running) { return }
        
        if (!connected) {
            timeUntilNextUpdate = min(timeUntilNextUpdate * 2, maxTimeUntilNextUpdate)
            connect()
        }
        else {
            receive()
        }
        
        DispatchQueue.global().asyncAfter(deadline: .now() + timeUntilNextUpdate) {
            self.receiveReconnect()
        }
    }
    
    // Properties
    
    private var url: URL
    private var task: URLSessionWebSocketTask?
    private var timeUntilNextUpdate = 0.5
    private let minTimeUntilNextUpdate = 0.5
    private let maxTimeUntilNextUpdate = 4.0
    private var running = false
    private var connected = false {
        didSet(prev) {
            if (prev && !connected) {
                delegate?.doorSocketDidDisconnect()
            }
        }
    }
    private lazy var session: URLSession = {
        URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
    }()
}

class DoorClient2: ObservableObject, DoorSocketDelegate {
    
    // Public
    
    static var main = DoorClient2()
    
    @Published private(set) var connected = false
    @Published private(set) var open = false
    @Published private(set) var paired = false
    @Published private(set) var validLocalUrl = false
    @Published private(set) var validGlobalUrl = false
    
    init() {
        local.delegate = self
        global.delegate = self
    }
    
    func send(message: DoorMessage) {
        if (local.isConnected()) {
            local.send(message: message)
        } else if (global.isConnected()) {
            global.send(message: message)
        }
    }
    
    func setup(state: DoorState) {
        paired = paired || state.isPaired()
        
        if let urlString = DoorClient2.getURLString(host: state.localHost, port: state.localPort),
            let url = URL(string: urlString)
        {
            local.setUrl(url: url)
            validLocalUrl = true
            let s = DoorState.main
            if !paired && !s.isPaired() && !s.username.isEmpty && !s.pin.isEmpty {
                local.send(message: DoorMessage(username: s.username, password: s.pin, state: .pair))
            }
        }
        else {
            validLocalUrl = false
        }
        
        if let urlString = DoorClient2.getURLString(host: state.globalHost, port: state.globalPort),
            let url = URL(string: urlString)
        {
            global.setUrl(url: url)
            validGlobalUrl = true
            let s = DoorState.main
            if !paired && !s.isPaired() && !s.username.isEmpty && !s.pin.isEmpty {
                global.send(message: DoorMessage(username: s.username, password: s.pin, state: .pair))
            }
        }
        else {
            validGlobalUrl = false
        }
    }
    
    // DoorSocketDelegate
    
    func doorSocketDidConnect() {
        DispatchQueue.main.sync { connected = true }
    }
    
    func doorSocketDidDisconnect() {
        DispatchQueue.main.sync { connected = local.isConnected() || global.isConnected() }
    }
    
    func doorSocketDidReceive(data: Data) {
        if let s = String(data: data, encoding: .utf8), !s.isEmpty {
            let success = s == "1"
            if (!paired && !s.isEmpty) {
                DispatchQueue.main.sync {
                    paired = true;
                    let _ = DoorState.main.pairHistory.insert(DoorState.main.username)
                    DoorState.main.saveLater()
                }
            }
            else if (!s.isEmpty) {
                DispatchQueue.main.sync { open = success }
            }
      }
    }
    
    // Private
    private var local = DoorSocket2()
    private var global = DoorSocket2()
    
    static func getURLString(host: String, port: String) -> String? {
        if (host.isEmpty || port.isEmpty || UInt(port) == nil) {
            return nil
        }
        let cleaned = host.replacingOccurrences(of: " ", with: "")
        return "ws://\(cleaned):\(port)"
    }
}

