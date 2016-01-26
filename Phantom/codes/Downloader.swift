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
public let PTInvalidProgressInfo = (PTInvalidDownloadProgressMetric, PTInvalidDownloadProgressMetric, PTInvalidDownloadProgressMetric)

public typealias ProgressInfo = (currentSize: Int64, totalRecievedSize: Int64, totalExpectedSize: Int64)

public typealias TaskGenerator = (url: NSURL, progress: (ProgressInfo -> Void)?, completion: Result<NSData> -> Void) -> Task

public enum Result<T> {
    case Success(url: NSURL, data: T)
    case Failed(url: NSURL, error: ErrorType?)
}

public enum DecodeResult<T> {
    case Success(data: T)
    case Failed(error: ErrorType?)
}

// MARK: - Task Tracking
final public class TrackingToken: Hashable {
    public var hashValue: Int {
        return "\(unsafeAddressOf(self))".hashValue
    }
}

public func ==(lhs: TrackingToken, rhs: TrackingToken) -> Bool {
    return lhs === rhs
}

public protocol Tracker: class {
    var progressInfo: ProgressInfo? { get }
    
    func addTracking(progress progress: (ProgressInfo -> Void)) -> TrackingToken?
    func addTracking<T>(progress progress: (ProgressInfo -> Void)?, decoder: (NSURL, NSData) -> DecodeResult<T> , completion: Result<T> -> Void) -> TrackingToken?
    
    func removeTracking(token: TrackingToken?)
}


// Task
public protocol Task: class {
    var cancelled: Bool { get }
    func cancel()
}


// MARK: downloader
public protocol Downloader: class {
    func download<T>(url: NSURL, progress: (ProgressInfo -> Void)?, decoder: (NSURL, NSData) -> DecodeResult<T> , completion: Result<T> -> Void) -> Task
    func download<T>(url: NSURL, cache: DownloaderCache?, progress: (ProgressInfo -> Void)?, decoder: (NSURL, NSData) -> DecodeResult<T> , completion: Result<T> -> Void) -> Task
    
    func trackerForTask(task: Task) -> Tracker?
    
}

public extension Downloader {
    func download<T>(url: NSURL, progress: (ProgressInfo -> Void)?, decoder: (NSURL, NSData) -> DecodeResult<T> , completion: Result<T> -> Void) -> Task {
        return download(url, cache: nil, progress: progress, decoder: decoder, completion: completion)
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

// MARK: -

func canncelledError(url: NSURL) -> NSError {
    return NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled, userInfo: [
        NSURLErrorFailingURLErrorKey: url,
        NSURLErrorFailingURLStringErrorKey: url.absoluteString,
        NSLocalizedDescriptionKey: "cancelled"
        ])
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
    
    private var tasks: [String: Tracker] = [:]
    private var lock = OS_SPINLOCK_INIT
    
    private var taskGenerator: TaskGenerator?
    
    public init(generator: TaskGenerator? = nil) {
        self.taskGenerator = generator
    }
    
    deinit {
        session.invalidateAndCancel()
    }
    
    public func download<T>(url: NSURL, cache: DownloaderCache?, progress: (ProgressInfo -> Void)?, decoder: (NSURL, NSData) -> DecodeResult<T> , completion: Result<T> -> Void) -> Task {
        var task: Task!
        let tracker = DefaultTracker()
        var taskGenerator: TaskGenerator! = self.taskGenerator  // swift compiler bug. cannot use ?: or ??
        if taskGenerator == nil {
            taskGenerator = taskForURL
        }
        dispatch_sync(queue) { [queue, operationQueue, weak self] in
            if let data = cache?.cachedDataFromMemory(url) {
                task = InMemoryTask()
                dispatch_async(queue) {
                    if task.cancelled {
                        tracker.notifyProgress(PTInvalidProgressInfo)
                        tracker.notifyCompletion(.Failed(url: url, error: canncelledError(url)))
                    } else {
                        let length = Int64(data.length)
                        tracker.notifyProgress((length, length ,length))
                        tracker.notifyCompletion(.Success(url: url, data: data))
                    }
                    self?.removeTracker(task)
                }
            } else {
                let combinedTask = CombinedDownloadTask()
                operationQueue.addOperationWithBlock { () -> Void in
                    if let diskURL = cache?.cachedDiskURLForURL(url), data = NSData(contentsOfURL: diskURL) {
                        dispatch_sync(queue) {
                            if combinedTask.cancelled {
                                tracker.notifyProgress(PTInvalidProgressInfo)
                                tracker.notifyCompletion(.Failed(url: url, error: canncelledError(url)))
                            } else {
                                let length = Int64(data.length)
                                tracker.notifyProgress((length, length ,length))
                                tracker.notifyCompletion(.Success(url: url, data: data))
                            }
                            self?.removeTracker(task)
                        }
                    } else {
                        dispatch_sync(queue) {
                            if !combinedTask.cancelled {
                                combinedTask.sessionTask = taskGenerator(url: url,
                                    progress: { c, tr, te in
                                        tracker.notifyProgress((c, tr, te))
                                    },
                                    completion: { result in
                                        let _ = combinedTask // just keep task's live
                                        if case .Success(let url, let data) = result {
                                            cache?.cache(url, data: data)
                                        } else {
                                            tracker.notifyProgress(PTInvalidProgressInfo)
                                        }
                                        tracker.notifyCompletion(result)
                                        self?.removeTracker(task)
                                })
                            } else {
                                tracker.notifyProgress(PTInvalidProgressInfo)
                                tracker.notifyCompletion(.Failed(url: url, error: canncelledError(url)))
                                self?.removeTracker(task)
                            }
                        }
                    }
                }
                task = combinedTask
            }
        }
        
        tracker.addTracking(progress: progress, decoder: decoder, completion: completion)
        OSSpinLockLock(&lock)
        self.tasks["\(unsafeAddressOf(task))"] = tracker
        OSSpinLockUnlock(&lock)
        return task
    }
    
    public func trackerForTask(task: Task) -> Tracker? {
        OSSpinLockLock(&lock)
        let tracker = tasks["\(unsafeAddressOf(task))"]
        OSSpinLockUnlock(&lock)
        return tracker
    }
    
    private func removeTracker(task: Task) {
        OSSpinLockLock(&lock)
        tasks.removeValueForKey("\(unsafeAddressOf(task))")
        OSSpinLockUnlock(&lock)
    }
    
    private func taskForURL(url: NSURL, progress: (ProgressInfo -> Void)?, completion: Result<NSData> -> Void) -> Task {
        let sessionTask = session.downloadTaskWithURL(url)
        sessionTask.taskDelegate = TaskDelegate(url: url, progress: progress, completion: completion)
        sessionTask.resume()
        return sessionTask
    }
    
}

// MARK: - DefaultTaskTracker
public class DefaultTracker: Tracker {
    
    typealias DecoderCompletion = (decoder: (NSURL, NSData) -> DecodeResult<Any>, completion: Result<Any> -> Void)
    
    public internal(set) var progressInfo: ProgressInfo?
    
    var lock = OS_SPINLOCK_INIT
    var trackings: [TrackingToken: (progress: (ProgressInfo -> Void)?, decoderCompletion: DecoderCompletion?)] = [:]
    
    // TODO: invalid progress?
    public func addTracking(progress progress: (ProgressInfo -> Void)) -> TrackingToken? {
        let token = TrackingToken()
        OSSpinLockLock(&lock)
        trackings[token] = (progress: progress, decoderCompletion: nil)
        OSSpinLockUnlock(&lock)
        return token
    }
    
    public func addTracking<T>(progress progress: (ProgressInfo -> Void)?, decoder: (NSURL, NSData) -> DecodeResult<T> , completion: Result<T> -> Void) -> TrackingToken? {
        let token = TrackingToken()
        let wrapDecoder = { (url: NSURL, data: NSData) -> DecodeResult<Any> in
            switch decoder(url, data) {
            case .Success(let result): return .Success(data: result as Any)
            case .Failed(let error): return .Failed(error: error)
            }
        }
        let wrapCompletion = { (decoded: Result<Any>) in
            switch decoded {
            case .Success(let url, let result): completion(.Success(url: url, data: result as! T))
            case .Failed(let url, let error): completion(.Failed(url: url, error: error))
            }
        }
        OSSpinLockLock(&lock)
        trackings[token] = (progress, (decoder: wrapDecoder, completion: wrapCompletion))
        OSSpinLockUnlock(&lock)
        return token
    }
    
    public func removeTracking(token: TrackingToken?) {
        if let token = token {
            OSSpinLockLock(&lock)
            trackings.removeValueForKey(token)
            OSSpinLockUnlock(&lock)
        }
    }
    
    func notifyProgress(progress: ProgressInfo) {
        self.progressInfo = progress
        OSSpinLockLock(&lock)
        let progresses = trackings.flatMap{$1.progress}
        OSSpinLockUnlock(&lock)
        progresses.forEach { $0(progress) }
    }
    
    func notifyCompletion(result: Result<NSData>) {
        OSSpinLockLock(&lock)
        let decodeCompletions = trackings.flatMap{$1.decoderCompletion}
        OSSpinLockUnlock(&lock)
        
        let decoded: [Result<Any>]
        switch result {
        case .Success(let url, let data):
            decoded = decodeCompletions.map {
                switch $0.decoder(url, data) {
                case .Success(let d):
                    return .Success(url: url, data: d as Any)
                case .Failed(let error):
                    return .Failed(url: url, error: error)
                }
            }
        case .Failed(let url, let error):
            decoded = [Result<Any>](count: decodeCompletions.count, repeatedValue: .Failed(url: url, error: error))
        }
        
        zip(decodeCompletions, decoded).forEach{ decodeCompletion, data in
            decodeCompletion.completion(data)
        }
    }
}

// MARK: -

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
