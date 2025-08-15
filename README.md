import UIKit

enum Section: Int, CaseIterable {
    case info
    case list
}

struct ListItem: Hashable {
    let id: UUID
    let title: String
    init(title: String) {
        self.id = UUID()
        self.title = title
    }
    init(id: UUID, title: String) {
        self.id = id
        self.title = title
    }
    static func == (lhs: ListItem, rhs: ListItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct TabItem: Hashable {
    let title: String
}

protocol TabCellConfigurable: UICollectionViewCell {
    associatedtype Item: Hashable
    func configure(with item: Item)
    var a11yTitle: String? { get }
    static var reuseIdentifier: String { get }
}

class TabCell: UICollectionViewCell, TabCellConfigurable {
    static let reuseIdentifier = "TabCell"
    typealias Item = TabItem
    var a11yTitle: String? { return titleLabel.text }
    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        label.adjustsFontForContentSizeCategory = true
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    override var isSelected: Bool { didSet { titleLabel.textColor = isSelected ? .systemBlue : .label } }
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private func setupViews() {
        contentView.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
    }
    func configure(with item: TabItem) {
        titleLabel.text = item.title
    }
}

@MainActor
protocol TabBarViewDelegate: AnyObject {
    func tabBarView(didSelectTabAt index: Int)
    func tabBarViewRequiresLayoutUpdate()
}

private enum TabBarViewConstants {
    static let verticalPadding: CGFloat = 8.0
    static let indicatorHeight: CGFloat = 5.0
    static let indicatorBottomOffset: CGFloat = 3.0
    static let bottomBorderHeight: CGFloat = 0.5
}

class TabBarView<Item: Hashable&Sendable, Cell: TabCellConfigurable>: UIView, UICollectionViewDelegate where Cell.Item == Item {
    enum TabSection { case main }
    weak var delegate: TabBarViewDelegate?
    private var selectedTabIndex: Int = 0

    override var intrinsicContentSize: CGSize {
        let fontHeight = UIFont.preferredFont(forTextStyle: .headline).lineHeight
        let totalHeight = fontHeight + (TabBarViewConstants.verticalPadding * 2) + TabBarViewConstants.bottomBorderHeight
        return CGSize(width: UIView.noIntrinsicMetric, height: totalHeight)
    }

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        layout.sectionInset = .zero
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.showsHorizontalScrollIndicator = false
        cv.delegate = self
        cv.register(Cell.self, forCellWithReuseIdentifier: Cell.reuseIdentifier)
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.clipsToBounds = false
        cv.backgroundColor = .clear
        return cv
    }()
    private var dataSource: UICollectionViewDiffableDataSource<TabSection, Item>!
    private let indicatorView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBlue
        return view
    }()
    private let bottomBorderView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        configureDataSource()
        NotificationCenter.default.addObserver(self, selector: #selector(contentSizeCategoryDidChange), name: UIContentSizeCategory.didChangeNotification, object: nil)
    }
    deinit { NotificationCenter.default.removeObserver(self) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupViews() {
        addSubview(collectionView)
        addSubview(bottomBorderView)
        collectionView.addSubview(indicatorView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: self.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            bottomBorderView.topAnchor.constraint(equalTo: collectionView.bottomAnchor),
            bottomBorderView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            bottomBorderView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            bottomBorderView.heightAnchor.constraint(equalToConstant: TabBarViewConstants.bottomBorderHeight),
            bottomBorderView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateIndicatorPosition(animated: false)
    }
    @objc private func contentSizeCategoryDidChange() {
        invalidateIntrinsicContentSize()
        delegate?.tabBarViewRequiresLayoutUpdate()
    }

    func configure(with items: [Item], selectedIndex: Int) {
        self.selectedTabIndex = selectedIndex
        var snapshot = NSDiffableDataSourceSnapshot<TabSection, Item>()
        snapshot.appendSections([.main])
        snapshot.appendItems(items, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: false)
        DispatchQueue.main.async {
            let indexPath = IndexPath(item: selectedIndex, section: 0)
            self.collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
            self.scrollToMakeTabVisible(at: indexPath, animated: false)
            self.updateIndicatorPosition(animated: false)
        }
    }
    private func configureDataSource() {
        dataSource = .init(collectionView: collectionView) { [weak self] (cv, ip, item) -> UICollectionViewCell? in
            guard let self = self, let cell = cv.dequeueReusableCell(withReuseIdentifier: Cell.reuseIdentifier, for: ip) as? Cell else { return nil }
            cell.configure(with: item)
            cell.isSelected = (ip.item == self.selectedTabIndex)
            return cell
        }
    }
    private func updateIndicatorPosition(animated: Bool) {
        guard let attributes = collectionView.layoutAttributesForItem(at: IndexPath(item: selectedTabIndex, section: 0)) else {
            indicatorView.alpha = 0
            return
        }
        indicatorView.alpha = 1
        let indicatorFrame = CGRect(x: attributes.frame.origin.x, y: attributes.frame.maxY - TabBarViewConstants.indicatorHeight + TabBarViewConstants.indicatorBottomOffset, width: attributes.frame.width, height: TabBarViewConstants.indicatorHeight)
        let animation = { self.indicatorView.frame = indicatorFrame }
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.1, options: [.curveEaseInOut, .allowUserInteraction], animations: animation)
        } else {
            animation()
        }
    }
    private func scrollToMakeTabVisible(at indexPath: IndexPath, animated: Bool) {
        guard let attributes = collectionView.layoutAttributesForItem(at: indexPath) else { return }
        let visibleRect = collectionView.bounds
        if visibleRect.contains(attributes.frame) { return }
        if attributes.frame.midX > visibleRect.midX {
            collectionView.scrollToItem(at: indexPath, at: .right, animated: animated)
        } else {
            collectionView.scrollToItem(at: indexPath, at: .left, animated: animated)
        }
    }
    
    // MARK: - SOLUCIÓN -
    // Pega este método corregido en tu clase TabBarView
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard selectedTabIndex != indexPath.item else { return }

        let oldSelectedIndexPath = IndexPath(item: selectedTabIndex, section: 0)
        selectedTabIndex = indexPath.item
        
        // --- INICIO DE LA SOLUCIÓN ---
        // Forzamos un pase de layout inmediato ANTES de las animaciones.
        // Esto asegura que los atributos de layout (especialmente los tamaños de celda)
        // para los elementos fuera de pantalla se calculen correctamente.
        collectionView.setNeedsLayout()
        collectionView.layoutIfNeeded()
        // --- FIN DE LA SOLUCIÓN ---

        scrollToMakeTabVisible(at: indexPath, animated: true)
        updateIndicatorPosition(animated: true)

        delegate?.tabBarView(didSelectTabAt: indexPath.item)
        
        var snapshot = dataSource.snapshot()
        let items = snapshot.itemIdentifiers(inSection: .main)
        if let oldItem = items[safe: oldSelectedIndexPath.item],
           let newItem = items[safe: indexPath.item] {
            let itemsToReconfigure = [oldItem, newItem]
            snapshot.reconfigureItems(itemsToReconfigure)
            dataSource.apply(snapshot, animatingDifferences: false)
        }
    }
}


class MainTabBarHeaderView: UITableViewHeaderFooterView, TabBarViewDelegate {
    static let reuseIdentifier = "MainTabBarHeaderView"
    weak var delegate: TabBarViewDelegate?
    private let tabBarView = TabBarView<TabItem, TabCell>()
    
    private enum Constants {
        static let portraitPadding: CGFloat = 16.0
        static let landscapePadding: CGFloat = 32.0
    }
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        tabBarView.delegate = self
        setupSubviews()
        updateHorizontalPadding()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.verticalSizeClass != previousTraitCollection?.verticalSizeClass {
            updateHorizontalPadding()
        }
    }
    
    private func setupSubviews() {
        contentView.backgroundColor = .systemBackground
        tabBarView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tabBarView)
        
        let margins = contentView.layoutMarginsGuide
        NSLayoutConstraint.activate([
            tabBarView.topAnchor.constraint(equalTo: contentView.topAnchor),
            tabBarView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            tabBarView.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            tabBarView.trailingAnchor.constraint(equalTo: margins.trailingAnchor)
        ])
    }
    
    private func updateHorizontalPadding() {
        let isLandscape = traitCollection.verticalSizeClass == .compact
        let padding = isLandscape ? Constants.landscapePadding : Constants.portraitPadding
        
        contentView.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 0,
            leading: padding,
            bottom: 0,
            trailing: padding
        )
    }
    
    func configure(with tabs: [TabItem], selectedIndex: Int) {
        tabBarView.configure(with: tabs, selectedIndex: selectedIndex)
    }
    
    func tabBarView(didSelectTabAt index: Int) { delegate?.tabBarView(didSelectTabAt: index) }
    func tabBarViewRequiresLayoutUpdate() { delegate?.tabBarViewRequiresLayoutUpdate() }
}


@MainActor
class ViewController: UIViewController {

    private var tableView: UITableView!
    private var dataSource: UITableViewDiffableDataSource<Section, ListItem>!
    private let infoItemIdentifier = UUID()
    private let tabData: [TabItem] = (0..<4).map { TabItem(title: "Categoría \($0 + 1)") }
    private var selectedTabIndex = 0
    private let infoTexts: [String] = [
        "Esta es la celda de información en la Sección 0.", "El texto ha sido actualizado. ¡Inténtalo de nuevo!",
        "Aquí tienes un dato interesante sobre listas.", "Puedes pulsar el botón de refrescar varias veces.",
        "Último mensaje antes de volver al principio."
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Lista Dinámica"
        navigationController?.navigationBar.prefersLargeTitles = true
        configureNavigationBar()
        configureTableView()
        configureDataSource()
        applyInitialData()
    }
    
    private func configureNavigationBar() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "arrow.clockwise"), style: .plain, target: self, action: #selector(refreshContent))
    }
    private func configureTableView() {
        tableView = UITableView(frame: view.bounds, style: .plain)
        if #available(iOS 15.0, *) { tableView.sectionHeaderTopPadding = 0.0 }
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "DefaultCell")
        tableView.register(MainTabBarHeaderView.self, forHeaderFooterViewReuseIdentifier: MainTabBarHeaderView.reuseIdentifier)
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
    private func applyInitialData() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, ListItem>()
        snapshot.appendSections([.info, .list])
        snapshot.appendItems([ListItem(id: infoItemIdentifier, title: infoTexts[0])], toSection: .info)
        snapshot.appendItems(generateItemsForTab(index: 0), toSection: .list)
        dataSource.apply(snapshot, animatingDifferences: false)
    }
    private func updateContent() {
        var snapshot = dataSource.snapshot()
        let infoItems = snapshot.itemIdentifiers(inSection: .info)
        snapshot.reconfigureItems(infoItems)
        snapshot.itemIdentifiers(inSection: .list).forEach { snapshot.deleteItems([$0]) }
        
        if let currentInfoItem = infoItems.first(where: { $0.id == infoItemIdentifier }) {
            var updatedInfoItem = ListItem(id: infoItemIdentifier, title: infoTexts[selectedTabIndex % infoTexts.count])
            snapshot.reconfigureItems([updatedInfoItem])
        }
        
        snapshot.deleteItems(snapshot.itemIdentifiers(inSection: .list))
        snapshot.appendItems(generateItemsForTab(index: selectedTabIndex), toSection: .list)
        
        dataSource.apply(snapshot, animatingDifferences: false)
    }
    private func generateItemsForTab(index: Int) -> [ListItem] {
        let tabTitle = tabData[safe: index]?.title ?? ""
        return (1...100).map { ListItem(title: "Item \($0) de \(tabTitle)") }
    }
    @objc private func refreshContent() {
        selectedTabIndex = 0
        updateContent()
    }
}
extension ViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let sectionKind = Section(rawValue: section), sectionKind == .list else { return nil }
        guard let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: MainTabBarHeaderView.reuseIdentifier) as? MainTabBarHeaderView else { return nil }
        header.delegate = self
        header.configure(with: tabData, selectedIndex: selectedTabIndex)
        return header
    }
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard let sectionKind = Section(rawValue: section) else { return 0 }
        return sectionKind == .list ? UITableView.automaticDimension : 0.0
    }
}
extension ViewController: TabBarViewDelegate {
    func tabBarView(didSelectTabAt index: Int) {
        guard index != selectedTabIndex else { return }
        selectedTabIndex = index
        updateContent()
    }
    func tabBarViewRequiresLayoutUpdate() {
        tableView.performBatchUpdates(nil)
    }
}
extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
