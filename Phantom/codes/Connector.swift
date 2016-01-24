//
//  Connector.swift
//  Phantom
//
//  Created by kaizei on 16/1/18.
//  Copyright © 2016年 kaizei. All rights reserved.
//

import Foundation


/**
 1. Connector hold only one task. It will cancel last task if new task is about to begin.
 2. all API calls should be in the 'queue' which is default to main queue.
*/
final public class Connector {
    
    final private class ConnectorTracker {
        private var lock = OS_SPINLOCK_INIT
        
        var url: NSURL

        weak var downloader: Downloader?
        weak var cache: Cache?
        
        var progressInfo: ProgressInfo?
        var trackings: [TrackingToken: (progress: DownloadProgressHandler?, completion: (decoder: (NSURL, NSData) -> Any?, completion: Any? -> Void)?)] = [:]
        
        init(url: NSURL) {
            self.url = url
        }
        
        func addTracking(progress progress: DownloadProgressHandler?) -> TrackingToken? {
            guard let progress = progress else { return nil }
            let token = TrackingToken()
            OSSpinLockLock(&lock)
            trackings[token] = (progress, nil)
            OSSpinLockUnlock(&lock)
            return token
        }
        
        func addTracking<T>(progress progress: DownloadProgressHandler?, decoder: (NSURL, NSData) -> T?, completion: T? -> Void) -> TrackingToken? {
            let token = TrackingToken()
            let wrapDecoder = { (url: NSURL, data: NSData) -> Any? in
                return decoder(url, data)
            }
            let wrapCompletion = { (decoded: Any?) in
                completion(decoded as? T)
            }
            OSSpinLockLock(&lock)
            trackings[token] = (progress, (wrapDecoder, wrapCompletion))
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
        
        func removeAllTracking() {
            OSSpinLockLock(&lock)
            trackings.removeAll()
            OSSpinLockUnlock(&lock)
        }
        
        func notifyProgress(progressInfo: ProgressInfo) {
            self.progressInfo = progressInfo
            OSSpinLockLock(&lock)
            trackings.forEach { _, info in
                info.progress?(progressInfo)
            }
            OSSpinLockUnlock(&lock)
        }
        
        func allCompletions() -> [(decoder: (NSURL, NSData) -> Any?, completion: Any? -> Void)] {
            let completions: [(decoder: (NSURL, NSData) -> Any?, completion: Any? -> Void)]
            OSSpinLockLock(&lock)
            completions = trackings.flatMap({$1.completion})
            OSSpinLockUnlock(&lock)
            return completions
        }
        
    }
    
    private weak var lastTask: Task?
    private var lastTracker: ConnectorTracker?
    
    public var progressInfo: ProgressInfo? {
        return lastTracker?.progressInfo
    }
    
    /// default is *false*. two task are treated same only if **URL** is same, **downloader** is same and **cache** is nil or same.
    public var cancelSameURLTask = false
    public var queue = dispatch_get_main_queue()
    public var taskGenerator: TaskGenerator?
    
    public init() {}
    
    deinit {
        cancelCurrentTask()
    }
    
    public func connect<T>(url: NSURL, downloader: Downloader = sharedDownloader, cache: Cache? = nil,
        progress: DownloadProgressHandler? = nil,
        decoder: (NSURL, NSData) -> T?, completion: T? -> Void) {
            
            if let lastTracker = self.lastTracker
                where lastTracker.url == url && lastTracker.downloader === downloader
                    && (cache == nil || lastTracker.cache === cache)
                    && !cancelSameURLTask {
                        lastTracker.notifyProgress(PTInvalidProgressInfo)
                        lastTracker.removeAllTracking()
                        lastTracker.addTracking(progress: progress, decoder: decoder, completion: completion)
                        if let progressInfo = lastTracker.progressInfo {
                            lastTracker.notifyProgress(progressInfo)
                        }
                        return
            }
            
            cancelCurrentTask()
            
            lastTracker = ConnectorTracker(url: url)
            lastTracker?.downloader = downloader
            lastTracker?.cache = cache
            lastTracker?.addTracking(progress: progress, decoder: decoder, completion: completion)
            
            var currentTask: Task!
            self.lastTask = downloader.download(url, taskGenerator: taskGenerator, cache: cache,
                progress: {[queue, weak self] c, tr, te in
                    dispatch_async(queue) {
                        self?.lastTracker?.progressInfo = (c, tr, te)
                        guard let task = currentTask where !task.cancelled else { return }
                        self?.lastTracker?.notifyProgress((c, tr, te))
                    }
                },
                completion: {[queue, weak self] result in
                    guard let completions = self?.lastTracker?.allCompletions() else { return }
                    var decoded: [Any?]
                    if case .Success(let url, let data) = result {
                        decoded = completions.map{$0.decoder(url, data)}
                    } else {
                        decoded = [Any?](count: completions.count, repeatedValue: nil)
                    }
                    dispatch_async(queue) {[weak self] in
                        if self?.lastTask === currentTask {
                            self?.lastTracker = nil
                            self?.lastTask = nil
                        }
                        guard let task = currentTask where !task.cancelled else { return }
                        zip(completions, decoded).forEach{ info, value in
                            info.completion(value)
                        }
                    }
                })
            
            currentTask = self.lastTask
    }
    
    public func cancelCurrentTask() {
        lastTask?.cancel()
        lastTracker?.notifyProgress(PTInvalidProgressInfo)
        lastTracker = nil
        lastTask = nil
    }
    
    func addTracking(progress progress: DownloadProgressHandler?) -> TrackingToken? {
        return lastTracker?.addTracking(progress: progress)
    }
    
    public func addTracking<T>(progress progress: DownloadProgressHandler?, decoder: (NSURL, NSData) -> T?, completion: T? -> Void) -> TrackingToken? {
        return lastTracker?.addTracking(progress: progress, decoder: decoder, completion: completion)
    }
    
    public func removeTracking(token: TrackingToken?) {
        lastTracker?.removeTracking(token)
    }

}


extension NSObject {
    
    private static var kConnectorKey = "kaizei.yimi.phantom.connectorKey"
    
    /// will create one if needed.
    public var pt_connector: Connector! {
        get {
            if let connector = objc_getAssociatedObject(self, &UIImageView.kConnectorKey) as? Connector {
                return connector
            } else {
                let connector = Connector()
                self.pt_connector = connector
                return connector
            }
        }
        set {
            objc_setAssociatedObject(self, &UIImageView.kConnectorKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
