//
//  UnixSocketClient.swift
//  Murmurix
//

import Foundation

// MARK: - Protocol

protocol SocketClientProtocol: Sendable {
    func send(request: [String: Any], timeout: Int) throws -> [String: Any]
}

// MARK: - Unix Socket Client

final class UnixSocketClient: SocketClientProtocol, @unchecked Sendable {
    private let socketPath: String

    init(socketPath: String) {
        self.socketPath = socketPath
    }

    func send(request: [String: Any], timeout: Int = NetworkConfig.daemonSocketTimeout) throws -> [String: Any] {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw SocketError.connectionFailed("Failed to create socket")
        }
        defer { close(fd) }

        // Set timeout
        var timeoutVal = timeval(tv_sec: timeout, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeoutVal, socklen_t(MemoryLayout<timeval>.size))

        // Connect
        try connect(fd: fd)

        // Send request
        let jsonData = try JSONSerialization.data(withJSONObject: request)
        let jsonString = String(data: jsonData, encoding: .utf8)! + "\n"

        jsonString.withCString { ptr in
            _ = Darwin.send(fd, ptr, strlen(ptr), 0)
        }

        // Receive response
        var buffer = [CChar](repeating: 0, count: 65536)
        let bytesRead = recv(fd, &buffer, buffer.count - 1, 0)

        guard bytesRead > 0 else {
            if errno == EAGAIN || errno == EWOULDBLOCK {
                throw SocketError.timeout
            }
            throw SocketError.noResponse
        }

        let responseString = String(cString: buffer)
        return try parseResponse(responseString)
    }

    // MARK: - Private

    private func connect(fd: Int32) throws {
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        let maxPathLen = MemoryLayout.size(ofValue: addr.sun_path) - 1

        socketPath.withCString { ptr in
            withUnsafeMutablePointer(to: &addr.sun_path) { pathPtr in
                let pathBuf = UnsafeMutableRawPointer(pathPtr).assumingMemoryBound(to: CChar.self)
                strncpy(pathBuf, ptr, maxPathLen)
                pathBuf[maxPathLen] = 0
            }
        }

        let connectResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                Darwin.connect(fd, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard connectResult == 0 else {
            throw SocketError.connectionFailed("Failed to connect to socket")
        }
    }

    private func parseResponse(_ response: String) throws -> [String: Any] {
        guard let data = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SocketError.invalidResponse
        }
        return json
    }
}

// MARK: - Socket Errors

enum SocketError: LocalizedError {
    case connectionFailed(String)
    case timeout
    case noResponse
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let reason):
            return "Socket connection failed: \(reason)"
        case .timeout:
            return "Socket request timed out"
        case .noResponse:
            return "No response from socket"
        case .invalidResponse:
            return "Invalid response from socket"
        }
    }
}
