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
        progress: DownloadProgressHandler?, completion: (() -> Void)?,
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
                    self?.image = image
                    completion?()
                },
                animations: animations)
    }
    
    public func pt_setImageWithURL<T>(url: NSURL, placeholder: UIImage? = nil,
        decoder: (NSURL, NSData) -> T?, completion:T? -> Void, animations:((UIImageView, T?) -> Void)? = nil) {
            pt_setImageWithURL(url, placeholder: placeholder, progress: nil, decoder: decoder, completion: completion)
    }
    
    public func pt_setImageWithURL<T>(url: NSURL, placeholder: UIImage? = nil,
        downloader: Downloader = sharedDownloader, cache: Cache? = sharedCache,
        progress: DownloadProgressHandler?,
        decoder: (NSURL, NSData) -> T?, completion:T? -> Void,
        animations:((UIImageView, T?) -> Void)? = nil) {
            pt_connector.connect(url, downloader: downloader ?? sharedDownloader, cache: cache,
                progress: {[weak self] c, tr, te in
                    guard let progress = progress, _ = self else { return }
                    progress(currentSize: c, totalRecievedSize: tr, totalExpectedSize: te)
                },
                decoder: decoder,
                completion:{[weak self] decoded in
                    guard let this = self else { return }
                    completion(decoded)
                    animations?(this, decoded)
                })
    }
    
}

/// stolen from SDWebImage's decoder. just change OC to swift.
private func decodeCGImage(image: CGImage?) -> CGImage? {
    guard let image = image else { return nil }
    var result: CGImage?
    autoreleasepool {
        let width = CGImageGetWidth(image), height = CGImageGetHeight(image)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var bitmapInfo = CGImageGetBitmapInfo(image).rawValue
        let infoMask = bitmapInfo & CGBitmapInfo.AlphaInfoMask.rawValue
        let anyNonAlpha = (infoMask == CGImageAlphaInfo.None.rawValue ||
            infoMask == CGImageAlphaInfo.NoneSkipFirst.rawValue ||
            infoMask == CGImageAlphaInfo.NoneSkipLast.rawValue)
        
        if infoMask == CGImageAlphaInfo.None.rawValue && CGColorSpaceGetNumberOfComponents(colorSpace) > 1 {
            bitmapInfo &= ~CGBitmapInfo.AlphaInfoMask.rawValue
            bitmapInfo |= CGImageAlphaInfo.NoneSkipFirst.rawValue
        } else if !anyNonAlpha && CGColorSpaceGetNumberOfComponents(colorSpace) == 3 {
            bitmapInfo &= ~CGBitmapInfo.AlphaInfoMask.rawValue
            bitmapInfo |= CGImageAlphaInfo.PremultipliedFirst.rawValue
        }
        
        let context = CGBitmapContextCreate(nil, CGImageGetWidth(image), CGImageGetHeight(image), CGImageGetBitsPerComponent(image), 0, colorSpace, bitmapInfo)
        
        CGContextDrawImage(context, CGRect(x: 0, y: 0, width: width, height: height), image)
        result = CGBitmapContextCreateImage(context)
    }
    return result
}


// MARK: helper animation methods
private func simpleTransitionAnimation(view: UIView, duration: NSTimeInterval, options: UIViewAnimationOptions) {
    UIView.transitionWithView(view, duration: duration, options: options, animations: {}, completion: nil)
}

public func PTFadeIn(duration: NSTimeInterval)(view: UIView, decoded: Any) {
    simpleTransitionAnimation(view, duration: duration, options: .TransitionCrossDissolve)
}

public func PTFlipFromLeft(duration: NSTimeInterval)(view: UIView, decoded: Any) {
    simpleTransitionAnimation(view, duration: duration, options: .TransitionFlipFromLeft)
}

public func PTFlipFromRight(duration: NSTimeInterval)(view: UIView, decoded: Any) {
    simpleTransitionAnimation(view, duration: duration, options: .TransitionFlipFromRight)
}

public func PTFlipFromBottom(duration: NSTimeInterval)(view: UIView, decoded: Any) {
    simpleTransitionAnimation(view, duration: duration, options: .TransitionFlipFromBottom)
}

public func PTFlipFromTop(duration: NSTimeInterval)(view: UIView, decoded: Any) {
    simpleTransitionAnimation(view, duration: duration, options: .TransitionFlipFromTop)
}

public func PTCurlUp(duration: NSTimeInterval)(view: UIView, decoded: Any) {
    simpleTransitionAnimation(view, duration: duration, options: .TransitionCurlUp)
}

public func PTCurlDown(duration: NSTimeInterval)(view: UIView, decoded: Any) {
    simpleTransitionAnimation(view, duration: duration, options: .TransitionCurlDown)
}
