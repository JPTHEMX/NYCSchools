//
//  EligibilityTableViewCell.swift
//  NYCSchools
//
//  Created by Juan Pablo Granados Garcia on 8/9/22.
//

import UIKit

class EligibilityTableViewCell: BaseTableViewCell {

    // MARK: - IBOutlet Variables List -
    @IBOutlet private weak var eligibilityLabel: UILabel!
    /// eligibility
    var eligibility: String?
    
    /// Configure the cell depending on the eligibility
    /// - Parameter item: Eligibility
    func configureCell(eligibility: String?) {
        self.eligibility = eligibility
        self.eligibilityLabel.text = eligibility ?? "N/A"
    }
    
}
