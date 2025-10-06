import UIKit

// MARK: - ViewController con Solución Híbrida
@MainActor
final class ViewController: UIViewController {
    
    // MARK: - Properties
    private var sectionDataManager: SectionDataManager!
    private var collectionView: UICollectionView!
    
    private typealias DataSource = UICollectionViewDiffableDataSource<Section, ItemIdentifier>
    private typealias Snapshot = NSDiffableDataSourceSnapshot<Section, ItemIdentifier>
    
    private var dataSource: DataSource!
    
    private let cellSpacing: CGFloat = 16.0
    private var expandedListSection: Int?
    
    // Cache for cell heights
    private var cachedGridCellHeight: CGFloat?
    private var shouldRecalculateGridHeight = true
    private var cachedCarouselCellHeight: CGFloat?
    private var shouldRecalculateCarouselHeight = true
    
    private var horizontalPadding: CGFloat {
        let traits = view.traitCollection
        if traits.userInterfaceIdiom == .pad { return 16.0 }
        if traits.verticalSizeClass == .compact { return 0.0 }
        return 16.0
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupDataManager()
        setupView()
        setupNotifications()
        configureCollectionView()
        configureDataSource()
        applySnapshot(animatingDifferences: false)
        
        if let carouselSectionIndex = sectionDataManager.sections.firstIndex(where: { $0.type == .carousel }) {
            (collectionView.collectionViewLayout as? StickyCarouselHeaderLayout)?.stickyHeaderSection = carouselSectionIndex
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.collectionView.collectionViewLayout.invalidateLayout()
        })
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.horizontalSizeClass != previousTraitCollection?.horizontalSizeClass ||
           traitCollection.verticalSizeClass != previousTraitCollection?.verticalSizeClass {
            invalidateCacheAndApplySnapshot()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup Methods
    private func setupDataManager() {
        sectionDataManager = SectionDataManager(
            isValueEnabled: true,
            isShoppingEnabled: true,
            experience: .list
        )
        sectionDataManager.onSectionsDidUpdate = { [weak self] in
            self?.handleDataUpdate()
        }
    }
    
    private func setupView() {
        view.backgroundColor = .systemBackground
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contentSizeCategoryDidChange),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )
    }
    
    private func configureCollectionView() {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.delegate = self
        collectionView.backgroundColor = .clear
        view.addSubview(collectionView)
        
        registerCellsAndHeaders()
        setupConstraints()
    }
    
    private func registerCellsAndHeaders() {
        // Register cells
        collectionView.register(InfoCell.self, forCellWithReuseIdentifier: InfoCell.reuseIdentifier)
        collectionView.register(CarouselCell.self, forCellWithReuseIdentifier: CarouselCell.reuseIdentifier)
        collectionView.register(ValueCell.self, forCellWithReuseIdentifier: ValueCell.reuseIdentifier)
        collectionView.register(ShoppingCell.self, forCellWithReuseIdentifier: ShoppingCell.reuseIdentifier)
        collectionView.register(TitleSubtitleCell.self, forCellWithReuseIdentifier: TitleSubtitleCell.reuseIdentifier)
        collectionView.register(FooterCell.self, forCellWithReuseIdentifier: FooterCell.reuseIdentifier)
        collectionView.register(ListDetailCell.self, forCellWithReuseIdentifier: ListDetailCell.reuseIdentifier)
        
        // Register headers
        collectionView.register(TitleHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: TitleHeaderView.reuseIdentifier)
        collectionView.register(TabBarHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: TabBarHeaderView.reuseIdentifier)
        collectionView.register(ListHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: ListHeaderView.reuseIdentifier)
        collectionView.register(UICollectionReusableView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "blankHeader")
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    // MARK: - Data Updates
    private func handleDataUpdate() {
        invalidateCacheAndApplySnapshot()
    }
    
    private func invalidateCacheAndApplySnapshot() {
        shouldRecalculateGridHeight = true
        shouldRecalculateCarouselHeight = true
        collectionView.collectionViewLayout.invalidateLayout()
        applySnapshot()
    }
    
    @objc private func contentSizeCategoryDidChange() {
        invalidateCacheAndApplySnapshot()
    }
    
    // MARK: - Hybrid Solution Implementation
    
    /// Updates a ContentModel without causing scroll jumps
    private func updateContentModelWithHybridSolution(_ updatedModel: ContentModel) {
        // 1. Update the model in data manager
        sectionDataManager.updateContentModel(updatedModel)
        
        // 2. Update visible cells directly (no scroll jump)
        updateVisibleCells(for: updatedModel)
        
        // 3. Update data source for consistency
        if #available(iOS 15.0, *) {
            updateSnapshotWithReconfigure(for: updatedModel)
        } else {
            updateDataSourceSilently(for: updatedModel)
        }
    }
    
    /// Updates all visible cells that display the given model
    private func updateVisibleCells(for model: ContentModel) {
        let visibleIndexPaths = collectionView.indexPathsForVisibleItems
        
        for indexPath in visibleIndexPaths {
            guard let section = sectionDataManager.getSection(at: indexPath.section) else { continue }
            
            switch section.type {
            case .carousel:
                // For carousel, check if any item in the carousel matches
                if section.items.contains(where: { ($0 as? ContentModel)?.id == model.id }),
                   let cell = collectionView.cellForItem(at: indexPath) as? CarouselCell {
                    let items = section.items.compactMap { $0 as? ContentModel }
                    cell.configure(with: items)
                }
                
            case .grid, .list:
                // For grid/list, check the specific item at this index
                if let item = section.items[safe: indexPath.item] as? ContentModel,
                   item.id == model.id,
                   let cell = collectionView.cellForItem(at: indexPath) {
                    configureCell(cell, at: indexPath, with: model)
                }
                
            default:
                break
            }
        }
        
        // Also update visible headers if they contain the model
        updateVisibleHeaders(for: model)
    }
    
    /// Updates visible headers that display the given model
    private func updateVisibleHeaders(for model: ContentModel) {
        let visibleSections = Set(collectionView.indexPathsForVisibleItems.map { $0.section })
        
        for sectionIndex in visibleSections {
            guard let section = sectionDataManager.getSection(at: sectionIndex),
                  let header = sectionDataManager.getHeader(for: sectionIndex) else { continue }
            
            if case .list(let headerModel) = header,
               headerModel.id == model.id {
                let indexPath = IndexPath(item: 0, section: sectionIndex)
                if let headerView = collectionView.supplementaryView(
                    forElementKind: UICollectionView.elementKindSectionHeader,
                    at: indexPath
                ) as? ListHeaderView {
                    headerView.configure(with: model)
                }
            }
        }
    }
    
    /// Configures a cell with the updated model
    private func configureCell(_ cell: UICollectionViewCell, at indexPath: IndexPath, with model: ContentModel) {
        switch cell {
        case let titleCell as TitleSubtitleCell:
            titleCell.configure(with: model)
        case let valueCell as ValueCell:
            valueCell.configure(with: model)
        case let shoppingCell as ShoppingCell:
            shoppingCell.configure(with: model)
        case let listDetailCell as ListDetailCell:
            listDetailCell.configure(with: model)
        default:
            break
        }
    }
    
    /// Updates snapshot using reconfigureItems (iOS 15+)
    @available(iOS 15.0, *)
    private func updateSnapshotWithReconfigure(for model: ContentModel) {
        var snapshot = dataSource.snapshot()
        var itemsToReconfigure: [ItemIdentifier] = []
        
        for section in sectionDataManager.sections {
            switch section.type {
            case .carousel:
                // For carousel, reconfigure if it contains the model
                if section.items.contains(where: { ($0 as? ContentModel)?.id == model.id }) {
                    let carouselIdentifiers = snapshot.itemIdentifiers(inSection: section)
                    itemsToReconfigure.append(contentsOf: carouselIdentifiers)
                }
                
            case .grid, .list:
                // For grid/list, find the specific item
                if let itemIndex = section.items.firstIndex(where: { ($0 as? ContentModel)?.id == model.id }) {
                    let sectionIdentifiers = snapshot.itemIdentifiers(inSection: section)
                    if itemIndex < sectionIdentifiers.count {
                        itemsToReconfigure.append(sectionIdentifiers[itemIndex])
                    }
                }
                
            default:
                break
            }
        }
        
        if !itemsToReconfigure.isEmpty {
            snapshot.reconfigureItems(itemsToReconfigure)
            dataSource.apply(snapshot, animatingDifferences: false)
        }
    }
    
    /// Updates data source without causing visual changes (iOS 14 fallback)
    private func updateDataSourceSilently(for model: ContentModel) {
        // For iOS 14, we rely on the visible cell updates
        // and only update the snapshot if absolutely necessary
        
        // Check if model is in non-visible area
        let visibleIndexPaths = collectionView.indexPathsForVisibleItems
        var isModelVisible = false
        
        for indexPath in visibleIndexPaths {
            if let section = sectionDataManager.getSection(at: indexPath.section) {
                switch section.type {
                case .carousel:
                    if section.items.contains(where: { ($0 as? ContentModel)?.id == model.id }) {
                        isModelVisible = true
                        break
                    }
                case .grid, .list:
                    if let item = section.items[safe: indexPath.item] as? ContentModel,
                       item.id == model.id {
                        isModelVisible = true
                        break
                    }
                default:
                    break
                }
            }
        }
        
        // Only update snapshot if model is not visible
        // This ensures data consistency for scrolling
        if !isModelVisible {
            var snapshot = dataSource.snapshot()
            // Mark for update without reloading
            dataSource.apply(snapshot, animatingDifferences: false)
        }
    }
    
    // MARK: - Modified reload methods using hybrid solution
    
    private func reloadSectionsContainingModel(_ model: ContentModel) {
        // Use hybrid solution instead of full reload
        updateContentModelWithHybridSolution(model)
    }
    
    // MARK: - Data Source Configuration
    private func configureDataSource() {
        dataSource = DataSource(collectionView: collectionView) { [weak self] (collectionView, indexPath, itemIdentifier) -> UICollectionViewCell? in
            guard let self = self else { return nil }
            
            guard let section = self.sectionDataManager.getSection(at: indexPath.section) else { return nil }
            
            switch section.type {
            case .info:
                guard let model = section.items[safe: indexPath.item] as? InfoModel else { return nil }
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: InfoCell.reuseIdentifier, for: indexPath) as! InfoCell
                cell.configure(with: model)
                return cell
                
            case .carousel:
                let items = section.items.compactMap { $0 as? ContentModel }
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CarouselCell.reuseIdentifier, for: indexPath) as! CarouselCell
                cell.configure(with: items)
                
                cell.onItemSelect = { [weak self] selectedModel in
                    guard let self = self else { return }
                    var updatedModel = selectedModel
                    updatedModel.isSelected.toggle()
                    // Use hybrid solution
                    self.updateContentModelWithHybridSolution(updatedModel)
                }
                return cell
                
            case .grid:
                guard let item = section.items[safe: indexPath.item] as? ContentModel else { return nil }
                
                if self.sectionDataManager.shouldUseShoppingCell(at: indexPath) {
                    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ShoppingCell.reuseIdentifier, for: indexPath) as! ShoppingCell
                    cell.configure(with: item)
                    return cell
                } else if self.sectionDataManager.shouldUseValueCell(at: indexPath) {
                    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ValueCell.reuseIdentifier, for: indexPath) as! ValueCell
                    cell.configure(with: item)
                    return cell
                } else {
                    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TitleSubtitleCell.reuseIdentifier, for: indexPath) as! TitleSubtitleCell
                    cell.configure(with: item)
                    return cell
                }
                
            case .list:
                guard let item = section.items.first as? ContentModel else { return nil }
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ListDetailCell.reuseIdentifier, for: indexPath) as! ListDetailCell
                cell.configure(with: item)
                return cell
                
            case .footer:
                guard let model = section.items[safe: indexPath.item] as? FooterModel else { return nil }
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FooterCell.reuseIdentifier, for: indexPath) as! FooterCell
                cell.configure(with: model)
                return cell
            }
        }
        
        dataSource.supplementaryViewProvider = { [weak self] (collectionView, kind, indexPath) -> UICollectionReusableView? in
            guard let self = self, kind == UICollectionView.elementKindSectionHeader else {
                return collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "blankHeader", for: indexPath)
            }
            
            guard let headerModel = self.sectionDataManager.getHeader(for: indexPath.section) else {
                return collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "blankHeader", for: indexPath)
            }
            
            switch headerModel {
            case .title(let title):
                let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: TitleHeaderView.reuseIdentifier, for: indexPath) as! TitleHeaderView
                header.configure(with: title)
                return header
                
            case .tabBar(let tabs, let selectedIndex):
                let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: TabBarHeaderView.reuseIdentifier, for: indexPath) as! TabBarHeaderView
                header.delegate = self
                
                let tabsToUse = tabs.isEmpty ? self.sectionDataManager.tabData : tabs
                header.configure(
                    with: tabsToUse,
                    selectedIndex: selectedIndex,
                    horizontalPadding: self.horizontalPadding
                )
                return header
                
            case .list(let item):
                let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: ListHeaderView.reuseIdentifier, for: indexPath) as! ListHeaderView
                header.configure(with: item)
                
                header.onHeaderSelect = { [weak self] selectedModel in
                    guard let self = self else { return }
                    guard !selectedModel.isLoading else { return }
                    
                    var loadingModel = selectedModel
                    loadingModel.isLoading = true
                    loadingModel.isSelected = true
                    
                    // Use hybrid solution
                    self.updateContentModelWithHybridSolution(loadingModel)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        var finishedModel = loadingModel
                        finishedModel.isLoading = false
                        
                        // Use hybrid solution
                        self.updateContentModelWithHybridSolution(finishedModel)
                    }
                }
                
                header.onDetailsButtonTapped = { [weak self] in
                    self?.toggleListDetails(at: indexPath.section)
                }
                return header
            }
        }
    }
    
    // MARK: - Snapshot Management
    private func applySnapshot(animatingDifferences: Bool = true) {
        var snapshot = Snapshot()
        let sections = sectionDataManager.sections
        snapshot.appendSections(sections)
        
        for section in sections {
            let items: [ItemIdentifier] = createItemIdentifiers(for: section)
            snapshot.appendItems(items, toSection: section)
        }
        
        dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
    }
    
    private func createItemIdentifiers(for section: Section) -> [ItemIdentifier] {
        switch section.type {
        case .info, .footer:
            return section.items.map { item in
                let itemId = (item as? (any IdentifiableItem))?.id ?? UUID()
                return ItemIdentifier(
                    id: itemId,
                    sectionId: section.id,
                    type: .single(itemId)
                )
            }
        case .grid, .list:
            return section.items.map { item in
                let itemId = (item as? (any IdentifiableItem))?.id ?? UUID()
                return ItemIdentifier(
                    id: itemId,
                    sectionId: section.id,
                    type: .single(itemId)
                )
            }
        case .carousel:
            return section.items.isEmpty ? [] : [
                ItemIdentifier(
                    id: UUID(),
                    sectionId: section.id,
                    type: .carousel
                )
            ]
        }
    }
    
    private func toggleListDetails(at sectionIndex: Int) {
        let previouslyExpanded = expandedListSection
        let isCollapsing = previouslyExpanded == sectionIndex
        
        if let oldIndex = previouslyExpanded, !isCollapsing {
            if let oldSection = sectionDataManager.getSection(at: oldIndex),
               var oldModel = oldSection.items.first as? ContentModel {
                oldModel.isDetailsVisible = false
                // Use hybrid solution
                updateContentModelWithHybridSolution(oldModel)
            }
        }
        
        if let currentSection = sectionDataManager.getSection(at: sectionIndex),
           var currentModel = currentSection.items.first as? ContentModel {
            currentModel.isDetailsVisible.toggle()
            // Use hybrid solution
            updateContentModelWithHybridSolution(currentModel)
        }
        
        expandedListSection = isCollapsing ? nil : sectionIndex
        
        // For structural changes like expanding/collapsing, we need a full snapshot update
        applySnapshot()
    }
    
    // MARK: - Layout Creation
    func createLayout() -> UICollectionViewCompositionalLayout {
        let layout = StickyCarouselHeaderLayout { [weak self] sectionIndex, layoutEnvironment in
            guard let self, let section = self.sectionDataManager.getSection(at: sectionIndex) else {
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(1))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                return NSCollectionLayoutSection(group: group)
            }
            
            switch section.type {
            case .info:
                return self.createInfoSection()
            case .carousel:
                return self.createCarouselSection(for: sectionIndex, layoutEnvironment: layoutEnvironment)
            case .grid:
                return self.createGridSection(for: sectionIndex, layoutEnvironment: layoutEnvironment)
            case .list:
                return self.createListSection(for: sectionIndex, layoutEnvironment: layoutEnvironment)
            case .footer:
                return self.createFooterSection(layoutEnvironment: layoutEnvironment)
            }
        }
        
        if let carouselSectionIndex = sectionDataManager.sections.firstIndex(where: { $0.type == .carousel }) {
            layout.stickyHeaderSection = carouselSectionIndex
        }
        return layout
    }
    
    private func createInfoSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(100))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = cellSpacing
        section.contentInsets = NSDirectionalEdgeInsets(top: cellSpacing, leading: horizontalPadding, bottom: cellSpacing, trailing: horizontalPadding)
        return section
    }
    
    private func createCarouselSection(for sectionIndex: Int, layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        if shouldRecalculateCarouselHeight || cachedCarouselCellHeight == nil {
            cachedCarouselCellHeight = calculateCarouselHeight(in: sectionIndex)
            shouldRecalculateCarouselHeight = false
        }
        let finalHeight = cachedCarouselCellHeight ?? 220.0
        
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(finalHeight)
        )
        
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: itemSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        
        section.contentInsetsReference = .none
        
        let isLandscape = layoutEnvironment.traitCollection.verticalSizeClass == .compact
        let horizontalInset: CGFloat = isLandscape ? 0 : horizontalPadding
        
        section.contentInsets = NSDirectionalEdgeInsets(
            top: cellSpacing,
            leading: horizontalInset,
            bottom: cellSpacing,
            trailing: horizontalInset
        )
        
        if let headerModel = sectionDataManager.getHeader(for: sectionIndex), case .tabBar = headerModel {
            section.boundarySupplementaryItems = [createTabBarHeader()]
        }
        return section
    }
    
    private func createGridSection(for sectionIndex: Int, layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let hasValueCell = sectionDataManager.shouldUseValueCell(at: IndexPath(item: 0, section: sectionIndex))
        let hasShoppingCell = sectionDataManager.isShoppingEnabled && sectionDataManager.numberOfItems(in: sectionIndex) > 20
        
        let section = (hasValueCell || hasShoppingCell) ?
            createMixedGridLayoutSection(for: sectionIndex, layoutEnvironment: layoutEnvironment) :
            createUniformGridSection(for: sectionIndex, layoutEnvironment: layoutEnvironment)
        
        if sectionDataManager.getHeader(for: sectionIndex) != nil {
            section.boundarySupplementaryItems = [createHeader(estimatedHeight: 44)]
        }
        return section
    }
    
    private func createMixedGridLayoutSection(for sectionIndex: Int, layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let traitCollection = layoutEnvironment.traitCollection
        let isPortrait = traitCollection.verticalSizeClass == .regular && traitCollection.horizontalSizeClass == .compact
        let isIPad = traitCollection.userInterfaceIdiom == .pad
        let itemCount = sectionDataManager.numberOfItems(in: sectionIndex)
        let hasValueCell = sectionDataManager.isValueEnabled
        
        let columnCount = (isIPad || !isPortrait) ? 3 : 2
        
        sectionDataManager.updateShoppingCellIndex(columnCount: columnCount)
        
        let dynamicShoppingCellIndex = sectionDataManager.currentShoppingCellIndex
        
        let cellWidth: CGFloat
        let availableWidth = layoutEnvironment.container.effectiveContentSize.width - (horizontalPadding * 2)
        if columnCount > 1 {
            cellWidth = (availableWidth - (CGFloat(columnCount - 1) * cellSpacing)) / CGFloat(columnCount)
        } else {
            cellWidth = availableWidth
        }
        
        if shouldRecalculateGridHeight || cachedGridCellHeight == nil {
            cachedGridCellHeight = calculateMaxGridCellHeight(for: cellWidth, in: sectionIndex)
            shouldRecalculateGridHeight = false
        }
        let finalHeight = cachedGridCellHeight ?? 192.0
        
        var layoutGroups: [NSCollectionLayoutGroup] = []
        var currentIndex = 0
        
        while currentIndex < itemCount {
            let isValueItem = hasValueCell && currentIndex == 0
            let isShoppingItem = dynamicShoppingCellIndex != nil && currentIndex == dynamicShoppingCellIndex
            
            if isValueItem {
                let rowSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(finalHeight))
                
                if sectionDataManager.experience == .list {
                    let fullWidthItem = NSCollectionLayoutItem(layoutSize: rowSize)
                    let group = NSCollectionLayoutGroup.horizontal(layoutSize: rowSize, subitems: [fullWidthItem])
                    layoutGroups.append(group)
                    currentIndex += 1
                } else {
                    if columnCount <= 2 {
                        let fullWidthItem = NSCollectionLayoutItem(layoutSize: rowSize)
                        let group = NSCollectionLayoutGroup.horizontal(layoutSize: rowSize, subitems: [fullWidthItem])
                        layoutGroups.append(group)
                        currentIndex += 1
                    } else {
                        let wideItemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(2/3), heightDimension: .fractionalHeight(1.0))
                        let wideItem = NSCollectionLayoutItem(layoutSize: wideItemSize)
                        let nextItemIsSpecial = (dynamicShoppingCellIndex != nil && currentIndex + 1 == dynamicShoppingCellIndex)
                        if currentIndex + 1 < itemCount && !nextItemIsSpecial {
                            let standardItemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1/3), heightDimension: .fractionalHeight(1.0))
                            let standardItem = NSCollectionLayoutItem(layoutSize: standardItemSize)
                            let group = NSCollectionLayoutGroup.horizontal(layoutSize: rowSize, subitems: [wideItem, standardItem])
                            group.interItemSpacing = .fixed(cellSpacing)
                            layoutGroups.append(group)
                            currentIndex += 2
                        } else {
                            let group = NSCollectionLayoutGroup.horizontal(layoutSize: rowSize, subitems: [wideItem])
                            layoutGroups.append(group)
                            currentIndex += 1
                        }
                    }
                }
            } else if isShoppingItem {
                let rowSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(finalHeight))
                if columnCount <= 2 {
                    let fullWidthItem = NSCollectionLayoutItem(layoutSize: rowSize)
                    let group = NSCollectionLayoutGroup.horizontal(layoutSize: rowSize, subitems: [fullWidthItem])
                    layoutGroups.append(group)
                    currentIndex += 1
                } else {
                    let wideItemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(2/3), heightDimension: .fractionalHeight(1.0))
                    let wideItem = NSCollectionLayoutItem(layoutSize: wideItemSize)
                    if currentIndex + 1 < itemCount {
                        let standardItemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1/3), heightDimension: .fractionalHeight(1.0))
                        let standardItem = NSCollectionLayoutItem(layoutSize: standardItemSize)
                        let group = NSCollectionLayoutGroup.horizontal(layoutSize: rowSize, subitems: [wideItem, standardItem])
                        group.interItemSpacing = .fixed(cellSpacing)
                        layoutGroups.append(group)
                        currentIndex += 2
                    } else {
                        let group = NSCollectionLayoutGroup.horizontal(layoutSize: rowSize, subitems: [wideItem])
                        layoutGroups.append(group)
                        currentIndex += 1
                    }
                }
            } else {
                let itemsLeft = itemCount - currentIndex
                let stopIndex = dynamicShoppingCellIndex ?? itemCount
                var itemsInThisRow = 0
                if currentIndex < stopIndex {
                    itemsInThisRow = min(columnCount, itemsLeft, stopIndex - currentIndex)
                } else {
                    itemsInThisRow = min(columnCount, itemsLeft)
                }
                guard itemsInThisRow > 0 else { break }
                
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0 / CGFloat(columnCount)), heightDimension: .fractionalHeight(1.0))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(finalHeight))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, repeatingSubitem: item, count: itemsInThisRow)
                if itemsInThisRow > 1 {
                    group.interItemSpacing = .fixed(cellSpacing)
                }
                layoutGroups.append(group)
                currentIndex += itemsInThisRow
            }
        }
        
        let containerGroupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(itemCount > 0 ? 2000 : 0))
        let containerGroup = NSCollectionLayoutGroup.vertical(layoutSize: containerGroupSize, subitems: layoutGroups)
        containerGroup.interItemSpacing = .fixed(cellSpacing)
        
        let section = NSCollectionLayoutSection(group: containerGroup)
        section.contentInsets = NSDirectionalEdgeInsets(top: cellSpacing, leading: horizontalPadding, bottom: cellSpacing, trailing: horizontalPadding)
        
        return section
    }
    
    private func createUniformGridSection(for sectionIndex: Int, layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let containerWidth = layoutEnvironment.container.effectiveContentSize.width
        let isPortrait = traitCollection.verticalSizeClass == .regular && traitCollection.horizontalSizeClass == .compact
        let isIPad = traitCollection.userInterfaceIdiom == .pad
        
        let columnCount = isIPad ? 3 : (isPortrait ? 2 : 3)
        let availableWidth = containerWidth - (horizontalPadding * 2)
        
        guard availableWidth > 0 else {
            let emptySize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(1))
            let emptyItem = NSCollectionLayoutItem(layoutSize: emptySize)
            let emptyGroup = NSCollectionLayoutGroup.horizontal(layoutSize: emptySize, subitems: [emptyItem])
            return NSCollectionLayoutSection(group: emptyGroup)
        }
        
        let cellWidth = (availableWidth - (CGFloat(columnCount - 1) * cellSpacing)) / CGFloat(columnCount)
        
        if shouldRecalculateGridHeight || cachedGridCellHeight == nil {
            cachedGridCellHeight = calculateMaxGridCellHeight(for: cellWidth, in: sectionIndex)
            shouldRecalculateGridHeight = false
        }
        let finalHeight = cachedGridCellHeight ?? 192.0
        
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0 / CGFloat(columnCount)), heightDimension: .fractionalHeight(1.0))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(finalHeight))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, repeatingSubitem: item, count: columnCount)
        group.interItemSpacing = .fixed(cellSpacing)
        
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = cellSpacing
        section.contentInsets = NSDirectionalEdgeInsets(top: cellSpacing, leading: horizontalPadding, bottom: cellSpacing, trailing: horizontalPadding)
        return section
    }
    
    func createListSection(for sectionIndex: Int, layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(150)
        )
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(50)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(50)
        )
        
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])
        
        let sectionLayout = NSCollectionLayoutSection(group: group)
        sectionLayout.boundarySupplementaryItems = [header]
        sectionLayout.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: horizontalPadding, bottom: 8, trailing: horizontalPadding)
        
        return sectionLayout
    }
    
    private func createFooterSection(layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let cellWidth: CGFloat = 160.0
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .absolute(cellWidth),
            heightDimension: .estimated(100)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .absolute(cellWidth),
            heightDimension: .estimated(100)
        )
        
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        
        let containerWidth = layoutEnvironment.container.effectiveContentSize.width
        let horizontalInset = (containerWidth - cellWidth) / 2.0
        let positiveHorizontalInset = max(0, horizontalInset)
        
        section.contentInsets = NSDirectionalEdgeInsets(
            top: cellSpacing,
            leading: positiveHorizontalInset,
            bottom: cellSpacing * 2,
            trailing: positiveHorizontalInset
        )
        
        section.boundarySupplementaryItems = [createHeader(estimatedHeight: 44)]
        
        return section
    }
    
    private func createHeader(estimatedHeight: CGFloat) -> NSCollectionLayoutBoundarySupplementaryItem {
        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(estimatedHeight))
        return NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
    }
    
    private func createTabBarHeader() -> NSCollectionLayoutBoundarySupplementaryItem {
        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(50))
        let sectionHeader = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
        sectionHeader.pinToVisibleBounds = false
        return sectionHeader
    }
    
    // MARK: - Height Calculations
    private func calculateCarouselHeight(in sectionIndex: Int) -> CGFloat {
        guard let section = sectionDataManager.getSection(at: sectionIndex),
              section.type == .carousel,
              !section.items.isEmpty else {
            return 220.0
        }
        
        let items = section.items.compactMap { $0 as? ContentModel }
        let sizingCell = CarouselCell(frame: .zero)
        sizingCell.configure(with: items)
        return sizingCell.calculateHeight(forWidth: 132.0)
    }
    
    private func calculateMaxGridCellHeight(for cellWidth: CGFloat, in sectionIndex: Int) -> CGFloat {
        guard let section = sectionDataManager.getSection(at: sectionIndex),
              section.type == .grid,
              !section.items.isEmpty else {
            return 192.0
        }
        
        var maxHeight: CGFloat = 0.0
        let valueSizingCell = ValueCell(frame: .zero)
        let shoppingSizingCell = ShoppingCell(frame: .zero)
        let standardSizingCell = TitleSubtitleCell(frame: .zero)
        
        for (index, item) in section.items.enumerated() {
            guard let contentItem = item as? ContentModel else { continue }
            
            let sizingView: UIView
            let indexPath = IndexPath(item: index, section: sectionIndex)
            
            if sectionDataManager.shouldUseShoppingCell(at: indexPath) {
                shoppingSizingCell.configure(with: contentItem)
                sizingView = shoppingSizingCell
            } else if sectionDataManager.shouldUseValueCell(at: indexPath) {
                valueSizingCell.configure(with: contentItem)
                sizingView = valueSizingCell
            } else {
                standardSizingCell.configure(with: contentItem)
                sizingView = standardSizingCell
            }
            
            let requiredSize = sizingView.systemLayoutSizeFitting(
                CGSize(width: cellWidth, height: 0),
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel
            )
            if requiredSize.height > maxHeight {
                maxHeight = requiredSize.height
            }
        }
        return maxHeight
    }
}

// MARK: - UICollectionViewDelegate
extension ViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        
        guard let section = sectionDataManager.getSection(at: indexPath.section),
              section.type == .grid,
              let item = section.items[safe: indexPath.item] as? ContentModel,
              !item.isShoppingPlaceholder else { return }
        
        var updatedModel = item
        updatedModel.isSelected.toggle()
        // Use hybrid solution
        updateContentModelWithHybridSolution(updatedModel)
    }
}

// MARK: - TabBarViewDelegate
extension ViewController: TabBarViewDelegate {
    func tabBarView(didSelectTabAt index: Int) {
        let isPortrait = traitCollection.verticalSizeClass == .regular &&
                        traitCollection.horizontalSizeClass == .compact
        let isIPad = traitCollection.userInterfaceIdiom == .pad
        let columnCount = (isIPad || !isPortrait) ? 3 : 2
        
        sectionDataManager.setSelectedTabIndex(index, columnCount: columnCount)
        
        applySnapshot(animatingDifferences: false)
        
        let topOffset = CGPoint(x: 0, y: -collectionView.adjustedContentInset.top)
        collectionView.setContentOffset(topOffset, animated: false)
    }
    
    func tabBarViewRequiresLayoutUpdate() {
        collectionView.collectionViewLayout.invalidateLayout()
    }
}
