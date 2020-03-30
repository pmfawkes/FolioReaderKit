//
//  FolioReaderTransitionDelegate.swift
//  FolioReaderKit
//
//  Created by Shawn Miller on 3/26/20.
//  Copyright © 2020 FolioReader. All rights reserved.
//

import Foundation
import UIKit

public class FolioReaderTransitionDelegate: NSObject, UIViewControllerTransitioningDelegate {
    public func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return FolioReaderAnimator()
    }
    
    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return nil
    }
}
