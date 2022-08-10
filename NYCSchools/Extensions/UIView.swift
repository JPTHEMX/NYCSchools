//
//  UIView.swift
//  NYCSchools
//
//  Created by Juan Pablo Granados Garcia on 8/9/22.
//

import UIKit

/// Views confirming this protocol will provide the Nib instance
protocol NibProtocol {
    static var nib: UINib? { get }
}

/// Extends UIView basic functionality to reduce duplication and reuse code.
extension UIView: NibProtocol {
    /// Creates a Nib instance using the UIView Class name as identifier
    static var nib: UINib? {
        UINib(nibName: String(describing: self), bundle: nil)
    }
}
