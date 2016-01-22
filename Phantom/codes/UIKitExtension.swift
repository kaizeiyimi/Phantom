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
    public func pt_setImageWithURL(url: NSURL, placeholder: UIImage? = nil, animations:((UIImageView, UIImage?) -> Void)? = nil) {
        pt_setImageWithURL(url, placeholder: placeholder, progress: nil, completion: nil, animations: animations)
    }
    
    public func pt_setImageWithURL(url: NSURL, placeholder: UIImage? = nil,
        downloader: Downloader = sharedDownloader, cache: Cache? = sharedCache,
        progress: DownloadProgressHandler?, completion: ((finished: Bool) -> Void)?,
        animations:((UIImageView, UIImage?) -> Void)? = nil) {
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
        animations:((imageView: UIImageView, decoded: T?) -> Void)? = nil) {
            pt_setImageWithURL(url, placeholder: placeholder, progress: nil, decoder: decoder, completion: completion)
    }
    
    public func pt_setImageWithURL<T>(url: NSURL, placeholder: UIImage? = nil,
        downloader: Downloader = sharedDownloader, cache: Cache? = sharedCache,
        progress: DownloadProgressHandler?,
        decoder: (url: NSURL, data: NSData) -> T?, completion: T? -> Void,
        animations:((imageView: UIImageView, decoded: T?) -> Void)? = nil) {
            pt_connector.connect(url, downloader: downloader ?? sharedDownloader, cache: cache,
                progress: {[weak self] c, tr, te in
                    guard let progress = progress, _ = self else { return }
                    progress(currentSize: c, totalRecievedSize: tr, totalExpectedSize: te)
                },
                decoder: decoder,
                completion:{[weak self] decoded in
                    guard let this = self else { return }
                    if decoded == nil {
                        this.image = nil
                    }
                    completion(decoded)
                    animations?(imageView: this, decoded: decoded)
                })
            
            image = placeholder
    }
    
}
