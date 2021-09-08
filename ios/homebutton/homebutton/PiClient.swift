//
//  PiClient.swift
//  homebutton
//
//  Created by djordje pepic on 05/09/2021.
//  Copyright © 2021 djordje pepic. All rights reserved.
//

import Foundation
import IOSSH



class PiClient: ObservableObject {
    
    var targetDir: String = "/Users/djordjepepic/Projects/homebutton"
    
    @Published private(set) var running = false
    @Published private(set) var pairing = false
    @Published private(set) var didCopyFiles = false
    
    static var main: PiClient = PiClient()
    
    func setRunning() {
        DispatchQueue.main.sync { running = true }
    }
    
    func run(completionHandler: @escaping () -> Void = {}) {
        DispatchQueue.global().async {
//            let doorCmd = "sh door.sh"
            let doorCmd = "venv/bin/python door.py --dev --host 192.168.0.172 & ls"
            if (self.executeCmd(cmd: "cd \(self.targetDir); \(doorCmd)", wait: false)) {
                DispatchQueue.main.sync { self.running = true; completionHandler() }
            }
            else {
                DispatchQueue.main.sync { completionHandler() }
            }
        }
    }
    
    func stop(completionHandler: @escaping () -> Void = {}) {
        DispatchQueue.global().async {
            if (self.executeCmd(cmd: "cd \(self.targetDir); echo '' > kill; while [ -f kill ]; do :; done")) {
                DispatchQueue.main.sync { self.running = false; completionHandler() }
            }
            else {
                DispatchQueue.main.sync { completionHandler() }
            }
        }
    }
    
    func pair(completionHandler: @escaping () -> Void = {}) {
        DispatchQueue.global().async {
            if (self.executeCmd(cmd: "cd \(self.targetDir); echo '' > pair; while [ -f kill ]; do :; done")) {
                DispatchQueue.main.sync { self.pairing = true }
                DispatchQueue.global().asyncAfter(deadline: .now() + 30.0) {
                    DispatchQueue.main.sync { self.pairing = false; completionHandler() }
                }
            }
            else {
                DispatchQueue.main.sync { completionHandler() }
            }
        }
    }
    
    func update(completionHandler: @escaping () -> Void = {}) {
        if !didCopyFiles {
            DispatchQueue.global().async {
                if self.copyFiles() {
                    DispatchQueue.main.sync { self.didCopyFiles = true; completionHandler() }
                }
                else if self.downloadFiles() {
                    if self.copyFiles() {
                        DispatchQueue.main.sync { self.didCopyFiles = true; completionHandler() }
                    }
                } else {
                    DispatchQueue.main.sync { completionHandler() }
                }
            }
        }
        else {
            completionHandler()
        }
    }
    
    private func executeCmd(cmd: String, wait: Bool = true) -> Bool {
        let s = DoorState.main
        guard let r = try? TSSH.ssh(cmd: cmd, host: s.localHost, user: s.piUsername, password: s.piPassword, wait: wait) else {
            return false
        }
        return r
    }
    
    // Download/Update scripts
    
    private static let files = Array<String>(arrayLiteral: "door.py", "door.sh")
    
    static private func remoteURL(file: String) -> URL {
        return URL(string: "https://raw.githubusercontent.com/sentrip/homebutton/master/\(file)")!
    }
    
    private static func documentURL(file: String) -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(file, isDirectory: false)
    }
    
    private func downloadFiles() -> Bool {
        let g = DispatchGroup()
        var results = Array<Bool>(repeating: false, count: PiClient.files.count)
        for (i, file) in PiClient.files.enumerated() {
            g.enter()
            PiClient.downloadURL(url: PiClient.remoteURL(file: file)) {url in
                guard let s = try? String(contentsOf: url) else { g.leave(); return }
                let doc = PiClient.documentURL(file: file)
                
                if (!FileManager.default.fileExists(atPath: doc.absoluteString)) {
                    FileManager.default.createFile(atPath: doc.absoluteString, contents: nil, attributes: nil)
                }
                do {
                    try s.write(to: doc, atomically: true, encoding: .utf8)
                    results[i] = true
                }
                catch {
                    print("Error", error.localizedDescription)
                    results[i] = false
                }
                g.leave()
            }
        }
        g.wait()
        return results.allSatisfy { v in v }
    }
    
    private func copyFiles() -> Bool {
        let g = DispatchGroup()
        var results = Array<Bool>(repeating: false, count: PiClient.files.count)
        for (i, file) in PiClient.files.enumerated() {
            g.enter()
            DispatchQueue.global().async {
                let url = PiClient.documentURL(file: file)
                let remote = self.targetDir + "/" + file
                let s = DoorState.main
                guard let r = try? TSSH.scp(file: url, remote: remote, host: s.localHost, user: s.piUsername, password: s.piPassword) else {
                    results[i] = false
                    g.leave()
                    return
                }
                results[i] = r
                g.leave()
            }
        }
        g.wait()
        return results.allSatisfy { v in v }
    }

    private static func downloadURL(url: URL, completionHandler: @escaping (URL) -> Void) {
        let session = URLSession(configuration: .default, delegate: nil, delegateQueue: nil)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let task = session.downloadTask(with: request) {data, response, error in
            if (error == nil) {
                if let url = data,
                   let r = response as? HTTPURLResponse,
                   r.statusCode == 200
                {
                    completionHandler(url)
                }
            }
            else {
                // Failure
                print("Failure: ", error?.localizedDescription as Any);
            }
        }
        task.resume()
    }

}
