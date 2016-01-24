//
//  Cache.swift
//  Phantom
//
//  Created by kaizei on 16/1/19.
//  Copyright © 2016年 kaizei. All rights reserved.
//

import Foundation


public protocol DownloaderCache: class {
    func cache(url: NSURL, data: NSData)
    func cacheFromMemory(url: NSURL) -> NSData?
    func cacheFromDisk(url: NSURL) -> NSData?
    func diskURLForCachedURL(url: NSURL) -> NSURL?
}

public var sharedDownloaderCache: DownloaderCache = {
    return DefaultCache()
}()


// MARK: DefaultCache
public class DefaultCache: DownloaderCache {
    
    private var cache = NSCache()
    
    public func cache(url: NSURL, data: NSData) {
        cache.setObject(data, forKey: url)
    }
    
    public func cacheFromMemory(url: NSURL) -> NSData? {
        return cache.objectForKey(url) as? NSData
    }
    
    public func cacheFromDisk(url: NSURL) -> NSData? {
        return nil
    }
    
    public func diskURLForCachedURL(url: NSURL) -> NSURL? {
        return nil
    }
}
