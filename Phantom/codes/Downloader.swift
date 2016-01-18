//
//  Downloader.swift
//  Phantom
//
//  Created by kaizei on 16/1/18.
//  Copyright © 2016年 kaizei. All rights reserved.
//

import Foundation

public enum Result {
    case Success(data: NSData)
    case Faild(error: ErrorType?)
}


public protocol Cancelable: class {
    func cancel()
}

public protocol Downloader {
    func download(request: NSURLRequest, completion: Result -> Void) throws -> Cancelable?
    func download(url: NSURL, completion: Result -> Void) -> Cancelable?
    func taskForURL(url: NSURL) -> Cancelable?
}

public protocol Cache {
    func cache(url: NSURL, data: NSData, saveToDisk: Bool)
    func cacheFromMemory(url: NSURL) -> NSData?
    func diskURLForCachedURL(url: NSURL) -> NSURL?
}

// MARK: - extension NSURLSessionTask
extension NSURLSessionTask: Cancelable {}

public var sharedDownloader: Downloader = {
   return DefaultDownloader()
}()

public var sharedCache: Cache = {
    return DefaultCache()
}()

// MARK: DefaultDownloader
public class DefaultDownloader: Downloader {
    
    private struct WeakWrapper {
        weak var task: Cancelable?
    }
    
    private let queue = dispatch_queue_create("Phantom.defaultDownloader", DISPATCH_QUEUE_SERIAL)
    private var tasks: [NSURL: WeakWrapper] = [:]
    private var cache: Cache {
        return sharedCache
    }
    
    public init() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "memoryWarning:", name: UIApplicationDidReceiveMemoryWarningNotification, object: nil)
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    @objc private func memoryWarning(sender: AnyObject) {
        tasks.filter{ $1.task == nil }.forEach{ tasks.removeValueForKey($0.0) }
    }
    
    public func download(url: NSURL, completion: Result -> Void) -> Cancelable? {
        return download(NSURLRequest(URL: url), completion: completion)
    }
    
    public func download(request: NSURLRequest, completion: Result -> Void) -> Cancelable? {
        guard let url = request.URL else {
            return nil
        }
        self.tasks.removeValueForKey(url)?.task?.cancel()
        var task: Cancelable?
        dispatch_sync(queue) {
            if let data = self.cache.cacheFromMemory(url) {
                completion(.Success(data: data))
            } else {
                if let current = self.tasks[url]?.task {
                    task = current
                } else {
                    self.tasks.removeValueForKey(url)?.task?.cancel()
                    let sessionTask = NSURLSession.sharedSession().downloadTaskWithRequest(request) {
                        [weak self] (diskURL, _, error) -> Void in
                        guard let this = self else { return }
                        dispatch_sync(this.queue) {
                            this.tasks.removeValueForKey(url)
                            if let diskURL = diskURL, data = NSData(contentsOfURL: diskURL) {
                                completion(.Success(data: data))
                            } else {
                                completion(.Faild(error: error))
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
    
    public func taskForURL(url: NSURL) -> Cancelable? {
        var task: Cancelable?
        dispatch_sync(queue) {
            task = self.tasks[url]?.task
        }
        return task
    }
}


// MARK: DefaultCache
public class DefaultCache: Cache {
    public func cache(url: NSURL, data: NSData, saveToDisk: Bool) {}
    
    public func cacheFromMemory(url: NSURL) -> NSData? {
        return nil
    }
    
    public func diskURLForCachedURL(url: NSURL) -> NSURL? {
        return nil
    }
}
