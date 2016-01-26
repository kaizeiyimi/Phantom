//
//  Tracker.swift
//  Phantom
//
//  Created by kaizei on 16/1/26.
//  Copyright © 2016年 kaizei. All rights reserved.
//

import Foundation


// MARK: - Task Tracking
final public class TrackingToken: Hashable {
    public var hashValue: Int {
        return "\(unsafeAddressOf(self))".hashValue
    }
}

public func ==(lhs: TrackingToken, rhs: TrackingToken) -> Bool {
    return lhs === rhs
}

// MARK: - DefaultTaskTracker. Not public
class DefaultTracker {
    
    struct TrackingItem {
        let queue: dispatch_queue_t?
        let progress: (ProgressInfo -> Void)?
        let decoderCompletion: (decoder: (NSURL, NSData) -> DecodeResult<Any>, completion: Result<Any> -> Void)?
    }
    
    var progressInfo: ProgressInfo?
    
    var lock = OS_SPINLOCK_INIT
    var trackings: [TrackingToken: TrackingItem] = [:]
    
    // TODO: invalid progress?
    func addTracking(queue: dispatch_queue_t?, progress: (ProgressInfo -> Void)) -> TrackingToken? {
        let token = TrackingToken()
        OSSpinLockLock(&lock)
        trackings[token] = TrackingItem(queue: queue, progress: progress, decoderCompletion: nil)
        OSSpinLockUnlock(&lock)
        return token
    }
    
    func addTracking<T>(queue: dispatch_queue_t?, progress: (ProgressInfo -> Void)?, decoder: (NSURL, NSData) -> DecodeResult<T> , completion: Result<T> -> Void) -> TrackingToken? {
        let token = TrackingToken()
        let wrapDecoder = { (url: NSURL, data: NSData) -> DecodeResult<Any> in
            switch decoder(url, data) {
            case .Success(let result): return .Success(data: result as Any)
            case .Failed(let error): return .Failed(error: error)
            }
        }
        let wrapCompletion = { (decoded: Result<Any>) in
            switch decoded {
            case .Success(let url, let result): completion(.Success(url: url, data: result as! T))
            case .Failed(let url, let error): completion(.Failed(url: url, error: error))
            }
        }
        OSSpinLockLock(&lock)
        trackings[token] = TrackingItem(queue: queue, progress: progress, decoderCompletion: (wrapDecoder, wrapCompletion))
        OSSpinLockUnlock(&lock)
        return token
    }
    
    func removeTracking(token: TrackingToken?) {
        if let token = token {
            OSSpinLockLock(&lock)
            trackings.removeValueForKey(token)
            OSSpinLockUnlock(&lock)
        }
    }
    
    func notifyProgress(progressInfo: ProgressInfo) {
        self.progressInfo = progressInfo
        OSSpinLockLock(&lock)
        let progresses = trackings.map { ($1.queue, $1.progress) }
        OSSpinLockUnlock(&lock)
        progresses.forEach { queue, progress in
            guard let progress = progress else { return }
            if let queue = queue {
                dispatch_async(queue){progress(progressInfo)}
            } else {
                progress(progressInfo)
            }
        }
    }
    
    // TODO: 性能
    func notifyCompletion(result: Result<NSData>) {
        OSSpinLockLock(&lock)
        let decodeCompletions = trackings.flatMap{($1.queue, $1.decoderCompletion)}
        OSSpinLockUnlock(&lock)
        
        decodeCompletions.forEach { queue, handler in
            guard let handler = handler else { return }
            let decoded: Result<Any>
            switch result {
            case .Success(let url, let data):
                switch handler.decoder(url, data) {
                case .Success(let d):
                    decoded = .Success(url: url, data: d as Any)
                case .Failed(let error):
                    decoded = .Failed(url: url, error: error)
                }
            case .Failed(let url, let error):
                decoded = .Failed(url: url, error: error)
            }
            
            if let queue = queue {
                dispatch_async(queue){handler.completion(decoded)}
            } else {
                handler.completion(decoded)
            }
        }
    }
}
