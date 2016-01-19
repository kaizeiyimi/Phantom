//
//  UIKitExtension.swift
//  Phantom
//
//  Created by kaizei on 16/1/19.
//  Copyright © 2016年 kaizei. All rights reserved.
//

import UIKit


extension UIImageView {
    
    private static var kConnectorKey = "kaizei.yimi.phantom.connectorKey"
    private static var kCurrentURLKey = "kaizei.yimi.phantom.currentURLKey"
    
    public var pt_connector: Connector {
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
    
    public var pt_currentDownloadingURL: NSURL? {
        get { return objc_getAssociatedObject(self, &UIImageView.kCurrentURLKey) as? NSURL }
        set { objc_setAssociatedObject(self, &UIImageView.kCurrentURLKey, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC) }
    }
    
}
