//
//  ViewController.swift
//  PhantomDemo
//
//  Created by kaizei on 16/1/18.
//  Copyright © 2016年 kaizei. All rights reserved.
//

import UIKit
import Phantom


class ViewController: UIViewController {

    @IBOutlet weak var imageView: UIImageView!
    
    let url0 = NSURL(string: "http://pic.wenwen.soso.com/p/20111012/20111012200145-550924489.jpg")!
    let url1 = NSURL(string: "https://devimages.apple.com.edgekey.net/home/images/ecosystem-thumb_2x.jpg")!
    let url2 = NSBundle.mainBundle().URLForResource("zuoluo", withExtension: "jpg")!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        
//        Phantom.sharedDownloader.download(url0, progress: nil) { result -> Void in
//            if case .Success(let _, let data) = result {
//                let image = UIImage(data: data)
//                dispatch_async(dispatch_get_main_queue()) { () -> Void in
//                    self.imageView.image = image
//                }
//            }
//        }
        
//        Phantom.sharedDownloader = DefaultDownloader()
//
        
        imageView.pt_setImageWithURL(url1, placeholder: nil,
            progress: PTAttachDefaultIndicator(toView: imageView),
            decoder: { _, data in
            return UIImage(data: data)
            },
            completion: { image in
                self.imageView.image = image
            },
            animations: PTCurlDown(0.8))
        
//        
//        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(Double(NSEC_PER_SEC) * 2)), dispatch_get_main_queue()) {
//            self.imageView.pt_setImageWithURL(self.url0,
//                animations: PTCurlDown(1))
//        }
        
//
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(Double(NSEC_PER_SEC) * 2)), dispatch_get_main_queue()) {
            self.imageView.pt_setImageWithURL(self.url0,
                progress: PTAttachDefaultProgress(toView: self.imageView),
                completion: nil,
                animations: PTFlipFromBottom(2))
//            self.imageView.removeFromSuperview()
//            self.imageView.pt_connector.cancelCurrentTask()
        }
        
//        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(Double(NSEC_PER_SEC) * 0)), dispatch_get_main_queue()) {
//            self.imageView.pt_connector.connect(self.url0, decoder: { _, data in
//                return UIImage(data: data)
//                }) {[weak self] image in
//                    self?.imageView.image = image
//            }
//        }
        
//        imageView.pt_connector.connect(url1, decoder: { _, data in
//            return UIImage(data: data)
//            }) {[weak self] image in
//                self?.imageView.image = image
//        }
        
    }

}

