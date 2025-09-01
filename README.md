import UIKit

// MARK: - Custom Layout for Persistent Sticky Header
@MainActor
final class StickyCarouselHeaderLayout: UICollectionViewCompositionalLayout {
    var stickyHeaderSection: Int = 1
    let stickyHeaderZIndex: Int = 1000
    let standardHeaderZIndex: Int = 100
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard let superAttributes = super.layoutAttributesForElements(in: rect),
              let collectionView else {
            return nil
        }
        
        var mutableAttributes = superAttributes.compactMap { $0.copy() as? UICollectionViewLayoutAttributes }
        let contentInsetTop = collectionView.adjustedContentInset.top
        let effectiveOffsetY = collectionView.contentOffset.y + contentInsetTop
        let stickyHeaderIndexPath = IndexPath(item: 0, section: stickyHeaderSection)
        
        var stickyHeaderAttrs: UICollectionViewLayoutAttributes?
        var needsToAddStickyHeader = false
        
        for attributes in mutableAttributes where attributes.representedElementKind == UICollectionView.elementKindSectionHeader {
            if attributes.indexPath == stickyHeaderIndexPath {
                stickyHeaderAttrs = attributes
                
                let originalStickyHeaderY = super.layoutAttributesForSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, at: stickyHeaderIndexPath)?.frame.origin.y ?? attributes.frame.origin.y
                let stickyY = max(effectiveOffsetY, originalStickyHeaderY)
                
                attributes.frame.origin.y = stickyY
                attributes.zIndex = stickyHeaderZIndex
            } else {
                attributes.zIndex = standardHeaderZIndex
            }
        }
        
        if stickyHeaderAttrs == nil {
            if let fetchedStickyAttrs = super.layoutAttributesForSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, at: stickyHeaderIndexPath)?.copy() as? UICollectionViewLayoutAttributes {
                let originalStickyHeaderY = super.layoutAttributesForSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, at: stickyHeaderIndexPath)?.frame.origin.y ?? fetchedStickyAttrs.frame.origin.y
                let stickyY = max(effectiveOffsetY, originalStickyHeaderY)
                fetchedStickyAttrs.frame.origin.y = stickyY
                fetchedStickyAttrs.zIndex = stickyHeaderZIndex
                
                if fetchedStickyAttrs.frame.intersects(rect) {
                    stickyHeaderAttrs = fetchedStickyAttrs
                    needsToAddStickyHeader = true
                }
            }
        }
        
        if needsToAddStickyHeader, let attrsToAdd = stickyHeaderAttrs {
            if !mutableAttributes.contains(where: { $0.indexPath == attrsToAdd.indexPath && $0.representedElementKind == attrsToAdd.representedElementKind }) {
                mutableAttributes.append(attrsToAdd)
            }
        }
        
        return mutableAttributes
    }
    
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        let oldBounds = collectionView?.bounds ?? .zero
        return newBounds.origin.y != oldBounds.origin.y || newBounds.size != oldBounds.size
    }
    
    override func layoutAttributesForSupplementaryView(ofKind elementKind: String, at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard let attributes = super.layoutAttributesForSupplementaryView(ofKind: elementKind, at: indexPath)?.copy() as? UICollectionViewLayoutAttributes else {
            return nil
        }
        
        if elementKind == UICollectionView.elementKindSectionHeader {
            if indexPath.section == stickyHeaderSection {
                guard let collectionView else {
                    return attributes
                }
                
                let contentInsetTop = collectionView.adjustedContentInset.top
                let effectiveOffsetY = collectionView.contentOffset.y + contentInsetTop
                let originalStickyHeaderY = super.layoutAttributesForSupplementaryView(ofKind: elementKind, at: indexPath)?.frame.origin.y ?? attributes.frame.origin.y
                
                attributes.frame.origin.y = max(effectiveOffsetY, originalStickyHeaderY)
                attributes.zIndex = stickyHeaderZIndex
            } else {
                attributes.zIndex = standardHeaderZIndex
            }
        }
        
        return attributes
    }
}


import UIKit

// MARK: - Main ViewController
@MainActor
final class ViewController: UIViewController {
    
    // MARK: - Section Definition
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
    
    // MARK: - Properties
    private let sections: [Section] = [.generalInfo, .carousel, .grid, .footer]
    private var collectionView: UICollectionView!
    private let cellSpacing: CGFloat = 16.0
    
    // Cache properties for grid cell height
    private var cachedGridCellHeight: CGFloat?
    private var shouldRecalculateGridHeight = true
    
    // MARK: - Lifecycle
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
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Dynamic Type & Trait Changes
    @objc private func contentSizeCategoryDidChange() {
        shouldRecalculateGridHeight = true
        collectionView.setCollectionViewLayout(createLayout(), animated: true)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        guard previousTraitCollection?.horizontalSizeClass != traitCollection.horizontalSizeClass ||
              previousTraitCollection?.verticalSizeClass != traitCollection.verticalSizeClass else { return }
        
        shouldRecalculateGridHeight = true
        collectionView.setCollectionViewLayout(createLayout(), animated: true)
    }
    
    // MARK: - Setup
    private func configureCollectionView() {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.backgroundColor = .clear
        view.addSubview(collectionView)
        
        // Register cells and supplementary views
        collectionView.register(TitleSubtitleCell.self, forCellWithReuseIdentifier: TitleSubtitleCell.reuseIdentifier)
        collectionView.register(CarouselCell.self, forCellWithReuseIdentifier: CarouselCell.reuseIdentifier)
        collectionView.register(TitleCell.self, forCellWithReuseIdentifier: TitleCell.reuseIdentifier)
        collectionView.register(FullWidthLabelCell.self, forCellWithReuseIdentifier: FullWidthLabelCell.reuseIdentifier) // Nueva celda
        collectionView.register(TitleHeaderView.self,
                              forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                              withReuseIdentifier: TitleHeaderView.reuseIdentifier)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    // MARK: - Cell Configuration
    private func configureCellContent(_ cell: TitleSubtitleCell, at indexPath: IndexPath) {
        let logoImage = UIImage(systemName: "photo.fill")
        
        switch indexPath.item {
        case 5:
            cell.configure(
                logo: logoImage,
                tag: "Exclusive",
                title: "Cell \(indexPath.item)",
                subtitle: "This is a subtitle",
                description: "And finally"
            )
        case 2:
            cell.configure(
                logo: logoImage,
                tag: nil,
                title: "Cell \(indexPath.item) (No Tag)",
                subtitle: "Subtitle for cell \(indexPath.item).",
                description: "This cell demonstrates how the layout adapts when the tag view is hidden from view."
            )
        default:
            cell.configure(
                logo: logoImage,
                tag: "New",
                title: "Cell \(indexPath.item)",
                subtitle: "Subtitle \(indexPath.item)",
                description: "A standard description for a standard cell."
            )
        }
    }
}

// MARK: - Layout Creation
extension ViewController {
    func createLayout() -> UICollectionViewLayout {
        let layout = StickyCarouselHeaderLayout(sectionProvider: { [weak self] sectionIndex, layoutEnvironment -> NSCollectionLayoutSection? in
            guard let self = self else { return nil }
            let sectionType = self.sections[sectionIndex]
            switch sectionType {
            case .generalInfo:
                return self.createListSection()
            case .carousel:
                return self.createCarouselSection()
            case .grid:
                return self.createGridSection(
                    containerWidth: layoutEnvironment.container.effectiveContentSize.width,
                    traitCollection: self.traitCollection
                )
            case .footer:
                return self.createFooterSection()
            }
        })
        
        return layout
    }
    
    private func createListSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(100)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let group = NSCollectionLayoutGroup.vertical(
            layoutSize: itemSize,
            subitems: [item]
        )
        
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = cellSpacing
        section.contentInsets = NSDirectionalEdgeInsets(
            top: cellSpacing,
            leading: 16,
            bottom: cellSpacing,
            trailing: 16
        )
        
        return section
    }
    
    private func createCarouselSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(180)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        // Apply horizontal margins to the group (not the section)
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: itemSize,
            subitems: [item]
        )
        group.contentInsets = NSDirectionalEdgeInsets(
            top: 0,
            leading: 16,
            bottom: 0,
            trailing: 16
        )
        
        let section = NSCollectionLayoutSection(group: group)
        // Section only needs vertical spacing
        section.contentInsets = NSDirectionalEdgeInsets(
            top: cellSpacing,
            leading: 0,
            bottom: cellSpacing,
            trailing: 0
        )
        
        // Header configuration (edge-to-edge)
        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(44)
        )
        let sectionHeader = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        section.boundarySupplementaryItems = [sectionHeader]
        
        return section
    }
    
    private func createGridSection(containerWidth: CGFloat, traitCollection: UITraitCollection) -> NSCollectionLayoutSection {
        let sectionInset: CGFloat = 16.0
        
        // Calcular el número de columnas según el trait collection
        let columnCount = (traitCollection.horizontalSizeClass == .compact &&
                          traitCollection.verticalSizeClass == .regular) ? 2 : 3
        
        let totalHorizontalInsets = sectionInset * 2
        let totalSpacing = CGFloat(columnCount - 1) * cellSpacing
        let availableWidth = containerWidth - totalHorizontalInsets
        
        guard availableWidth > 0 else {
            let emptySize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(1))
            let emptyItem = NSCollectionLayoutItem(layoutSize: emptySize)
            let emptyGroup = NSCollectionLayoutGroup.horizontal(layoutSize: emptySize, subitems: [emptyItem])
            return NSCollectionLayoutSection(group: emptyGroup)
        }
        
        let cellWidth = (availableWidth - totalSpacing) / CGFloat(columnCount)
        
        // Calcular alturas para diferentes tipos de celdas
        let fullWidthCellHeight = calculateFullWidthCellHeight(for: availableWidth)
        
        // Calcular altura del grid solo si es necesario
        if shouldRecalculateGridHeight || cachedGridCellHeight == nil {
            cachedGridCellHeight = calculateMaxGridCellHeight(for: cellWidth)
            shouldRecalculateGridHeight = false
        }
        let gridCellHeight = cachedGridCellHeight ?? 184.0
        
        // Crear grupos de manera más eficiente
        var allGroups: [NSCollectionLayoutGroup] = []
        
        // Primeras dos celdas full-width con altura calculada
        for _ in 0..<2 {
            let fullWidthItemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(fullWidthCellHeight)
            )
            let fullWidthItem = NSCollectionLayoutItem(layoutSize: fullWidthItemSize)
            
            let fullWidthGroupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(fullWidthCellHeight)
            )
            let fullWidthGroup = NSCollectionLayoutGroup.horizontal(
                layoutSize: fullWidthGroupSize,
                subitems: [fullWidthItem]
            )
            allGroups.append(fullWidthGroup)
        }
        
        // Celdas del grid regulares
        let totalItems = sections[2].itemCount // grid section index
        let remainingItems = max(0, totalItems - 2)
        
        if remainingItems > 0 {
            // Configuración para items regulares del grid
            let regularItemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0 / CGFloat(columnCount)),
                heightDimension: .fractionalHeight(1.0)
            )
            let regularItem = NSCollectionLayoutItem(layoutSize: regularItemSize)
            
            let regularGroupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(gridCellHeight)
            )
            
            // Crear grupos regulares de manera más eficiente
            let numberOfFullRows = remainingItems / columnCount
            let remainingItemsInLastRow = remainingItems % columnCount
            
            // Grupos completos
            for _ in 0..<numberOfFullRows {
                let group = NSCollectionLayoutGroup.horizontal(
                    layoutSize: regularGroupSize,
                    repeatingSubitem: regularItem,
                    count: columnCount
                )
                group.interItemSpacing = .fixed(cellSpacing)
                allGroups.append(group)
            }
            
            // Última fila parcial si existe
            if remainingItemsInLastRow > 0 {
                let group = NSCollectionLayoutGroup.horizontal(
                    layoutSize: regularGroupSize,
                    repeatingSubitem: regularItem,
                    count: remainingItemsInLastRow
                )
                group.interItemSpacing = .fixed(cellSpacing)
                allGroups.append(group)
            }
        }
        
        // Crear el grupo principal
        let estimatedTotalHeight = CGFloat(2) * fullWidthCellHeight +
                                 CGFloat(allGroups.count - 2) * gridCellHeight +
                                 CGFloat(max(0, allGroups.count - 1)) * cellSpacing
        
        let mainGroupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(estimatedTotalHeight)
        )
        
        let mainGroup = NSCollectionLayoutGroup.vertical(
            layoutSize: mainGroupSize,
            subitems: allGroups
        )
        mainGroup.interItemSpacing = .fixed(cellSpacing)
        
        let section = NSCollectionLayoutSection(group: mainGroup)
        section.contentInsets = NSDirectionalEdgeInsets(
            top: cellSpacing,
            leading: sectionInset,
            bottom: cellSpacing,
            trailing: sectionInset
        )
        
        return section
    }
    
    // Nueva función para calcular altura de celdas full-width
    private func calculateFullWidthCellHeight(for containerWidth: CGFloat) -> CGFloat {
        let sizingCell = FullWidthLabelCell()
        
        // Configurar con contenido de muestra (puedes ajustar según tus necesidades)
        sizingCell.configure(title: "Sample Full Width Text", backgroundColor: .systemBlue)
        
        let requiredSize = sizingCell.systemLayoutSizeFitting(
            CGSize(width: containerWidth, height: 0),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        
        // Altura mínima para celdas full-width
        return max(requiredSize.height, 60.0)
    }
    
    // Función mejorada para calcular altura del grid
    private func calculateMaxGridCellHeight(for cellWidth: CGFloat) -> CGFloat {
        var maxHeight: CGFloat = 0
        
        // Crear una celda temporal para medición
        let sizingCell = TitleSubtitleCell()
        sizingCell.setSpacerActive(false)
        
        if let gridSectionIndex = sections.firstIndex(of: .grid) {
            let totalItems = sections[gridSectionIndex].itemCount
            
            // Solo calcular para las celdas que usan TitleSubtitleCell (índices 2+)
            for itemIndex in 2..<totalItems {
                let indexPath = IndexPath(item: itemIndex, section: gridSectionIndex)
                configureCellContent(sizingCell, at: indexPath)
                
                let requiredSize = sizingCell.systemLayoutSizeFitting(
                    CGSize(width: cellWidth, height: 0),
                    withHorizontalFittingPriority: .required,
                    verticalFittingPriority: .fittingSizeLevel
                )
                
                maxHeight = max(maxHeight, requiredSize.height)
            }
        }
        
        // Ajustar altura mínima según la orientación
        let minimumHeight: CGFloat = (traitCollection.horizontalSizeClass == .compact &&
                                    traitCollection.verticalSizeClass == .regular) ? 220.0 : 184.0
        
        return max(maxHeight, minimumHeight)
    }
    
    private func createFooterSection() -> NSCollectionLayoutSection {
        return createListSection()
    }
}

// MARK: - UICollectionViewDataSource
extension ViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        sections.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        sections[section].itemCount
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let sectionType = sections[indexPath.section]
        
        switch sectionType {
        case .generalInfo, .footer:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: TitleCell.reuseIdentifier,
                for: indexPath
            ) as! TitleCell
            cell.configure(title: "Simple Cell for \(sectionType) section (\(indexPath.item))")
            cell.backgroundColor = .systemGray5
            cell.layer.cornerRadius = 12
            return cell
            
        case .carousel:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: CarouselCell.reuseIdentifier,
                for: indexPath
            ) as! CarouselCell
            cell.configure(title: "Carousel Cell")
            cell.backgroundColor = .systemBlue
            cell.layer.cornerRadius = 12
            return cell
            
        case .grid:
            // Primeras dos celdas: full width con colores específicos
            if indexPath.item < 2 {
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: FullWidthLabelCell.reuseIdentifier,
                    for: indexPath
                ) as! FullWidthLabelCell
                
                let backgroundColor: UIColor = indexPath.item == 0 ? .systemBlue : .systemGreen
                let title = indexPath.item == 0 ? "Primera Celda Azul" : "Segunda Celda Verde"
                
                cell.configure(title: title, backgroundColor: backgroundColor)
                return cell
            } else {
                // Resto de celdas: comportamiento actual sin cambios
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: TitleSubtitleCell.reuseIdentifier,
                    for: indexPath
                ) as! TitleSubtitleCell
                configureCellContent(cell, at: indexPath)
                cell.backgroundColor = .systemGray6
                cell.layer.cornerRadius = 12
                return cell
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView,
                       viewForSupplementaryElementOfKind kind: String,
                       at indexPath: IndexPath) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionHeader,
              sections[indexPath.section] == .carousel else {
            return UICollectionReusableView()
        }
        
        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: TitleHeaderView.reuseIdentifier,
            for: indexPath
        ) as! TitleHeaderView
        
        header.configure(title: "Header for Carousel")
        return header
    }
}

// MARK: - UICollectionViewDelegate
extension ViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        
        let sectionType = sections[indexPath.section]
        print("Selected item at section: \(sectionType), item: \(indexPath.item)")
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    func collectionView(_ collectionView: UICollectionView,
                       willDisplay cell: UICollectionViewCell,
                       forItemAt indexPath: IndexPath) {
        // Add subtle animation
        cell.alpha = 0
        UIView.animate(withDuration: 0.3) {
            cell.alpha = 1
        }
    }
}

// MARK: - TitleSubtitleCell
final class TitleSubtitleCell: UICollectionViewCell {
    static let reuseIdentifier = "TitleSubtitleCell"
    
    // MARK: - UI Components
    private let logoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .systemGray4
        imageView.layer.cornerRadius = 8
        imageView.image = UIImage(systemName: "photo.fill")
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    let tagLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .caption1)
        label.textColor = .white
        label.backgroundColor = .systemRed
        label.textAlignment = .center
        label.layer.cornerRadius = 8
        label.layer.masksToBounds = true
        label.numberOfLines = 1
        label.adjustsFontForContentSizeCategory = true
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .headline)
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // Spacer view to absorb extra vertical space
    private let spacerView = UIView()
    
    // MARK: - Constants
    private enum Constants {
        static let logoTopPadding: CGFloat = 12
        static let logoSize: CGFloat = 56
        static let horizontalPadding: CGFloat = 12
        static let tagTopPadding: CGFloat = 12
        static let stackTopPadding: CGFloat = 8
        static let stackSpacing: CGFloat = 4
        static let bottomPadding: CGFloat = 12
    }
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Configuration
    func configure(logo: UIImage?, tag: String?, title: String, subtitle: String, description: String) {
        logoImageView.image = logo ?? UIImage(systemName: "photo.fill")
        titleLabel.text = title
        subtitleLabel.text = subtitle
        descriptionLabel.text = description
        
        // Handle tag visibility
        if let tagText = tag, !tagText.isEmpty {
            tagLabel.text = " \(tagText) "
            tagLabel.isHidden = false
        } else {
            tagLabel.text = nil
            tagLabel.isHidden = true
        }
        
        // Hide labels without content
        subtitleLabel.isHidden = subtitle.isEmpty
        descriptionLabel.isHidden = description.isEmpty
    }
    
    func setSpacerActive(_ isActive: Bool) {
        spacerView.isHidden = !isActive
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        spacerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create vertical stack for text content
        let textContentStack = UIStackView(arrangedSubviews: [
            titleLabel,
            subtitleLabel,
            descriptionLabel,
            spacerView
        ])
        textContentStack.axis = .vertical
        textContentStack.alignment = .fill
        textContentStack.distribution = .fill
        textContentStack.spacing = Constants.stackSpacing
        textContentStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Set content priorities
        [titleLabel, subtitleLabel, descriptionLabel].forEach { label in
            label.setContentHuggingPriority(.required, for: .vertical)
            label.setContentCompressionResistancePriority(.required, for: .vertical)
        }
        
        // Add subviews
        contentView.addSubview(logoImageView)
        contentView.addSubview(tagLabel)
        contentView.addSubview(textContentStack)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            // Logo constraints
            logoImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Constants.logoTopPadding),
            logoImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Constants.horizontalPadding),
            logoImageView.widthAnchor.constraint(equalToConstant: Constants.logoSize),
            logoImageView.heightAnchor.constraint(equalToConstant: Constants.logoSize),
            
            // Tag constraints
            tagLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Constants.tagTopPadding),
            tagLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Constants.horizontalPadding),
            tagLabel.leadingAnchor.constraint(greaterThanOrEqualTo: logoImageView.trailingAnchor, constant: 8),
            
            // Text stack constraints
            textContentStack.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: Constants.stackTopPadding),
            textContentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Constants.horizontalPadding),
            textContentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Constants.horizontalPadding),
            textContentStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Constants.bottomPadding)
        ])
        
        setSpacerActive(true)
    }
}

// MARK: - CarouselCell
final class CarouselCell: UICollectionViewCell {
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

// MARK: - TitleCell
final class TitleCell: UICollectionViewCell {
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

// MARK: - TitleHeaderView
final class TitleHeaderView: UICollectionReusableView {
    static let reuseIdentifier = "TitleHeaderView"
    
    private var titleLabelLeadingConstraint: NSLayoutConstraint!
    private var titleLabelTrailingConstraint: NSLayoutConstraint!
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .label
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        guard traitCollection.horizontalSizeClass != previousTraitCollection?.horizontalSizeClass ||
              traitCollection.verticalSizeClass != previousTraitCollection?.verticalSizeClass else { return }
        
        updatePaddingForCurrentTraits()
    }
    
    private func updatePaddingForCurrentTraits() {
        let horizontalPadding = padding(for: traitCollection)
        titleLabelLeadingConstraint.constant = horizontalPadding
        titleLabelTrailingConstraint.constant = -horizontalPadding
    }
    
    private func setupUI() {
        backgroundColor = .systemBackground
        addSubview(titleLabel)
        
        titleLabelLeadingConstraint = titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor)
        titleLabelTrailingConstraint = titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            titleLabelLeadingConstraint,
            titleLabelTrailingConstraint
        ])
        
        updatePaddingForCurrentTraits()
    }
    
    private func padding(for traits: UITraitCollection) -> CGFloat {
        // iPhone landscape has 0 padding, all other cases have 16
        if traits.userInterfaceIdiom == .phone && traits.verticalSizeClass == .compact {
            return 0.0
        }
        return 16.0
    }
    
    func configure(title: String) {
        titleLabel.text = title
        accessibilityLabel = title
        isAccessibilityElement = true
    }
}

// MARK: - FullWidthLabelCell
final class FullWidthLabelCell: UICollectionViewCell {
    static let reuseIdentifier = "FullWidthLabelCell"
    
    private let label: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .title2)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(label)
        layer.cornerRadius = 12
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
    }
    
    func configure(title: String, backgroundColor: UIColor) {
        label.text = title
        self.backgroundColor = backgroundColor
    }
}

