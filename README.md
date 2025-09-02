import UIKit

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

@MainActor
final class ViewController: UIViewController {
    
    private var allowShopping: Bool = true
    
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
    
    private var cachedCarouselCellHeight: CGFloat?
    private var shouldRecalculateCarouselHeight = true
    
    private var carouselItems: [(tag: String?, title: String, subtitle: String, description: String)] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        setupCarouselData()
        
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
    
    @objc private func contentSizeCategoryDidChange() {
        shouldRecalculateGridHeight = true
        shouldRecalculateCarouselHeight = true
        collectionView.collectionViewLayout.invalidateLayout()
        collectionView.reloadData()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        guard previousTraitCollection?.horizontalSizeClass != traitCollection.horizontalSizeClass ||
              previousTraitCollection?.verticalSizeClass != traitCollection.verticalSizeClass else { return }
        
        shouldRecalculateGridHeight = true
        shouldRecalculateCarouselHeight = true
        collectionView.collectionViewLayout.invalidateLayout()
        collectionView.reloadData()
    }
    
    private func setupCarouselData() {
        for i in 0..<12 {
            let tag: String? = (i % 3 == 0) ? "Destacado" : nil
            let title = "Item del Carrusel \(i)"
            let subtitle = "Este es el subtítulo para el item \(i)."
            var description = "Descripción breve."
            if i % 4 == 0 {
                description += " Esta descripción es un poco más larga para probar cómo se ajusta la altura de la celda."
            }
            carouselItems.append((tag: tag, title: title, subtitle: subtitle, description: description))
        }
        
        let carouselItemWidth: CGFloat = 132.0
        let cell = CarouselCell()
        cell.configure(with: carouselItems)
        cachedCarouselCellHeight = cell.calculateHeight(forWidth: carouselItemWidth)
    }
    
    private func configureCollectionView() {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.backgroundColor = .clear
        view.addSubview(collectionView)
        
        collectionView.register(ShoppingCell.self, forCellWithReuseIdentifier: ShoppingCell.reuseIdentifier)
        collectionView.register(TitleSubtitleCell.self, forCellWithReuseIdentifier: TitleSubtitleCell.reuseIdentifier)
        collectionView.register(CarouselCell.self, forCellWithReuseIdentifier: CarouselCell.reuseIdentifier)
        collectionView.register(TitleCell.self, forCellWithReuseIdentifier: TitleCell.reuseIdentifier)
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
    
    private func getContentForGridCell(at indexPath: IndexPath) -> (logo: UIImage?, tag: String?, title: String, subtitle: String, description: String) {
        let logoImage = UIImage(systemName: "photo.fill")
        let tag: String?
        let title: String
        let subtitle: String
        let description: String
        
        switch indexPath.item {
        case 0 where allowShopping:
             tag = "Shopping"
             title = "Celda de Shopping (0)"
             subtitle = "Esta celda tiene un diseño especial."
             description = "Su tamaño cambia según la orientación."
        case 5:
            tag = "Exclusive"
            title = "Celda \(indexPath.item)"
            subtitle = "Este es un subtítulo"
            description = "Y finalmente"
        case 2:
            tag = nil
            title = "Celda \(indexPath.item) (Sin Tag)"
            subtitle = "Subtítulo para la celda \(indexPath.item)."
            description = "Esta celda demuestra cómo se adapta el diseño."
        default:
            tag = "New"
            title = "Celda \(indexPath.item)"
            subtitle = "Subtítulo \(indexPath.item)"
            description = "Una descripción estándar para una celda estándar."
        }
        return (logo: logoImage, tag: tag, title: title, subtitle: subtitle, description: description)
    }
}

extension ViewController {
    func createLayout() -> UICollectionViewCompositionalLayout {
        let layout = StickyCarouselHeaderLayout { [weak self] sectionIndex, layoutEnvironment in
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
                return self.createFooterSection()
            }
        }
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
        if shouldRecalculateCarouselHeight || cachedCarouselCellHeight == nil {
            let carouselItemWidth: CGFloat = 132.0
            let cell = CarouselCell()
            cell.configure(with: carouselItems)
            cachedCarouselCellHeight = cell.calculateHeight(forWidth: carouselItemWidth)
            shouldRecalculateCarouselHeight = false
        }
        
        let finalHeight = cachedCarouselCellHeight ?? 180.0
        
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(finalHeight)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: itemSize,
            subitems: [item]
        )
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(
            top: cellSpacing,
            leading: 0,
            bottom: cellSpacing,
            trailing: 0
        )
        
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
    
    private func createGridSection(layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        guard allowShopping else {
            return createUniformGridSection(layoutEnvironment: layoutEnvironment)
        }
        
        let traitCollection = layoutEnvironment.traitCollection
        let isPortrait = traitCollection.verticalSizeClass == .regular && traitCollection.horizontalSizeClass == .compact
        let isIPad = traitCollection.userInterfaceIdiom == .pad
        let gridItemCount = sections.first { $0 == .grid }?.itemCount ?? 0
        
        let cellWidth: CGFloat
        if isIPad || (!isPortrait) {
            let availableWidth = layoutEnvironment.container.effectiveContentSize.width - 32
            cellWidth = (availableWidth - (2 * cellSpacing)) / 3
        } else {
            let availableWidth = layoutEnvironment.container.effectiveContentSize.width - 32
            cellWidth = (availableWidth - cellSpacing) / 2
        }
        
        if shouldRecalculateGridHeight || cachedGridCellHeight == nil {
            cachedGridCellHeight = calculateMaxGridCellHeight(for: cellWidth)
            shouldRecalculateGridHeight = false
        }
        
        let finalHeight = cachedGridCellHeight ?? 184.0
        
        let containerGroupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(2000)
        )
        
        var subitems: [NSCollectionLayoutGroup] = []
        
        if isIPad {
            if gridItemCount > 0 {
                let fullWidthItemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(finalHeight))
                let fullWidthItem = NSCollectionLayoutItem(layoutSize: fullWidthItemSize)
                subitems.append(NSCollectionLayoutGroup.vertical(layoutSize: fullWidthItemSize, subitems: [fullWidthItem]))
            }
            
            let remainingItems = gridItemCount - 1
            if remainingItems > 0 {
                let thirdWidthItemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1/3), heightDimension: .fractionalHeight(1.0))
                let thirdWidthItem = NSCollectionLayoutItem(layoutSize: thirdWidthItemSize)
                
                let tripletGroupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(finalHeight))
                let tripletGroup = NSCollectionLayoutGroup.horizontal(layoutSize: tripletGroupSize, subitems: [thirdWidthItem, thirdWidthItem, thirdWidthItem])
                tripletGroup.interItemSpacing = .fixed(cellSpacing)
                
                for _ in 0..<(remainingItems / 3) {
                    subitems.append(tripletGroup)
                }
                
                let leftoverCount = remainingItems % 3
                if leftoverCount > 0 {
                    let leftoverItems = Array(repeating: thirdWidthItem, count: leftoverCount)
                    let leftoverGroup = NSCollectionLayoutGroup.horizontal(layoutSize: tripletGroupSize, subitems: leftoverItems)
                    leftoverGroup.interItemSpacing = .fixed(cellSpacing)
                    subitems.append(leftoverGroup)
                }
            }
        } else if isPortrait {
            if gridItemCount > 0 {
                let fullWidthItemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(finalHeight))
                let fullWidthItem = NSCollectionLayoutItem(layoutSize: fullWidthItemSize)
                subitems.append(NSCollectionLayoutGroup.vertical(layoutSize: fullWidthItemSize, subitems: [fullWidthItem]))
            }
            
            let remainingItems = gridItemCount - 1
            if remainingItems > 0 {
                let halfWidthItemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5), heightDimension: .fractionalHeight(1.0))
                let halfWidthItem = NSCollectionLayoutItem(layoutSize: halfWidthItemSize)
                
                let pairGroupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(finalHeight))
                let pairGroup = NSCollectionLayoutGroup.horizontal(layoutSize: pairGroupSize, subitems: [halfWidthItem, halfWidthItem])
                pairGroup.interItemSpacing = .fixed(cellSpacing)
                
                for _ in 0..<(remainingItems / 2) {
                    subitems.append(pairGroup)
                }
                
                if remainingItems % 2 != 0 {
                    let soloGroup = NSCollectionLayoutGroup.horizontal(layoutSize: pairGroupSize, subitems: [halfWidthItem])
                    subitems.append(soloGroup)
                }
            }
        } else {
            let availableWidth = layoutEnvironment.container.effectiveContentSize.width - 32
            let standardColumnWidth = (availableWidth - (2 * cellSpacing)) / 3
            
            if gridItemCount > 0 {
                let shoppingItemSize = NSCollectionLayoutSize(
                    widthDimension: .absolute(standardColumnWidth * 2 + cellSpacing),
                    heightDimension: .fractionalHeight(1.0)
                )
                let shoppingItem = NSCollectionLayoutItem(layoutSize: shoppingItemSize)
                
                let regularItemSize = NSCollectionLayoutSize(
                    widthDimension: .absolute(standardColumnWidth),
                    heightDimension: .fractionalHeight(1.0)
                )
                let regularItem = NSCollectionLayoutItem(layoutSize: regularItemSize)
                
                let firstRowGroupSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .absolute(finalHeight)
                )
                
                if gridItemCount > 1 {
                    let firstRowGroup = NSCollectionLayoutGroup.horizontal(
                        layoutSize: firstRowGroupSize,
                        subitems: [shoppingItem, regularItem]
                    )
                    firstRowGroup.interItemSpacing = .fixed(cellSpacing)
                    subitems.append(firstRowGroup)
                } else {
                    let firstRowGroup = NSCollectionLayoutGroup.horizontal(
                        layoutSize: firstRowGroupSize,
                        subitems: [shoppingItem]
                    )
                    subitems.append(firstRowGroup)
                }
            }
            
            let remainingItems = gridItemCount - 2
            if remainingItems > 0 {
                let standardItemSize = NSCollectionLayoutSize(
                    widthDimension: .absolute(standardColumnWidth),
                    heightDimension: .fractionalHeight(1.0)
                )
                let standardItem = NSCollectionLayoutItem(layoutSize: standardItemSize)
                
                let tripletGroupSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .absolute(finalHeight)
                )
                
                for _ in 0..<(remainingItems / 3) {
                    let tripletGroup = NSCollectionLayoutGroup.horizontal(
                        layoutSize: tripletGroupSize,
                        subitems: [standardItem, standardItem, standardItem]
                    )
                    tripletGroup.interItemSpacing = .fixed(cellSpacing)
                    subitems.append(tripletGroup)
                }
                
                let leftoverCount = remainingItems % 3
                if leftoverCount > 0 {
                    let leftoverItems = Array(repeating: standardItem, count: leftoverCount)
                    let leftoverGroup = NSCollectionLayoutGroup.horizontal(
                        layoutSize: tripletGroupSize,
                        subitems: leftoverItems
                    )
                    leftoverGroup.interItemSpacing = .fixed(cellSpacing)
                    subitems.append(leftoverGroup)
                }
            }
        }
        
        let containerGroup = NSCollectionLayoutGroup.vertical(layoutSize: containerGroupSize, subitems: subitems)
        containerGroup.interItemSpacing = .fixed(cellSpacing)
        
        let section = NSCollectionLayoutSection(group: containerGroup)
        section.contentInsets = NSDirectionalEdgeInsets(top: cellSpacing, leading: 16, bottom: cellSpacing, trailing: 16)
        
        return section
    }
    
    private func createUniformGridSection(layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let containerWidth = layoutEnvironment.container.effectiveContentSize.width
       
        let isPortrait = traitCollection.verticalSizeClass == .regular && traitCollection.horizontalSizeClass == .compact
        let isIPad = traitCollection.userInterfaceIdiom == .pad
        
        let columnCount: Int
        if isIPad {
            columnCount = 3
        } else if isPortrait {
            columnCount = 2
        } else {
            columnCount = 3
        }
        
        let sectionInset: CGFloat = 16.0
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
        
        if shouldRecalculateGridHeight || cachedGridCellHeight == nil {
            cachedGridCellHeight = calculateMaxGridCellHeight(for: cellWidth)
            shouldRecalculateGridHeight = false
        }
        
        let finalHeight = cachedGridCellHeight ?? 184.0
        
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0 / CGFloat(columnCount)),
            heightDimension: .fractionalHeight(1.0)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(finalHeight)
        )
        
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            repeatingSubitem: item,
            count: columnCount
        )
        group.interItemSpacing = .fixed(cellSpacing)
        
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = cellSpacing
        section.contentInsets = NSDirectionalEdgeInsets(
            top: cellSpacing,
            leading: sectionInset,
            bottom: cellSpacing,
            trailing: sectionInset
        )
        
        return section
    }

    private func createFooterSection() -> NSCollectionLayoutSection {
        return createListSection()
    }

    private func calculateMaxGridCellHeight(for cellWidth: CGFloat) -> CGFloat {
        var maxHeight: CGFloat = 0
        let titleSubtitleSizingCell = TitleSubtitleCell()
        let shoppingSizingCell = ShoppingCell()
        
        guard let gridSectionIndex = sections.firstIndex(of: .grid) else { return 184.0 }
        let totalItems = sections[gridSectionIndex].itemCount
        
        for itemIndex in 0..<totalItems {
            let indexPath = IndexPath(item: itemIndex, section: gridSectionIndex)
            let content = getContentForGridCell(at: indexPath)
            
            let requiredSize: CGSize
            
            if allowShopping && indexPath.item == 0 {
                shoppingSizingCell.configure(logo: content.logo, tag: content.tag, title: content.title, subtitle: content.subtitle, description: content.description)
                requiredSize = shoppingSizingCell.systemLayoutSizeFitting(
                    CGSize(width: cellWidth, height: 0),
                    withHorizontalFittingPriority: .required,
                    verticalFittingPriority: .fittingSizeLevel
                )
            } else {
                titleSubtitleSizingCell.configure(logo: content.logo, tag: content.tag, title: content.title, subtitle: content.subtitle, description: content.description)
                requiredSize = titleSubtitleSizingCell.systemLayoutSizeFitting(
                    CGSize(width: cellWidth, height: 0),
                    withHorizontalFittingPriority: .required,
                    verticalFittingPriority: .fittingSizeLevel
                )
            }
            
            maxHeight = max(maxHeight, requiredSize.height)
        }
        
        return maxHeight
    }
}

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
            
            cell.configure(with: carouselItems)
            cell.backgroundColor = .clear
            return cell
            
        case .grid:
            let content = getContentForGridCell(at: indexPath)
            
            if allowShopping && indexPath.item == 0 {
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: ShoppingCell.reuseIdentifier,
                    for: indexPath
                ) as! ShoppingCell
                cell.configure(logo: content.logo, tag: content.tag, title: content.title, subtitle: content.subtitle, description: content.description)
                return cell
            } else {
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: TitleSubtitleCell.reuseIdentifier,
                    for: indexPath
                ) as! TitleSubtitleCell
                cell.configure(logo: content.logo, tag: content.tag, title: content.title, subtitle: content.subtitle, description: content.description)
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

extension ViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        
        let sectionType = sections[indexPath.section]
        print("Selected item at section: \(sectionType), item: \(indexPath.item)")
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    func collectionView(_ collectionView: UICollectionView,
                       willDisplay cell: UICollectionViewCell,
                       forItemAt indexPath: IndexPath) {
        if let carouselCell = cell as? CarouselCell {
            carouselCell.invalidateCarouselLayout()
        }
        
        cell.alpha = 0
        UIView.animate(withDuration: 0.3) {
            cell.alpha = 1
        }
    }
}
















import UIKit

final class TitleSubtitleCell: UICollectionViewCell {
    static let reuseIdentifier = "TitleSubtitleCell"
    
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
    
    private let tagLabel: UILabel = {
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
    
    private enum Constants {
        static let logoTopPadding: CGFloat = 12
        static let logoSize: CGFloat = 56
        static let horizontalPadding: CGFloat = 12
        static let tagTopPadding: CGFloat = 12
        static let stackTopPadding: CGFloat = 8
        static let stackSpacing: CGFloat = 4
        static let bottomPadding: CGFloat = 12
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(logo: UIImage?, tag: String?, title: String, subtitle: String, description: String) {
        logoImageView.image = logo ?? UIImage(systemName: "photo.fill")
        titleLabel.text = title
        subtitleLabel.text = subtitle
        descriptionLabel.text = description
        
        if let tagText = tag, !tagText.isEmpty {
            tagLabel.text = " \(tagText) "
            tagLabel.isHidden = false
        } else {
            tagLabel.text = nil
            tagLabel.isHidden = true
        }
        
        subtitleLabel.isHidden = subtitle.isEmpty
        descriptionLabel.isHidden = description.isEmpty
    }
    
    private func setupUI() {
        let textContentStack = UIStackView(arrangedSubviews: [
            titleLabel,
            subtitleLabel,
            descriptionLabel
        ])
        textContentStack.axis = .vertical
        textContentStack.alignment = .leading
        textContentStack.distribution = .fill
        textContentStack.spacing = Constants.stackSpacing
        textContentStack.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(logoImageView)
        contentView.addSubview(tagLabel)
        contentView.addSubview(textContentStack)
        
        NSLayoutConstraint.activate([
            logoImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Constants.logoTopPadding),
            logoImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Constants.horizontalPadding),
            logoImageView.widthAnchor.constraint(equalToConstant: Constants.logoSize),
            logoImageView.heightAnchor.constraint(equalToConstant: Constants.logoSize),
            
            tagLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Constants.tagTopPadding),
            tagLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Constants.horizontalPadding),
            tagLabel.leadingAnchor.constraint(greaterThanOrEqualTo: logoImageView.trailingAnchor, constant: 8),
            
            textContentStack.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: Constants.stackTopPadding),
            textContentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Constants.horizontalPadding),
            textContentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Constants.horizontalPadding),
            textContentStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -Constants.bottomPadding)
        ])
    }
}

import UIKit

@MainActor
protocol CarouselHeightCalculator {
    func calculateHeight(forWidth width: CGFloat) -> CGFloat
}

import UIKit

final class CarouselCell: UICollectionViewCell, CarouselHeightCalculator {
    static let reuseIdentifier = "CarouselCell"
    
    private var carouselCollectionView: UICollectionView!
    private var items: [(tag: String?, title: String, subtitle: String, description: String)] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCollectionView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(with items: [(tag: String?, title: String, subtitle: String, description: String)]) {
        self.items = items
        self.carouselCollectionView.reloadData()
    }

    private func setupCollectionView() {
        let layout = UICollectionViewCompositionalLayout { (sectionIndex, layoutEnvironment) -> NSCollectionLayoutSection? in
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .absolute(132),
                heightDimension: .fractionalHeight(1.0)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            let groupSize = NSCollectionLayoutSize(
                widthDimension: .absolute(132),
                heightDimension: .fractionalHeight(1.0)
            )
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
            
            let section = NSCollectionLayoutSection(group: group)
            section.orthogonalScrollingBehavior = .continuous
            section.interGroupSpacing = 12
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
            
            return section
        }

        carouselCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        carouselCollectionView.translatesAutoresizingMaskIntoConstraints = false
        carouselCollectionView.backgroundColor = .clear
        carouselCollectionView.dataSource = self
        carouselCollectionView.delegate = self
        
        carouselCollectionView.register(TitleSubtitleCell.self, forCellWithReuseIdentifier: TitleSubtitleCell.reuseIdentifier)
        
        contentView.addSubview(carouselCollectionView)
        
        NSLayoutConstraint.activate([
            carouselCollectionView.topAnchor.constraint(equalTo: contentView.topAnchor),
            carouselCollectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            carouselCollectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            carouselCollectionView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
    
    func invalidateCarouselLayout() {
        carouselCollectionView.collectionViewLayout.invalidateLayout()
    }
    
    func calculateHeight(forWidth width: CGFloat) -> CGFloat {
        var maxHeight: CGFloat = 0
        let sizingCell = TitleSubtitleCell()
        
        for item in items {
            sizingCell.configure(
                logo: nil,
                tag: item.tag,
                title: item.title,
                subtitle: item.subtitle,
                description: item.description
            )
            
            let requiredSize = sizingCell.systemLayoutSizeFitting(
                CGSize(width: width, height: 0),
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel
            )
            
            maxHeight = max(maxHeight, requiredSize.height)
        }
        
        return maxHeight + 16
    }
}

extension CarouselCell: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TitleSubtitleCell.reuseIdentifier, for: indexPath) as! TitleSubtitleCell
        
        let item = items[indexPath.item]
        let logoImage = UIImage(systemName: "star.fill")
        
        cell.configure(
            logo: logoImage,
            tag: item.tag,
            title: item.title,
            subtitle: item.subtitle,
            description: item.description
        )
        
        cell.backgroundColor = .systemGray5
        cell.layer.cornerRadius = 10
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        print("Item del carrusel interno seleccionado: \(indexPath.item)")
    }
}

import UIKit

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

import UIKit

// --- INICIO: NUEVO ARCHIVO ---
final class ShoppingCell: UICollectionViewCell {
    static let reuseIdentifier = "ShoppingCell"
    
    // UI y diseño idénticos a TitleSubtitleCell
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
    
    private let tagLabel: UILabel = {
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
    
    private enum Constants {
        static let logoTopPadding: CGFloat = 12
        static let logoSize: CGFloat = 56
        static let horizontalPadding: CGFloat = 12
        static let tagTopPadding: CGFloat = 12
        static let stackTopPadding: CGFloat = 8
        static let stackSpacing: CGFloat = 4
        static let bottomPadding: CGFloat = 12
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        // Requerimiento: Fondo amarillo y esquinas redondeadas
        backgroundColor = .systemYellow
        layer.cornerRadius = 12
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(logo: UIImage?, tag: String?, title: String, subtitle: String, description: String) {
        logoImageView.image = logo ?? UIImage(systemName: "photo.fill")
        titleLabel.text = title
        subtitleLabel.text = subtitle
        descriptionLabel.text = description
        
        if let tagText = tag, !tagText.isEmpty {
            tagLabel.text = " \(tagText) "
            tagLabel.isHidden = false
        } else {
            tagLabel.text = nil
            tagLabel.isHidden = true
        }
        
        subtitleLabel.isHidden = subtitle.isEmpty
        descriptionLabel.isHidden = description.isEmpty
    }
    
    private func setupUI() {
        let textContentStack = UIStackView(arrangedSubviews: [
            titleLabel,
            subtitleLabel,
            descriptionLabel
        ])
        textContentStack.axis = .vertical
        textContentStack.alignment = .leading
        textContentStack.distribution = .fill
        textContentStack.spacing = Constants.stackSpacing
        textContentStack.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(logoImageView)
        contentView.addSubview(tagLabel)
        contentView.addSubview(textContentStack)
        
        NSLayoutConstraint.activate([
            logoImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Constants.logoTopPadding),
            logoImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Constants.horizontalPadding),
            logoImageView.widthAnchor.constraint(equalToConstant: Constants.logoSize),
            logoImageView.heightAnchor.constraint(equalToConstant: Constants.logoSize),
            
            tagLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Constants.tagTopPadding),
            tagLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Constants.horizontalPadding),
            tagLabel.leadingAnchor.constraint(greaterThanOrEqualTo: logoImageView.trailingAnchor, constant: 8),
            
            textContentStack.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: Constants.stackTopPadding),
            textContentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Constants.horizontalPadding),
            textContentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Constants.horizontalPadding),
            textContentStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -Constants.bottomPadding)
        ])
    }
}



