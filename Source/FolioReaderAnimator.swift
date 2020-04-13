//
//  FolioReaderAnimator.swift
//  FolioReaderKit
//
//  Created by Shawn Miller on 3/26/20.
//  Copyright © 2020 FolioReader. All rights reserved.
//
import Foundation
import UIKit


class FolioReaderAnimator: NSObject, UIViewControllerAnimatedTransitioning, FolioReaderCenterDelegate {
    
    let duration: TimeInterval = 1.25
    var pageDidLoadNotificationToken: NSObjectProtocol?

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return duration
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        
        let containerView = transitionContext.containerView
        
        guard let toView = transitionContext.viewController(forKey: .to)?.view else {
            transitionContext.completeTransition(false)
            return
        }
        
        containerView.addSubview(toView)
        
        toView.alpha = 0
        let duration = transitionDuration(using: transitionContext)
        
        pageDidLoadNotificationToken = NotificationCenter.default.addObserver(forName: .pageDidLoadNotification, object: nil, queue: .main, using: { [weak self] _ in
            guard let strongSelf = self else {return}
            UIView.animate(withDuration: duration, delay: 0, options: .curveEaseInOut, animations: {
                toView.alpha = 1
            }) { (complete) in
                NotificationCenter.default.removeObserver(strongSelf.pageDidLoadNotificationToken)
                transitionContext.completeTransition(true)
            }
        })
    }
    
}
