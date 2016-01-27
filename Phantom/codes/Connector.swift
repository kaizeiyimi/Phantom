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
 2. all API calls should be in the `queue` which is default to main queue.
*/
final public class Connector {

    private var tracker: ConnectorTracker?
    
    /// default is *false*. two task are treated same only if **URL** is same, **downloader** is same and **cache** is nil or same.
    public var cancelSameURLTask = false
    private var queue = dispatch_get_main_queue()

    public init(queue: dispatch_queue_t = dispatch_get_main_queue()) {
        self.queue = queue
    }
    
    deinit {
        cancelCurrentTask()
    }
    
    public func connect<T>(url: NSURL, downloader: Downloader = sharedDownloader, cache: DownloaderCache? = nil,
        progress: (ProgressInfo -> Void)? = nil,
        decoder: (NSURL, NSData) -> DecodeResult<T>, completion: Result<T> -> Void) {
            
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
            
            // judge cancel
            if let tracker = self.tracker
                where tracker.url == url && tracker.downloader === downloader
                    && (cache == nil || tracker.cache === cache)
                    && !cancelSameURLTask {
                        tracker.progress?(PTInvalidProgressInfo)
                        tracker.progress = progress
                        tracker.decoder = wrapDecoder
                        tracker.completion = wrapCompletion
                        if let progressInfo = tracker.progressInfo {
                            progress?(progressInfo)
                        }
                        return
            }
            
            cancelCurrentTask()
            
            var tracker: ConnectorTracker!
            var currentTask: Task!
            currentTask = downloader.download(url, cache: cache, queue: queue,
                progress: { c, tr, te in
                    guard let task = currentTask where !task.cancelled else { return }
                    tracker.progressInfo = (c, tr, te)
                    tracker.progress?((c, tr, te))
                },
                decoder: { url, data in
                    return tracker.decoder(url, data)
                },
                completion: {[weak self] result in
                    guard let task = currentTask where !task.cancelled else { return }
                    if self?.tracker === tracker {
                        self?.tracker = nil
                    }
                    tracker.completion(result)
                })
            
            tracker = ConnectorTracker(task: currentTask, url: url, progress: progress, decoder: wrapDecoder, completion: wrapCompletion)
            tracker.downloader = downloader
            tracker.cache = cache
            self.tracker = tracker
    }
    
    public func cancelCurrentTask() {
        tracker?.task.cancel()
        if let tracker = self.tracker {
            tracker.progress?(PTInvalidProgressInfo)
            tracker.completion(.Failed(url: tracker.url, error: canncelledError(tracker.url)))
        }
        tracker = nil
    }

}


final private class ConnectorTracker {
    
    var url: NSURL
    var task: Task
    var progressInfo: ProgressInfo?
    
    weak var downloader: Downloader?
    weak var cache: DownloaderCache?
    
    var progress: (ProgressInfo -> Void)?
    var decoder: (NSURL, NSData) -> DecodeResult<Any>
    var completion: Result<Any> -> Void
    
    init(task: Task, url: NSURL, progress: (ProgressInfo -> Void)?, decoder: (NSURL, NSData) -> DecodeResult<Any>, completion: Result<Any> -> Void) {
        self.task = task
        self.url = url
        self.progress = progress
        self.decoder = decoder
        self.completion = completion
    }
    
}


extension UIImageView {
    
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
