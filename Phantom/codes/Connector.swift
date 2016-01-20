//
//  Connector.swift
//  Phantom
//
//  Created by kaizei on 16/1/18.
//  Copyright © 2016年 kaizei. All rights reserved.
//

import Foundation


final public class Connector {
    
    private weak var task: Task?
    private var lastURL: NSURL?
    
    public var requestIgnoreSameURL = true
    public var queue = dispatch_get_main_queue()
    public var taskGenerator: TaskGenerator?
    
    public init() {}
    
    public func connect<T>(url: NSURL, downloader: Downloader? = nil, cache: Cache? = nil,
        progress: ProgressHandler? = nil,
        decoder: (NSURL, NSData) -> T?, completion: T? -> Void) {
            
            guard self.task == nil || url != lastURL || requestIgnoreSameURL else { return }
            self.task?.cancel()
            self.lastURL = url
            
            var task: Task?
            let cancelled = { () -> Bool in
                return task !== self.task
            }
            
            let downloader = downloader ?? sharedDownloader
            task = downloader.download(url, taskGenerator: taskGenerator, cache: cache,
                progress: {[queue] c, tr, te in
                    guard let progress = progress else { return }
                    dispatch_async(queue) {
                        guard !cancelled() else { return }
                        progress(currentSize: c, totalRecievedSize: tr, totalExpectedSize: te)
                    }
                },
                completion: {[queue] result in
                    if case .Success(let url, let data) = result {
                        let r = decoder(url, data)
                        dispatch_async(queue) {
                            guard !cancelled() else { return }
                            completion(r)
                        }
                    } else {
                        dispatch_async(queue) {
                            guard !cancelled() else { return }
                            completion(nil)
                        }
                    }
                })
            self.task = task
    }
    
    public func cancelCurrentTask() {
        task?.cancel()
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

