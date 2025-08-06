import UIKit

class TabCell: UICollectionViewCell {
    static let reuseIdentifier = "TabCell"

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        label.adjustsFontForContentSizeCategory = true
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override var isSelected: Bool {
        didSet {
            titleLabel.textColor = isSelected ? .systemBlue : .label
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        contentView.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
    }

    func configure(with title: String) {
        titleLabel.text = title
    }
}


import UIKit

protocol TabBarHeaderViewDelegate: AnyObject {
    func tabBarHeaderView(didSelectTabAt index: Int)
    func tabBarHeaderViewRequiresLayoutUpdate()
}

class TabBarHeaderView: UITableViewHeaderFooterView {
    
    enum TabSection {
        case main
    }

    static let reuseIdentifier = "TabBarHeaderView"

    weak var delegate: TabBarHeaderViewDelegate?
    private var selectedTabIndex: Int = 0

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        layout.sectionInset = .zero
        
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .systemBackground
        cv.showsHorizontalScrollIndicator = false
        cv.delegate = self
        cv.register(TabCell.self, forCellWithReuseIdentifier: TabCell.reuseIdentifier)
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.clipsToBounds = false
        return cv
    }()
    
    private var dataSource: UICollectionViewDiffableDataSource<TabSection, TabItem>!

    private let indicatorView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBlue
        return view
    }()
    
    private let bottomBorderView: UIView = {
        let view = UIView()
        view.backgroundColor = .separator
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        setupViews()
        configureDataSource()
        NotificationCenter.default.addObserver(self, selector: #selector(contentSizeCategoryDidChange), name: UIContentSizeCategory.didChangeNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        self.clipsToBounds = false
        contentView.clipsToBounds = false
        contentView.backgroundColor = .systemBackground
        
        contentView.addSubview(collectionView)
        contentView.addSubview(bottomBorderView)
        contentView.addSubview(indicatorView)

        let initialHeight = calculateCollectionViewHeight()
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: contentView.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            collectionView.heightAnchor.constraint(equalToConstant: initialHeight),

            bottomBorderView.topAnchor.constraint(equalTo: collectionView.bottomAnchor),
            bottomBorderView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            bottomBorderView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            bottomBorderView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            bottomBorderView.heightAnchor.constraint(equalToConstant: 0.5),
        ])
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateIndicatorPosition(animated: false)
    }
    
    func configure(with tabs: [TabItem], selectedIndex: Int) {
        self.selectedTabIndex = selectedIndex
        
        var snapshot = NSDiffableDataSourceSnapshot<TabSection, TabItem>()
        snapshot.appendSections([.main])
        snapshot.appendItems(tabs, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: false)
        
        DispatchQueue.main.async {
            let indexPath = IndexPath(item: selectedIndex, section: 0)
            self.collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
            self.scrollToMakeTabVisible(at: indexPath, animated: false)
            self.updateIndicatorPosition(animated: false)
        }
    }
    
    private func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<TabSection, TabItem>(collectionView: collectionView) {
            (collectionView, indexPath, tabItem) -> UICollectionViewCell? in
            
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TabCell.reuseIdentifier, for: indexPath) as? TabCell else {
                fatalError("Cannot create new TabCell")
            }
            cell.configure(with: tabItem.title)
            return cell
        }
    }
    
    private func calculateCollectionViewHeight() -> CGFloat {
        let font = UIFont.preferredFont(forTextStyle: .headline)
        let verticalPadding: CGFloat = 24.0
        return font.lineHeight + verticalPadding
    }
    
    @objc private func contentSizeCategoryDidChange() {
        delegate?.tabBarHeaderViewRequiresLayoutUpdate()
    }
    
    private func updateIndicatorPosition(animated: Bool) {
        guard let attributes = collectionView.layoutAttributesForItem(at: IndexPath(item: selectedTabIndex, section: 0)) else {
            indicatorView.frame = .zero
            return
        }

        var labelFrame: CGRect
        if let cell = collectionView.cellForItem(at: IndexPath(item: selectedTabIndex, section: 0)) as? TabCell {
            labelFrame = cell.titleLabel.frame
        } else {
            labelFrame = attributes.bounds.insetBy(dx: 16, dy: 12)
        }
        
        let indicatorWidth = labelFrame.width + 16
        let indicatorHeight: CGFloat = 3.0
        let indicatorX = attributes.frame.origin.x + labelFrame.origin.x - 8
        let indicatorY = attributes.frame.maxY - indicatorHeight
        
        let indicatorFrameInCollectionView = CGRect(x: indicatorX, y: indicatorY, width: indicatorWidth, height: indicatorHeight)
        let finalIndicatorFrame = collectionView.convert(indicatorFrameInCollectionView, to: contentView)

        let animation = {
            self.indicatorView.frame = finalIndicatorFrame
        }
        
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.1, options: .curveEaseInOut, animations: animation)
        } else {
            animation()
        }
    }

    private func scrollToMakeTabVisible(at indexPath: IndexPath, animated: Bool) {
        guard let cellAttributes = collectionView.layoutAttributesForItem(at: indexPath) else {
            return
        }

        let cellFrame = cellAttributes.frame
        let collectionViewBounds = collectionView.bounds

        var scrollPosition: UICollectionView.ScrollPosition = []

        if cellFrame.maxX > collectionViewBounds.maxX {
            scrollPosition = .right
        } else if cellFrame.minX < collectionViewBounds.minX {
            scrollPosition = .left
        }

        if !scrollPosition.isEmpty {
            collectionView.scrollToItem(at: indexPath, at: scrollPosition, animated: animated)
        }
    }
}

extension TabBarHeaderView: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedTabIndex = indexPath.item
        
        delegate?.tabBarHeaderView(didSelectTabAt: indexPath.item)
        
        scrollToMakeTabVisible(at: indexPath, animated: true)
        
        updateIndicatorPosition(animated: true)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateIndicatorPosition(animated: false)
    }
}


import UIKit

enum Section: Int, CaseIterable {
    case info
    case list
}

struct ListItem: Hashable {
    let id = UUID()
    let title: String
}

struct TabItem: Hashable {
    let title: String
}

class ViewController: UIViewController {

    private var tableView: UITableView!
    private var dataSource: UITableViewDiffableDataSource<Section, ListItem>!
    
    private let tabData: [TabItem] = (0..<12).map { TabItem(title: "Categoría \($0 + 1)") }
    
    private var selectedTabIndex = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Lista Dinámica"
        navigationController?.navigationBar.prefersLargeTitles = true
        
        configureTableView()
        configureDataSource()
        applyInitialSnapshot()
    }

    private func configureTableView() {
        tableView = UITableView(frame: view.bounds, style: .plain)
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.delegate = self
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "DefaultCell")
        tableView.register(TabBarHeaderView.self, forHeaderFooterViewReuseIdentifier: TabBarHeaderView.reuseIdentifier)
        
        tableView.sectionHeaderHeight = UITableView.automaticDimension
        tableView.estimatedSectionHeaderHeight = 50
        
        view.addSubview(tableView)
    }

    private func configureDataSource() {
        dataSource = UITableViewDiffableDataSource<Section, ListItem>(tableView: tableView) {
            (tableView, indexPath, item) -> UITableViewCell? in
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "DefaultCell", for: indexPath)
            var content = cell.defaultContentConfiguration()
            content.text = item.title
            cell.contentConfiguration = content
            return cell
        }
    }

    private func applyInitialSnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, ListItem>()
        
        snapshot.appendSections([.info])
        snapshot.appendItems([ListItem(title: "Esta es la celda de información en la Sección 0.")], toSection: .info)
        
        snapshot.appendSections([.list])
        let initialItems = generateItemsForTab(index: selectedTabIndex)
        snapshot.appendItems(initialItems, toSection: .list)
        
        dataSource.apply(snapshot, animatingDifferences: false)
    }
    
    private func generateItemsForTab(index: Int) -> [ListItem] {
        let category = tabData[index].title
        return (1...100).map { ListItem(title: "Item \($0) de \(category)") }
    }
    
    private func updateListSection(forTabIndex index: Int) {
        let newItems = generateItemsForTab(index: index)
        var currentSnapshot = dataSource.snapshot()
        let oldItems = currentSnapshot.itemIdentifiers(inSection: .list)
        currentSnapshot.deleteItems(oldItems)
        currentSnapshot.appendItems(newItems, toSection: .list)
        dataSource.apply(currentSnapshot, animatingDifferences: true)
    }
}

extension ViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let sectionKind = Section(rawValue: section), sectionKind == .list else {
            return nil
        }
        
        guard let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: TabBarHeaderView.reuseIdentifier) as? TabBarHeaderView else {
            return nil
        }
        
        headerView.delegate = self
        headerView.configure(with: tabData, selectedIndex: selectedTabIndex)
        
        return headerView
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard let sectionKind = Section(rawValue: section) else { return 0 }
        
        switch sectionKind {
        case .info:
            return CGFloat.leastNormalMagnitude
        case .list:
            return UITableView.automaticDimension
        }
    }
}

extension ViewController: TabBarHeaderViewDelegate {
    
    func tabBarHeaderView(didSelectTabAt index: Int) {
        guard index != selectedTabIndex else { return }
        selectedTabIndex = index
        updateListSection(forTabIndex: index)
    }
    
    func tabBarHeaderViewRequiresLayoutUpdate() {
        tableView.beginUpdates()
        tableView.endUpdates()
    }
}
