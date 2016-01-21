//
//  Connector.swift
//  Phantom
//
//  Created by kaizei on 16/1/18.
//  Copyright © 2016年 kaizei. All rights reserved.
//

import Foundation


final public class Connector {
    
    /// -1 means progress is cancelled.
    public static let PTCancelledDownloadProgressMetric: Int64 = -1
    
    private weak var task: Task?
    private var lastURL: NSURL?
    
    public var requestIgnoreSameURL = true
    public var queue = dispatch_get_main_queue()
    public var taskGenerator: TaskGenerator?
    
    public init() {}
    
    deinit {
        task?.cancel()
    }
    
    public func connect<T>(url: NSURL, downloader: Downloader? = nil, cache: Cache? = nil,
        progress: DownloadProgressHandler? = nil,
        decoder: (NSURL, NSData) -> T?, completion: T? -> Void) {
            
            guard self.task == nil || url != lastURL || requestIgnoreSameURL else { return }
            self.task?.cancel()
            self.lastURL = url
            
            var task: Task?
            let downloader = downloader ?? sharedDownloader
            task = downloader.download(url, taskGenerator: taskGenerator, cache: cache,
                progress: {[queue] c, tr, te in
                    guard let progress = progress else { return }
                    dispatch_async(queue) {
                        guard let task = task where !task.cancelled else { return }
                        progress((c, tr, te))
                    }
                },
                completion: {[queue] result in
                    var decoded: T?
                    if case .Success(let url, let data) = result {
                        decoded = decoder(url, data)
                    }
                    dispatch_async(queue) {
                        guard let task = task where !task.cancelled else {
                            let metric = Connector.PTCancelledDownloadProgressMetric
                            progress?((metric, metric, metric))
                            return
                        }
                        completion(decoded)
                    }
                })
            self.task = task
    }
    
    public func cancelCurrentTask() {
        task?.cancel()
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

