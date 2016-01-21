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
        
        if type == 0 || type == 2 {
            imageView.pt_setImageWithURL(type == 0 ? normalURL : localURL, placeholder: placeholder,
                progress: progressHandler(),
                completion: nil,
                animations: animationHandler())
        } else if type == 1 {
            imageView.pt_setImageWithURL(GIFURL, placeholder: placeholder,
                progress: progressHandler(),
                decoder: { _, data in
                    return UIImage(data: data)
                },
                completion: {[weak self] image in
                    self?.imageView.image = image
                },
                animations: animationHandler())
        }
    }
    
    private func progressHandler() -> DownloadProgressHandler {
        return progressSegment.selectedSegmentIndex == 0 ? PTAttachDefaultIndicator(toView: imageView) : PTAttachDefaultProgress(toView: imageView)
    }
    
    private func animationHandler() -> (view: UIView, decoded: Any) -> Void {
        let type = animationSegment.selectedSegmentIndex
        if type == 0 {
            return PTCurlDown(0.5)
        } else if type == 1 {
            return PTFadeIn(0.5)
        } else {
            return PTFlipFromBottom(0.6)
        }
    }
    
}

