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

    /// default is *false*. two task are treated same only if **URL** is same, **downloader** is same and **cache** is nil or same.
    public var cancelSameURLTask = false
    public private(set) weak var taskTracker: TaskTracker?

    private var trackingItem: ConnectorTrackingItem?
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
            
            let decoder = wrapDecoder(decoder)
            let completion = wrapCompletion(completion)
            
            // judge cancel
            if let item = self.trackingItem
                where item.url == url && item.downloader === downloader
                    && (cache == nil || item.cache === cache)
                    && !cancelSameURLTask {
                        item.progress?(PTInvalidProgressInfo)
                        item.progress = progress
                        item.decoder = decoder
                        item.completion = completion
                        if let progressInfo = item.progressInfo {
                            progress?(progressInfo)
                        }
                        return
            }
            
            cancelCurrentTask()
            
            var trackingItem: ConnectorTrackingItem!
            var currentTask: Task!
            
            let tracker = TaskTracker.track(url, trackerQueue: queue, downloader: downloader, cache: cache)
            tracker.addTracking(queue,
                progress: { c, tr, te in
                    guard let task = currentTask where !task.cancelled else { return }
                    trackingItem.progressInfo = (c, tr, te)
                    trackingItem.progress?((c, tr, te))
                },
                decoder: { url, data in
                    return trackingItem.decoder(url, data)
                },
                completion: {[weak self] result in
                    guard let task = currentTask where !task.cancelled else { return }
                    if self?.trackingItem === trackingItem {
                        self?.trackingItem = nil
                        self?.taskTracker = nil
                    }
                    trackingItem.completion(result)
                })
            currentTask = tracker.task
            self.taskTracker = tracker
            
            trackingItem = ConnectorTrackingItem(task: currentTask, url: url, progress: progress, decoder: decoder, completion: completion)
            trackingItem.downloader = downloader
            trackingItem.cache = cache
            self.trackingItem = trackingItem
    }
    
    public func cancelCurrentTask() {
        trackingItem?.task.cancel()
        if let item = self.trackingItem {
            item.progress?(PTInvalidProgressInfo)
            item.completion(.Failed(url: item.url, error: canncelledError(item.url)))
        }
        trackingItem = nil
        taskTracker = nil
    }

}


final private class ConnectorTrackingItem {  // only track previous task's state
    
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
