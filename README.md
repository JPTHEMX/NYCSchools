import UIKit

struct TabItem: Hashable {
    let title: String
}

enum SectionHeader: Hashable {
    case title(String)
    case tabBar(tabs: [TabItem], selectedIndex: Int)
    case list(ContentModel)
}

struct InfoModel: Hashable {
    let id = UUID()
    let title: String
    let subtitle: String?
    
    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: InfoModel, rhs: InfoModel) -> Bool {
        return lhs.id == rhs.id
    }
}

struct FooterModel: Hashable {
    let id = UUID()
    let title: String
    let subtitle: String?
    
    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: FooterModel, rhs: FooterModel) -> Bool {
        return lhs.id == rhs.id
    }
}

struct ShoppingModel: Hashable {
    let id = UUID()
    let title: String
    let subtitle: String?
    
    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ShoppingModel, rhs: ShoppingModel) -> Bool {
        return lhs.id == rhs.id
    }
}

struct ContentModel: Hashable {
    let id = UUID()
    let logo: UIImage?
    let tag: String?
    let title: String
    let subtitle: String
    let description: String
    
    init(logo: UIImage? = nil, tag: String? = nil, title: String, subtitle: String, description: String) {
        self.logo = logo
        self.tag = tag
        self.title = title
        self.subtitle = subtitle
        self.description = description
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ContentModel, rhs: ContentModel) -> Bool {
        return lhs.id == rhs.id
    }
}

// Extensión actualizada para ContentModel
extension ContentModel {
    static func carouselItem(index: Int, prefix: String, isHighlighted: Bool = false) -> ContentModel {
        let tag: String? = isHighlighted ? "Destacado" : nil
        let title = "\(prefix) - Item del Carrusel \(index)"
        let subtitle = "Subtítulo para el item \(index) de \(prefix)."
        var description = "Descripción para \(prefix)."
        
        if index % 4 == 0 {
            description += " Esta descripción es un poco más larga."
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
                title: "\(prefix) - Celda Value (\(index))",
                subtitle: "Esta celda tiene un diseño especial.",
                description: "Su tamaño cambia según la orientación."
            )
        } else {
            return ContentModel(
                logo: UIImage(systemName: "photo.fill"),
                tag: "New",
                title: "\(prefix) - Celda \(index)",
                subtitle: "Subtítulo \(index)",
                description: "Una descripción estándar para una celda estándar de \(prefix)."
            )
        }
    }
}

/// This enum now holds only the content type and its associated data.
enum SectionContent: Hashable {
    case generalInfo(header: SectionHeader?, items: [InfoModel])
    case carousel(header: SectionHeader?, items: [ContentModel])
    case grid(header: SectionHeader?, items: [ContentModel])
    case list(header: SectionHeader?, item: ContentModel)
    case footer(header: SectionHeader?, items: [FooterModel])
}

/// Section is now a struct, allowing its properties (like the header) to be mutable.
struct Section: Hashable {
    let id = UUID()
    var content: SectionContent
    
    // Computed property para acceder al header
    var header: SectionHeader? {
        switch content {
        case .generalInfo(let header, _),
             .carousel(let header, _),
             .grid(let header, _),
             .list(let header, _),
             .footer(let header, _):
            return header
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Section, rhs: Section) -> Bool {
        return lhs.id == rhs.id
    }
}

import UIKit

@MainActor
class SectionDataManager {
    
    // MARK: - Properties
    
    private var sectionsByTab: [TabItem: [Section]] = [:]
    var isValueEnabled: Bool
    var isVideoEnabled: Bool
    var isShoppingEnabled: Bool
    
    var tabData: [TabItem] = (0..<8).map { TabItem(title: "Categoría \($0 + 1)") }
    private(set) var selectedTabIndex: Int = 0
    
    var onSectionsDidUpdate: (() -> Void)?
    
    private var currentTab: TabItem? {
        return tabData[safe: selectedTabIndex]
    }
    
    /// Almacena el índice dinámico calculado para la pestaña actual. Es la única fuente de verdad para la posición de la ShoppingCell.
    private(set) var currentShoppingCellIndex: Int?

    // MARK: - Initializer

    init(isValueEnabled: Bool = false, isVideoEnabled: Bool = false, isShoppingEnabled: Bool = false) {
        self.isValueEnabled = isValueEnabled
        self.isVideoEnabled = isVideoEnabled
        self.isShoppingEnabled = isShoppingEnabled
        setupInitialData()
    }
    
    // MARK: - Subscripts for Mutable Data Access
    
    subscript(section index: Int) -> Section? {
        get {
            guard let tab = currentTab,
                  let sections = sectionsByTab[tab],
                  sections.indices.contains(index) else {
                return nil
            }
            return sections[index]
        }
        set {
            guard let tab = currentTab,
                  let newValue = newValue,
                  sectionsByTab[tab]?.indices.contains(index) == true else {
                return
            }
            sectionsByTab[tab]?[index] = newValue
        }
    }
    
    subscript(itemAt indexPath: IndexPath) -> Any? {
        get {
            guard let content = self[section: indexPath.section]?.content else { return nil }
            
            switch content {
            case .generalInfo(_, let items):
                return items[safe: indexPath.item]
            case .carousel(_, let items):
                return items
            case .grid(_, let items):
                return items[safe: indexPath.item]
            case .list(_, let item):
                return item
            case .footer(_, let items):
                return items[safe: indexPath.item]
            }
        }
        set {
            guard var sectionToUpdate = self[section: indexPath.section] else {
                return
            }
            
            var newContent = sectionToUpdate.content
            var modelToSync: ContentModel?
            
            switch newContent {
            case .generalInfo(let header, var items):
                if let newItem = newValue as? InfoModel, items.indices.contains(indexPath.item) {
                    items[indexPath.item] = newItem
                    newContent = .generalInfo(header: header, items: items)
                }
            case .carousel(let header, _):
                if let newItems = newValue as? [ContentModel] {
                    newContent = .carousel(header: header, items: newItems)
                }
            case .grid(let header, var items):
                if let newItem = newValue as? ContentModel, items.indices.contains(indexPath.item) {
                    items[indexPath.item] = newItem
                    newContent = .grid(header: header, items: items)
                    modelToSync = newItem
                }
            case .list(let header, _):
                if let newItem = newValue as? ContentModel {
                    newContent = .list(header: header, item: newItem)
                    modelToSync = newItem
                }
            case .footer(let header, var items):
                if let newItem = newValue as? FooterModel, items.indices.contains(indexPath.item) {
                    items[indexPath.item] = newItem
                    newContent = .footer(header: header, items: items)
                }
            }
            
            sectionToUpdate.content = newContent
            self[section: indexPath.section] = sectionToUpdate
            
            if let model = modelToSync {
                updateContentModel(model)
            }
        }
    }
    
    subscript(headerFor sectionIndex: Int) -> SectionHeader? {
        get {
            guard var headerModel = self[section: sectionIndex]?.header else {
                return nil
            }
            if case .tabBar = headerModel {
                headerModel = .tabBar(tabs: self.tabData, selectedIndex: self.selectedTabIndex)
            }
            return headerModel
        }
        set {
            guard let tab = currentTab,
                  var sections = sectionsByTab[tab],
                  sections.indices.contains(sectionIndex) else {
                return
            }
            
            var section = sections[sectionIndex]
            switch section.content {
            case .generalInfo(_, let items):
                section.content = .generalInfo(header: newValue, items: items)
            case .carousel(_, let items):
                section.content = .carousel(header: newValue, items: items)
            case .grid(_, let items):
                section.content = .grid(header: newValue, items: items)
            case .list(_, let item):
                section.content = .list(header: newValue, item: item)
            case .footer(_, let items):
                section.content = .footer(header: newValue, items: items)
            }
            
            sections[sectionIndex] = section
            sectionsByTab[tab] = sections
        }
    }
    
    subscript(itemsForSection sectionIndex: Int) -> Any? {
        get {
            guard let content = self[section: sectionIndex]?.content else { return nil }
            
            switch content {
            case .generalInfo(_, let items):
                return items
            case .carousel(_, let items):
                return items
            case .grid(_, let items):
                return items
            case .list(_, let item):
                return item
            case .footer(_, let items):
                return items
            }
        }
        set {
            guard var section = self[section: sectionIndex], let newItems = newValue else { return }
            switch section.content {
            case .generalInfo(let header, _):
                if let items = newItems as? [InfoModel] {
                    section.content = .generalInfo(header: header, items: items)
                }
            case .carousel(let header, _):
                if let items = newItems as? [ContentModel] {
                    section.content = .carousel(header: header, items: items)
                }
            case .grid(let header, _):
                if let items = newItems as? [ContentModel] {
                    section.content = .grid(header: header, items: items)
                }
            case .list(let header, _):
                if let item = newItems as? ContentModel {
                    section.content = .list(header: header, item: item)
                }
            case .footer(let header, _):
                if let items = newItems as? [FooterModel] {
                    section.content = .footer(header: header, items: items)
                }
            }
            
            // Usar el subscript de sección existente para actualizar la fuente de datos
            self[section: sectionIndex] = section
        }
    }
    
    // MARK: - Read-Only Accessors
    
    var sections: [Section] {
        sectionsByTab[currentTab ?? TabItem(title: "")] ?? []
    }

    func numberOfSections() -> Int {
        sections.count
    }

    func numberOfItems(in sectionIndex: Int) -> Int {
        guard let content = self[section: sectionIndex]?.content else {
            return 0
        }
        switch content {
        case .generalInfo(_, let items):
            return items.count
        case .carousel:
            return 1
        case .grid(_, let items):
            return items.count
        case .list:
            return 0
        case .footer(_, let items):
            return items.count
        }
    }

    // MARK: - Logic for Special Cells

    /// Calcula y actualiza el índice de la ShoppingCell basándose en el entorno del layout.
    /// El ViewController llamará a este método cuando el layout se invalide.
    func updateShoppingCellIndex(for tab: TabItem, columnCount: Int) {
        self.currentShoppingCellIndex = nil
        
        guard let sections = sectionsByTab[tab],
              let gridSection = sections.first(where: { if case .grid = $0.content { return true } else { return false } }),
              case .grid(_, let items) = gridSection.content else {
            return
        }
        
        let itemCount = items.count
        let baseShoppingIndex = 19

        guard isShoppingEnabled && itemCount > baseShoppingIndex else {
            return
        }

        // 1. Determinar desde dónde empieza el grid
        var gridStartIndex = 0
        if isValueEnabled {
            // En iPad/Portrait (<=2 columnas), ValueCell ocupa 1 espacio.
            // En Landscape (>2 columnas), ValueCell y su par ocupan 2 espacios.
            gridStartIndex = (columnCount <= 2) ? 1 : 2
        }
        
        // 2. Calcular la posición ideal alineada con el inicio de una fila
        var finalIndex: Int
        if baseShoppingIndex >= gridStartIndex {
            let indexRelativeToGrid = baseShoppingIndex - gridStartIndex
            let offset = indexRelativeToGrid % columnCount
            
            if offset == 0 {
                finalIndex = baseShoppingIndex
            } else {
                finalIndex = baseShoppingIndex - offset + columnCount
            }
        } else {
            finalIndex = gridStartIndex
        }
        
        // 3. Guardar el resultado si es válido
        if finalIndex < itemCount {
            self.currentShoppingCellIndex = finalIndex
        }
    }

    func shouldUseValueCell(at indexPath: IndexPath) -> Bool {
        guard let content = self[section: indexPath.section]?.content else { return false }
        switch content {
        case .grid:
            return isValueEnabled && indexPath.item == 0
        default:
            return false
        }
    }
    
    func shouldUseShoppingCell(at indexPath: IndexPath) -> Bool {
        guard isShoppingEnabled, let shoppingIndex = currentShoppingCellIndex else {
            return false
        }
        return indexPath.item == shoppingIndex
    }
    
    // MARK: - Data Synchronization
    func updateContentModel(_ updatedModel: ContentModel) {
        var needsUpdate = false
        for (tab, sections) in sectionsByTab {
            var updatedSections = sections
            var sectionWasUpdated = false
            for (sectionIndex, section) in sections.enumerated() {
                var updatedSection = section
                switch section.content {
                case .carousel(let header, var items):
                    if let index = items.firstIndex(where: { $0.id == updatedModel.id }) {
                        items[index] = updatedModel
                        updatedSection.content = .carousel(header: header, items: items)
                        updatedSections[sectionIndex] = updatedSection
                        sectionWasUpdated = true
                    }
                case .grid(let header, var items):
                    if let index = items.firstIndex(where: { $0.id == updatedModel.id }) {
                        items[index] = updatedModel
                        updatedSection.content = .grid(header: header, items: items)
                        updatedSections[sectionIndex] = updatedSection
                        sectionWasUpdated = true
                    }
                case .list(let header, let item):
                    if item.id == updatedModel.id {
                        updatedSection.content = .list(header: header, item: updatedModel)
                        updatedSections[sectionIndex] = updatedSection
                        sectionWasUpdated = true
                    }
                default:
                    break
                }
            }
            if sectionWasUpdated {
                sectionsByTab[tab] = updatedSections
                needsUpdate = true
            }
        }
        if needsUpdate {
            onSectionsDidUpdate?()
        }
    }
    
    func updateContentModels(_ updatedModels: [ContentModel]) {
        var needsUpdate = false
        let modelsDict = Dictionary(uniqueKeysWithValues: updatedModels.map { ($0.id, $0) })
        for (tab, sections) in sectionsByTab {
            var updatedSections = sections
            var sectionWasUpdated = false
            
            for (sectionIndex, section) in sections.enumerated() {
                var updatedSection = section
                
                switch section.content {
                case .carousel(let header, var items):
                    var itemsWereUpdated = false
                    for (index, item) in items.enumerated() {
                        if let updatedModel = modelsDict[item.id] {
                            items[index] = updatedModel
                            itemsWereUpdated = true
                        }
                    }
                    if itemsWereUpdated {
                        updatedSection.content = .carousel(header: header, items: items)
                        updatedSections[sectionIndex] = updatedSection
                        sectionWasUpdated = true
                    }
                case .grid(let header, var items):
                    var itemsWereUpdated = false
                    for (index, item) in items.enumerated() {
                        if let updatedModel = modelsDict[item.id] {
                            items[index] = updatedModel
                            itemsWereUpdated = true
                        }
                    }
                    if itemsWereUpdated {
                        updatedSection.content = .grid(header: header, items: items)
                        updatedSections[sectionIndex] = updatedSection
                        sectionWasUpdated = true
                    }
                case .list(let header, let item):
                    if let updatedModel = modelsDict[item.id] {
                        updatedSection.content = .list(header: header, item: updatedModel)
                        updatedSections[sectionIndex] = updatedSection
                        sectionWasUpdated = true
                    }
                default:
                    break
                }
            }
            if sectionWasUpdated {
                sectionsByTab[tab] = updatedSections
                needsUpdate = true
            }
        }
        
        if needsUpdate {
            onSectionsDidUpdate?()
        }
    }
    
    func resetData() {
        setupInitialData()
        selectedTabIndex = 0
        onSectionsDidUpdate?()
    }
    
    func reloadTab(at index: Int) {
        guard tabData.indices.contains(index),
              let tab = tabData[safe: index] else { return }
        
        sectionsByTab[tab] = createSections(for: tab)
        
        if index == selectedTabIndex {
            onSectionsDidUpdate?()
        }
    }
    
    func setSelectedTabIndex(_ index: Int) {
        guard index != selectedTabIndex, tabData.indices.contains(index) else { return }
        selectedTabIndex = index
        onSectionsDidUpdate?()
    }
    
    // MARK: - State Management & Data Generation
    
    private func setupInitialData() {
        for tab in tabData {
            sectionsByTab[tab] = createSections(for: tab)
        }
    }

    private func createSections(for tab: TabItem) -> [Section] {
        let prefix = tab.title.replacingOccurrences(of: "Categoría", with: "Contenido")
        let itemCount = 100 + (Int(tab.title.last?.wholeNumberValue ?? 1) * 3)
        return [
            createGeneralInfoSection(prefix: prefix),
            createCarouselSection(prefix: prefix),
            createGridSection(prefix: prefix, itemCount: itemCount),
            createFooterSection(prefix: prefix)
        ]
    }
    
    // MARK: - Section Factory Methods
    
    private func createGeneralInfoSection(prefix: String) -> Section {
        let items = [
            InfoModel(title: "\(prefix) Info Item 1", subtitle: "General info subtitle"),
            InfoModel(title: "\(prefix) Info Item 2", subtitle: "Another subtitle")
        ]
        return Section(content: .generalInfo(header: nil, items: items))
    }

    private func createCarouselSection(prefix: String) -> Section {
        let items = (0..<12).map { i in
            ContentModel.carouselItem(index: i, prefix: prefix, isHighlighted: i % 4 == 0)
        }
        let header = SectionHeader.tabBar(tabs: [], selectedIndex: 0)
        return Section(content: .carousel(header: header, items: items))
    }

    private func createGridSection(prefix: String, itemCount: Int) -> Section {
        let items = (0..<itemCount).map { i in
            ContentModel.gridItem(index: i, prefix: prefix, isValue: self.isValueEnabled && i == 0)
        }
        let header = SectionHeader.title("Explorar Contenido")
        return Section(content: .grid(header: header, items: items))
    }

    private func createFooterSection(prefix: String) -> Section {
        let items = [FooterModel(title: "\(prefix) Footer", subtitle: "Additional footer details")]
        return Section(content: .footer(header: nil, items: items))
    }
}

import UIKit

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
        backgroundColor = .systemBackground
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

final class TabBarHeaderView: UICollectionReusableView, TabBarViewDelegate {
    
    weak var delegate: TabBarViewDelegate?
    private let tabBarView = TabBarView<TabItem, TabCell>()
    
    private enum Constants {
        static let portraitPadding: CGFloat = 16.0
        static let landscapePadding: CGFloat = 32.0
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
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
    
    private func updateHorizontalPadding() {
        let isLandscape = traitCollection.verticalSizeClass == .compact
        let padding = isLandscape ? Constants.landscapePadding : Constants.portraitPadding
        
        directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 0,
            leading: padding,
            bottom: 0,
            trailing: padding
        )
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

import UIKit

// This is a UICollectionReusableView that has the exact layout and logic of a cell.
final class ListHeaderView: UICollectionReusableView {
    
    // All UI elements are copied directly from TitleSubtitleCell
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
        static let horizontalPadding: CGFloat = 16 // Adjusted for header
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
    
    // The configure method now takes a single model
    func configure(with model: ContentModel) {
        currentModel = model
        
        logoImageView.image = model.logo ?? UIImage(systemName: "photo.fill")
        titleLabel.text = model.title
        subtitleLabel.text = model.subtitle
        descriptionLabel.text = model.description
        
        updateTagVisibility(for: model.tag)
        updateContentVisibility(for: model)
    }
    
    private func setupDefaultStyle() {
        backgroundColor = .systemGray6
        layer.cornerRadius = 12
        layer.masksToBounds = true
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
        
        addSubview(logoImageView)
        addSubview(tagLabel)
        addSubview(textContentStack)
        
        NSLayoutConstraint.activate([
            logoImageView.topAnchor.constraint(equalTo: topAnchor, constant: Constants.logoTopPadding),
            logoImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Constants.horizontalPadding),
            logoImageView.widthAnchor.constraint(equalToConstant: Constants.logoSize),
            logoImageView.heightAnchor.constraint(equalToConstant: Constants.logoSize),
            
            tagLabel.topAnchor.constraint(equalTo: topAnchor, constant: Constants.tagTopPadding),
            tagLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Constants.horizontalPadding),
            tagLabel.leadingAnchor.constraint(greaterThanOrEqualTo: logoImageView.trailingAnchor, constant: 8),
            
            textContentStack.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: Constants.stackTopPadding),
            textContentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Constants.horizontalPadding),
            textContentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Constants.horizontalPadding),
            textContentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Constants.bottomPadding)
        ])
    }
}


import UIKit

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
        applyStyling()
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
        
        applyStyling()
    }
    
    private func applyStyling() {
        backgroundColor = .systemYellow
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
        applyStyling()
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
        
        applyStyling()
    }
    
    private func applyStyling() {
        backgroundColor = .systemYellow
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
    }
    
    func configure(logo: UIImage?, tag: String?, title: String, subtitle: String, description: String) {
        let model = ContentModel(
            logo: logo,
            tag: tag,
            title: title,
            subtitle: subtitle,
            description: description
        )
        configure(with: model)
    }
    
    private func setupDefaultStyle() {
        backgroundColor = .systemBackground
        layer.cornerRadius = 12
        layer.masksToBounds = true
        
        layer.borderWidth = 1
        layer.borderColor = UIColor.systemGray5.cgColor
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
    
    private var carouselCollectionView: UICollectionView!
    private var items: [ContentModel] = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCollectionView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Implementar prepareForReuse correctamente
    override func prepareForReuse() {
        super.prepareForReuse()
        // Limpiar los datos
        items.removeAll()
        // Resetear el scroll position
        carouselCollectionView.setContentOffset(.zero, animated: false)
        // Recargar para limpiar las celdas reutilizadas
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
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
            
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
            sizingCell.configure(
                logo: UIImage(systemName: "star.fill"),
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
        let item = items[indexPath.item]
        print("Item del carrusel interno seleccionado: \(item.title)")
    }
}

@MainActor
protocol CarouselHeightCalculator {
    func calculateHeight(forWidth width: CGFloat) -> CGFloat
}

import UIKit

protocol TabCellConfigurable: UICollectionViewCell {
    associatedtype Item: Hashable
    func configure(with item: Item)
    var a11yTitle: String? { get }
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
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard selectedTabIndex != indexPath.item else { return }

        selectedTabIndex = indexPath.item
        delegate?.tabBarView(didSelectTabAt: indexPath.item)
        
        collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
        
        collectionView.performBatchUpdates({
            let context = UICollectionViewFlowLayoutInvalidationContext()
            context.invalidateItems(at: [indexPath])
            collectionView.collectionViewLayout.invalidateLayout(with: context)
        }, completion: { [weak self] _ in
            self?.updateIndicatorPosition(animated: true)
        })
    }
}


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
    
    // MARK: - Properties
    
    private var sectionDataManager: SectionDataManager!
    private var collectionView: UICollectionView!
    private let cellSpacing: CGFloat = 16.0
    
    // Cache para el cálculo de alturas de celdas
    private var cachedGridCellHeight: CGFloat?
    private var shouldRecalculateGridHeight = true
    private var cachedCarouselCellHeight: CGFloat?
    private var shouldRecalculateCarouselHeight = true
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupDataManager()
        setupView()
        setupNotifications()
        configureCollectionView()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    
    private func setupDataManager() {
        sectionDataManager = SectionDataManager()
        sectionDataManager.isValueEnabled = true
        sectionDataManager.isShoppingEnabled = true
        sectionDataManager.onSectionsDidUpdate = { [weak self] in
            self?.handleDataUpdate()
        }
    }
    
    private func setupView() {
        view.backgroundColor = .systemBackground
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(contentSizeCategoryDidChange), name: UIContentSizeCategory.didChangeNotification, object: nil)
    }
    
    // MARK: - UI Configuration
    
    private func configureCollectionView() {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.dataSource = self
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
        collectionView.register(ShoppingCell.self, forCellWithReuseIdentifier: ShoppingCell.reuseIdentifier) // Agregar esta línea
        collectionView.register(TitleSubtitleCell.self, forCellWithReuseIdentifier: TitleSubtitleCell.reuseIdentifier)
        collectionView.register(FooterCell.self, forCellWithReuseIdentifier: FooterCell.reuseIdentifier)
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "cell")
        
        collectionView.register(TitleHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: TitleHeaderView.reuseIdentifier)
        collectionView.register(TabBarHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: TabBarHeaderView.reuseIdentifier)
        collectionView.register(ListHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: ListHeaderView.reuseIdentifier)
        collectionView.register(UICollectionReusableView.self,
                                    forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                                    withReuseIdentifier: "blankHeader")
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    // MARK: - Handlers
    
    private func handleDataUpdate() {
        invalidateCacheAndReload()
        
        DispatchQueue.main.async {
            let topOffset = CGPoint(x: 0, y: -self.collectionView.adjustedContentInset.top)
            self.collectionView.setContentOffset(topOffset, animated: false)
        }
    }

    @objc private func contentSizeCategoryDidChange() {
        invalidateCacheAndReload()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.horizontalSizeClass != previousTraitCollection?.horizontalSizeClass ||
           traitCollection.verticalSizeClass != previousTraitCollection?.verticalSizeClass {
            invalidateCacheAndReload()
        }
    }
    
    private func invalidateCacheAndReload() {
        shouldRecalculateGridHeight = true
        shouldRecalculateCarouselHeight = true
        collectionView.collectionViewLayout.invalidateLayout()
        collectionView.reloadData()
    }
}

// MARK: - Layout Creation
extension ViewController {
    func createLayout() -> UICollectionViewCompositionalLayout {
        let layout = StickyCarouselHeaderLayout { [weak self] sectionIndex, layoutEnvironment in
            guard let self, let section = self.sectionDataManager[section: sectionIndex] else {
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(1))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                return NSCollectionLayoutSection(group: group)
            }
            
            switch section.content {
            case .generalInfo:
                return createInfoSection()
            case .carousel:
                return createCarouselSection(for: sectionIndex)
            case .grid:
                return createGridSection(for: sectionIndex, layoutEnvironment: layoutEnvironment)
            case .list:
                return nil
            case .footer:
                return createFooterSection(layoutEnvironment: layoutEnvironment)
            }
        }
        if let carouselSectionIndex = sectionDataManager.sections.firstIndex(where: {
            if case .carousel = $0.content {
                return true
            }
            return false
        }) {
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
        section.contentInsets = NSDirectionalEdgeInsets(top: cellSpacing, leading: 16, bottom: cellSpacing, trailing: 16)
        return section
    }

    private func createCarouselSection(for sectionIndex: Int) -> NSCollectionLayoutSection {
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
        section.contentInsets = NSDirectionalEdgeInsets(top: cellSpacing, leading: 0, bottom: cellSpacing, trailing: 0)

        if let headerModel = sectionDataManager[headerFor: sectionIndex], case .tabBar = headerModel {
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
        
        if sectionDataManager[headerFor: sectionIndex] != nil {
            section.boundarySupplementaryItems = [createHeader(estimatedHeight: 44)]
        }
        return section
    }
    
    private func createHeader(estimatedHeight: CGFloat) -> NSCollectionLayoutBoundarySupplementaryItem {
        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(estimatedHeight))
        return NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
    }

    private func createTabBarHeader() -> NSCollectionLayoutBoundarySupplementaryItem {
        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(50))
        let sectionHeader = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
        sectionHeader.pinToVisibleBounds = true
        return sectionHeader
    }
    
    private func createMixedGridLayoutSection(for sectionIndex: Int, layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let traitCollection = layoutEnvironment.traitCollection
        let isPortrait = traitCollection.verticalSizeClass == .regular && traitCollection.horizontalSizeClass == .compact
        let isIPad = traitCollection.userInterfaceIdiom == .pad
        let itemCount = sectionDataManager.numberOfItems(in: sectionIndex)
        let hasValueCell = sectionDataManager.isValueEnabled

        let columnCount = (isIPad || !isPortrait) ? 3 : 2
        
        if let currentTab = sectionDataManager.tabData[safe: sectionDataManager.selectedTabIndex] {
            sectionDataManager.updateShoppingCellIndex(for: currentTab, columnCount: columnCount)
        }
        let dynamicShoppingCellIndex = sectionDataManager.currentShoppingCellIndex
        
        let cellWidth: CGFloat
        let availableWidth = layoutEnvironment.container.effectiveContentSize.width - 32
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

            if isValueItem || isShoppingItem {
                let rowSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(finalHeight))
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
        section.contentInsets = NSDirectionalEdgeInsets(top: cellSpacing, leading: 16, bottom: cellSpacing, trailing: 16)
        
        return section
    }
    
    private func createUniformGridSection(for sectionIndex: Int, layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let containerWidth = layoutEnvironment.container.effectiveContentSize.width
        let isPortrait = traitCollection.verticalSizeClass == .regular && traitCollection.horizontalSizeClass == .compact
        let isIPad = traitCollection.userInterfaceIdiom == .pad
        
        let columnCount = isIPad ? 3 : (isPortrait ? 2 : 3)
        let sectionInset: CGFloat = 16.0
        let availableWidth = containerWidth - (sectionInset * 2)
        
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
        section.contentInsets = NSDirectionalEdgeInsets(top: cellSpacing, leading: sectionInset, bottom: cellSpacing, trailing: sectionInset)
        return section
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
        
        return section
    }
}

// MARK: - Height Calculation
extension ViewController {
    
    private func calculateCarouselHeight(in sectionIndex: Int) -> CGFloat {
        guard let section = sectionDataManager[section: sectionIndex],
              case .carousel(_, let items) = section.content, !items.isEmpty else {
            return 220.0
        }
        let sizingCell = CarouselCell(frame: .zero)
        sizingCell.configure(with: items)
        return sizingCell.calculateHeight(forWidth: 132.0)
    }
    
    private func calculateMaxGridCellHeight(for cellWidth: CGFloat, in sectionIndex: Int) -> CGFloat {
        guard let section = sectionDataManager[section: sectionIndex],
              case .grid(_, let items) = section.content, !items.isEmpty else {
            return 192.0
        }
        
        var maxHeight: CGFloat = 0.0
        let valueSizingCell = ValueCell(frame: .zero)
        let shoppingSizingCell = ShoppingCell(frame: .zero)
        let standardSizingCell = TitleSubtitleCell(frame: .zero)
        
        for (index, item) in items.enumerated() {
            let sizingView: UIView
            let indexPath = IndexPath(item: index, section: sectionIndex)
            
            if sectionDataManager.shouldUseShoppingCell(at: indexPath) {
                shoppingSizingCell.configure(with: item)
                sizingView = shoppingSizingCell
            } else if sectionDataManager.shouldUseValueCell(at: indexPath) {
                valueSizingCell.configure(with: item)
                sizingView = valueSizingCell
            } else {
                standardSizingCell.configure(with: item)
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

// MARK: - UICollectionViewDataSource
extension ViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return sectionDataManager.numberOfSections()
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return sectionDataManager.numberOfItems(in: section)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let section = sectionDataManager[section: indexPath.section] else {
            return collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
        }
        
        switch section.content {
        case .generalInfo(_, let items):
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: InfoCell.reuseIdentifier, for: indexPath) as! InfoCell
            if let item = items[safe: indexPath.item] { cell.configure(with: item) }
            return cell
            
        case .carousel(_, let items):
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CarouselCell.reuseIdentifier, for: indexPath) as! CarouselCell
            cell.configure(with: items)
            return cell
            
        case .grid(_, let items):
            guard let item = items[safe: indexPath.item] else {
                return collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
            }
            if sectionDataManager.shouldUseShoppingCell(at: indexPath) {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ShoppingCell.reuseIdentifier, for: indexPath) as! ShoppingCell
                cell.configure(with: item)
                return cell
            } else if sectionDataManager.shouldUseValueCell(at: indexPath) {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ValueCell.reuseIdentifier, for: indexPath) as! ValueCell
                cell.configure(with: item)
                return cell
            } else {
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TitleSubtitleCell.reuseIdentifier, for: indexPath) as! TitleSubtitleCell
                cell.configure(with: item)
                cell.backgroundColor = .systemGray6
                return cell
            }
        case .list(_, _):
            return collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
            
        case .footer(_, let items):
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FooterCell.reuseIdentifier, for: indexPath) as! FooterCell
            if let item = items[safe: indexPath.item] { cell.configure(with: item) }
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionHeader,
              let headerModel = sectionDataManager[headerFor: indexPath.section] else {
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "blankHeader", for: indexPath)
            return header
        }
        
        switch headerModel {
        case .title(let title):
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: TitleHeaderView.reuseIdentifier, for: indexPath) as! TitleHeaderView
            header.configure(with: title)
            return header
            
        case .tabBar(let tabs, let selectedIndex):
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: TabBarHeaderView.reuseIdentifier, for: indexPath) as! TabBarHeaderView
            header.delegate = self
            header.configure(with: tabs, selectedIndex: selectedIndex)
            return header
            
        case .list(let item):
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: ListHeaderView.reuseIdentifier, for: indexPath) as! ListHeaderView
            header.configure(with: item)
            return header
        }
    }
}

// MARK: - UICollectionViewDelegate
extension ViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        
        if let item = sectionDataManager[itemAt: indexPath] as? ContentModel {
             print("Tapped on item: \(item.title)")
        }
    }
}

// MARK: - TabBarViewDelegate
extension ViewController: TabBarViewDelegate {
    func tabBarView(didSelectTabAt index: Int) {
        sectionDataManager.setSelectedTabIndex(index)
    }
    
    func tabBarViewRequiresLayoutUpdate() {
        collectionView.collectionViewLayout.invalidateLayout()
    }
}

// MARK: - Utility Extension
extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
