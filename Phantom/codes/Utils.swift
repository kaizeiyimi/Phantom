//
//  Utils.swift
//  Phantom
//
//  Created by kaizei on 16/1/21.
//  Copyright © 2016年 kaizei. All rights reserved.
//

import UIKit


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


// MARK: helper progress view method

/// indicator will be removed when download finished.
public func PTAttachProgressHintView<T: UIView>(toView: UIView,
    @noescape attach: (toView: UIView) -> T,
    update: ((indicator: T, progressInfo: ProgressInfo) -> Void)?)
    -> DownloadProgressHandler {
        let indicator = attach(toView: toView)
        func progress(currentSize: Int64, totalRecievedSize: Int64, totalExpectedSize: Int64) -> Void {
            if let update = update {
                update(indicator: indicator, progressInfo: (currentSize, totalRecievedSize, totalExpectedSize))
            }
            if totalRecievedSize >= totalExpectedSize {
                indicator.removeFromSuperview()
            }
        }
    
        return progress
}

/// indicator will be removed when download finished.
public func PTAttachDefaultIndicator(style:UIActivityIndicatorViewStyle = .Gray, toView: UIView) -> DownloadProgressHandler {
    return PTAttachProgressHintView(toView, attach: {
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
public func PTAttachDefaultProgress(toView toView: UIView) -> DownloadProgressHandler {
        return PTAttachProgressHintView(toView,
            attach: { toView -> UIProgressView in
                let progress = UIProgressView(progressViewStyle: .Default)
                progress.frame = CGRectMake(3, toView.bounds.maxY - progress.frame.height - 3,
                    toView.bounds.width - 6, progress.frame.height)
                progress.autoresizingMask = [.FlexibleWidth, .FlexibleTopMargin]
                toView.addSubview(progress)
                return progress
            },
            update: {
                $0.setProgress(Float($1.totalRecievedSize) / Float($1.totalExpectedSize), animated: true)
            })
}
