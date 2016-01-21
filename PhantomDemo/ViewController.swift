//
//  ViewController.swift
//  PhantomDemo
//
//  Created by kaizei on 16/1/18.
//  Copyright © 2016年 kaizei. All rights reserved.
//

import UIKit
import Phantom
import XLYAnimatedImage


class ViewController: UIViewController {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var urlSegment: UISegmentedControl!
    @IBOutlet weak var progressSegment: UISegmentedControl!
    @IBOutlet weak var animationSegment: UISegmentedControl!
    @IBOutlet weak var placeholderSwitch: UISwitch!
    
    let normalURL = NSURL(string: "http://i3.3conline.com/images/piclib/201211/21/batch/1/155069/1353489276201kiifd0ycgl_medium.jpg")!
    let GIFURL = NSURL(string: "http://bbs.byr.cn/att/Picture/0/2895510/256")!
    let localURL = NSBundle.mainBundle().URLForResource("zuoluo", withExtension: "jpg")!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        urlSegment.selectedSegmentIndex = UISegmentedControlNoSegment
    }
    
    @IBAction func changeURL(sender: UISegmentedControl) {
        let placeholder = placeholderSwitch.on ? UIImage(named: "placeholder") : nil
        let type = sender.selectedSegmentIndex
        
        imageView.xly_animatedImagePlayer = nil // remove GIF play
        
        if type == 0 || type == 2 {
            imageView.pt_setImageWithURL(type == 0 ? normalURL : localURL, placeholder: placeholder,
                progress: progressHandler(),
                completion: nil,
                animations: animationHandler())
        } else if type == 1 {
            imageView.pt_setImageWithURL(GIFURL, placeholder: placeholder,
                progress: progressHandler(),
                decoder: { _, data -> AnimatedGIFImage? in
                    return AnimatedGIFImage(data: data) // decode as AnimatedGIFImage
                },
                completion: {[weak self] image in
                    if let image = image {
                        self?.imageView.xly_setAnimatedImage(image) // playGIF
                    } else {
                        self?.imageView.image = nil
                    }
                },
                animations: animationHandler())
        }
    }
    
    private func progressHandler() -> DownloadProgressHandler? {
        switch progressSegment.selectedSegmentIndex {
        case 0: return PTAttachDefaultIndicator(toView: imageView)
        case 1: return PTAttachDefaultProgress(toView: imageView)
        default: return nil
        }
    }
    
    private func animationHandler() -> ((view: UIView, decoded: Any?) -> Void)? {
        switch animationSegment.selectedSegmentIndex {
        case 0: return PTCurlDown(0.5)
        case 1: return PTFadeIn(0.5)
        case 2: return PTFlipFromBottom(0.6)
        default: return nil
        }
    }
    
}

