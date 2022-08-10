//
//  SchoolDetailViewController.swift
//  NYCSchools
//
//  Created by Juan Pablo Granados Garcia on 8/9/22.
//

import UIKit

typealias OverView = (schoolName: String?, overView: String?)
typealias SAT = (numberTestTakers: String?, mathScore: String?, readingScore: String?, writingScore: String?)
typealias Address = (address: String?, phone: String?, email: String?, website: String?, time: String?)

enum Item {
    case overView(OverView)
    case sat(SAT)
    case eligibility(String?)
    case address(Address)
}

class SchoolDetailViewController: UIViewController {
    
    // MARK: - IBOutlet Variables List -
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var activityIndicatorView: UIActivityIndicatorView!
    /// Api service
    private lazy var apiService = {
        ApiService.shared
    }()
    /// School
    var school: School?
    /// Score
    private var score: SATScore? {
        didSet {
            self.bindingRows()
        }
    }
    /// Items
    var items: [Item] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupUI()
    }
    
    /// Sets up UI after view is loaded
    private func setupUI() {
        self.activityIndicatorView.transform = CGAffineTransform(scaleX: 3, y: 3)
        self.registerIndividualCell()
        self.getSchoolDetail(dbn: self.school?.dbn)
    }
    
    /// Registering all reusable cells
    private func registerIndividualCell() {
        self.tableView.register(HeaderTableViewCell.nib, forCellReuseIdentifier: HeaderTableViewCell.reuseIdentifier)
        self.tableView.register(SatTableViewCell.nib, forCellReuseIdentifier: SatTableViewCell.reuseIdentifier)
        self.tableView.register(EligibilityTableViewCell.nib, forCellReuseIdentifier: EligibilityTableViewCell.reuseIdentifier)
        self.tableView.register(AddressTableViewCell.nib, forCellReuseIdentifier: AddressTableViewCell.reuseIdentifier)
    }
    
    /// Binding sections
    private func bindingRows() {
        guard let school = self.school else {
            print("school is nil")
            return
        }
        self.items.removeAll()
        self.items.append(.overView((school.schoolName, school.overView)))
        if let score = self.score {
            self.items.append(.sat((score.numberTestTakers, score.mathScore, score.readingScore, score.writingScore)))
        }
        if let eligibility = school.eligibility {
            self.items.append(.eligibility(eligibility))
        }
        let address = [school.primaryAddressLine, school.city, school.state, school.zip].compactMap { $0 }.joined(separator: ", ")
        let time = [school.startTime, school.endTime].compactMap { $0 }.joined(separator: " to ")
        if !address.isEmpty || !time.isEmpty || school.phoneNumber != nil || school.email != nil || school.website != nil {
            self.items.append(.address((address, school.phoneNumber, school.email, school.website, time.isEmpty ? nil : time)))
        }
        DispatchQueue.main.async { [weak self] in
            self?.tableView.reloadData()
        }
    }
    
    // Get school SAT details
    private func getSchoolDetail(dbn: String?) {
        guard let dbn = dbn else {
            print("dbn is nil")
            return
        }
        self.activityIndicatorView.update(isAnimating: true)
        self.apiService.getSATScores(dbn: dbn) { [weak self] result in
            switch result {
            case let .success(scores):
                self?.score = scores.first
            case let .failure(error):
                print("error: \(error)")
            }
            DispatchQueue.main.async { [weak self] in
                self?.activityIndicatorView.update(isAnimating: false)
            }
        }
    }
}

// MARK: - UITableViewDataSource implementation -
extension SchoolDetailViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = self.items[indexPath.row]
        switch item {
        case let .overView(item):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: HeaderTableViewCell.reuseIdentifier) as? HeaderTableViewCell else {
                return UITableViewCell()
            }
            cell.configureCell(item: item)
            return cell
        case let .sat(item):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: SatTableViewCell.reuseIdentifier) as? SatTableViewCell else {
                return UITableViewCell()
            }
            cell.configureCell(item: item)
            return cell
        case let .eligibility(eligibility):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: EligibilityTableViewCell.reuseIdentifier) as? EligibilityTableViewCell else {
                return UITableViewCell()
            }
            cell.configureCell(eligibility: eligibility)
            return cell
        case let .address(item):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: AddressTableViewCell.reuseIdentifier) as? AddressTableViewCell else {
                return UITableViewCell()
            }
            cell.configureCell(item: item)
            return cell
        }
    }
}

// MARK: - UITableViewDelegate implementation -
extension SchoolDetailViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }
}
