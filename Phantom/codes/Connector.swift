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
    
    final private class ConnectorTracker: DefaultTracker {
        var url: NSURL

        weak var downloader: Downloader?
        weak var cache: DownloaderCache?
        
        init(url: NSURL) {
            self.url = url
        }
        
        func removeAllTracking() {
            OSSpinLockLock(&lock)
            trackings.removeAll()
            OSSpinLockUnlock(&lock)
        }
        
        func allDecodeCompletions() -> [(decoder: (NSURL, NSData) -> DecodeResult<Any>, completion: Result<Any> -> Void)] {
            OSSpinLockLock(&lock)
            let decodeCompletions = trackings.flatMap({$1.decoderCompletion})
            OSSpinLockUnlock(&lock)
            return decodeCompletions
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
    
    public func connect<T>(url: NSURL, downloader: Downloader = sharedDownloader, cache: DownloaderCache? = nil,
        progress: (ProgressInfo -> Void)? = nil,
        decoder: (NSURL, NSData) -> DecodeResult<T>, completion: Result<T> -> Void) {
            
            if let lastTracker = self.lastTracker
                where lastTracker.url == url && lastTracker.downloader === downloader
                    && (cache == nil || lastTracker.cache === cache)
                    && !cancelSameURLTask {
                        let preProgress = lastTracker.progressInfo
                        lastTracker.notifyProgress(PTInvalidProgressInfo)
                        lastTracker.removeAllTracking()
                        lastTracker.progressInfo = preProgress
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
            self.lastTask = downloader.download(url, cache: cache,
                progress: {[queue, weak self] c, tr, te in
                    dispatch_async(queue) {
                        self?.lastTracker?.progressInfo = (c, tr, te)
                        guard let task = currentTask where !task.cancelled else { return }
                        self?.lastTracker?.notifyProgress((c, tr, te))
                    }
                },
                decoder: { _, data in
                    return .Success(data: data)
                },
                completion: {[queue, weak self] result in
                    guard let decodeCompletions = self?.lastTracker?.allDecodeCompletions() else { return }
                    
                    let decoded: [Result<Any>]
                    switch result {
                    case .Success(let url, let data):
                        decoded = decodeCompletions.map {
                            switch $0.decoder(url, data) {
                            case .Success(let d):
                                return .Success(url: url, data: d as Any)
                            case .Failed(let error):
                                return .Failed(url: url, error: error)
                            }
                        }
                    case .Failed(let url, let error):
                        decoded = [Result<Any>](count: decodeCompletions.count, repeatedValue: .Failed(url: url, error: error))
                    }

                    dispatch_async(queue) {[weak self] in
                        if self?.lastTask === currentTask {
                            self?.lastTracker = nil
                            self?.lastTask = nil
                        }
                        guard let task = currentTask where !task.cancelled else { return }
                        zip(decodeCompletions, decoded).forEach{ info, value in
                            info.completion(value)
                        }
                    }
                })
            
            currentTask = self.lastTask
    }
    
    public func cancelCurrentTask() {
        lastTask?.cancel()
        if let tracker = lastTracker {
            tracker.notifyProgress(PTInvalidProgressInfo)
            tracker.notifyCompletion(Result<NSData>.Failed(url: tracker.url, error: canncelledError(tracker.url)))
            lastTracker = nil
        }
        lastTask = nil
    }
    
    func addTracking(progress progress: (ProgressInfo -> Void)) -> TrackingToken? {
        return lastTracker?.addTracking(progress: progress)
    }
    
    public func addTracking<T>(progress progress: (ProgressInfo -> Void)?, decoder: (NSURL, NSData) -> DecodeResult<T>, completion: Result<T> -> Void) -> TrackingToken? {
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
