//
//  SATScore.swift
//  NYCSchools
//
//  Created by Juan Pablo Granados Garcia on 8/9/22.
//

import UIKit

// MARK: - SAT Score
struct SATScore: Codable {
    let dbn: String?
    let schoolName: String?
    let numberSATTestTakers: String?
    let mathScore: String?
    let readingScore: String?
    let writingScore: String?
    
    enum CodingKeys: String, CodingKey {
        case dbn = "dbn"
        case schoolName = "school_name"
        case numberSATTestTakers = "num_of_sat_test_takers"
        case mathScore = "sat_math_avg_score"
        case readingScore = "sat_critical_reading_avg_score"
        case writingScore = "sat_writing_avg_score"
    }
}
