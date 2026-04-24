import Darwin
import Foundation
import os

/// Fire-and-forget UDP sink for bar-frame data. Used by external consumers
/// (e.g. a keyboard RGB bridge) to receive the same spectrum bars the UI renders.
/// Packet format: raw little-endian Float32 array, bars in [0, 1]-ish range.
/// Sends on every `tick()` if the sink is configured (destination on loopback by default).
final class UDPBarSink {
    private let log = Logger(subsystem: "com.zman.cavalier", category: "UDPBarSink")
    private let fd: Int32
    private let addr: sockaddr_in

    init?(host: String = "127.0.0.1", port: UInt16 = 7777) {
        let s = socket(AF_INET, SOCK_DGRAM, 0)
        guard s >= 0 else { return nil }
        var a = sockaddr_in()
        a.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        a.sin_family = sa_family_t(AF_INET)
        a.sin_port = port.bigEndian
        guard inet_pton(AF_INET, host, &a.sin_addr) == 1 else {
            close(s)
            return nil
        }
        self.fd = s
        self.addr = a
    }

    deinit { close(fd) }

    func send(bars: [Float]) {
        var a = addr
        bars.withUnsafeBufferPointer { buf in
            guard let base = buf.baseAddress else { return }
            let byteCount = MemoryLayout<Float>.size * buf.count
            withUnsafePointer(to: &a) { aPtr in
                aPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
                    _ = sendto(fd, base, byteCount, 0, saPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
    }
}
