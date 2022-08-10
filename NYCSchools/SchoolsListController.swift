//
//  SchoolsListController.swift
//  NYCSchools
//
//  Created by Juan Pablo Granados Garcia on 8/9/22.
//

import UIKit

// MARK: - SchoolsListController implementation -
class SchoolsListController: UIViewController {
    
    // MARK: - IBOutlet Variables List -
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var activityIndicatorView: UIActivityIndicatorView!
    /// Schools
    private var schools: [School] = [] {
        didSet {
            DispatchQueue.main.async { [weak self] in
                self?.tableView.reloadData()
            }
        }
    }
    /// Api service
    private lazy var apiService = {
        ApiService.shared
    }()
    /// Current selected school
    var selectedSchool: School?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupUI()
    }
    
    /// Sets up UI after view is loaded
    private func setupUI() {
        self.title = "NYC Schools"
        self.activityIndicatorView.transform = CGAffineTransform(scaleX: 3, y: 3)
        self.registerIndividualCell()
        self.getSchoolsList()
    }
    
    /// Registering all reusable cells
    private func registerIndividualCell() {
        self.tableView.register(SchoolTableViewCell.nib, forCellReuseIdentifier: SchoolTableViewCell.reuseIdentifier)
    }
    
    // Fetch schools list
    private func getSchoolsList() {
        self.activityIndicatorView.update(isAnimating: true)
        self.apiService.getHighSchools { [weak self] result in
            switch result {
            case let .success(shools):
                self?.schools = shools
            case let .failure(error):
                print("error: \(error)")
            }
            DispatchQueue.main.async { [weak self] in
                self?.activityIndicatorView.update(isAnimating: false)
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "schoolDetailViewController", let schoolDetailVC = segue.destination as? SchoolDetailViewController {
            schoolDetailVC.school = self.selectedSchool
        }
    }
    
}

// MARK: - UITableViewDataSource implementation -
extension SchoolsListController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        self.schools.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: SchoolTableViewCell.reuseIdentifier) as? SchoolTableViewCell else {
            return UITableViewCell()
        }
        let shool = self.schools[indexPath.row]
        cell.configureCell(shool: shool)
        return cell
    }
}

// MARK: - UITableViewDelegate implementation -
extension SchoolsListController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.selectedSchool = self.schools[indexPath.row]
        self.performSegue(withIdentifier: "schoolDetailViewController", sender: self)
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }
}
