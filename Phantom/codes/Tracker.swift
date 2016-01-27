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

//public protocol Tracker {
//    var progressInfo: ProgressInfo? { get }
//    var result: Result<NSData>? { get }
//    
//    func addTracking(queue: dispatch_queue_t?, progress: (ProgressInfo -> Void)) -> TrackingToken?
//    func addTracking<T>(queue: dispatch_queue_t?, progress: (ProgressInfo -> Void)?, decoder: (NSURL, NSData) -> DecodeResult<T> , completion: Result<T> -> Void) -> TrackingToken?
//    func removeTracking(token: TrackingToken?)
//}

// MARK: - DefaultTaskTracker.
class Tracker {
    
    struct TrackingItem {
        let queue: dispatch_queue_t?
        let progress: (ProgressInfo -> Void)?
        let decoderCompletion: (decoder: (NSURL, NSData) -> DecodeResult<Any>, completion: Result<Any> -> Void)?
    }
    
    var progressInfo: ProgressInfo?
    var result: Result<NSData>?
    
    var lock = OS_SPINLOCK_INIT
    var trackings: [TrackingToken: TrackingItem] = [:]
    
    init(){}
    
    func addTracking(queue: dispatch_queue_t?, progress: (ProgressInfo -> Void)) -> TrackingToken? {
        return addTracking(TrackingItem(queue: queue, progress: progress, decoderCompletion: nil))
    }
    
    func addTracking<T>(queue: dispatch_queue_t?, progress: (ProgressInfo -> Void)?, decoder: (NSURL, NSData) -> DecodeResult<T> , completion: Result<T> -> Void) -> TrackingToken? {
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
        return addTracking(TrackingItem(queue: queue, progress: progress, decoderCompletion: (wrapDecoder, wrapCompletion)))
    }
    
    func removeTracking(token: TrackingToken?) {
        if let token = token {
            OSSpinLockLock(&lock)
            trackings.removeValueForKey(token)
            OSSpinLockUnlock(&lock)
        }
    }
    
    func notifyProgress(progressInfo: ProgressInfo) {
        OSSpinLockLock(&lock)
        self.progressInfo = progressInfo
        let items = trackings.values
        OSSpinLockUnlock(&lock)
        items.forEach{ notifyProgrss($0, progressInfo: progressInfo) }
    }
    
    func notifyCompletion(result: Result<NSData>) {
        OSSpinLockLock(&lock)
        self.result = result
        let items = trackings.values
        OSSpinLockUnlock(&lock)
        items.forEach{ notifyCompletion($0, result: result) }
    }
    
    private func addTracking(item: TrackingItem) -> TrackingToken? {
        OSSpinLockLock(&lock)
        let token = TrackingToken()
        trackings[token] = item
        let progressInfo = self.progressInfo
        let result = self.result
        OSSpinLockUnlock(&lock)
        
        if let progressInfo = progressInfo {
            notifyProgrss(item, progressInfo: progressInfo)
        }
        if let result = result {
            notifyCompletion(item, result: result)
        }

        return token
    }
    
    func notifyProgrss(item: TrackingItem, progressInfo: ProgressInfo) {
        guard let progress = item.progress else { return }
        if let queue = item.queue {
            dispatch_async(queue){progress(progressInfo)}
        } else {
            progress(progressInfo)
        }
    }
    
    func notifyCompletion(item: TrackingItem, result: Result<NSData>) {
        guard let decoderCompletion = item.decoderCompletion else { return }
        
        if let queue = item.queue {
            dispatch_async(queue){
                decoderCompletion.completion(decode(result, decoder: decoderCompletion.decoder))
            }
        } else {
            decoderCompletion.completion(decode(result, decoder: decoderCompletion.decoder))
        }
    }
}
