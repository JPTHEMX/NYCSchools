//
//  AddressTableViewCell.swift
//  NYCSchools
//
//  Created by Juan Pablo Granados Garcia on 8/9/22.
//

import UIKit

class AddressTableViewCell: BaseTableViewCell {
    
    // MARK: - IBOutlet Variables List -
    @IBOutlet private weak var addressLabel: UILabel!
    @IBOutlet private weak var phoneLabel: UILabel!
    @IBOutlet private weak var emailLabel: UILabel!
    @IBOutlet private weak var websiteLabel: UILabel!
    @IBOutlet private weak var timingLabel: UILabel!
    /// item
    var item: Address?
    
    /// Configure the cell depending on the item
    /// - Parameter item: Address
    func configureCell(item: Address) {
        self.item = item
        self.addressLabel.text = "Address: \(item.address ?? "N/A")"
        self.phoneLabel.text = "Phone: \(item.phone ?? "N/A")"
        self.emailLabel.text = "Email: \(item.email ?? "N/A")"
        self.websiteLabel.text = "Website: \(item.website ?? "N/A")"
        self.timingLabel.text = "Hours: \(item.time ?? "N/A")"
    }
    
}
