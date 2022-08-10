//
//  UIActivityIndicatorView.swift
//  NYCSchools
//
//  Created by Juan Pablo Granados Garcia on 8/9/22.
//

import UIKit

extension UIActivityIndicatorView {
    /// Update animation state flag
    /// - Parameter isAnimating: state flag animation
    func update(isAnimating: Bool) {
        if isAnimating {
            self.isHidden = false
            self.startAnimating()
        } else {
            self.stopAnimating()
            self.isHidden = true
        }
    }
    
}
