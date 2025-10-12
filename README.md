import UIKit

enum ExperienceType {
    case grid
    case list
    case carousel
}

struct TabItem: Hashable, Sendable {
    let title: String
}

enum SectionHeader: Hashable, Sendable {
    case title(String)
    case tabBar(tabs: [TabItem], selectedIndex: Int)
    case list(ContentModel)

    func containsModel(_ model: ContentModel) -> Bool {
        if case .list(let headerModel) = self {
            return headerModel.id == model.id
        }
        return false
    }
}

protocol ContentItem: Hashable, Sendable {
    var id: String? { get }
}

struct InfoModel: ContentItem {
    let id: String?
    let title: String
    let subtitle: String?
    
    init(title: String, subtitle: String? = nil) {
        self.id = UUID().uuidString
        self.title = title
        self.subtitle = subtitle
    }
}

struct FooterModel: ContentItem {
    let id: String?
    let title: String
    let subtitle: String?
    
    init(title: String, subtitle: String? = nil) {
        self.id = UUID().uuidString
        self.title = title
        self.subtitle = subtitle
    }
}

struct DisclaimerModel: ContentItem {
    let id: String?
    let title: String
    let subtitle: String?
    
    init(title: String, subtitle: String? = nil) {
        self.id = UUID().uuidString
        self.title = title
        self.subtitle = subtitle
    }
}

struct ContentModel: ContentItem {
    let id: String?
    let logo: UIImage?
    let tag: String?
    let title: String
    let subtitle: String
    let description: String
    let isShoppingPlaceholder: Bool
    var isSelected: Bool
    var isLoading: Bool
    var isDetailsVisible: Bool

    init(logo: UIImage? = nil,
         tag: String? = nil,
         title: String,
         subtitle: String,
         description: String,
         isShoppingPlaceholder: Bool = false,
         isSelected: Bool = false,
         isLoading: Bool = false,
         isDetailsVisible: Bool = false) {
        self.id = UUID().uuidString
        self.logo = logo
        self.tag = tag
        self.title = title
        self.subtitle = subtitle
        self.description = description
        self.isShoppingPlaceholder = isShoppingPlaceholder
        self.isSelected = isSelected
        self.isLoading = isLoading
        self.isDetailsVisible = isDetailsVisible
    }
    
    static func emptyShoppingPlaceholder() -> ContentModel {
        return ContentModel(
            logo: nil,
            tag: nil,
            title: "",
            subtitle: "",
            description: "",
            isShoppingPlaceholder: true
        )
    }
}

extension ContentModel {
    static func carouselItem(index: Int, prefix: String, isHighlighted: Bool = false) -> ContentModel {
        let tag: String? = isHighlighted ? "Featured" : nil
        let title = "\(prefix) - Carousel Item \(index)"
        let subtitle = "Subtitle for item \(index) of \(prefix)."
        var description = "Description for \(prefix)."
        
        if index % 4 == 0 {
            description += " This is a slightly longer description."
        }
        
        return ContentModel(
            logo: UIImage(systemName: "star.fill"),
            tag: tag,
            title: title,
            subtitle: subtitle,
            description: description
        )
    }
    
    static func gridItem(index: Int, prefix: String, isValue: Bool = false) -> ContentModel {
        if isValue {
            return ContentModel(
                logo: UIImage(systemName: "photo.fill"),
                tag: "Value",
                title: "\(prefix) - Value Cell (\(index))",
                subtitle: "This cell has a special design.",
                description: "Its size changes based on orientation."
            )
        } else {
            return ContentModel(
                logo: UIImage(systemName: "photo.fill"),
                tag: "New",
                title: "\(prefix) - Cell \(index)",
                subtitle: "Subtitle \(index)",
                description: "A standard description for a standard cell from \(prefix)."
            )
        }
    }
}

struct ItemIdentifier: Hashable, Sendable {
    let id: String?
    let sectionId: String?
    let type: ItemType
    
    enum ItemType: Hashable, Sendable {
        case single(String?)
        case carousel
    }
}

enum ListItemPosition {
    case top
    case middle
    case bottom
}

enum SectionType: Hashable, Sendable {
    case info
    case carousel
    case grid
    case list
    case footer
    case disclaimer
}

struct Section: Hashable, Sendable {
    let id: String?
    let type: SectionType
    var header: SectionHeader?
    var items: [any ContentItem]
    
    init(id: String? = UUID().uuidString, type: SectionType, header: SectionHeader? = nil, items: [any ContentItem] = []) {
        self.id = id
        self.type = type
        self.header = header
        self.items = items
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(header)
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.id == rhs.id && lhs.header == rhs.header
    }
}

@MainActor
class SectionDataManager {
    
    private struct SectionReference {
        let sectionId: String?
        let type: SectionType
        var header: SectionHeader?
        var itemIds: [String?]
    }
    
    private var contentStore: [String: ContentModel] = [:]
    private var infoStore: [String: InfoModel] = [:]
    private var footerStore: [String: FooterModel] = [:]
    private var disclaimerStore: [String: DisclaimerModel] = [:]
    private var sectionsByTab: [TabItem: [SectionReference]] = [:]
    private var listSectionPositions: [Int: ListItemPosition] = [:]
    private var shoppingPlaceholderId: String?
    
    var isValueEnabled: Bool
    var isVideoEnabled: Bool
    var isShoppingEnabled: Bool
    var experience: ExperienceType
    
    var tabData: [TabItem] = (0..<8).map { TabItem(title: "Category \($0 + 1)") }
    private(set) var selectedTabIndex: Int = 0
    private(set) var currentShoppingCellIndex: Int?
    
    var onSectionsDidUpdate: (() -> Void)?
    
    private var currentTab: TabItem? {
        return tabData[safe: selectedTabIndex]
    }
    
    var sections: [Section] {
        guard let tab = currentTab,
              let refs = sectionsByTab[tab] else { return [] }
        
        return refs.map { ref in
            Section(
                id: ref.sectionId,
                type: ref.type,
                header: resolveHeader(ref.header),
                items: resolveItems(for: ref.itemIds, type: ref.type)
            )
        }
    }
    
    init(isValueEnabled: Bool = false,
         isVideoEnabled: Bool = false,
         isShoppingEnabled: Bool = false,
         experience: ExperienceType = .grid) {
        self.isValueEnabled = isValueEnabled
        self.isVideoEnabled = isVideoEnabled
        self.isShoppingEnabled = isShoppingEnabled
        self.experience = experience
        setupInitialData()
        
        if isShoppingEnabled {
            updateShoppingState(columnCount: 2, shouldNotify: false)
        }
    }
    
    private func resolveHeader(_ header: SectionHeader?) -> SectionHeader? {
        guard let header = header else { return nil }
        
        switch header {
        case .list(let model):
            if let id = model.id, let updatedModel = contentStore[id] {
                return .list(updatedModel)
            }
            return header
        default:
            return header
        }
    }
    
    private func resolveItems(for ids: [String?], type: SectionType) -> [any ContentItem] {
        switch type {
        case .info:
            return ids.compactMap { id in
                guard let id = id else { return nil }
                return infoStore[id]
            }
        case .footer:
            return ids.compactMap { id in
                guard let id = id else { return nil }
                return footerStore[id]
            }
        case .disclaimer:
            return ids.compactMap { id in
                guard let id = id else { return nil }
                return disclaimerStore[id]
            }
        case .carousel, .grid, .list:
            return ids.compactMap { id in
                guard let id = id else { return nil }
                return contentStore[id]
            }
        }
    }
    
    func getSection(at index: Int) -> Section? {
        guard let tab = currentTab,
              let refs = sectionsByTab[tab],
              refs.indices.contains(index) else {
            return nil
        }
        
        let ref = refs[index]
        return Section(
            id: ref.sectionId,
            type: ref.type,
            header: resolveHeader(ref.header),
            items: resolveItems(for: ref.itemIds, type: ref.type)
        )
    }
    
    func updateSection(_ section: Section, at index: Int) {
        guard let tab = currentTab,
              var refs = sectionsByTab[tab],
              refs.indices.contains(index) else {
            return
        }
        
        let itemIds = section.items.compactMap { item -> String? in
            if let contentModel = item as? ContentModel, let id = contentModel.id {
                contentStore[id] = contentModel
                return id
            } else if let infoModel = item as? InfoModel, let id = infoModel.id {
                infoStore[id] = infoModel
                return id
            } else if let footerModel = item as? FooterModel, let id = footerModel.id {
                footerStore[id] = footerModel
                return id
            } else if let disclaimerModel = item as? DisclaimerModel, let id = disclaimerModel.id {
                disclaimerStore[id] = disclaimerModel
                return id
            }
            return item.id
        }
        
        refs[index] = SectionReference(
            sectionId: section.id,
            type: section.type,
            header: section.header,
            itemIds: itemIds
        )
        sectionsByTab[tab] = refs
    }
    
    func getItem(at indexPath: IndexPath) -> (any ContentItem)? {
        guard let tab = currentTab,
              let refs = sectionsByTab[tab],
              refs.indices.contains(indexPath.section) else {
            return nil
        }
        
        let ref = refs[indexPath.section]
        
        switch ref.type {
        case .carousel:
            let items = ref.itemIds.compactMap { id -> ContentModel? in
                guard let id = id else { return nil }
                return contentStore[id]
            }
            return items.first
        case .info:
            guard let itemId = ref.itemIds[safe: indexPath.item],
                  let id = itemId else { return nil }
            return infoStore[id]
        case .footer:
            guard let itemId = ref.itemIds[safe: indexPath.item],
                  let id = itemId else { return nil }
            return footerStore[id]
        case .disclaimer:
            guard let itemId = ref.itemIds[safe: indexPath.item],
                  let id = itemId else { return nil }
            return disclaimerStore[id]
        default:
            guard let itemId = ref.itemIds[safe: indexPath.item],
                  let id = itemId else { return nil }
            return contentStore[id]
        }
    }
    
    func updateCarouselItems(_ items: [ContentModel], at sectionIndex: Int) {
        guard let tab = currentTab,
              var refs = sectionsByTab[tab],
              refs.indices.contains(sectionIndex),
              refs[sectionIndex].type == .carousel else { return }
        
        let itemIds = items.compactMap { model -> String? in
            guard let id = model.id else { return nil }
            contentStore[id] = model
            return id
        }
        
        refs[sectionIndex].itemIds = itemIds
        sectionsByTab[tab] = refs
        
        onSectionsDidUpdate?()
    }
    
    func updateItem(_ item: any ContentItem, at indexPath: IndexPath) {
        if let contentModel = item as? ContentModel, let id = contentModel.id {
            contentStore[id] = contentModel
            onSectionsDidUpdate?()
        } else if let infoModel = item as? InfoModel, let id = infoModel.id {
            infoStore[id] = infoModel
            onSectionsDidUpdate?()
        } else if let footerModel = item as? FooterModel, let id = footerModel.id {
            footerStore[id] = footerModel
            onSectionsDidUpdate?()
        } else if let disclaimerModel = item as? DisclaimerModel, let id = disclaimerModel.id {
            disclaimerStore[id] = disclaimerModel
            onSectionsDidUpdate?()
        } else {
            guard var section = getSection(at: indexPath.section) else { return }
            
            if indexPath.item < section.items.count {
                section.items[indexPath.item] = item
            }
            updateSection(section, at: indexPath.section)
        }
    }
    
    func getHeader(for sectionIndex: Int) -> SectionHeader? {
        guard let section = getSection(at: sectionIndex) else { return nil }
        
        if case .tabBar(let tabs, _) = section.header {
            return .tabBar(tabs: tabs, selectedIndex: selectedTabIndex)
        }
        
        return section.header
    }
    
    func updateHeader(_ header: SectionHeader?, for sectionIndex: Int) {
        guard let tab = currentTab,
              var refs = sectionsByTab[tab],
              refs.indices.contains(sectionIndex) else { return }
        
        refs[sectionIndex].header = header
        sectionsByTab[tab] = refs
    }
    
    func numberOfSections() -> Int {
        sections.count
    }
    
    func numberOfItems(in sectionIndex: Int) -> Int {
        guard let section = getSection(at: sectionIndex) else { return 0 }
        
        switch section.type {
        case .carousel:
            return section.items.isEmpty ? 0 : 1
        case .list:
            if let contentModel = section.items.first as? ContentModel {
                return contentModel.isDetailsVisible ? 1 : 0
            }
            return 0
        default:
            return section.items.count
        }
    }
    
    func setSelectedTabIndex(_ index: Int, columnCount: Int) {
        guard index != selectedTabIndex, tabData.indices.contains(index) else { return }
        selectedTabIndex = index
        
        // Limpiar el shopping placeholder antes de cambiar de tab
        if let placeholderId = shoppingPlaceholderId {
            contentStore.removeValue(forKey: placeholderId)
            shoppingPlaceholderId = nil
        }
        
        updateShoppingState(columnCount: columnCount, shouldNotify: true)
        updateListSectionPositions()
    }
    
    func setIsShoppingEnabled(_ isEnabled: Bool, columnCount: Int) {
        guard isEnabled != isShoppingEnabled else { return }
        isShoppingEnabled = isEnabled
        updateShoppingState(columnCount: columnCount, shouldNotify: true)
    }
    
    func updateStateForLayoutChange(columnCount: Int) {
        let oldIndex = currentShoppingCellIndex
        updateShoppingCellIndex(columnCount: columnCount)
        
        if oldIndex != currentShoppingCellIndex {
            updateShoppingPlaceholderPosition(shouldNotify: false)
        }
    }
    
    func shouldUseValueCell(at indexPath: IndexPath) -> Bool {
        guard let section = getSection(at: indexPath.section),
              section.type == .grid else { return false }
        
        if let item = section.items[safe: indexPath.item] as? ContentModel,
           !item.isShoppingPlaceholder {
            return isValueEnabled && indexPath.item == 0
        }
        return false
    }
    
    func shouldUseShoppingCell(at indexPath: IndexPath) -> Bool {
        guard let section = getSection(at: indexPath.section),
              section.type == .grid else { return false }
        
        if let item = section.items[safe: indexPath.item] as? ContentModel {
            return item.isShoppingPlaceholder
        }
        return false
    }

    func updateContentModel(_ updatedModel: ContentModel, notify: Bool = true) {
        guard !updatedModel.isShoppingPlaceholder,
              let id = updatedModel.id else { return }
        
        contentStore[id] = updatedModel
        if notify {
            onSectionsDidUpdate?()
        }
    }
    
    func updateListSectionPositions() {
        listSectionPositions.removeAll()
        guard experience == .list else {
            return
        }
        let sections = self.sections
        let listIndices = sections.enumerated().compactMap { index, section in
            section.type == .list ? index : nil
        }
        
        let count = listIndices.count
        for (position, sectionIndex) in listIndices.enumerated() {
            if position == 0 {
                listSectionPositions[sectionIndex] = .top
            } else if position == count - 1 {
                listSectionPositions[sectionIndex] = .bottom
            } else {
                listSectionPositions[sectionIndex] = .middle
            }
        }
    }
    
    func getListPosition(for sectionIndex: Int) -> ListItemPosition? {
        listSectionPositions[sectionIndex]
    }
    
    func resetData() {
        shoppingPlaceholderId = nil
        contentStore.removeAll()
        infoStore.removeAll()
        footerStore.removeAll()
        disclaimerStore.removeAll()
        setupInitialData()
        selectedTabIndex = 0
    }
    
    func reloadTab(at index: Int) {
        guard tabData.indices.contains(index),
              let tab = tabData[safe: index] else { return }
        
        sectionsByTab[tab] = createSectionsOptimized(for: tab)
    }
    
    public func updateShoppingCellIndex(columnCount: Int) {
        currentShoppingCellIndex = nil
        
        guard let currentTab,
              let refs = sectionsByTab[currentTab],
              let gridRef = refs.first(where: { $0.type == .grid }) else {
            return
        }
        
        // Obtiene los IDs de los items del carrusel para identificar los modelos compartidos.
        let carouselItemIdsSet: Set<String?>
        if let carouselRef = refs.first(where: { $0.type == .carousel }) {
            carouselItemIdsSet = Set(carouselRef.itemIds.compactMap { $0 })
        } else {
            carouselItemIdsSet = []
        }
        
        // Cuenta los modelos que existen tanto en la cuadrícula como en el carrusel (es decir, modelos "compartidos").
        var sharedModelCount = 0
        for id in gridRef.itemIds {
            guard let id = id else { continue }
            if carouselItemIdsSet.contains(id) {
                sharedModelCount += 1
            }
        }
        
        let realItemCount = gridRef.itemIds.compactMap { id -> ContentModel? in
            guard let id = id else { return nil }
            return contentStore[id]
        }.filter { !$0.isShoppingPlaceholder }.count
        
        let baseShoppingIndex = 19
        
        guard isShoppingEnabled && realItemCount > baseShoppingIndex else {
            currentShoppingCellIndex = nil
            return
        }
        
        var gridStartIndex = 0
        if isValueEnabled {
            switch experience {
            case .list:
                gridStartIndex = 1
            case .grid, .carousel:
                gridStartIndex = (columnCount <= 2) ? 1 : 2
            }
        }
        
        // Ajusta el índice base según la cantidad de modelos compartidos.
        let adjustedBaseIndex = baseShoppingIndex + sharedModelCount
        
        var finalIndex: Int
        if adjustedBaseIndex >= gridStartIndex {
            let indexRelativeToGrid = adjustedBaseIndex - gridStartIndex
            let offset = indexRelativeToGrid % columnCount
            
            if offset == 0 {
                finalIndex = adjustedBaseIndex
            } else {
                finalIndex = adjustedBaseIndex - offset + columnCount
            }
        } else {
            finalIndex = gridStartIndex
        }
        
        if finalIndex < realItemCount {
            currentShoppingCellIndex = finalIndex
        } else {
            currentShoppingCellIndex = nil
        }
    }
    
    private func updateShoppingState(columnCount: Int, shouldNotify: Bool) {
        updateShoppingCellIndex(columnCount: columnCount)
        updateShoppingPlaceholderPosition(shouldNotify: shouldNotify)
    }
    
    private func updateShoppingPlaceholderPosition(shouldNotify: Bool) {
        guard let tab = currentTab,
              var refs = sectionsByTab[tab] else { return }
        
        guard let gridIndex = refs.firstIndex(where: { $0.type == .grid }) else { return }
        var gridRef = refs[gridIndex]
        
        if let placeholderId = shoppingPlaceholderId {
            gridRef.itemIds.removeAll { $0 == placeholderId }
            contentStore.removeValue(forKey: placeholderId)
            shoppingPlaceholderId = nil
        }
        
        if isShoppingEnabled,
           let shoppingIndex = currentShoppingCellIndex,
           shoppingIndex <= gridRef.itemIds.count {
            let placeholder = ContentModel.emptyShoppingPlaceholder()
            if let id = placeholder.id {
                contentStore[id] = placeholder
                shoppingPlaceholderId = id
                gridRef.itemIds.insert(id, at: shoppingIndex)
            }
        }
        
        refs[gridIndex] = gridRef
        sectionsByTab[tab] = refs
        
        if shouldNotify {
            onSectionsDidUpdate?()
        }
    }
    
    private func setupInitialData() {
        for tab in tabData {
            sectionsByTab[tab] = createSectionsOptimized(for: tab)
        }
        updateListSectionPositions()
    }
    
    private func createSectionsOptimized(for tab: TabItem) -> [SectionReference] {
        let prefix = tab.title.replacingOccurrences(of: "Category", with: "Content")
        
        let sharedModels = (0..<3).map { i in
            ContentModel.carouselItem(index: i, prefix: "\(prefix) (Shared)", isHighlighted: true)
        }
        
        for model in sharedModels {
            if let id = model.id {
                contentStore[id] = model
            }
        }
        
        var refs: [SectionReference] = []
        
        refs.append(createGeneralInfoSectionOptimized(prefix: prefix))
        refs.append(createCarouselSectionOptimized(prefix: prefix, sharedModels: sharedModels))
        
        switch experience {
        case .list:
            let firstListItem = ContentModel.gridItem(index: 0, prefix: prefix, isValue: isValueEnabled)
            if let id = firstListItem.id {
                contentStore[id] = firstListItem
            }
            refs.append(createListSectionOptimized(item: firstListItem))
            
            for sharedModel in sharedModels {
                refs.append(createListSectionOptimized(item: sharedModel))
            }
            
            for i in 1..<300 {
                let listItem = ContentModel.gridItem(index: i, prefix: prefix, isValue: false)
                if let id = listItem.id {
                    contentStore[id] = listItem
                }
                refs.append(createListSectionOptimized(item: listItem))
            }
            
        case .grid, .carousel:
            let itemCount = 300 + (Int(tab.title.last?.wholeNumberValue ?? 1) * 3)
            refs.append(createGridSectionOptimized(prefix: prefix, itemCount: itemCount, sharedModels: sharedModels))
        }
        
        refs.append(createFooterSectionOptimized(prefix: prefix))
        
        if experience == .list {
            refs.append(createDisclaimerSectionOptimized(prefix: prefix))
        }
        
        return refs
    }
    
    private func createGeneralInfoSectionOptimized(prefix: String) -> SectionReference {
        let info1 = InfoModel(title: "\(prefix) Info Item 1", subtitle: "General info subtitle")
        let info2 = InfoModel(title: "\(prefix) Info Item 2", subtitle: "Another subtitle")
        
        if let id1 = info1.id {
            infoStore[id1] = info1
        }
        if let id2 = info2.id {
            infoStore[id2] = info2
        }
        
        return SectionReference(
            sectionId: UUID().uuidString,
            type: .info,
            header: nil,
            itemIds: [info1.id, info2.id].compactMap { $0 }
        )
    }
    
    private func createCarouselSectionOptimized(prefix: String, sharedModels: [ContentModel]) -> SectionReference {
        var itemIds = sharedModels.compactMap { $0.id }
        
        let regularItems = (0..<12).map { i in
            ContentModel.carouselItem(index: i, prefix: prefix, isHighlighted: i % 4 == 0)
        }
        
        for item in regularItems {
            if let id = item.id {
                contentStore[id] = item
                itemIds.append(id)
            }
        }
        
        let header = SectionHeader.tabBar(tabs: self.tabData, selectedIndex: self.selectedTabIndex)
        return SectionReference(
            sectionId: UUID().uuidString,
            type: .carousel,
            header: header,
            itemIds: itemIds
        )
    }

    private func createGridSectionOptimized(prefix: String, itemCount: Int, sharedModels: [ContentModel]) -> SectionReference {
        var itemIds: [String?] = []
        
        let firstItem = ContentModel.gridItem(index: 0, prefix: prefix, isValue: isValueEnabled)
        if let id = firstItem.id {
            contentStore[id] = firstItem
            itemIds.append(id)
        }
        
        itemIds.append(contentsOf: sharedModels.compactMap { $0.id })
        
        for i in 1..<itemCount {
            let item = ContentModel.gridItem(index: i, prefix: prefix, isValue: false)
            if let id = item.id {
                contentStore[id] = item
                itemIds.append(id)
            }
        }
        
        let header = SectionHeader.title("Explore Content")
        return SectionReference(
            sectionId: UUID().uuidString,
            type: .grid,
            header: header,
            itemIds: itemIds
        )
    }

    private func createListSectionOptimized(item: ContentModel) -> SectionReference {
        let header = SectionHeader.list(item)
        return SectionReference(
            sectionId: UUID().uuidString,
            type: .list,
            header: header,
            itemIds: [item.id].compactMap { $0 }
        )
    }

    private func createFooterSectionOptimized(prefix: String) -> SectionReference {
        let footer = FooterModel(title: "\(prefix) Footer", subtitle: "Additional footer details")
        if let id = footer.id {
            footerStore[id] = footer
        }
        
        return SectionReference(
            sectionId: UUID().uuidString,
            type: .footer,
            header: .title("Test"),
            itemIds: [footer.id].compactMap { $0 }
        )
    }
    
    private func createDisclaimerSectionOptimized(prefix: String) -> SectionReference {
        let disclaimer = DisclaimerModel(
            title: "Legal Disclaimer",
            subtitle: "This content is for demonstration purposes only. All data shown is fictitious and does not represent real information. Any resemblance to real people or companies is purely coincidental."
        )
        if let id = disclaimer.id {
            disclaimerStore[id] = disclaimer
        }
        
        return SectionReference(
            sectionId: UUID().uuidString,
            type: .disclaimer,
            header: nil,
            itemIds: [disclaimer.id].compactMap { $0 }
        )
    }
    
    func debugPrintSections() {
        print("=== Debug: Current Sections ===")
        for (index, section) in sections.enumerated() {
            print("Section \(index): Type = \(section.type)")
            if let header = section.header {
                switch header {
                case .tabBar(let tabs, let selected):
                    print("  Header: TabBar with \(tabs.count) tabs, selected: \(selected)")
                    for (i, tab) in tabs.enumerated() {
                        print("    Tab \(i): \(tab.title)")
                    }
                case .title(let title):
                    print("  Header: Title = \(title)")
                case .list(_):
                    print("  Header: List")
                }
            }
            print("  Items: \(section.items.count)")
        }
        print("==============================")
    }
}

final class DisclaimerCell: UICollectionViewCell {
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let textView: UITextView = {
        let textView = UITextView()
        textView.font = .preferredFont(forTextStyle: .caption1)
        textView.textColor = .tertiaryLabel
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.translatesAutoresizingMaskIntoConstraints = false
        return textView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupDefaultStyle()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(with model: DisclaimerModel) {
        titleLabel.text = model.title
        textView.text = model.subtitle
    }
    
    private func setupDefaultStyle() {
        backgroundColor = .systemGray6
        layer.cornerRadius = 8
        layer.masksToBounds = true
    }
    
    private func setupUI() {
        contentView.addSubview(titleLabel)
        contentView.addSubview(textView)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            
            textView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            textView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            textView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            textView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }
}

final class TitleHeaderView: UICollectionReusableView {

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .headline)
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemGreen
        addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            titleLabel.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with title: String) {
        titleLabel.text = title
    }
}


final class ListHeaderView: UICollectionReusableView {
    
    var onHeaderSelect: ((ContentModel) -> Void)?
    var onDetailsButtonTapped: (() -> Void)?
    var onLinkButtonTapped: (() -> Void)?

    private var tapGestureRecognizer: UITapGestureRecognizer!
    private var currentModel: ContentModel?
    
    private var bottomConstraintWithActions: NSLayoutConstraint!
    private var bottomConstraintWithoutActions: NSLayoutConstraint!

    private let spinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.hidesWhenStopped = true
        spinner.color = .secondaryLabel
        return spinner
    }()
    
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
    
    private let tagsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 4.0
        stackView.alignment = .leading
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private lazy var linkButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.buttonSize = .medium
        config.cornerStyle = .medium
        config.image = UIImage(systemName: "link")
        config.imagePadding = 6
        
        let button = UIButton(type: .system)
        button.configuration = config
        button.setTitle("Go to Site", for: .normal)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.addTarget(self, action: #selector(linkButtonAction), for: .touchUpInside)
        return button
    }()
    
    private lazy var detailsButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.buttonSize = .medium
        config.cornerStyle = .medium
        
        let button = UIButton(type: .system)
        button.configuration = config
        button.titleLabel?.font = .preferredFont(forTextStyle: .body)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.addTarget(self, action: #selector(detailsButtonAction), for: .touchUpInside)
        return button
    }()
    
    private let spacerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return view
    }()
    
    private lazy var actionsStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [detailsButton, spacerView, linkButton])
        stackView.axis = .horizontal
        stackView.distribution = .fill
        stackView.spacing = 12.0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private enum Constants {
        static let logoTopPadding: CGFloat = 12
        static let logoSize: CGFloat = 56
        static let horizontalPadding: CGFloat = 16
        static let tagTopPadding: CGFloat = 12
        static let stackTopPadding: CGFloat = 8
        static let stackSpacing: CGFloat = 4
        static let bottomPadding: CGFloat = 12
        static let verticalSpacing: CGFloat = 12
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupDefaultStyle()
        setupTapGesture()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        spinner.stopAnimating()
        
        currentModel = nil
        titleLabel.text = nil
        subtitleLabel.text = nil
        descriptionLabel.text = nil
        logoImageView.image = nil
        tagLabel.text = nil
        detailsButton.setTitle(nil, for: .normal)
        
        backgroundColor = .systemGray6
        tagLabel.isHidden = true
        actionsStackView.isHidden = true

        tagsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        tagsStackView.isHidden = true
    }
    
    func configure(with model: ContentModel) {
        currentModel = model
        
        logoImageView.image = model.logo ?? UIImage(systemName: "photo.fill")
        titleLabel.text = model.title
        subtitleLabel.text = model.subtitle
        descriptionLabel.text = model.description
        
        updateContentVisibility(for: model)
        updateSelectionStyle(for: model)
        
        if model.isLoading {
            spinner.startAnimating()
            actionsStackView.isHidden = true
            tagLabel.isHidden = true
        } else {
            spinner.stopAnimating()
            actionsStackView.isHidden = !model.isSelected
            updateTagVisibility(for: model.tag)
        }
        
        if model.isSelected && !model.isLoading {
            tagsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
            let dynamicTags = ["title0", "title1", "title2"]
            if dynamicTags.isEmpty {
                tagsStackView.isHidden = true
            } else {
                tagsStackView.isHidden = false
                for tagText in dynamicTags {
                    let label = createTagLabel(with: tagText)
                    tagsStackView.addArrangedSubview(label)
                }
            }
        }
        
        if model.isSelected && !model.isLoading {
            let title = model.isDetailsVisible ? "Hide Details" : "Show Details"
            detailsButton.setTitle(title, for: .normal)
        }
        
        if actionsStackView.isHidden {
            bottomConstraintWithActions.isActive = false
            bottomConstraintWithoutActions.isActive = true
        } else {
            bottomConstraintWithoutActions.isActive = false
            bottomConstraintWithActions.isActive = true
        }
    }
    
    private func createTagLabel(with text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.font = .preferredFont(forTextStyle: .caption2)
        label.textColor = .secondaryLabel
        label.backgroundColor = .systemGray4
        label.layer.cornerRadius = 4
        label.layer.masksToBounds = true
        label.textAlignment = .center
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }
    
    private func setupDefaultStyle() {
        backgroundColor = .systemGray6
        layer.cornerRadius = 12
        layer.masksToBounds = true
    }
    
    private func setupTapGesture() {
        isUserInteractionEnabled = true
        tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGestureRecognizer)
    }

    @objc private func handleTap() {
        guard let model = currentModel, !model.isSelected, !model.isLoading else { return }
        onHeaderSelect?(model)
    }
    
    @objc private func detailsButtonAction() {
        onDetailsButtonTapped?()
    }
    
    @objc private func linkButtonAction() {
        onLinkButtonTapped?()
        print("Link button tapped!")
    }
    
    private func updateSelectionStyle(for model: ContentModel) {
        if model.isSelected && !model.isLoading {
            backgroundColor = .systemGreen
        } else {
            backgroundColor = .systemGray6
        }
    }
    
    private func updateTagVisibility(for tag: String?) {
        if let tagText = tag, !tagText.isEmpty {
            tagLabel.text = " \(tagText) "
            tagLabel.isHidden = false
        } else {
            tagLabel.text = nil
            tagLabel.isHidden = true
        }
    }
    
    private func updateContentVisibility(for model: ContentModel) {
        subtitleLabel.isHidden = model.subtitle.isEmpty
        descriptionLabel.isHidden = model.description.isEmpty
    }
    
    private func setupUI() {
        let textContentStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, descriptionLabel])
        textContentStack.axis = .vertical
        textContentStack.alignment = .leading
        textContentStack.spacing = Constants.stackSpacing
        textContentStack.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(logoImageView)
        addSubview(tagLabel)
        addSubview(textContentStack)
        addSubview(tagsStackView)
        addSubview(spinner)
        addSubview(actionsStackView)
        
        bottomConstraintWithActions = actionsStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Constants.bottomPadding)
        bottomConstraintWithoutActions = tagsStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Constants.bottomPadding)
        
        bottomConstraintWithoutActions.isActive = true
        
        NSLayoutConstraint.activate([
            logoImageView.topAnchor.constraint(equalTo: topAnchor, constant: Constants.logoTopPadding),
            logoImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Constants.horizontalPadding),
            logoImageView.widthAnchor.constraint(equalToConstant: Constants.logoSize),
            logoImageView.heightAnchor.constraint(equalToConstant: Constants.logoSize),
            
            tagLabel.topAnchor.constraint(equalTo: topAnchor, constant: Constants.tagTopPadding),
            tagLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Constants.horizontalPadding),
            tagLabel.leadingAnchor.constraint(greaterThanOrEqualTo: logoImageView.trailingAnchor, constant: 8),
            
            spinner.topAnchor.constraint(equalTo: tagLabel.bottomAnchor, constant: 4),
            spinner.centerXAnchor.constraint(equalTo: tagLabel.centerXAnchor),
            
            textContentStack.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: Constants.stackTopPadding),
            textContentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Constants.horizontalPadding),
            textContentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Constants.horizontalPadding),
            
            tagsStackView.topAnchor.constraint(equalTo: textContentStack.bottomAnchor, constant: Constants.verticalSpacing),
            tagsStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Constants.horizontalPadding),
            tagsStackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -Constants.horizontalPadding),
            
            actionsStackView.topAnchor.constraint(equalTo: tagsStackView.bottomAnchor, constant: Constants.verticalSpacing),
            actionsStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Constants.horizontalPadding),
            actionsStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Constants.horizontalPadding),
        ])
    }
}

@MainActor
protocol CellRegistrationProtocol: AnyObject {
    static var reuseIdentifier: String { get }
}

extension UICollectionReusableView: CellRegistrationProtocol {
    static var reuseIdentifier: String {
        String(describing: self)
    }
}

final class InfoCell: UICollectionViewCell {
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .headline)
        label.textColor = .label
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
    
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(systemName: "info.circle.fill")
        imageView.tintColor = .systemBlue
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private var currentModel: InfoModel?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupDefaultStyle()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(with model: InfoModel) {
        currentModel = model
        titleLabel.text = model.title
        subtitleLabel.text = model.subtitle
        subtitleLabel.isHidden = model.subtitle?.isEmpty ?? true
    }
    
    private func setupDefaultStyle() {
        backgroundColor = .systemGray5
        layer.cornerRadius = 12
        layer.masksToBounds = true
        
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 2
        layer.shadowOpacity = 0.1
    }
    
    private func setupUI() {
        let stackView = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        stackView.axis = .vertical
        stackView.alignment = .leading
        stackView.distribution = .fill
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(iconImageView)
        contentView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            stackView.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
    }
}

final class FooterCell: UICollectionViewCell {
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .headline)
        label.textColor = .label
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = .tertiaryLabel
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(systemName: "doc.text.fill")
        imageView.tintColor = .systemGray
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private var currentModel: FooterModel?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupDefaultStyle()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(with model: FooterModel) {
        currentModel = model
        titleLabel.text = model.title
        subtitleLabel.text = model.subtitle
        subtitleLabel.isHidden = model.subtitle?.isEmpty ?? true
    }
    
    private func setupDefaultStyle() {
        backgroundColor = .systemGray5
        layer.cornerRadius = 12
        layer.masksToBounds = true
        
        layer.borderWidth = 1
        layer.borderColor = UIColor.systemGray4.cgColor
    }
    
    private func setupUI() {
        let stackView = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        stackView.axis = .vertical
        stackView.alignment = .leading
        stackView.distribution = .fill
        stackView.spacing = 2
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(iconImageView)
        contentView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 20),
            iconImageView.heightAnchor.constraint(equalToConstant: 20),
            
            stackView.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            
            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 32)
        ])
    }
}

final class ValueCell: UICollectionViewCell {
    
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
    
    private var currentModel: ContentModel?
    
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
    
    func configure(with model: ContentModel) {
        currentModel = model
        
        logoImageView.image = model.logo ?? UIImage(systemName: "photo.fill")
        titleLabel.text = model.title
        subtitleLabel.text = model.subtitle
        descriptionLabel.text = model.description
        
        updateTagVisibility(for: model.tag)
        updateContentVisibility(for: model)
        
        applyStyling(for: model)
    }
    
    private func applyStyling(for model: ContentModel) {
        backgroundColor = model.isSelected ? .systemGreen : .systemYellow
        layer.borderWidth = 3
        layer.cornerRadius = 12
        layer.borderColor = UIColor.systemOrange.cgColor
        
        tagLabel.backgroundColor = .systemOrange
        
        UIView.animate(withDuration: 0.2, delay: 0, options: [.allowUserInteraction], animations: {
            self.transform = CGAffineTransform(scaleX: 1.02, y: 1.02)
        }) { _ in
            UIView.animate(withDuration: 0.2) {
                self.transform = .identity
            }
        }
    }
    
    private func updateTagVisibility(for tag: String?) {
        if let tagText = tag, !tagText.isEmpty {
            tagLabel.text = " \(tagText) "
            tagLabel.isHidden = false
        } else {
            tagLabel.text = nil
            tagLabel.isHidden = true
        }
    }
    
    private func updateContentVisibility(for model: ContentModel) {
        subtitleLabel.isHidden = model.subtitle.isEmpty
        descriptionLabel.isHidden = model.description.isEmpty
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

final class ShoppingCell: UICollectionViewCell {
    
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
    
    private var currentModel: ContentModel?
    
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
    
    func configure(with model: ContentModel) {
        currentModel = model
        
        logoImageView.image = model.logo ?? UIImage(systemName: "photo.fill")
        titleLabel.text = model.title
        subtitleLabel.text = model.subtitle
        descriptionLabel.text = model.description
        
        updateTagVisibility(for: model.tag)
        updateContentVisibility(for: model)
        
        applyStyling(for: model)
    }
    
    private func applyStyling(for model: ContentModel) {
        backgroundColor = model.isSelected ? .systemGreen : .systemYellow
        layer.borderWidth = 3
        layer.cornerRadius = 12
        layer.borderColor = UIColor.systemOrange.cgColor
        
        tagLabel.backgroundColor = .systemOrange
        
        UIView.animate(withDuration: 0.2, delay: 0, options: [.allowUserInteraction], animations: {
            self.transform = CGAffineTransform(scaleX: 1.02, y: 1.02)
        }) { _ in
            UIView.animate(withDuration: 0.2) {
                self.transform = .identity
            }
        }
    }
    
    private func updateTagVisibility(for tag: String?) {
        if let tagText = tag, !tagText.isEmpty {
            tagLabel.text = " \(tagText) "
            tagLabel.isHidden = false
        } else {
            tagLabel.text = nil
            tagLabel.isHidden = true
        }
    }
    
    private func updateContentVisibility(for model: ContentModel) {
        subtitleLabel.isHidden = model.subtitle.isEmpty
        descriptionLabel.isHidden = model.description.isEmpty
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

final class TitleSubtitleCell: UICollectionViewCell {
    
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
    
    private var currentModel: ContentModel?
    
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
        setupDefaultStyle()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(with model: ContentModel) {
        currentModel = model
        
        logoImageView.image = model.logo ?? UIImage(systemName: "photo.fill")
        titleLabel.text = model.title
        subtitleLabel.text = model.subtitle
        descriptionLabel.text = model.description
        
        updateTagVisibility(for: model.tag)
        updateContentVisibility(for: model)
        updateSelectionStyle(for: model)
    }
    
    private func setupDefaultStyle() {
        backgroundColor = .systemBackground
        layer.cornerRadius = 12
        layer.masksToBounds = true
        
        layer.borderWidth = 1
        layer.borderColor = UIColor.systemGray5.cgColor
    }
    
    private func updateSelectionStyle(for model: ContentModel) {
        backgroundColor = model.isSelected ? .systemGreen : .systemGray6
    }
    
    private func updateTagVisibility(for tag: String?) {
        if let tagText = tag, !tagText.isEmpty {
            tagLabel.text = " \(tagText) "
            tagLabel.isHidden = false
        } else {
            tagLabel.text = nil
            tagLabel.isHidden = true
        }
    }
    
    private func updateContentVisibility(for model: ContentModel) {
        subtitleLabel.isHidden = model.subtitle.isEmpty
        descriptionLabel.isHidden = model.description.isEmpty
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

final class CarouselCell: UICollectionViewCell, CarouselHeightCalculator {
    
    var onItemSelect: ((ContentModel) -> Void)?
    
    private var carouselCollectionView: UICollectionView!
    private var items: [ContentModel] = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCollectionView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.verticalSizeClass != previousTraitCollection?.verticalSizeClass {
            carouselCollectionView.collectionViewLayout.invalidateLayout()
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        items.removeAll()
        carouselCollectionView.setContentOffset(.zero, animated: false)
        carouselCollectionView.reloadData()
    }
    
    func configure(with items: [ContentModel]) {
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
            
            let isLandscape = layoutEnvironment.traitCollection.verticalSizeClass == .compact
            
            let horizontalInset: CGFloat = isLandscape ? 0 : 16.0
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: horizontalInset, bottom: 0, trailing: horizontalInset)
            
            return section
        }

        carouselCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        carouselCollectionView.translatesAutoresizingMaskIntoConstraints = false
        carouselCollectionView.backgroundColor = .clear
        carouselCollectionView.dataSource = self
        carouselCollectionView.delegate = self
        carouselCollectionView.showsHorizontalScrollIndicator = false
        
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
            sizingCell.configure(with: item)
            
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
        cell.configure(with: item)
        
        if item.isSelected {
            cell.backgroundColor = .systemGreen
        } else {
            cell.backgroundColor = .systemGray5
        }
        
        cell.layer.cornerRadius = 10
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = items[indexPath.item]
        onItemSelect?(item)
    }
}

@MainActor
protocol CarouselHeightCalculator {
    func calculateHeight(forWidth width: CGFloat) -> CGFloat
}

protocol TabCellConfigurable: UICollectionViewCell {
    associatedtype Item: Hashable
    func configure(with item: Item)
    var a11yTitle: String? { get }
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
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard selectedTabIndex != indexPath.item else { return }

        selectedTabIndex = indexPath.item
        delegate?.tabBarView(didSelectTabAt: indexPath.item)
        
        scrollToMakeTabVisible(at: indexPath, animated: true)
        
        updateIndicatorPosition(animated: true)
    }
}

class TabCell: UICollectionViewCell, TabCellConfigurable {
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

final class TabBarHeaderView: UICollectionReusableView, TabBarViewDelegate {
    
    weak var delegate: TabBarViewDelegate?
    private let tabBarView = TabBarView<TabItem, TabCell>()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        tabBarView.delegate = self
        setupSubviews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupSubviews() {
        backgroundColor = .systemBackground
        tabBarView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tabBarView)
        
        NSLayoutConstraint.activate([
            tabBarView.topAnchor.constraint(equalTo: topAnchor),
            tabBarView.bottomAnchor.constraint(equalTo: bottomAnchor),
            tabBarView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tabBarView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }
    
    func configure(with tabs: [TabItem], selectedIndex: Int, horizontalPadding: CGFloat) {
        tabBarView.configure(with: tabs, selectedIndex: selectedIndex)
        directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 0,
            leading: horizontalPadding,
            bottom: 0,
            trailing: horizontalPadding
        )
    }
    
    func tabBarView(didSelectTabAt index: Int) {
        delegate?.tabBarView(didSelectTabAt: index)
    }
    
    func tabBarViewRequiresLayoutUpdate() {
        delegate?.tabBarViewRequiresLayoutUpdate()
    }
}

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

final class ListDetailCell: UICollectionViewCell {
    
    var onScrollToDisclaimerTapped: (() -> Void)?
    
    private let infoLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Expanded cell details"
        label.textAlignment = .center
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .label
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var scrollToDisclaimerButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("View Legal Disclaimer", for: .normal)
        button.titleLabel?.font = .preferredFont(forTextStyle: .callout)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(scrollToDisclaimerAction), for: .touchUpInside)
        return button
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .systemGray5
        contentView.layer.cornerRadius = 12
        contentView.addSubview(infoLabel)
        contentView.addSubview(scrollToDisclaimerButton)
        
        let verticalPadding: CGFloat = 20.0
        let horizontalPadding: CGFloat = 16.0
        
        NSLayoutConstraint.activate([
            infoLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: verticalPadding),
            infoLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: horizontalPadding),
            infoLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -horizontalPadding),
            
            scrollToDisclaimerButton.topAnchor.constraint(equalTo: infoLabel.bottomAnchor, constant: 12),
            scrollToDisclaimerButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            scrollToDisclaimerButton.widthAnchor.constraint(equalToConstant: 200),
            scrollToDisclaimerButton.heightAnchor.constraint(equalToConstant: 36),
            scrollToDisclaimerButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -verticalPadding)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func scrollToDisclaimerAction() {
        onScrollToDisclaimerTapped?()
    }
    
    func configure(with model: ContentModel) {
        
    }
}

enum HeightCacheKey: Hashable {
    case grid(sectionIndex: Int, width: CGFloat, contentSizeCategory: String)
    case carousel(sectionIndex: Int, width: CGFloat, contentSizeCategory: String)
    case list(sectionIndex: Int, width: CGFloat, contentSizeCategory: String)
    case custom(String)
}

private final class HeightCacheManager: @unchecked Sendable {
    private var cache: [HeightCacheKey: CGFloat] = [:]
    private let queue = DispatchQueue(label: "heightCache", attributes: .concurrent)
    
    func getHeight(for key: HeightCacheKey, calculator: () -> CGFloat) -> CGFloat {
        if let cachedHeight = queue.sync(execute: { cache[key] }) {
            return cachedHeight
        }
        
        let calculatedHeight = calculator()
        
        queue.async(flags: .barrier) { [weak self] in
            self?.cache[key] = calculatedHeight
        }
        
        return calculatedHeight
    }
    
    func invalidate(matching predicate: (@Sendable (HeightCacheKey) -> Bool)? = nil) {
        let predicateCopy = predicate
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            if let predicate = predicateCopy {
                self.cache = self.cache.filter { !predicate($0.key) }
            } else {
                self.cache.removeAll()
            }
        }
    }
    
    func invalidateAll() {
        queue.async(flags: .barrier) { [weak self] in
            self?.cache.removeAll()
        }
    }
}


@MainActor
final class ViewController: UIViewController {
    
    private var sectionDataManager: SectionDataManager!
    private var collectionView: UICollectionView!
    
    private typealias DataSource = UICollectionViewDiffableDataSource<Section, ItemIdentifier>
    private typealias Snapshot = NSDiffableDataSourceSnapshot<Section, ItemIdentifier>
    
    private var dataSource: DataSource!
    
    private let cellSpacing: CGFloat = 16.0
    private var expandedListSection: Int?
    
    private let heightCache = HeightCacheManager()
    
    private var horizontalPadding: CGFloat {
        let traits = view.traitCollection
        if traits.userInterfaceIdiom == .pad { return 16.0 }
        if traits.verticalSizeClass == .compact { return 0.0 }
        return 16.0
    }
    
    override func viewDidLoad() {
            super.viewDidLoad()
            setupDataManager()
            setupView()
            configureCollectionView()
            configureDataSource()
            applySnapshot(animatingDifferences: false)
            
            if let carouselSectionIndex = sectionDataManager.sections.firstIndex(where: { $0.type == .carousel }) {
                (collectionView.collectionViewLayout as? StickyCarouselHeaderLayout)?.stickyHeaderSection = carouselSectionIndex
            }
        }
        
        override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
            super.traitCollectionDidChange(previousTraitCollection)
            
            if traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory ||
               traitCollection.horizontalSizeClass != previousTraitCollection?.horizontalSizeClass ||
               traitCollection.verticalSizeClass != previousTraitCollection?.verticalSizeClass {
                
                heightCache.invalidateAll()
                collectionView.collectionViewLayout.invalidateLayout()
            }
        }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupDataManager() {
        sectionDataManager = SectionDataManager(
            isValueEnabled: true,
            isVideoEnabled: false,
            isShoppingEnabled: true,
            experience: .carousel
        )
        sectionDataManager.onSectionsDidUpdate = { [weak self] in
            self?.handleDataUpdate()
        }
    }
    
    private func setupView() {
        view.backgroundColor = .systemBackground
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
        collectionView.register(InfoCell.self, forCellWithReuseIdentifier: InfoCell.reuseIdentifier)
        collectionView.register(CarouselCell.self, forCellWithReuseIdentifier: CarouselCell.reuseIdentifier)
        collectionView.register(ValueCell.self, forCellWithReuseIdentifier: ValueCell.reuseIdentifier)
        collectionView.register(ShoppingCell.self, forCellWithReuseIdentifier: ShoppingCell.reuseIdentifier)
        collectionView.register(TitleSubtitleCell.self, forCellWithReuseIdentifier: TitleSubtitleCell.reuseIdentifier)
        collectionView.register(FooterCell.self, forCellWithReuseIdentifier: FooterCell.reuseIdentifier)
        collectionView.register(ListDetailCell.self, forCellWithReuseIdentifier: ListDetailCell.reuseIdentifier)
        collectionView.register(DisclaimerCell.self, forCellWithReuseIdentifier: DisclaimerCell.reuseIdentifier)
        
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
    
    private func handleDataUpdate() {
        let currentContentSizeCategory = traitCollection.preferredContentSizeCategory.rawValue
        heightCache.invalidate { @Sendable key in
            switch key {
            case .grid(_, _, let category), .carousel(_, _, let category):
                return category == currentContentSizeCategory
            default:
                return false
            }
        }
        applySnapshot(animatingDifferences: false)
    }

    private func invalidateCacheAndApplySnapshot(animatingDifferences: Bool = true) {
        heightCache.invalidateAll()
        collectionView.collectionViewLayout.invalidateLayout()
        applySnapshot(animatingDifferences: animatingDifferences)
    }
    
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
                    self.sectionDataManager.updateContentModel(updatedModel)
                    self.reloadSectionsContainingModel(updatedModel)
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
                cell.onScrollToDisclaimerTapped = { [weak self] in
                    guard let self = self else { return }
                    self.collectionView.scrollToSectionWithType(.disclaimer, using: self.sectionDataManager, animated: false)
                }
                return cell
                
            case .footer:
                guard let model = section.items[safe: indexPath.item] as? FooterModel else { return nil }
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FooterCell.reuseIdentifier, for: indexPath) as! FooterCell
                cell.configure(with: model)
                return cell
            case .disclaimer:
                guard let model = section.items[safe: indexPath.item] as? DisclaimerModel else { return nil }
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: DisclaimerCell.reuseIdentifier, for: indexPath) as! DisclaimerCell
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
                    guard let self = self, !selectedModel.isLoading else { return }

                    var loadingModel = selectedModel
                    loadingModel.isLoading = true
                    loadingModel.isSelected = true
                    
                    self.sectionDataManager.updateContentModel(loadingModel, notify: false)
                    
                    if let carouselSectionIndex = self.sectionDataManager.sections.firstIndex(where: { $0.type == .carousel }),
                       let carouselSection = self.sectionDataManager.getSection(at: carouselSectionIndex) {
                        var updatedCarouselItems = carouselSection.items.compactMap { $0 as? ContentModel }
                        if let index = updatedCarouselItems.firstIndex(where: { $0.id == loadingModel.id }) {
                            updatedCarouselItems[index] = loadingModel
                            self.sectionDataManager.updateCarouselItems(updatedCarouselItems, at: carouselSectionIndex)
                        }
                    }
                    
                    var snapshot = self.dataSource.snapshot()
                    
                    for section in snapshot.sectionIdentifiers {
                        var shouldReload = false
                        
                        if section.type == .list,
                           let header = section.header,
                           header.containsModel(selectedModel) {
                            shouldReload = true
                        } else if section.type == .carousel {
                            shouldReload = section.items.contains { ($0 as? ContentModel)?.id == selectedModel.id }
                        }
                        
                        if shouldReload {
                            snapshot.reloadSections([section])
                        }
                    }
                    
                    self.dataSource.apply(snapshot, animatingDifferences: false)

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        var finishedModel = loadingModel
                        finishedModel.isLoading = false
                        
                        self.sectionDataManager.updateContentModel(finishedModel, notify: false)
                        
                        if let carouselSectionIndex = self.sectionDataManager.sections.firstIndex(where: { $0.type == .carousel }),
                           let carouselSection = self.sectionDataManager.getSection(at: carouselSectionIndex) {
                            var updatedCarouselItems = carouselSection.items.compactMap { $0 as? ContentModel }
                            if let index = updatedCarouselItems.firstIndex(where: { $0.id == finishedModel.id }) {
                                updatedCarouselItems[index] = finishedModel
                                self.sectionDataManager.updateCarouselItems(updatedCarouselItems, at: carouselSectionIndex)
                            }
                        }
                        
                        var updatedSnapshot = self.dataSource.snapshot()
                        
                        for section in updatedSnapshot.sectionIdentifiers {
                            var shouldReload = false
                            
                            if section.type == .list,
                               let header = section.header,
                               header.containsModel(finishedModel) {
                                shouldReload = true
                            } else if section.type == .carousel {
                                shouldReload = section.items.contains { ($0 as? ContentModel)?.id == finishedModel.id }
                            }
                            
                            if shouldReload {
                                updatedSnapshot.reloadSections([section])
                            }
                        }
                        
                        self.dataSource.apply(updatedSnapshot, animatingDifferences: false)
                    }
                }
                
                header.onDetailsButtonTapped = { [weak self] in
                    self?.toggleListDetails(at: indexPath.section)
                }
                return header
            }
        }
    }
    
    private func applySnapshot(animatingDifferences: Bool = true, completion: (() -> Void)? = nil) {
        var snapshot = Snapshot()
        let sections = sectionDataManager.sections
        snapshot.appendSections(sections)
        
        for section in sections {
            let items: [ItemIdentifier] = createItemIdentifiers(for: section)
            snapshot.appendItems(items, toSection: section)
        }
        
        dataSource.apply(snapshot, animatingDifferences: animatingDifferences, completion: completion)
    }
    
    private func createItemIdentifiers(for section: Section) -> [ItemIdentifier] {
        switch section.type {
        case .carousel:
            if section.items.isEmpty {
                return []
            } else {
                return [ItemIdentifier(
                    id: UUID().uuidString,
                    sectionId: section.id,
                    type: .carousel
                )]
            }
            
        case .list:
            if let contentModel = section.items.first as? ContentModel,
               contentModel.isDetailsVisible {
                return [ItemIdentifier(
                    id: contentModel.id,
                    sectionId: section.id,
                    type: .single(contentModel.id)
                )]
            }
            return []
            
        case .grid:
            return section.items.map { item in
                ItemIdentifier(
                    id: item.id,
                    sectionId: section.id,
                    type: .single(item.id)
                )
            }
            
        default:
            return section.items.map { item in
                ItemIdentifier(
                    id: item.id,
                    sectionId: section.id,
                    type: .single(item.id)
                )
            }
        }
    }
    
    private func findSectionIndexForModel(_ model: ContentModel) -> Int? {
        for (index, section) in sectionDataManager.sections.enumerated() {
            switch section.type {
            case .list:
                if let header = section.header,
                   header.containsModel(model) {
                    return index
                }
            case .carousel, .grid:
                if section.items.contains(where: { ($0 as? ContentModel)?.id == model.id }) {
                    return index
                }
            default:
                continue
            }
        }
        return nil
    }
    
    private func reloadSectionsContainingModel(_ model: ContentModel) {
        var snapshot = dataSource.snapshot()
        var sectionsToReload: [Section] = []
        
        for section in sectionDataManager.sections {
            var containsModel = false
            
            switch section.type {
            case .carousel:
                containsModel = section.items.contains { ($0 as? ContentModel)?.id == model.id }
            case .grid:
                containsModel = section.items.contains { ($0 as? ContentModel)?.id == model.id }
            case .list:
                if let header = section.header {
                    containsModel = header.containsModel(model)
                }
            default:
                break
            }
            
            if containsModel {
                sectionsToReload.append(section)
            }
        }
        
        if !sectionsToReload.isEmpty {
            snapshot.reloadSections(sectionsToReload)
            dataSource.apply(snapshot, animatingDifferences: false)
        }
    }
    
    
    private func toggleListDetails(at sectionIndex: Int) {
        let previouslyExpanded = expandedListSection
        let isCollapsing = previouslyExpanded == sectionIndex
        
        let currentOffset = collectionView.contentOffset
        
        if let oldIndex = previouslyExpanded, !isCollapsing {
            if let oldSection = sectionDataManager.getSection(at: oldIndex),
               var oldModel = oldSection.items.first as? ContentModel {
                oldModel.isDetailsVisible = false
                sectionDataManager.updateContentModel(oldModel, notify: false)
            }
        }
        
        if let currentSection = sectionDataManager.getSection(at: sectionIndex),
           var currentModel = currentSection.items.first as? ContentModel {
            currentModel.isDetailsVisible.toggle()
            sectionDataManager.updateContentModel(currentModel, notify: false)
            
            expandedListSection = isCollapsing ? nil : sectionIndex
            
            applySnapshot(animatingDifferences: false) {
                if currentModel.isDetailsVisible {
                    if let layoutAttributes = self.collectionView.layoutAttributesForSupplementaryElement(
                        ofKind: UICollectionView.elementKindSectionHeader,
                        at: IndexPath(item: 0, section: sectionIndex)
                    ) {
                        var stickyHeaderHeight: CGFloat = 0
                        if let carouselSection = self.sectionDataManager.sections.firstIndex(where: { $0.type == .carousel }),
                           let stickyAttrs = self.collectionView.layoutAttributesForSupplementaryElement(
                               ofKind: UICollectionView.elementKindSectionHeader,
                               at: IndexPath(item: 0, section: carouselSection)
                           ) {
                            stickyHeaderHeight = stickyAttrs.frame.height
                        }
                        
                        let targetY = layoutAttributes.frame.origin.y - self.collectionView.adjustedContentInset.top - stickyHeaderHeight - 8
                        
                        self.collectionView.setContentOffset(CGPoint(x: 0, y: targetY), animated: false)
                    }
                } else {
                    self.collectionView.setContentOffset(currentOffset, animated: false)
                }
            }
        }
    }
    
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
            case .disclaimer:
                return self.createDisclaimerSection()
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
        let contentSizeCategory = traitCollection.preferredContentSizeCategory.rawValue
        let cacheKey = HeightCacheKey.carousel(
            sectionIndex: sectionIndex,
            width: 132.0,
            contentSizeCategory: contentSizeCategory
        )
        
        let finalHeight = heightCache.getHeight(for: cacheKey) {
            self.calculateCarouselHeight(in: sectionIndex)
        }
        
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
        
        let contentSizeCategory = traitCollection.preferredContentSizeCategory.rawValue
        let cacheKey = HeightCacheKey.grid(
            sectionIndex: sectionIndex,
            width: cellWidth,
            contentSizeCategory: contentSizeCategory
        )
        
        let finalHeight = heightCache.getHeight(for: cacheKey) {
            self.calculateMaxGridCellHeight(for: cellWidth, in: sectionIndex)
        }
        
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
        
        let contentSizeCategory = traitCollection.preferredContentSizeCategory.rawValue
        let cacheKey = HeightCacheKey.grid(
            sectionIndex: sectionIndex,
            width: cellWidth,
            contentSizeCategory: contentSizeCategory
        )
        
        let finalHeight = heightCache.getHeight(for: cacheKey) {
            self.calculateMaxGridCellHeight(for: cellWidth, in: sectionIndex)
        }
        
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
        sectionLayout.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: horizontalPadding, bottom: 0, trailing: horizontalPadding)
        
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
    
    private func createDisclaimerSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(100))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = cellSpacing
        section.contentInsets = NSDirectionalEdgeInsets(top: cellSpacing, leading: horizontalPadding, bottom: cellSpacing, trailing: horizontalPadding)
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

extension ViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        
        guard let section = sectionDataManager.getSection(at: indexPath.section),
              section.type == .grid,
              let item = section.items[safe: indexPath.item] as? ContentModel,
              !item.isShoppingPlaceholder else { return }
        
        var updatedModel = item
        updatedModel.isSelected.toggle()
        sectionDataManager.updateContentModel(updatedModel)
        reloadSectionsContainingModel(updatedModel)
    }
}

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

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

extension UICollectionView {
    func scrollToSection(_ section: Int, at position: UICollectionView.ScrollPosition = .top, animated: Bool = true) {
        guard numberOfSections > section else { return }
        
        if let layoutAttributes = layoutAttributesForSupplementaryElement(ofKind: UICollectionView.elementKindSectionHeader,
                                                                              at: IndexPath(item: 0, section: section)) {
            let offsetY = layoutAttributes.frame.origin.y - adjustedContentInset.top
            setContentOffset(CGPoint(x: 0, y: offsetY), animated: animated)
        } else if numberOfItems(inSection: section) > 0 {
            let indexPath = IndexPath(item: 0, section: section)
            scrollToItem(at: indexPath, at: position, animated: animated)
        }
    }
    
    func scrollToSectionWithType(_ sectionType: SectionType, using dataManager: SectionDataManager, at position: UICollectionView.ScrollPosition = .top, animated: Bool = true) {
        guard let sectionIndex = dataManager.sections.firstIndex(where: { $0.type == sectionType }) else { return }
        scrollToSection(sectionIndex, at: position, animated: animated)
    }

}
