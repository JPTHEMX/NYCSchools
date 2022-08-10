//
//  UITableViewCell.swift
//  NYCSchools
//
//  Created by Juan Pablo Granados Garcia on 8/9/22.
//

import UIKit

/// Views confirming this protocol will provide the reuseIdentifier and Nib instance to register the cell to UITableView or UICollectionView
protocol CellRegistrationProtocol {
    /// Reuse Identifier getter variable.
    static var reuseIdentifier: String { get }
    /// CellNib getter variable.
    static var nib: UINib? { get }
}

extension UITableViewCell: CellRegistrationProtocol {
    static var reuseIdentifier: String {
        String(describing: self)
    }
}
