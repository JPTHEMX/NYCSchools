//
//  ServiceTests.swift
//  NYCSchoolsTests
//
//  Created by Juan Pablo Granados Garcia on 8/10/22.
//

import XCTest
@testable import NYCSchools

class ServiceTests: XCTestCase {
    
    let apiService = ApiService.shared
    
    func testGetHighSchools() {
        let expec = expectation(description: "\(#function)")
        self.apiService.getHighSchools { result in
            switch result {
            case let .success(shools):
                XCTAssertNotNil(shools)
            case let .failure(error):
                XCTFail(error.localizedDescription)
            }
            expec.fulfill()
        }
        waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testGetSATScores() {
        let expec = expectation(description: "\(#function)")
        self.apiService.getSATScores(dbn: "21K728") { result in
            switch result {
            case let .success(scores):
                XCTAssertNotNil(scores)
            case let .failure(error):
                XCTFail(error.localizedDescription)
            }
            expec.fulfill()
        }
        waitForExpectations(timeout: 2, handler: nil)
    }
    
}
