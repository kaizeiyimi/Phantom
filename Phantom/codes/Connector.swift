//
//  Connector.swift
//  Phantom
//
//  Created by kaizei on 16/1/18.
//  Copyright © 2016年 kaizei. All rights reserved.
//

import Foundation


final public class Connector {
    
    public weak var currentTask: Task?
    
    public var downloader: Downloader
    public var cache: Cache?
    public var taskGenerator: TaskGenerator?
    
    public init(downloader: Downloader = sharedDownloader, cache: Cache? = sharedCache) {
        self.downloader = downloader
        self.cache = cache
    }
    
    public func connect(downloader: Downloader? = nil, cache: Cache? = nil, taskGenerator: TaskGenerator? = nil)
        (url: NSURL, progress: ProgressHandler?, completion: CompletionHandler) -> Task? {
            let downloader = downloader ?? self.downloader
            let cache = cache ?? self.cache
            let taskGenerator = taskGenerator ?? self.taskGenerator
            currentTask?.cancel()
            currentTask = downloader.download(url, taskGenerator: taskGenerator, cache: cache,
                progress: { currentSize, totalRecievedSize, totalExpectedSize -> Void in
                    dispatch_async(dispatch_get_main_queue()) {
                        progress?(currentSize: currentSize, totalRecievedSize: totalRecievedSize, totalExpectedSize: totalExpectedSize)
                    }
                },
                completion: {(result: Result) -> Void in
                    dispatch_async(dispatch_get_main_queue()) {
                        
                    }
                })
            return currentTask
    }
}
