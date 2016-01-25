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
    func cachedDataFromMemory(url: NSURL) -> NSData?
    func cachedDataFromDisk(url: NSURL) -> NSData?
    func cachedDiskURLForURL(url: NSURL) -> NSURL?
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
    
    public func cachedDataFromMemory(url: NSURL) -> NSData? {
        return cache.objectForKey(url) as? NSData
    }
    
    public func cachedDataFromDisk(url: NSURL) -> NSData? {
        return nil
    }
    
    public func cachedDiskURLForURL(url: NSURL) -> NSURL? {
        return nil
    }
}
