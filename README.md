import UIKit

// MARK: - Modelo de Datos

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

    // La identidad se basa solo en el ID, no en el título.
    static func == (lhs: ListItem, rhs: ListItem) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct TabItem: Hashable {
    let title: String
}

// MARK: - TabCell

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
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
    }

    func configure(with title: String) {
        titleLabel.text = title
    }
}


// MARK: - TabBarView

@MainActor
protocol TabBarViewDelegate: AnyObject {
    func tabBarView(didSelectTabAt index: Int)
    func tabBarViewRequiresLayoutUpdate()
}

class TabBarView: UIView {

    private enum Constants {
        static let verticalPadding: CGFloat = 8.0
        static let indicatorHeight: CGFloat = 5.0
        static let indicatorBottomOffset: CGFloat = 3.0
        static let bottomBorderHeight: CGFloat = 0.5
    }

    enum TabSection { case main }
    weak var delegate: TabBarViewDelegate?
    private var selectedTabIndex: Int = 0

    override var intrinsicContentSize: CGSize {
        let fontHeight = UIFont.preferredFont(forTextStyle: .headline).lineHeight
        let totalHeight = fontHeight + (Constants.verticalPadding * 2) + Constants.bottomBorderHeight
        return CGSize(width: UIView.noIntrinsicMetric, height: totalHeight)
    }

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        layout.sectionInset = .zero
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.delegate = self
        collectionView.register(TabCell.self, forCellWithReuseIdentifier: TabCell.reuseIdentifier)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.clipsToBounds = false
        collectionView.backgroundColor = .clear
        return collectionView
    }()

    private var dataSource: UICollectionViewDiffableDataSource<TabSection, TabItem>!
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

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        addSubview(collectionView)
        addSubview(bottomBorderView)
        // El indicador es subvista del CollectionView para que se mueva con el scroll.
        collectionView.addSubview(indicatorView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: self.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: self.trailingAnchor),

            bottomBorderView.topAnchor.constraint(equalTo: collectionView.bottomAnchor),
            bottomBorderView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            bottomBorderView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            bottomBorderView.heightAnchor.constraint(equalToConstant: Constants.bottomBorderHeight),
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
        dataSource = .init(collectionView: collectionView) { [weak self] (cv, ip, item) -> UICollectionViewCell? in
            guard let self = self, let cell = cv.dequeueReusableCell(withReuseIdentifier: TabCell.reuseIdentifier, for: ip) as? TabCell else {
                return nil
            }
            cell.configure(with: item.title)
            // Asegura que el estado visual de selección sea correcto al reciclar celdas.
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

        let indicatorFrame = CGRect(
            x: attributes.frame.origin.x,
            y: attributes.frame.maxY - Constants.indicatorHeight + Constants.indicatorBottomOffset,
            width: attributes.frame.width,
            height: Constants.indicatorHeight
        )

        let animation = { self.indicatorView.frame = indicatorFrame }
        
        if animated {
            UIView.animate(
                withDuration: 0.3,
                delay: 0,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0.1,
                options: [.curveEaseInOut, .allowUserInteraction],
                animations: animation
            )
        } else {
            animation()
        }
    }

    private func scrollToMakeTabVisible(at indexPath: IndexPath, animated: Bool) {
        guard let attributes = collectionView.layoutAttributesForItem(at: indexPath) else {
            return
        }
        
        let visibleRect = collectionView.bounds

        // Si la celda ya está completamente contenida, no hacer nada.
        if visibleRect.contains(attributes.frame) {
            return
        }
        
        // Decidir si alinear a la izquierda o a la derecha.
        if attributes.frame.midX > visibleRect.midX {
            collectionView.scrollToItem(at: indexPath, at: .right, animated: animated)
        } else {
            collectionView.scrollToItem(at: indexPath, at: .left, animated: animated)
        }
    }
}

extension TabBarView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard selectedTabIndex != indexPath.item else {
            return
        }
        
        let oldSelectedIndexPath = IndexPath(item: selectedTabIndex, section: 0)
        selectedTabIndex = indexPath.item
        
        var snapshot = dataSource.snapshot()
        let itemsToReconfigure = [
            snapshot.itemIdentifiers[oldSelectedIndexPath.item],
            snapshot.itemIdentifiers[indexPath.item]
        ]
        snapshot.reconfigureItems(itemsToReconfigure)
        dataSource.apply(snapshot, animatingDifferences: false)
        
        scrollToMakeTabVisible(at: indexPath, animated: true)
        updateIndicatorPosition(animated: true)
        
        delegate?.tabBarView(didSelectTabAt: indexPath.item)
    }
}


// MARK: - Adaptador para UITableView

class TabBarTableViewHeader: UITableViewHeaderFooterView, TabBarViewDelegate {
    static let reuseIdentifier = "TabBarTableViewHeader"
    weak var delegate: TabBarViewDelegate?
    private let tabBarView = TabBarView()
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        tabBarView.delegate = self
        setupSubviews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupSubviews() {
        contentView.backgroundColor = .systemBackground
        tabBarView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tabBarView)
        NSLayoutConstraint.activate([
            tabBarView.topAnchor.constraint(equalTo: contentView.topAnchor),
            tabBarView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            tabBarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            tabBarView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])
    }
    
    func configure(with tabs: [TabItem], selectedIndex: Int) {
        tabBarView.configure(with: tabs, selectedIndex: selectedIndex)
    }
    
    func tabBarView(didSelectTabAt index: Int) {
        delegate?.tabBarView(didSelectTabAt: index)
    }
    
    func tabBarViewRequiresLayoutUpdate() {
        delegate?.tabBarViewRequiresLayoutUpdate()
    }
}


// MARK: - ViewController Principal

@MainActor
class ViewController: UIViewController {

    private var tableView: UITableView!
    private var dataSource: UITableViewDiffableDataSource<Section, ListItem>!
    
    private let infoItemIdentifier = UUID()
    private let tabData: [TabItem] = (0..<12).map { TabItem(title: "Categoría \($0 + 1)") }
    private var selectedTabIndex = 0
    private let infoTexts: [String] = [
        "Esta es la celda de información en la Sección 0.",
        "El texto ha sido actualizado. ¡Inténtalo de nuevo!",
        "Aquí tienes un dato interesante sobre listas.",
        "Puedes pulsar el botón de refrescar varias veces.",
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
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "arrow.clockwise"),
            style: .plain,
            target: self,
            action: #selector(refreshContent)
        )
    }

    private func configureTableView() {
        tableView = UITableView(frame: view.bounds, style: .plain)
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0.0
        }
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "DefaultCell")
        tableView.register(TabBarTableViewHeader.self, forHeaderFooterViewReuseIdentifier: TabBarTableViewHeader.reuseIdentifier)
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
        // Reconfigura la celda de información con el nuevo texto
        snapshot.reconfigureItems([ListItem(id: infoItemIdentifier, title: infoTexts[selectedTabIndex % infoTexts.count])])
        // Borra los items antiguos de la lista
        snapshot.deleteItems(snapshot.itemIdentifiers(inSection: .list))
        // Añade los nuevos items de la lista
        snapshot.appendItems(generateItemsForTab(index: selectedTabIndex), toSection: .list)
        // Aplica todos los cambios a la vez y sin animaciones
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func generateItemsForTab(index: Int) -> [ListItem] {
        return (1...100).map { ListItem(title: "Item \($0) de \(tabData[index].title)") }
    }

    @objc private func refreshContent() {
        // 1. Actualiza el estado del modelo a 0
        selectedTabIndex = 0
        
        // 2. Prepara una nueva instantánea para actualizar la UI.
        // Obtenemos una copia del estado actual para modificarla.
        var snapshot = dataSource.snapshot()
        
        // 3. Reconfigura la celda de información.
        // Usamos el ID conocido para identificar el ítem. ListItem es hashable por su 'id'.
        // El título aquí solo sirve para el contenido, no para la identificación.
        snapshot.reconfigureItems([ListItem(id: infoItemIdentifier, title: infoTexts[0])])
        
        // 4. Actualiza los ítems de la lista para el tab 0.
        snapshot.deleteItems(snapshot.itemIdentifiers(inSection: .list))
        snapshot.appendItems(generateItemsForTab(index: selectedTabIndex), toSection: .list)
        
        // 5. ¡LA SOLUCIÓN DEFINITIVA!
        // Le decimos al DataSource que la sección '.list' necesita ser recargada.
        // Esto es el equivalente a 'tableView.reloadSections', pero seguro para DiffableDataSource.
        // Forzará que se llame de nuevo a 'tableView(_:viewForHeaderInSection:)', que ahora
        // creará y configurará la cabecera con el 'selectedTabIndex' ya puesto en 0.
        snapshot.reloadSections([.list])
        
        // 6. Aplica todos los cambios (celdas, ítems y recarga de sección) a la vez.
        // Esto soluciona el problema de temporización y el bug visual.
        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

extension ViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let sectionKind = Section(rawValue: section), sectionKind == .list else {
            return nil
        }
        guard let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: TabBarTableViewHeader.reuseIdentifier) as? TabBarTableViewHeader else {
            return nil
        }
        header.delegate = self
        header.configure(with: tabData, selectedIndex: selectedTabIndex)
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard let sectionKind = Section(rawValue: section) else {
            return 0
        }
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
        // En iOS 15+ se recomienda `performBatchUpdates`.
        tableView.performBatchUpdates(nil)
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
