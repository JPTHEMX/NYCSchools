//
//  SchoolTableViewCell.swift
//  NYCSchools
//
//  Created by Juan Pablo Granados Garcia on 8/9/22.
//

import UIKit

class SchoolTableViewCell: BaseTableViewCell {
    
    // MARK: - IBOutlet Variables List -
    @IBOutlet private weak var schoolNameLabel: UILabel!
    /// school
    var school: School?
    
    /// Configure the cell depending on the school
    /// - Parameter item: School
    func configureCell(shool: School) {
        self.school = shool
        self.schoolNameLabel.text = shool.schoolName
    }
    
}
