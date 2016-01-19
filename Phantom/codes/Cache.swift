//
//  Cache.swift
//  Phantom
//
//  Created by kaizei on 16/1/19.
//  Copyright © 2016年 kaizei. All rights reserved.
//

import Foundation


public protocol Cache: class {
    func cache(url: NSURL, data: NSData, saveToDisk: Bool)
    func cacheFromMemory(url: NSURL) -> NSData?
    func cacheFromDisk(url: NSURL) -> NSData?
    func diskURLForCachedURL(url: NSURL) -> NSURL?
}

public var sharedCache: Cache = {
    return DefaultCache()
}()


// MARK: DefaultCache
public class DefaultCache: Cache {
    public func cache(url: NSURL, data: NSData, saveToDisk: Bool) {}
    
    public func cacheFromMemory(url: NSURL) -> NSData? {
        return nil
    }
    
    public func cacheFromDisk(url: NSURL) -> NSData? {
        return nil
    }
    
    public func diskURLForCachedURL(url: NSURL) -> NSURL? {
        return nil
    }
}
