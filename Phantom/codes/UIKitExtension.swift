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
    public func pt_setImageWithURL(url: NSURL, placeholder: UIImage? = nil, animations:(Result<UIImage> -> Void)? = nil) {
        pt_setImageWithURL(url, placeholder: placeholder, progress: nil, completion: nil, animations: animations)
    }
    
    public func pt_setImageWithURL(url: NSURL, placeholder: UIImage? = nil,
        downloader: Downloader = sharedDownloader, cache: DownloaderCache? = sharedDownloaderCache,
        progress: (ProgressInfo -> Void)?, completion: ((finished: Bool) -> Void)?,
        animations:(Result<UIImage> -> Void)? = nil) {
            pt_setImageWithURL(url, placeholder: placeholder, downloader: downloader, cache: cache, progress: progress,
                decoder: { _, data in
                    guard var image = UIImage(data: data) else {
                        return .Failed(error: nil)
                    }
                    if let cgImage = decodeCGImage(image.CGImage) {
                        image = UIImage(CGImage: cgImage)
                    }
                    return .Success(data: image)
                },
                completion: {[weak self] result in
                    guard let this = self else { return }
                    if case .Success(_, let image) = result {
                        this.image = image
                        completion?(finished: true)
                    } else {
                        completion?(finished: false)
                    }
                },
                animations: animations)
    }
    
    public func pt_setImageWithURL<T>(url: NSURL, placeholder: UIImage? = nil,
        decoder: (NSURL, NSData) -> DecodeResult<T>, completion: Result<T> -> Void,
        animations:(Result<T> -> Void)? = nil) {
            pt_setImageWithURL(url, placeholder: placeholder, progress: nil, decoder: decoder, completion: completion)
    }
    
    public func pt_setImageWithURL<T>(url: NSURL, placeholder: UIImage? = nil,
        downloader: Downloader = sharedDownloader, cache: DownloaderCache? = sharedDownloaderCache,
        progress: (ProgressInfo -> Void)?,
        decoder: (NSURL, NSData) -> DecodeResult<T>, completion: Result<T> -> Void,
        animations:(Result<T> -> Void)? = nil) {
            
            if cache != nil, let decoded = (sharedDecodedCache.objectForKey(url) as? Wrapper)?.value as? T {
                pt_connector.cancelCurrentTask()
                progress?(PTInvalidProgressInfo)
                completion(.Success(url: url, data: decoded))
                animations?(.Success(url: url, data: decoded))
            } else {
                pt_connector.connect(url, downloader: downloader ?? sharedDownloader, cache: cache,
                    progress: {[weak self] c, tr, te in
                        guard let progress = progress, _ = self else { return }
                        progress(currentSize: c, totalRecievedSize: tr, totalExpectedSize: te)
                    },
                    decoder: decoder,
                    completion:{[weak self] result in
                        switch result {
                        case .Success(let url, let decoded):
                            sharedDecodedCache.setObject(Wrapper(decoded), forKey: url)
                        case .Failed(_, _):
                            self?.image = nil
                        }
                        
                        guard let _ = self else { return }
                        completion(result)
                        animations?(result)
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


extension UIImageView {
    
    private static var kConnectorKey = "kaizei.yimi.phantom.connectorKey"
    
    /// will create one if needed.
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
