//
//  SatTableViewCell.swift
//  NYCSchools
//
//  Created by Juan Pablo Granados Garcia on 8/9/22.
//

import UIKit

class SatTableViewCell: BaseTableViewCell {
    
    // MARK: - IBOutlet Variables List -
    @IBOutlet private weak var numberTestTakersLabel: UILabel!
    @IBOutlet private weak var mathScoreLabel: UILabel!
    @IBOutlet private weak var readingScoreLabel: UILabel!
    @IBOutlet private weak var writingScoreLabel: UILabel!
    /// item
    var item: SAT?
    
    /// Configure the cell depending on the item
    /// - Parameter item: SAT
    func configureCell(item: SAT) {
        self.item = item
        self.numberTestTakersLabel.text = item.numberTestTakers
        self.mathScoreLabel.text = item.mathScore
        self.readingScoreLabel.text = item.readingScore
        self.writingScoreLabel.text = item.writingScore
    }
    
}
