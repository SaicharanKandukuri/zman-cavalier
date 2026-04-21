import Foundation
import os.lock

/// Single-producer / single-consumer float ring buffer. Lock-free-ish (os_unfair_lock for small critical sections).
final class FloatRingBuffer {
    private var storage: [Float]
    private let capacity: Int
    private var writeIdx = 0
    private var available = 0
    private var lock = os_unfair_lock()

    init(capacity: Int) {
        self.capacity = capacity
        self.storage = [Float](repeating: 0, count: capacity)
    }

    func write(_ ptr: UnsafePointer<Float>, count: Int) {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        for i in 0..<count {
            storage[writeIdx] = ptr[i]
            writeIdx = (writeIdx + 1) % capacity
        }
        available = min(capacity, available + count)
    }

    /// Read the most recent `count` samples into `out`, ending at the write head.
    /// Returns true if enough samples were available.
    @discardableResult
    func readLatest(_ out: inout [Float], count: Int) -> Bool {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        guard available >= count else { return false }
        var idx = (writeIdx - count + capacity) % capacity
        for i in 0..<count {
            out[i] = storage[idx]
            idx = (idx + 1) % capacity
        }
        return true
    }
}
