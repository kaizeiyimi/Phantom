//
//  Downloader.swift
//  Phantom
//
//  Created by kaizei on 16/1/18.
//  Copyright © 2016年 kaizei. All rights reserved.
//

import Foundation

/// -1 means progress is cancelled.
public let PTInvalidDownloadProgressMetric: Int64 = -1

public typealias ProgressInfo = (currentSize: Int64, totalRecievedSize: Int64, totalExpectedSize: Int64)

public typealias DownloadProgressHandler = ProgressInfo -> Void
public typealias DownloadCompletionHandler = Result -> Void

public typealias TaskGenerator = (url: NSURL, progress: DownloadProgressHandler?, completion: DownloadCompletionHandler) -> (task: Task, saveToDisk: Bool)

public enum Result {
    case Success(url: NSURL, data: NSData)
    case Faild(url: NSURL, error: ErrorType?)
    case Cancelled(url: NSURL)
}

public protocol Task: class {
    var cancelled: Bool { get }
    func cancel()
}

public protocol Downloader {
    func download(url: NSURL, progress: DownloadProgressHandler?, completion: DownloadCompletionHandler) -> Task
    func download(url: NSURL, cache: Cache?, progress: DownloadProgressHandler?, completion: DownloadCompletionHandler) -> Task
    func download(url: NSURL, taskGenerator: TaskGenerator?, cache: Cache?, progress: DownloadProgressHandler?, completion: DownloadCompletionHandler) -> Task
}

public extension Downloader {
    func download(url: NSURL, progress: DownloadProgressHandler?, completion: DownloadCompletionHandler) -> Task {
        return download(url, taskGenerator: nil, cache: nil, progress: progress, completion: completion)
    }
    
    func download(url: NSURL, cache: Cache?, progress: DownloadProgressHandler?, completion: DownloadCompletionHandler) -> Task {
        return download(url, taskGenerator: nil, cache: cache, progress: progress, completion: completion)
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


private func notifyProgressInvalid(progress: DownloadProgressHandler?) {
    let metric = PTInvalidDownloadProgressMetric
    progress?((metric, metric, metric))
}

// MARK: - sharedDownloader
public var sharedDownloader: Downloader = {
    return DefaultDownloader()
}()


// MARK: - DefaultDownloader
public class DefaultDownloader: Downloader {
    
    private let queue = dispatch_queue_create("Phantom.defaultDownloader", DISPATCH_QUEUE_CONCURRENT)
    private let operationQueue = NSOperationQueue()
    lazy private var session: NSURLSession = {
        let session = NSURLSession(configuration: .defaultSessionConfiguration(),
            delegate: URLSessionDelegate(queue: self.queue),
            delegateQueue: self.operationQueue)
        return session
    }()
    
    private var taskGenerator: TaskGenerator!
    
    public init(taskGenerator: TaskGenerator? = nil) {
        self.taskGenerator = (taskGenerator != nil ? taskGenerator : taskForURL)
    }
    
    deinit {
        session.invalidateAndCancel()
    }
    
    public func download(url: NSURL, taskGenerator: TaskGenerator?, cache: Cache?, progress: DownloadProgressHandler?, completion: DownloadCompletionHandler) -> Task {
        var task: Task!
        let taskGenerator: TaskGenerator! = (taskGenerator != nil ? taskGenerator : self.taskGenerator)
        dispatch_sync(queue) { [queue, operationQueue] in
            if let data = cache?.cacheFromMemory(url) {
                task = InMemoryTask()
                dispatch_async(queue) {
                    if task.cancelled {
                        notifyProgressInvalid(progress)
                        completion(.Cancelled(url: url))
                    } else {
                        let length = Int64(data.length)
                        progress?((length, length ,length))
                        completion(.Success(url: url, data: data))
                    }
                }
            } else {
                let combinedTask = CombinedDownloadTask()
                operationQueue.addOperationWithBlock { () -> Void in
                    if let diskURL = cache?.diskURLForCachedURL(url), data = NSData(contentsOfURL: diskURL) {
                        dispatch_sync(queue) {
                            if combinedTask.cancelled {
                                notifyProgressInvalid(progress)
                                completion(.Cancelled(url: url))
                            } else {
                                let length = Int64(data.length)
                                progress?((length, length ,length))
                                completion(.Success(url: url, data: data))
                            }
                        }
                    } else {
                        dispatch_sync(queue) {
                            if !combinedTask.cancelled {
                                var taskInfo: (task: Task, saveToDisk: Bool)!
                                taskInfo = taskGenerator(url: url, progress: progress,
                                    completion: { result in
                                        let _ = combinedTask // just keep task's live
                                        if case .Success(let url, let data) = result {
                                            cache?.cache(url, data: data, saveToDisk: taskInfo.saveToDisk)
                                        } else {
                                            notifyProgressInvalid(progress)
                                        }
                                        completion(result)
                                })
                                combinedTask.sessionTask = taskInfo.task
                            } else {
                                notifyProgressInvalid(progress)
                                completion(.Cancelled(url: url))
                            }
                        }
                    }
                }
                task = combinedTask
            }
        }
        return task
    }
    
    public func taskForURL(url: NSURL, progress: DownloadProgressHandler?, completion: DownloadCompletionHandler) -> (task: Task, saveToDisk: Bool) {
        let sessionTask = session.downloadTaskWithURL(url)
        sessionTask.taskDelegate = TaskDelegate(url: url, progress: progress, completion: completion)
        sessionTask.resume()
        return (sessionTask, true)
    }
    
}


final private class URLSessionDelegate: NSObject, NSURLSessionDownloadDelegate {
    private var queue: dispatch_queue_t
    init(queue: dispatch_queue_t) {
        self.queue = queue
    }
    
    @objc private func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didFinishDownloadingToURL location: NSURL) {
        guard let data = NSData(contentsOfURL: location) else { return }
        dispatch_sync(queue) {
            downloadTask.taskDelegate?.didFinishDownloading(data)
            downloadTask.taskDelegate = nil
        }
    }
    
    @objc private func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        dispatch_sync(queue) {
            downloadTask.taskDelegate?.didWriteData(bytesWritten: bytesWritten, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
        }
    }
    
    @objc private func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
        dispatch_sync(queue) {
            task.taskDelegate?.didCompleteWithError(error)
            task.taskDelegate = nil
        }
    }
    
}


final private class TaskDelegate {
    
    private let url: NSURL
    private let progress: DownloadProgressHandler?
    private let completion: DownloadCompletionHandler
    
    init(url: NSURL, progress: DownloadProgressHandler?, completion: DownloadCompletionHandler) {
        self.progress = progress
        self.completion = completion
        self.url = url
    }
    
    @objc private func didFinishDownloading(data: NSData) {
        completion(.Success(url: url, data: data))
    }
    
    @objc private func didCompleteWithError(error: NSError?) {
        if let error = error where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            completion(.Cancelled(url: url))
        } else {
            completion(.Faild(url: url, error: error))
        }
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
