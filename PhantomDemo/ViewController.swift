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
    
//    let url = NSURL(string: "http://pic.wenwen.soso.com/p/20111012/20111012200145-550924489.jpg")!
    
    let url = NSURL(string: "https://devimages.apple.com.edgekey.net/home/images/ecosystem-thumb_2x.jpg")!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        let url = NSBundle.mainBundle().URLForResource("zuoluo", withExtension: "jpg")!
        Phantom.sharedDownloader.download(url) { result -> Void in
            if case .Success(let data) = result {
                let image = UIImage(data: data)
                dispatch_async(dispatch_get_main_queue()) { () -> Void in
                    self.imageView.image = image
                }
            }
        }
    }

}

