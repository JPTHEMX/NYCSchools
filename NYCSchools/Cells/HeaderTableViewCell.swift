//
//  DetailHeaderTableViewCell.swift
//  NYCSchools
//
//  Created by Juan Pablo Granados Garcia on 8/9/22.
//

import UIKit

class HeaderTableViewCell: BaseTableViewCell {
    
    // MARK: - IBOutlet Variables List -
    @IBOutlet private weak var schoolNameLabel: UILabel!
    @IBOutlet private weak var overViewLabel: UILabel!
    /// item
    var item: OverView?
    
    /// Configure the cell depending on the item
    /// - Parameter item: OverView
    func configureCell(item: OverView) {
        self.item = item
        self.schoolNameLabel.text = item.schoolName
        self.overViewLabel.text = item.overView
    }
    
}
