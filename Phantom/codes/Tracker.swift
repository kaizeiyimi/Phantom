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

// MARK: - TaskTracker.
final public class TaskTracker {
    
    struct TrackingItem {
        let queue: dispatch_queue_t?
        let progress: (ProgressInfo -> Void)?
        let decoderCompletion: (decoder: (NSURL, NSData) -> DecodeResult<Any>, completion: Result<Any> -> Void)?
    }
    
    public private(set) var task: Task!
    public private(set) var progressInfo: ProgressInfo?
    public private(set) var result: Result<NSData>?
    
    private var lock = OS_SPINLOCK_INIT
    private var trackings: [TrackingToken: TrackingItem] = [:]
    private let trackerQueue: dispatch_queue_t
    
    init(trackerQueue: dispatch_queue_t? = nil) {
        self.trackerQueue = trackerQueue ?? dispatch_queue_create("Phantom.TaskTracker.queue", DISPATCH_QUEUE_CONCURRENT)
    }
    
    public static func track(url: NSURL, trackerQueue: dispatch_queue_t? = nil, downloader: Downloader = sharedDownloader, cache: DownloaderCache? = nil) -> TaskTracker {
        let tracker = TaskTracker()
        tracker.task = downloader.download(url, cache: cache, queue: tracker.trackerQueue,
            progress: tracker.notifyProgress, decoder: tracker.decoder, completion: tracker.notifyCompletion)
        return tracker
    }
    
    // MARK: tracking
    /// `queue` default to trackerQueue.
    public func addTracking(queue: dispatch_queue_t? = nil, progress: (ProgressInfo -> Void)) -> TrackingToken {
        return addTracking(TrackingItem(queue: queue, progress: progress, decoderCompletion: nil))
    }
    
    public func addTracking<T>(queue: dispatch_queue_t? = nil, progress: (ProgressInfo -> Void)?, decoder: (NSURL, NSData) -> DecodeResult<T> , completion: Result<T> -> Void) -> TrackingToken {
        return addTracking(TrackingItem(queue: queue, progress: progress, decoderCompletion: (wrapDecoder(decoder), wrapCompletion(completion))))
    }
    
    public func removeTracking(token: TrackingToken?) {
        if let token = token {
            OSSpinLockLock(&lock)
            trackings.removeValueForKey(token)
            OSSpinLockUnlock(&lock)
        }
    }
    
    // MARK: progress, decoder and completion wrappers.
    func notifyProgress(progressInfo: ProgressInfo) {
        OSSpinLockLock(&lock)
        self.progressInfo = progressInfo
        let items = trackings.values
        OSSpinLockUnlock(&lock)
        items.forEach{ notifyProgrss($0, progressInfo: progressInfo) }
    }
    
    private func decoder(url: NSURL, data: NSData) -> DecodeResult<NSData> {
        return .Success(data: data)
    }
    
    func notifyCompletion(result: Result<NSData>) {
        OSSpinLockLock(&lock)
        self.result = result
        let items = trackings.values
        OSSpinLockUnlock(&lock)
        items.forEach{ notifyCompletion($0, result: result) }
    }
    
    // MARK: private methods
    private func addTracking(item: TrackingItem) -> TrackingToken {
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
    
    private func notifyProgrss(item: TrackingItem, progressInfo: ProgressInfo) {
        guard let progress = item.progress else { return }
        dispatch_async(item.queue ?? trackerQueue){ progress(progressInfo) }
    }
    
    private func notifyCompletion(item: TrackingItem, result: Result<NSData>) {
        guard let decoderCompletion = item.decoderCompletion else { return }
        switch result {
        case .Success(_, _):
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {[trackerQueue] in
                let decoded = decode(result, decoder: decoderCompletion.decoder)
                dispatch_async(item.queue ?? trackerQueue) {
                    decoderCompletion.completion(decoded)
                }
            }
        case .Failed(_, _):
            dispatch_async(item.queue ?? trackerQueue) {
                decoderCompletion.completion(decode(result, decoder: decoderCompletion.decoder))
            }
        }
    }
}



// MARK: - ResultTracker. only track progress and result

struct ResultTrackingItem<T> {
    let queue: dispatch_queue_t?
    let progress: (ProgressInfo -> Void)?
    let completion: (Result<T> -> Void)?
}

final public class ResultTracker<T> {
    
    public private(set) var task: Task!
    public private(set) var progressInfo: ProgressInfo?
    public private(set) var result: Result<T>?
    
    private var lock = OS_SPINLOCK_INIT
    private var trackings: [TrackingToken: ResultTrackingItem<T>] = [:]
    private let trackerQueue: dispatch_queue_t
    
    init(trackerQueue: dispatch_queue_t? = nil) {
        self.trackerQueue = trackerQueue ?? dispatch_queue_create("Phantom.ResultTracker.queue", DISPATCH_QUEUE_CONCURRENT)
    }
    
    public static func track(url: NSURL, trackerQueue: dispatch_queue_t? = nil, downloader: Downloader = sharedDownloader, cache: DownloaderCache? = nil, decoder: (NSURL, NSData) -> DecodeResult<T>) -> ResultTracker<T> {
        let tracker = ResultTracker<T>(trackerQueue: trackerQueue)
        tracker.task = downloader.download(url, cache: cache, queue: tracker.trackerQueue,
            progress: tracker.notifyProgress, decoder: decoder, completion: tracker.notifyCompletion)
        return tracker
    }
    
    // MARK: tracking
    /// `queue` default to trackerQueue.
    public func addTracking(queue: dispatch_queue_t? = nil, progress: (ProgressInfo -> Void)) -> TrackingToken {
        return addTracking(ResultTrackingItem<T>(queue: queue, progress: progress, completion: nil))
    }
    
    public func addTracking(queue: dispatch_queue_t? = nil, progress: (ProgressInfo -> Void)?, completion: Result<T> -> Void) -> TrackingToken {
        return addTracking(ResultTrackingItem(queue: queue, progress: progress, completion: completion))
    }
    
    public func removeTracking(token: TrackingToken?) {
        if let token = token {
            OSSpinLockLock(&lock)
            trackings.removeValueForKey(token)
            OSSpinLockUnlock(&lock)
        }
    }
    
    // MARK: progress, decoder and completion wrappers.
    func notifyProgress(progressInfo: ProgressInfo) {
        OSSpinLockLock(&lock)
        self.progressInfo = progressInfo
        let items = trackings.values
        OSSpinLockUnlock(&lock)
        items.forEach{ notifyProgrss($0, progressInfo: progressInfo) }
    }
    
    func notifyCompletion(result: Result<T>) {
        OSSpinLockLock(&lock)
        self.result = result
        let items = trackings.values
        OSSpinLockUnlock(&lock)
        items.forEach{ notifyCompletion($0, result: result) }
    }
    
    // MARK: private methods
    private func addTracking(item: ResultTrackingItem<T>) -> TrackingToken {
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
    
    private func notifyProgrss(item: ResultTrackingItem<T>, progressInfo: ProgressInfo) {
        guard let progress = item.progress else { return }
        dispatch_async(item.queue ?? trackerQueue){ progress(progressInfo) }
    }
    
    private func notifyCompletion(item: ResultTrackingItem<T>, result: Result<T>) {
        guard let completion = item.completion else { return }
        dispatch_async(item.queue ?? trackerQueue) { completion(result) }
    }
}
