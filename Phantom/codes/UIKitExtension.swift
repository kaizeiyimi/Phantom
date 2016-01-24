//
//  UIKitExtension.swift
//  Phantom
//
//  Created by kaizei on 16/1/19.
//  Copyright © 2016年 kaizei. All rights reserved.
//

import UIKit


extension UIImageView {
    
    // MARK: - helper method
    public func pt_setImageWithURL(url: NSURL, placeholder: UIImage? = nil, animations:(UIImage? -> Void)? = nil) {
        pt_setImageWithURL(url, placeholder: placeholder, progress: nil, completion: nil, animations: animations)
    }
    
    public func pt_setImageWithURL(url: NSURL, placeholder: UIImage? = nil,
        downloader: Downloader = sharedDownloader, cache: DownloaderCache? = sharedDownloaderCache,
        progress: DownloadProgressHandler?, completion: ((finished: Bool) -> Void)?,
        animations:(UIImage? -> Void)? = nil) {
            pt_setImageWithURL(url, placeholder: placeholder, downloader: downloader, cache: cache, progress: progress,
                decoder: {_, data in
                    let image = UIImage(data: data)
                    if let cgImage = decodeCGImage(image?.CGImage) {
                        return UIImage(CGImage: cgImage)
                    } else {
                        return image
                    }
                },
                completion: {[weak self] image in
                    guard let this = self else { return }
                    this.image = image
                    completion?(finished: image != nil)
                },
                animations: animations)
    }
    
    public func pt_setImageWithURL<T>(url: NSURL, placeholder: UIImage? = nil,
        decoder: (url: NSURL, data: NSData) -> T?, completion: T? -> Void,
        animations:(T? -> Void)? = nil) {
            pt_setImageWithURL(url, placeholder: placeholder, progress: nil, decoder: decoder, completion: completion)
    }
    
    public func pt_setImageWithURL<T>(url: NSURL, placeholder: UIImage? = nil,
        downloader: Downloader = sharedDownloader, cache: DownloaderCache? = sharedDownloaderCache,
        progress: DownloadProgressHandler?,
        decoder: (url: NSURL, data: NSData) -> T?, completion: T? -> Void,
        animations:(T? -> Void)? = nil) {
            
            if cache != nil, let decoded = (sharedDecodedCache.objectForKey(url) as? Wrapper)?.value as? T {
                pt_connector.cancelCurrentTask()
                progress?(PTInvalidProgressInfo)
                completion(decoded)
                animations?(decoded)
            } else {
                pt_connector.connect(url, downloader: downloader ?? sharedDownloader, cache: cache,
                    progress: {[weak self] c, tr, te in
                        guard let progress = progress, _ = self else { return }
                        progress(currentSize: c, totalRecievedSize: tr, totalExpectedSize: te)
                    },
                    decoder: decoder,
                    completion:{[weak self] decoded in
                        if let decoded = decoded {
                            sharedDecodedCache.setObject(Wrapper(decoded), forKey: url)
                        }
                        guard let this = self else { return }
                        if decoded == nil {
                            this.image = nil
                        }
                        completion(decoded)
                        animations?(decoded)
                    })
                image = placeholder
            }
    }
    
}

private let sharedDecodedCache = NSCache()

// MARK: decoded cache
final private class Wrapper {
    private let value: Any
    init(_ value: Any) { self.value = value }
}
