//
//  Utils.swift
//  Phantom
//
//  Created by kaizei on 16/1/21.
//  Copyright © 2016年 kaizei. All rights reserved.
//

import UIKit


func canncelledError(url: NSURL) -> NSError {
    return NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled, userInfo: [
        NSURLErrorFailingURLErrorKey: url,
        NSURLErrorFailingURLStringErrorKey: url.absoluteString,
        NSLocalizedDescriptionKey: "cancelled"
        ])
}

func decode<P>(result: Result<NSData>, decoder: (NSURL, NSData) -> DecodeResult<P>) -> Result<P> {
    switch result {
    case .Success(let url, let data):
        switch decoder(url, data) {
        case .Success(let d):
            return .Success(url: url, data: d)
        case .Failed(let error):
            return .Failed(url: url, error: error)
        }
    case .Failed(let url, let error):
        return .Failed(url: url, error: error)
    }
}

func execute(queue: dispatch_queue_t?, action: () -> Void) {
    if let queue = queue {
        dispatch_async(queue, action)
    } else {
        action()
    }
}

func wrapDecoder<T>(decoder: (NSURL, NSData) -> DecodeResult<T>)(url: NSURL, data: NSData) -> DecodeResult<Any> {
    switch decoder(url, data) {
    case .Success(let result): return .Success(data: result as Any)
    case .Failed(let error): return .Failed(error: error)
    }
}

func wrapCompletion<T>(completion: Result<T> -> Void)(decoded: Result<Any>) -> Void {
    switch decoded {
    case .Success(let url, let result): completion(.Success(url: url, data: result as! T))
    case .Failed(let url, let error): completion(.Failed(url: url, error: error))
    }
}


/// stolen from SDWebImage's decoder. just change OC to swift.
public func decodeCGImage(image: CGImage?) -> CGImage? {
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


// MARK: helper animation methods. PTxxx animations will not be excuted if decoded is nil.
private func simpleTransitionAnimation(view: UIView, duration: NSTimeInterval, options: UIViewAnimationOptions) {
    UIView.transitionWithView(view, duration: duration, options: options, animations: {}, completion: nil)
}

public func PTFadeIn<T>(view: UIView, duration: NSTimeInterval)(_ decoded: Result<T>) {
    if case .Success(_, _) = decoded {
        simpleTransitionAnimation(view, duration: duration, options: .TransitionCrossDissolve)
    }
}

public func PTFlipFromLeft<T>(view: UIView, duration: NSTimeInterval)(_ decoded: Result<T>) {
    if case .Success(_, _) = decoded {
        simpleTransitionAnimation(view, duration: duration, options: .TransitionFlipFromLeft)
    }
}

public func PTFlipFromRight<T>(view: UIView, duration: NSTimeInterval)(_ decoded: Result<T>) {
    if case .Success(_, _) = decoded {
        simpleTransitionAnimation(view, duration: duration, options: .TransitionFlipFromRight)
    }
}

public func PTFlipFromBottom<T>(view: UIView, duration: NSTimeInterval)(_ decoded: Result<T>) {
    if case .Success(_, _) = decoded {
        simpleTransitionAnimation(view, duration: duration, options: .TransitionFlipFromBottom)
    }
}

public func PTFlipFromTop<T>(view: UIView, duration: NSTimeInterval)(_ decoded: Result<T>) {
    if case .Success(_, _) = decoded {
        simpleTransitionAnimation(view, duration: duration, options: .TransitionFlipFromTop)
    }
}

public func PTCurlUp<T>(view: UIView, duration: NSTimeInterval)(_ decoded: Result<T>) {
    if case .Success(_, _) = decoded {
        simpleTransitionAnimation(view, duration: duration, options: .TransitionCurlUp)
    }
}

public func PTCurlDown<T>(view: UIView, duration: NSTimeInterval)(_ decoded: Result<T>) {
    if case .Success(_, _) = decoded {
        simpleTransitionAnimation(view, duration: duration, options: .TransitionCurlDown)
    }
}


// MARK: helper progress view method

/// indicator will be removed when download finished.
public func PTAttachProgressHintView<T: UIView>(toView: UIView,
    attachImmediately: Bool = true, removeImmediately: Bool = true,
    attach: (toView: UIView) -> T,
    update: ((indicator: T, progressInfo: ProgressInfo) -> Void)?)
    -> (ProgressInfo -> Void) {
        weak var indicator: T?
        if attachImmediately {
            indicator = attach(toView: toView)
        }
        func progress(currentSize: Int64, totalRecievedSize: Int64, totalExpectedSize: Int64) -> Void {
            if totalRecievedSize < totalExpectedSize && indicator == nil {
                indicator = attach(toView: toView)
            }
            if let update = update, indicator = indicator {
                update(indicator: indicator, progressInfo: (currentSize, totalRecievedSize, totalExpectedSize))
            }
            if totalRecievedSize >= totalExpectedSize, let indicator = indicator {
                if removeImmediately {
                    indicator.removeFromSuperview()
                } else {
                    dispatch_async(dispatch_get_main_queue()) {
                        indicator.removeFromSuperview()
                    }
                }
            }
        }
        
        return progress
}

/// indicator will be removed when download finished.
public func PTAttachDefaultIndicator(style:UIActivityIndicatorViewStyle = .Gray, toView: UIView, attachImmediately: Bool = true) -> (ProgressInfo -> Void) {
    return PTAttachProgressHintView(toView, attachImmediately: attachImmediately,
        attach: {
        let indicator = UIActivityIndicatorView()
        indicator.activityIndicatorViewStyle = .Gray
        indicator.hidesWhenStopped = true
        indicator.startAnimating()
        indicator.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
        indicator.center = CGPointMake($0.bounds.midX, $0.bounds.midY)
        $0.addSubview(indicator)
        return indicator
        }, update: nil)
    
}

/// progress will be removed when download finished.
public func PTAttachDefaultProgress(toView toView: UIView, attachImmediately: Bool = true) -> (ProgressInfo -> Void) {
    return PTAttachProgressHintView(toView, attachImmediately: attachImmediately,
        attach: { toView -> UIProgressView in
            let progress = UIProgressView(progressViewStyle: .Default)
            progress.frame = CGRectMake(toView.layer.borderWidth + 5,
                toView.bounds.height * 0.618 - progress.frame.height / 2,
                toView.bounds.width - 10 - 2 * toView.layer.borderWidth,
                progress.frame.height)
            progress.autoresizingMask = .FlexibleWidth
            toView.addSubview(progress)
            return progress
        },
        update: {
            $0.setProgress(Float($1.totalRecievedSize) / Float($1.totalExpectedSize), animated: false)
    })
}
