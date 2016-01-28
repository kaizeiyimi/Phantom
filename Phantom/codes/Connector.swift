//
//  Connector.swift
//  Phantom
//
//  Created by kaizei on 16/1/18.
//  Copyright © 2016年 kaizei. All rights reserved.
//

import Foundation


final public class Connector<T> {
    
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
        
    @objc public func cancelCurrentTask() {
        guard !task.cancelled && result == nil else { return }
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
