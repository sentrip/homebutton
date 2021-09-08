//
//  TSSH.swift
//  IOSSH
//
//  Created by djordje pepic on 06/09/2021.
//  Copyright © 2021 djordje pepic. All rights reserved.
//

import Foundation
import Socket


public struct TSSH {
    public static func ssh(cmd: String, host: String, user: String, password: String, wait: Bool = true) throws -> Bool {
        let sess = try CSession(host: host)
        try sess.authenticate(user: user, password: password)
        let ch = try sess.openExec()
        try ch.exec(cmd: cmd)
        if wait { try ch.waitEOF() }
        let status = ch.exitStatus()
        try ch.close()
        if wait { try ch.waitClosed() }
        return status == 0
    }
    
    public static func cssh(cmd: String, host: String, user: String, password: String, wait: Bool = true) throws -> (Bool, String) {
        let sess = try CSession(host: host)
        try sess.authenticate(user: user, password: password)
        let ch = try sess.openExec()
        try ch.exec(cmd: cmd)
        if wait { try ch.waitEOF() }
        let status = ch.exitStatus()
        
        if (status != 0) {
            try ch.close()
            return (false, "")
        }
        
        let r = ch.readData()
        try ch.close()
        if wait { try ch.waitClosed() }
        
        switch r {
        case .done:
            return (true, "")
        case .eagain:
            return (true, "")
        case .data(let d):
            return (true, String(data: d, encoding: .utf8)!)
        case .error(let e):
            throw e
        }
    }

    public static func scp(file: URL, remote: String, host: String, user: String, password: String) throws -> Bool {
        let sess = try CSession(host: host)
        try sess.authenticate(user: user, password: password)
        let status = try sess.sendFile(localURL: file, remotePath: remote)
        return status == 0
    }
}


public struct CSSHError: Swift.Error, CustomStringConvertible {
    
    public enum Kind: Int32 {
        case genericError = 1
        case bannerRecv
        case bannerSend
        case invalidMac
        case kexFailure // 5
        case alloc
        case socketSend
        case keyExchangeFailure
        case errorTimeout
        case hostkeyInit // 10
        case hostkeySign
        case decrypt
        case socketDisconnect
        case proto
        case passwordExpired // 15
        case file
        case methodNone
        case authenticationFailed
        case publicKeyUnverified
        case channelOutOfOrder // 20
        case channelFailure
        case channelRequestDenied
        case channelUnknown
        case channelWindowExceeded
        case channelPacketExceeded // 25
        case channelClosed
        case channelEofSent
        case scpProtocol
        case zlib
        case socketTimeout // 30
        case sftpProtocol
        case requestDenied
        case methodNotSupported
        case inval
        case invalidPollType // 35
        case publicKeyProtocol
        case eagain
        case bufferTooSmall
        case badUse
        case compress // 40
        case outOfBoundary
        case agentProtocol
        case socketRecv
        case encrypt
        case badSocket // 45
        case knownHosts
        case channelWindowFull
        case keyfileAuthFailed
    }
    
    static func check(code: Int32, session: OpaquePointer) throws {
        if code != 0 {
            throw CSSHError.codeError(code: code, session: session)
        }
    }
    
    static func codeError(code: Int32, session: OpaquePointer) -> CSSHError {
        return CSSHError(kind: Kind(rawValue: -code) ?? .genericError, session: session)
    }
    
    static func genericError(_ message: String) -> CSSHError {
        return CSSHError(kind: .genericError, message: message)
    }
    
    static func mostRecentError(session: OpaquePointer, backupMessage: String = "") -> CSSHError {
        let kind = Kind(rawValue: libssh2_session_last_errno(session)) ?? .genericError
        return CSSHError(kind: kind, session: session, backupMessage: backupMessage)
    }
    
    public let kind: Kind
    public let message: String
    
    public var description: String {
        let kindMessage = "code \(kind.rawValue) = " + String(describing: kind)
        if message.isEmpty {
            return "Error: \(kindMessage)"
        }
        return "Error: \(message) (\(kindMessage))"
    }
    
    private init(kind: Kind, message: String) {
        self.kind = kind
        self.message = message
    }
    
    private init(kind: Kind, session: OpaquePointer, backupMessage: String = "") {
        var messagePointer: UnsafeMutablePointer<Int8>? = nil
        var length: Int32 = 0

        libssh2_session_last_error(session, &messagePointer, &length, 0)
        let message = messagePointer.flatMap({ String(cString: $0) }) ?? backupMessage
        
        self.init(kind: kind, message: message)
    }


    static func check(code: Int32, session: OpaquePointer, msg: String) throws {
        guard code == 0 else {
            throw CSSHError.genericError(msg)
        }
    }

}

public struct CPermissions: OptionSet {
    public let rawValue: UInt
    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }
    
    public static let read = CPermissions(rawValue: 1 << 1)
    public static let write = CPermissions(rawValue: 1 << 2)
    public static let execute = CPermissions(rawValue: 1 << 3)
}

public struct CFilePermissions: RawRepresentable {
    public var owner: CPermissions
    public var group: CPermissions
    public var others: CPermissions

    public init(owner: CPermissions, group: CPermissions, others: CPermissions) {
        self.owner = owner
        self.group = group
        self.others = others
    }

    public init(rawValue: Int32) {
        var owner: CPermissions = []
        var group: CPermissions = []
        var others: CPermissions = []

        if (rawValue & LIBSSH2_SFTP_S_IRUSR == LIBSSH2_SFTP_S_IRUSR) { owner.insert(.read) }
        if (rawValue & LIBSSH2_SFTP_S_IWUSR == LIBSSH2_SFTP_S_IWUSR) { owner.insert(.write) }
        if (rawValue & LIBSSH2_SFTP_S_IXUSR == LIBSSH2_SFTP_S_IXUSR) { owner.insert(.execute) }
        if (rawValue & LIBSSH2_SFTP_S_IRGRP == LIBSSH2_SFTP_S_IRGRP) { group.insert(.read) }
        if (rawValue & LIBSSH2_SFTP_S_IWGRP == LIBSSH2_SFTP_S_IWGRP) { group.insert(.write) }
        if (rawValue & LIBSSH2_SFTP_S_IXGRP == LIBSSH2_SFTP_S_IXGRP) { group.insert(.execute) }
        if (rawValue & LIBSSH2_SFTP_S_IROTH == LIBSSH2_SFTP_S_IROTH) { others.insert(.read) }
        if (rawValue & LIBSSH2_SFTP_S_IWOTH == LIBSSH2_SFTP_S_IWOTH) { others.insert(.write) }
        if (rawValue & LIBSSH2_SFTP_S_IXOTH == LIBSSH2_SFTP_S_IXOTH) { others.insert(.execute) }

        self.init(owner: owner, group: group, others: others)
    }

    public var rawValue: Int32 {
        var flag: Int32 = 0

        if owner.contains(.read) { flag |= LIBSSH2_SFTP_S_IRUSR }
        if owner.contains(.write) { flag |= LIBSSH2_SFTP_S_IWUSR }
        if owner.contains(.execute) { flag |= LIBSSH2_SFTP_S_IXUSR }
        
        if group.contains(.read) { flag |= LIBSSH2_SFTP_S_IRGRP }
        if group.contains(.write) { flag |= LIBSSH2_SFTP_S_IWGRP }
        if group.contains(.execute) { flag |= LIBSSH2_SFTP_S_IXGRP }
        
        if others.contains(.read) { flag |= LIBSSH2_SFTP_S_IROTH }
        if others.contains(.write) { flag |= LIBSSH2_SFTP_S_IWOTH }
        if others.contains(.execute) { flag |= LIBSSH2_SFTP_S_IXOTH }
        
        return flag
    }

    public static let `default` = CFilePermissions(owner: [.read, .write], group: [.read], others: [.read])

}



public enum CReadWriteProcessor {
    
    public enum ReadResult {
        case data(Data)
        case eagain
        case done
        case error(CSSHError)
    }
    
    static func processRead(result: Int, buffer: inout [Int8], session: OpaquePointer) -> ReadResult {
        if result > 0 {
            let data = Data(bytes: &buffer, count: result)
            return .data(data)
        } else if result == 0 {
            return .done
        } else if result == LIBSSH2_ERROR_EAGAIN {
            return .eagain
        } else {
            return .error(CSSHError.codeError(code: Int32(result), session: session))
        }
    }
    
    public enum WriteResult {
        case written(Int)
        case eagain
        case error(CSSHError)
    }
    
    static func processWrite(result: Int, session: OpaquePointer) -> WriteResult {
        if result >= 0 {
            return .written(result)
        } else if result == LIBSSH2_ERROR_EAGAIN {
            return .eagain
        } else {
            return .error(CSSHError.codeError(code: Int32(result), session: session))
        }
    }
    
}


public class CChannel {
    private static let session = "session"
    private static let exec = "exec"
    
    static let windowDefault: UInt32 = 2 * 1024 * 1024
    static let packetDefaultSize: UInt32 = 32768
    static let readBufferSize = 0x4000
    
    public init(cSession: OpaquePointer) throws {
        guard let cChannel = libssh2_channel_open_ex(cSession,
                                                     CChannel.session, UInt32(CChannel.session.count),
                                                     CChannel.windowDefault,
                                                     CChannel.packetDefaultSize, nil, 0) else
        {
            throw CSSHError.genericError("libssh2_channel_open_ex failed")
        }
        self.cChannel = cChannel
        self.cSession = cSession
    }
    
    public init(cSession: OpaquePointer, fileSize: Int64, remotePath: String, permissions: CFilePermissions = .default) throws {
        guard let cChannel = libssh2_scp_send64(cSession, remotePath, permissions.rawValue, fileSize, 0, 0) else {
            throw CSSHError.genericError("libssh2_scp_send64 failed")
        }
        self.cChannel = cChannel
        self.cSession = cSession
    }
    
    public func exec(cmd: String) throws {
        let code = libssh2_channel_process_startup(cChannel, CChannel.exec, UInt32(CChannel.exec.count), cmd, UInt32(cmd.count))
        try CSSHError.check(code: code, session: cSession, msg: "libssh2_channel_process_startup failed")
    }

    public func readData() -> CReadWriteProcessor.ReadResult {
        let result = libssh2_channel_read_ex(cChannel, 0, &readBuffer, CChannel.readBufferSize)
        return CReadWriteProcessor.processRead(result: result, buffer: &readBuffer, session: cSession)
    }
    
    public func write(data: Data, length: Int, to stream: Int32 = 0) -> CReadWriteProcessor.WriteResult {
        let result: Result<Int, CSSHError> = data.withUnsafeBytes {
            guard let unsafePointer = $0.bindMemory(to: Int8.self).baseAddress else {
                return .failure(CSSHError.genericError("Channel write failed to bind memory"))
            }
            return .success(libssh2_channel_write_ex(cChannel, stream, unsafePointer, length))
        }
        switch result {
        case .failure(let error):
            return .error(error)
        case .success(let value):
            return CReadWriteProcessor.processWrite(result: value, session: cSession)
        }
    }
    
    public func sendEOF() throws {
        let code = libssh2_channel_send_eof(cChannel)
        try CSSHError.check(code: code, session: cSession)
    }
    
    public func waitEOF() throws {
        let code = libssh2_channel_wait_eof(cChannel)
        try CSSHError.check(code: code, session: cSession)
    }
    
    public func close() throws {
        let code = libssh2_channel_close(cChannel)
        try CSSHError.check(code: code, session: cSession)
    }
    
    public func waitClosed() throws {
        let code = libssh2_channel_wait_closed(cChannel)
        try CSSHError.check(code: code, session: cSession)
    }
    
    public func exitStatus() -> Int32 {
        return libssh2_channel_get_exit_status(cChannel)
    }
    
    deinit {
        libssh2_channel_free(cChannel)
    }
    
    private let cSession: OpaquePointer
    private let cChannel: OpaquePointer
    private var readBuffer = [Int8](repeating: 0, count: CChannel.readBufferSize)
    
}


public class CSession {
    
    public init(host: String) throws {
        guard CSession.initResult == 0 else {
            throw CSSHError.genericError("libssh2_init failed")
        }
        
        guard let sock = try? Socket.create() else {
            throw CSSHError.genericError("Socket.create failed")
        }
        self.sock = sock
        
        guard let _ = try? sock.connect(to: host, port: 22) else {
            throw CSSHError.genericError("Socket.connect failed")
        }
        
        guard let cSession = libssh2_session_init_ex(nil, nil, nil, nil) else {
            throw CSSHError.genericError("libssh2_session_init failed")
        }
        self.cSession = cSession
        
        try CSSHError.check(code: libssh2_session_handshake(cSession, sock.socketfd),
                         session: cSession, msg: "libssh2_session_handshake failed")
        
    }
    
    deinit {
        libssh2_session_free(cSession)
        sock.close()
    }
    
    public func authenticate(user: String, password: String) throws {
        try CSSHError.check(code: libssh2_userauth_password_ex(cSession, user, UInt32(user.count), password, UInt32(password.count), nil),
                         session: cSession, msg: "libssh2_userauth_password_ex failed")
    }
    
    public func openExec() throws -> CChannel {
        return try CChannel(cSession: cSession)
    }

    public func sendFile(localURL: URL, remotePath: String, permissions: CFilePermissions = .default) throws -> Int32 {
        guard let resources = try? localURL.resourceValues(forKeys: [.fileSizeKey]),
            let fileSize = resources.fileSize,
            let inputStream = InputStream(url: localURL) else {
                throw CSSHError.genericError("couldn't open file at \(localURL)")
        }
        
        let channel = try CChannel(cSession: cSession, fileSize: Int64(fileSize), remotePath: remotePath, permissions: permissions)
        
        inputStream.open()
        defer { inputStream.close() }
        
        let bufferSize = Int(CChannel.packetDefaultSize)
        var buffer = Data(capacity: bufferSize)
        
        while inputStream.hasBytesAvailable {
            let bytesRead: Int  = try buffer.withUnsafeMutableBytes {
                guard let pointer = $0.bindMemory(to: UInt8.self).baseAddress else {
                   throw CSSHError.genericError("SSH write failed to bind buffer memory")
                }
                return inputStream.read(pointer, maxLength: bufferSize)
            }
            
            if bytesRead == 0 { break }
            
            var bytesSent = 0
            while bytesSent < bytesRead {
                let chunk = bytesSent == 0 ? buffer : buffer.advanced(by: bytesSent)
                switch channel.write(data: chunk, length: bytesRead - bytesSent) {
                case .written(let count):
                    bytesSent += count
                case .eagain:
                    break
                case .error(let error):
                    throw error
                }
            }
        }
        
        try channel.sendEOF()
        try channel.waitEOF()
        let status = channel.exitStatus()
        try channel.close()
        try channel.waitClosed()
        
        return status
    }

    
    private let cSession: OpaquePointer
    private let sock: Socket

    
    class Deinit {
        deinit {
            libssh2_exit()
        }
    }
    private static let initResult = libssh2_init(0)
    private static let deinitResult = Deinit()
}

