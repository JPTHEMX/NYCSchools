//
//  School.swift
//  NYCSchools
//
//  Created by Juan Pablo Granados Garcia on 8/9/22.
//

import UIKit

// MARK: - School
struct School: Codable {
    let dbn: String?
    let schoolName: String?
    let overView: String?
    let eligibility: String?
    let primaryAddressLine: String?
    let city: String?
    let zip: String?
    let state: String?
    let phoneNumber: String?
    let email: String?
    let website: String?
    let startTime: String?
    let endTime: String?
    
    enum CodingKeys: String, CodingKey {
        case dbn = "dbn"
        case schoolName = "school_name"
        case overView = "overview_paragraph"
        case eligibility = "eligibility1"
        case primaryAddressLine = "primary_address_line_1"
        case city = "city"
        case zip = "zip"
        case state = "state_code"
        case phoneNumber = "phone_number"
        case email = "school_email"
        case website = "website"
        case startTime = "start_time"
        case endTime = "end_time"
    }
}
