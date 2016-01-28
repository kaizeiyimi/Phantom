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
final public class Connector<T> {

    /// default is *false*. two task are treated same only if **URL** is same, **downloader** is same and **cache** is nil or same.
//    public var cancelSameURLTask = false
    public private(set) var taskTracker: TaskTracker?
    public private(set) var resultTracker: ResultTracker<T>?
    
    public private(set) weak var downloader: Downloader?
    public private(set) weak var cache: DownloaderCache?

    public private(set) var task: Task!
    public private(set) var progressInfo: ProgressInfo?
    public private(set) var result: Result<T>?
    
    private let url: NSURL
    private var progress: (ProgressInfo -> Void)?
    private var completion: (Result<T> -> Void)?
    
    private var queue = dispatch_get_main_queue()

    init(url: NSURL, queue: dispatch_queue_t = dispatch_get_main_queue()) {
        self.url = url
        self.queue = queue
    }
    
    deinit {
        cancelCurrentTask()
    }
    
    public static func connect(url: NSURL, queue: dispatch_queue_t? = nil, downloader: Downloader = sharedDownloader, cache: DownloaderCache? = nil)
        (progress: (ProgressInfo -> Void)?, decoder: (NSURL, NSData) -> DecodeResult<T>, completion: Result<T> -> Void) -> Connector<T> {
            let queue: dispatch_queue_t = queue ?? dispatch_get_main_queue()
            let connector = Connector(url: url, queue: queue)
            connector.progress = progress
            connector.completion = completion
            
            var currentTask: Task!
            
            let taskTracker = TaskTracker.track(url, trackerQueue: queue, downloader: downloader, cache: cache)
            taskTracker.addTracking(queue,
                progress: {[weak connector] info in
                    guard let task = currentTask where !task.cancelled else { return }
                    connector?.progressInfo = info
                    progress?(info)
                    connector?.resultTracker?.notifyProgress(info)
                },
                decoder: decoder,
                completion: {[weak connector] result in
                    guard let task = currentTask where !task.cancelled else { return }
                    connector?.result = result
                    completion(result)
                    connector?.resultTracker?.notifyCompletion(result)
                })
            
            currentTask = taskTracker.task
            connector.task = currentTask
            connector.taskTracker = taskTracker
            connector.resultTracker = ResultTracker<T>(trackerQueue: queue)
            
            return connector
    }
    
//    public func connect<T>(url: NSURL, downloader: Downloader = sharedDownloader, cache: DownloaderCache? = nil,
//        progress: (ProgressInfo -> Void)? = nil,
//        decoder: (NSURL, NSData) -> DecodeResult<T>, completion: Result<T> -> Void) {
//            
//            let decoder = wrapDecoder(decoder)
//            let completion = wrapCompletion(completion)
//            
//            // judge cancel
//            if let item = self.trackingItem
//                where item.url == url && item.downloader === downloader
//                    && (cache == nil || item.cache === cache)
//                    && !cancelSameURLTask {
//                        item.progress?(PTInvalidProgressInfo)
//                        item.progress = progress
//                        item.decoder = decoder
//                        item.completion = completion
//                        if let progressInfo = item.progressInfo {
//                            progress?(progressInfo)
//                        }
//                        return
//            }
//            
//            cancelCurrentTask()
//            
//            var trackingItem: ConnectorTrackingItem!
//            var currentTask: Task!
//            
//            let tracker = TaskTracker.track(url, trackerQueue: queue, downloader: downloader, cache: cache)
//            tracker.addTracking(queue,
//                progress: { c, tr, te in
//                    guard let task = currentTask where !task.cancelled else { return }
//                    trackingItem.progressInfo = (c, tr, te)
//                    trackingItem.progress?((c, tr, te))
//                },
//                decoder: { url, data in
//                    return trackingItem.decoder(url, data)
//                },
//                completion: {[weak self] result in
//                    guard let task = currentTask where !task.cancelled else { return }
//                    if self?.trackingItem === trackingItem {
//                        self?.trackingItem = nil
//                        self?.taskTracker = nil
//                    }
//                    trackingItem.completion(result)
//                })
//            currentTask = tracker.task
//            self.taskTracker = tracker
//            
//            trackingItem = ConnectorTrackingItem(task: currentTask, url: url, progress: progress, decoder: decoder, completion: completion)
//            trackingItem.downloader = downloader
//            trackingItem.cache = cache
//            self.trackingItem = trackingItem
//    }
    
    @objc public func cancelCurrentTask() {
        guard !task.cancelled else { return }
        task.cancel()
        progress?(PTInvalidProgressInfo)
        resultTracker?.notifyProgress(PTInvalidProgressInfo)
        let error = Result<T>.Failed(url: url, error: canncelledError(url))
        completion?(error)
        resultTracker?.notifyCompletion(error)
        progress = nil
        completion = nil
    }

}

