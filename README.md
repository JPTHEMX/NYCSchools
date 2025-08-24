import UIKit

final class ViewController: UIViewController {

    private enum Section: Int, CaseIterable {
        case generalInfo = 0
        case carousel = 1
        case grid = 2
        case footer = 3

        var itemCount: Int {
            switch self {
            case .generalInfo: return 2
            case .carousel:    return 1
            case .grid:        return 30
            case .footer:      return 1
            }
        }
    }

    private let sections: [Section] = [.generalInfo, .carousel, .grid, .footer]
    private var collectionView: UICollectionView!
    private let cellSpacing: CGFloat = 16.0

    private var cachedGridCellHeight: CGFloat?
    private var shouldRecalculateGridHeight = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contentSizeCategoryDidChange),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )
        
        configureCollectionView()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: UIContentSizeCategory.didChangeNotification, object: nil)
    }

    @objc private func contentSizeCategoryDidChange() {
        shouldRecalculateGridHeight = true
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut]) {
            self.collectionView.collectionViewLayout.invalidateLayout()
            self.collectionView.reloadData()
        }
    }
    
    private func configureCellContent(_ cell: TitleSubtitleCell, at indexPath: IndexPath) {
        if indexPath.item == 5 {
            cell.configure(title: "Cell \(indexPath.item)", subtitle: "This subtitle is much, much longer to demonstrate how the cell grows vertically to accommodate its content. All cells in this section will match this new height.")
        } else {
            cell.configure(title: "Cell \(indexPath.item)", subtitle: "Subtitle \(indexPath.item)")
        }
    }
    
    private func configureCollectionView() {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.dataSource = self
        collectionView.backgroundColor = .clear
        view.addSubview(collectionView)

        collectionView.register(TitleSubtitleCell.self, forCellWithReuseIdentifier: TitleSubtitleCell.reuseIdentifier)
        collectionView.register(CarouselCell.self, forCellWithReuseIdentifier: CarouselCell.reuseIdentifier)
        collectionView.register(TitleCell.self, forCellWithReuseIdentifier: TitleCell.reuseIdentifier)
        collectionView.register(TitleHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: TitleHeaderView.reuseIdentifier)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
}

// MARK: - Layout Creation & Data Source
extension ViewController: UICollectionViewDataSource {
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, layoutEnvironment in
            guard let self = self else { return nil }
            let sectionType = self.sections[sectionIndex]
            
            switch sectionType {
            case .generalInfo:
                return self.createListSection()
            case .carousel:
                return self.createCarouselSection()
            case .grid:
                return self.createGridSection(layoutEnvironment: layoutEnvironment)
            case .footer:
                return self.createListSection()
            }
        }
        return layout
    }

    private func createListSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(60))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = cellSpacing
        section.contentInsets = NSDirectionalEdgeInsets(top: cellSpacing, leading: 16, bottom: cellSpacing, trailing: 16)
        return section
    }

    private func createCarouselSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(180))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: itemSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: cellSpacing, leading: 16, bottom: cellSpacing, trailing: 16)
        
        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(44)
        )
        let sectionHeader = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
        section.boundarySupplementaryItems = [sectionHeader]
        
        return section
    }
    
    private func createGridSection(layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let traitCollection = layoutEnvironment.traitCollection
        
        // --- INICIO DEL CAMBIO ---
        // Lógica explícita para determinar el número de columnas según el dispositivo y orientación.
        let columnCount: Int
        if traitCollection.userInterfaceIdiom == .pad {
            // En iPad, siempre serán 3 columnas, sin importar la orientación.
            columnCount = 3
        } else {
            // En iPhone, serán 2 columnas en portrait y 3 en landscape.
            // Una forma fiable de detectar portrait en iPhone es con la clase de tamaño vertical.
            let isPortrait = traitCollection.verticalSizeClass == .regular
            columnCount = isPortrait ? 2 : 3
        }
        // --- FIN DEL CAMBIO ---

        let sectionInset: CGFloat = 16.0
        let totalSpacing = CGFloat(columnCount - 1) * cellSpacing
        let availableWidth = layoutEnvironment.container.effectiveContentSize.width - (sectionInset * 2) - totalSpacing
        
        guard availableWidth > 0 else {
            let emptyItemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
            let emptyItem = NSCollectionLayoutItem(layoutSize: emptyItemSize)
            let emptyGroup = NSCollectionLayoutGroup.horizontal(layoutSize: emptyItemSize, subitems: [emptyItem])
            return NSCollectionLayoutSection(group: emptyGroup)
        }
        
        let cellWidth = availableWidth / CGFloat(columnCount)
        
        var maxHeight: CGFloat = cachedGridCellHeight ?? 0
        if shouldRecalculateGridHeight || maxHeight == 0 {
            maxHeight = 0
            let sizingCell = TitleSubtitleCell()
            if let gridSectionIndex = sections.firstIndex(of: .grid) {
                for itemIndex in 0..<sections[gridSectionIndex].itemCount {
                    let indexPath = IndexPath(item: itemIndex, section: gridSectionIndex)
                    configureCellContent(sizingCell, at: indexPath)
                    let requiredSize = sizingCell.systemLayoutSizeFitting(
                        CGSize(width: cellWidth, height: .greatestFiniteMagnitude),
                        withHorizontalFittingPriority: .required,
                        verticalFittingPriority: .fittingSizeLevel
                    )
                    if requiredSize.height > maxHeight {
                        maxHeight = requiredSize.height
                    }
                }
            }
            cachedGridCellHeight = maxHeight
            shouldRecalculateGridHeight = false
        }
        
        let finalHeight = max(maxHeight, 184.0)

        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(finalHeight)
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitem: item,
            count: columnCount
        )
        group.interItemSpacing = .fixed(cellSpacing)
        
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = cellSpacing
        section.contentInsets = NSDirectionalEdgeInsets(top: cellSpacing, leading: 16, bottom: cellSpacing, trailing: 16)
        
        return section
    }
    
    // --- MÉTODOS DEL DATASOURCE ---

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return sections.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return sections[section].itemCount
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let sectionType = sections[indexPath.section]

        switch sectionType {
        case .generalInfo:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TitleSubtitleCell.reuseIdentifier, for: indexPath) as! TitleSubtitleCell
            cell.configure(title: "Cell \(indexPath.item)", subtitle: "This is Section 0.")
            cell.backgroundColor = .systemGray5
            cell.layer.cornerRadius = 12
            return cell
        case .carousel:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CarouselCell.reuseIdentifier, for: indexPath) as! CarouselCell
            cell.configure(title: "Carousel Cell")
            cell.backgroundColor = .systemBlue
            cell.layer.cornerRadius = 12
            return cell
        case .grid:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TitleSubtitleCell.reuseIdentifier, for: indexPath) as! TitleSubtitleCell
            configureCellContent(cell, at: indexPath)
            cell.backgroundColor = .systemTeal
            cell.layer.cornerRadius = 12
            return cell
        case .footer:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TitleCell.reuseIdentifier, for: indexPath) as! TitleCell
            cell.configure(title: "Footer Cell")
            cell.backgroundColor = .systemGray4
            cell.layer.cornerRadius = 12
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionHeader, sections[indexPath.section] == .carousel else {
            return UICollectionReusableView()
        }
        
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: TitleHeaderView.reuseIdentifier, for: indexPath) as! TitleHeaderView
        header.configure(title: "Header for Section \(sections[indexPath.section].rawValue). This is an example of a longer header that will wrap to multiple lines when the text size increases.")
        return header
    }
}











import UIKit

class TitleSubtitleCell: UICollectionViewCell {
    static let reuseIdentifier = "TitleSubtitleCell"

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .headline)
        label.textColor = .label
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.textAlignment = .center
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentHuggingPriority(.required, for: .vertical)
        return label
    }()

    private let subTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.textAlignment = .center
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentHuggingPriority(.required, for: .vertical)
        return label
    }()
    
    // Un stack view interior solo para el contenido de texto.
    private let contentStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 5
        return stack
    }()

    // Un stack view exterior que maneja el centrado.
    private let centeringStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center // Centra el contentStackView horizontalmente.
        stack.distribution = .equalCentering // Centra el contentStackView verticalmente.
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        
        contentStackView.addArrangedSubview(titleLabel)
        contentStackView.addArrangedSubview(subTitleLabel)
        
        centeringStackView.addArrangedSubview(contentStackView)
        
        contentView.addSubview(centeringStackView)
        
        // El stack exterior se ancla a los 4 bordes.
        // Esto le da a systemLayoutSizeFitting una ruta vertical completa para medir.
        NSLayoutConstraint.activate([
            centeringStackView.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            centeringStackView.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),
            centeringStackView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            centeringStackView.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String, subtitle: String?) {
        titleLabel.text = title
        subTitleLabel.text = subtitle
        subTitleLabel.isHidden = subtitle == nil || subtitle?.isEmpty == true
    }
}








import UIKit

class CarouselCell: UICollectionViewCell {
    static let reuseIdentifier = "CarouselCell"

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .title1)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(greaterThanOrEqualTo: contentView.layoutMarginsGuide.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.layoutMarginsGuide.bottomAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String) {
        titleLabel.text = title
    }
}

import UIKit

class TitleCell: UICollectionViewCell {
    static let reuseIdentifier = "TitleCell"

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .headline)
        label.textColor = .label
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(title: String) {
        titleLabel.text = title
    }
}





import UIKit

class TitleHeaderView: UICollectionReusableView {
    static let reuseIdentifier = "TitleHeaderView"

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .label
        
        // --- LA CORRECCIÓN ESTÁ AQUÍ ---
        label.numberOfLines = 0 // Cambiado de 1 a 0 para permitir múltiples líneas
        
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground
        addSubview(titleLabel)

        // Las constraints existentes ya son correctas para el auto-dimensionamiento
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 0),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String) {
        titleLabel.text = title
        accessibilityLabel = title
        isAccessibilityElement = true
    }
}









