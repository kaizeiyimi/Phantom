//
//  Downloader.swift
//  Phantom
//
//  Created by kaizei on 16/1/18.
//  Copyright © 2016年 kaizei. All rights reserved.
//

import Foundation

/// -1 means progress is invalid now. may be triggered by failed or cancelled.
public let PTInvalidDownloadProgressMetric: Int64 = -1
public let PTInvalidProgressInfo = (PTInvalidDownloadProgressMetric, PTInvalidDownloadProgressMetric, PTInvalidDownloadProgressMetric)

public typealias ProgressInfo = (currentSize: Int64, totalRecievedSize: Int64, totalExpectedSize: Int64)

public typealias TaskGenerator = (url: NSURL, progress: (ProgressInfo -> Void)?, completion: Result<NSData> -> Void) -> Task

/// Common Result Enum.
public enum Result<T> {
    typealias DataType = T
    case Success(url: NSURL, data: T)
    case Failed(url: NSURL, error: ErrorType?)
}

/// Decode Result Enum. used for decoder's result.
public enum DecodeResult<T> {
    case Success(data: T)
    case Failed(error: ErrorType?)
}

/// Task.
public protocol Task: class {
    var cancelled: Bool { get }
    func cancel()
}


// MARK: downloader

/**
a `Downloader` provides the ability to download data.

`url`, `cache` are the most important things. `url` defines which resource to download and `cache` controls which cache should be used for the task.

`queue` is the callback queue for `progress` and `completion`. if set to `nil`, will use downloader's default setting.
`progress` is a callback for the downloading task's progress. will be called in the `queue`. if task is cancelled or failed, will be called with `PTInvalidProgressInfo`.
`decoder` defines how to decode the `NSData`.
`completion` will be called with decoded content.

@See **Tracker** for more detail.

*/
public protocol Downloader: class {
    func download<T>(url: NSURL, cache: DownloaderCache?, queue: dispatch_queue_t?, progress: (ProgressInfo -> Void)?, decoder: (NSURL, NSData) -> DecodeResult<T> , completion: Result<T> -> Void) -> Task
}

public extension Downloader {
    
    func download<T>(url: NSURL, progress: (ProgressInfo -> Void)?, decoder: (NSURL, NSData) -> DecodeResult<T> , completion: Result<T> -> Void) -> Task {
        return download(url, cache: nil, queue: nil, progress: progress, decoder: decoder, completion: completion)
    }
    
    func download<T>(url: NSURL, cache: DownloaderCache?, progress: (ProgressInfo -> Void)?, decoder: (NSURL, NSData) -> DecodeResult<T> , completion: Result<T> -> Void) -> Task {
        return download(url, cache: cache, queue: nil, progress: progress, decoder: decoder, completion: completion)
    }
    
    func download<T>(url: NSURL, queue: dispatch_queue_t?, progress: (ProgressInfo -> Void)?, decoder: (NSURL, NSData) -> DecodeResult<T> , completion: Result<T> -> Void) -> Task {
        return download(url, cache: nil, queue: queue, progress: progress, decoder: decoder, completion: completion)
    }
}


// MARK: - extension NSURLSessionTask
extension NSURLSessionTask: Task {
    static private var TaskDelegateKey = "kaizei.yimi.Phantom.TaskDelegateKey"
    private var taskDelegate: TaskDelegate? {
        get { return objc_getAssociatedObject(self, &NSURLSessionTask.TaskDelegateKey) as? TaskDelegate }
        set { objc_setAssociatedObject(self, &NSURLSessionTask.TaskDelegateKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    public var cancelled: Bool {
        return state == .Canceling
    }
}

// MARK: - sharedDownloader

/// sharedDownloader. you can set your own too.
public var sharedDownloader: Downloader = {
    return DefaultDownloader()
}()

// MARK: - DefaultDownloader

/**
a default implementation. downloads using NSURLSession's download task.

you can set `URLRequestGenerator` to modify `URLRequest` or set `taskGenerator` to provide custom task.
*/
public class DefaultDownloader: Downloader {
    
    private let operationQueue = NSOperationQueue()
    lazy private var session: NSURLSession = {
        let session = NSURLSession(configuration: .defaultSessionConfiguration(),
            delegate: URLSessionDelegate(operationQueue: self.operationQueue),
            delegateQueue: self.operationQueue)
        return session
    }()
    
    /// if you choose to use `DefaultDownloader`'s logic, you can set this to generator your own task ranther than default.
    private var taskGenerator: TaskGenerator?
    
    /// if you use default `TaskGenerator`, you can set `URLRequestGenerator` to generate `NSURLRequest` with custom config.
    public var URLRequestGenerator: NSURL -> NSURLRequest = { url in
        return NSURLRequest(URL: url)
    }
    
    public init(generator: TaskGenerator? = nil) {
        self.taskGenerator = generator
    }
    
    deinit {
        session.invalidateAndCancel()
        operationQueue.cancelAllOperations()
    }
    
    /**
     this implementation will always callback async even hit cache.
     */
    public func download<T>(url: NSURL, cache: DownloaderCache?, queue: dispatch_queue_t?, progress: (ProgressInfo -> Void)?, decoder: (NSURL, NSData) -> DecodeResult<T> , completion: Result<T> -> Void) -> Task {
        var task: Task!
        var taskGenerator: TaskGenerator! = self.taskGenerator  // swift compiler bug. cannot use ?: or ??
        if taskGenerator == nil {
            taskGenerator = taskForURL
        }
        
        // try load from cache
        if let data = cache?.cachedDataFromMemory(url) {
            task = InMemoryTask()
            operationQueue.addOperationWithBlock {
                if !task.cancelled {
                    let length = Int64(data.length)
                    let decoded = decode(.Success(url: url, data: data), decoder: decoder)
                    if !task.cancelled {
                        execute(queue) { progress?((length, length, length)) }
                        execute(queue) { completion(decoded) }
                        return
                    }
                }
                execute(queue) { progress?(PTInvalidProgressInfo) }
                execute(queue) { completion(.Failed(url: url, error: canncelledError(url))) }
            }
        } else {    // load from disk first if failed load from network.
            let combinedTask = CombinedDownloadTask()
            operationQueue.addOperationWithBlock {
                if let data = cache?.cachedDataFromDisk(url) {
                    if !task.cancelled {
                        let length = Int64(data.length)
                        let decoded = decode(.Success(url: url, data: data), decoder: decoder)
                        if !task.cancelled {
                            execute(queue) { progress?((length, length, length)) }
                            execute(queue) { completion(decoded) }
                            return
                        }
                    }
                    execute(queue) { progress?(PTInvalidProgressInfo) }
                    execute(queue) { completion(.Failed(url: url, error: canncelledError(url))) }
                } else {
                    if !task.cancelled {
                        combinedTask.sessionTask = taskGenerator(url: url,
                            progress: { c, tr, te in
                                execute(queue) { progress?((c, tr, te)) }
                            },
                            completion: { result in
                                let _ = combinedTask // just keep task's live
                                switch result {
                                case .Success(let url, let data):
                                    cache?.cache(url, data: data)
                                    let decoded = decode(.Success(url: url, data: data), decoder: decoder)
                                    if !task.cancelled {
                                        execute(queue) { completion(decoded) }
                                    } else {
                                        execute(queue) { progress?(PTInvalidProgressInfo) }
                                        execute(queue) { completion(.Failed(url: url, error: canncelledError(url))) }
                                    }
                                case .Failed(let url, let error):
                                    execute(queue) { progress?(PTInvalidProgressInfo) }
                                    execute(queue) { completion(.Failed(url: url, error: error)) }
                                }
                        })
                    } else {
                        execute(queue) { progress?(PTInvalidProgressInfo) }
                        execute(queue) { completion(.Failed(url: url, error: canncelledError(url))) }
                    }
                }
            }
            
            task = combinedTask
        }

        return task
    }
    
    /// default taskGenerator. set `taskGenerator` to customise.
    private func taskForURL(url: NSURL, progress: (ProgressInfo -> Void)?, completion: Result<NSData> -> Void) -> Task {
        let sessionTask = session.downloadTaskWithRequest(URLRequestGenerator(url))
        sessionTask.taskDelegate = TaskDelegate(url: url, progress: progress, completion: completion)
        sessionTask.resume()
        return sessionTask
    }
    
}


// MARK: - Helpers

final private class URLSessionDelegate: NSObject, NSURLSessionDownloadDelegate {
    private var operationQueue: NSOperationQueue
    init(operationQueue: NSOperationQueue) {
        self.operationQueue = operationQueue
    }
    
    @objc private func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didFinishDownloadingToURL location: NSURL) {
        guard let data = NSData(contentsOfURL: location) else { return }
        operationQueue.addOperationWithBlock {
            if let taskDelegate = downloadTask.taskDelegate {
                downloadTask.taskDelegate = nil
                taskDelegate.didFinishDownloading(data)
            }
        }
    }
    
    @objc private func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        operationQueue.addOperationWithBlock {
            downloadTask.taskDelegate?.didWriteData(bytesWritten: bytesWritten, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
        }
    }
    
    @objc private func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
        operationQueue.addOperationWithBlock {
            if let taskDelegate = task.taskDelegate {
                task.taskDelegate = nil
                taskDelegate.didCompleteWithError(error)
            }
            
        }
    }
    
}


final private class TaskDelegate {
    
    private let url: NSURL
    private let progress: (ProgressInfo -> Void)?
    private let completion: Result<NSData> -> Void
    
    init(url: NSURL, progress: (ProgressInfo -> Void)?, completion: Result<NSData> -> Void) {
        self.progress = progress
        self.completion = completion
        self.url = url
    }
    
    @objc private func didFinishDownloading(data: NSData) {
        completion(.Success(url: url, data: data))
    }
    
    @objc private func didCompleteWithError(error: NSError?) {
        completion(.Failed(url: url, error: error))
    }
    
    @objc private func didWriteData(bytesWritten bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        progress?(currentSize: bytesWritten, totalRecievedSize: totalBytesWritten, totalExpectedSize: totalBytesExpectedToWrite)
    }
}


final private class CombinedDownloadTask: Task {
    private var sessionTask: Task?
    private var cancelled = false
    private func cancel() {
        cancelled = true
        sessionTask?.cancel()
    }
}

final private class InMemoryTask: Task {
    private var cancelled = false
    private func cancel() {
        cancelled = true
    }
}
