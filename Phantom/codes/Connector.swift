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
    
    private weak var task: Task?
    private var cancelHandler: (() -> Void)?
    
    public var queue = dispatch_get_main_queue()
    public var taskGenerator: TaskGenerator?
    
    public init() {}
    
    deinit {
        cancelCurrentTask()
    }
    
    public func connect<T>(url: NSURL, downloader: Downloader? = nil, cache: Cache? = nil,
        progress: DownloadProgressHandler? = nil,
        decoder: (NSURL, NSData) -> T?, completion: T? -> Void) {
            cancelCurrentTask()
            
            var currentTask: Task!
            let downloader = downloader ?? sharedDownloader
            self.task = downloader.download(url, taskGenerator: taskGenerator, cache: cache,
                progress: {[queue] c, tr, te in
                    guard let progress = progress else { return }
                    dispatch_async(queue) {
                        guard let task = currentTask where !task.cancelled else { return }
                        progress((c, tr, te))
                    }
                },
                completion: {[queue, weak self] result in
                    var decoded: T?
                    if case .Success(let url, let data) = result {
                        decoded = decoder(url, data)
                    }
                    dispatch_async(queue) {
                        if self?.task === currentTask {
                            self?.cancelHandler = nil
                        }
                        guard let task = currentTask where !task.cancelled else { return }
                        completion(decoded)
                    }
                })
            
            currentTask = self.task
            
            cancelHandler = {
                let metric = PTInvalidDownloadProgressMetric
                progress?((metric, metric, metric))
                completion(nil)
            }
    }
    
    public func cancelCurrentTask() {
        task?.cancel()
        cancelHandler?()
        cancelHandler = nil
        task = nil
    }

}


extension NSObject {
    
    private static var kConnectorKey = "kaizei.yimi.phantom.connectorKey"
    
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
