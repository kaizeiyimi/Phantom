//
//  Downloader.swift
//  Phantom
//
//  Created by kaizei on 16/1/18.
//  Copyright © 2016年 kaizei. All rights reserved.
//

import Foundation

public typealias ProgressHandler = (currentData: NSData, currentSize: Double, totalSize: Double) -> Void
public typealias CompletionHandler = (result: Result) -> Void

public enum Result {
    case Success(data: NSData)
    case Faild(error: ErrorType?)
    case Canceled
}

public protocol Task: class {
    func cancel()
}

public protocol Downloader {
    func download(url: NSURL, progress: ProgressHandler?, completion: CompletionHandler) -> Task?
    func taskForURL(url: NSURL) -> Task?
}


// MARK: - extension NSURLSessionTask
extension NSURLSessionTask: Task {}

public var sharedDownloader: Downloader = {
   return DefaultDownloader()
}()


// MARK: DefaultDownloader
public class DefaultDownloader: Downloader {
    
    private struct WeakWrapper {
        weak var task: Task?
    }
    
    private let queue = dispatch_queue_create("Phantom.defaultDownloader", DISPATCH_QUEUE_SERIAL)
    private var tasks: [NSURL: WeakWrapper] = [:]
    private var cache: Cache {
        return sharedCache
    }
    
    public func download(url: NSURL, progress: ProgressHandler? = nil, completion: CompletionHandler) -> Task? {
        var task: Task?
        dispatch_sync(queue) {
            self.tasks.removeValueForKey(url)?.task?.cancel()
            if let data = self.cache.cacheFromMemory(url) {
                completion(result: .Success(data: data))
            } else {
                if let current = self.tasks[url]?.task {
                    task = current
                } else {
                    
                    let sessionTask = NSURLSession.sharedSession().downloadTaskWithURL(url) {
                        [weak self] (diskURL, _, error) -> Void in
                        guard let this = self else { return }
                        dispatch_sync(this.queue) {
                            this.tasks.removeValueForKey(url)
                            if let diskURL = diskURL, data = NSData(contentsOfURL: diskURL) {
                                completion(result: .Success(data: data))
                            } else {
                                completion(result: .Faild(error: error))
                            }
                        }
                    }
                    self.tasks[url] = WeakWrapper(task: sessionTask)
                    sessionTask.resume()
                    task = sessionTask
                }
            }
        }
        return task
    }
    
    public func taskForURL(url: NSURL) -> Task? {
        var task: Task?
        dispatch_sync(queue) {
            task = self.tasks[url]?.task
        }
        return task
    }
}
