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
    
    private struct Tracker {
        private var url: NSURL
        private var progress: DownloadProgressHandler?
        private var progressInfo: ProgressInfo?
        private var completion: (Any? -> Void)
        private weak var downloader: Downloader?
        private weak var cache: Cache?
        
        func notifyInvalid() {
            let metric = PTInvalidDownloadProgressMetric
            progress?((metric, metric, metric))
            completion(nil)
        }
    }
    
    private weak var lastTask: Task?
    private var lastTracker: Tracker?
    
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
                        lastTracker.notifyInvalid()
                        self.lastTracker!.progress = progress
                        self.lastTracker!.completion = {completion($0 as? T)}
                        if let progressInfo = lastTracker.progressInfo {
                            progress?(progressInfo)
                        }
                        return
            }
            
            cancelCurrentTask()
            
            self.lastTracker = Tracker(url: url, progress: progress, progressInfo: nil,
                completion: {completion($0 as? T)}, downloader: downloader, cache: cache)
            
            var currentTask: Task!
            self.lastTask = downloader.download(url, taskGenerator: taskGenerator, cache: cache,
                progress: {[queue, weak self] c, tr, te in
                    self?.lastTracker?.progressInfo = (c, tr, te)
                    guard let progress = self?.lastTracker?.progress else { return }
                    dispatch_async(queue) {
                        guard let task = currentTask where !task.cancelled else { return }
                        progress((c, tr, te))
                    }
                },
                completion: {[queue, weak self] result in
                    guard let completion = self?.lastTracker?.completion else { return }
                    var decoded: T?
                    if case .Success(let url, let data) = result {
                        decoded = decoder(url, data)
                    }
                    dispatch_async(queue) {[weak self] in
                        if self?.lastTask === currentTask {
                            self?.lastTracker = nil
                        }
                        guard let task = currentTask where !task.cancelled else { return }
                        completion(decoded)
                    }
                })
            
            currentTask = self.lastTask
    }
    
    public func cancelCurrentTask() {
        lastTask?.cancel()
        lastTracker?.notifyInvalid()
        lastTracker = nil
        lastTask = nil
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
