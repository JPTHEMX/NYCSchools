import UIKit

// MARK: - Models with Separated Protocols
// =================================================================================

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
}

// MARK: - Base Protocol (No ID required)
protocol SectionItem: Hashable, Sendable {
    // No requiere ID - cada tipo decide cómo identificarse
}

// MARK: - Protocol for items needing tracking
protocol IdentifiableItem: SectionItem {
    var id: UUID { get }
}

// MARK: - Simple Models (identified by content)
struct InfoModel: SectionItem {
    let title: String
    let subtitle: String?
    
    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }
}

struct FooterModel: SectionItem {
    let title: String
    let subtitle: String?
    
    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }
}

// MARK: - Complex Model (with ID for tracking)
struct ContentModel: IdentifiableItem {
    let id = UUID()
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

// MARK: - Section Model
enum SectionType: Hashable, Sendable {
    case info
    case carousel
    case grid
    case list
    case footer
}

struct Section: Hashable, Sendable {
    let id = UUID()
    let type: SectionType
    var header: SectionHeader?
    var items: [any SectionItem]  // Now uses SectionItem base protocol
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Section, rhs: Section) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - ItemIdentifier (keeping original structure)
struct ItemIdentifier: Hashable, Sendable {
    let id: UUID
    let sectionId: UUID
    let type: ItemType
    
    enum ItemType: Hashable, Sendable {
        case single(UUID)  // For regular items
        case carousel     // For carousel container
    }
}

// MARK: - Refactored Data Manager
@MainActor
class SectionDataManager {
    
    // MARK: - Properties
    
    // <<< CAMBIO: El contentStore es ahora la ÚNICA fuente de verdad para los ContentModel.
    private var contentStore: [UUID: ContentModel] = [:]
    
    private var sectionsByTab: [TabItem: [Section]] = [:]
    private var shoppingPlaceholderId: UUID?
    
    var isValueEnabled: Bool
    var isVideoEnabled: Bool
    var isShoppingEnabled: Bool
    var experience: ExperienceType
    
    var tabData: [TabItem] = (0..<8).map { TabItem(title: "Categoría \($0 + 1)") }
    private(set) var selectedTabIndex: Int = 0
    private(set) var currentShoppingCellIndex: Int?
    
    var onSectionsDidUpdate: (() -> Void)?
    
    private var currentTab: TabItem? {
        return tabData[safe: selectedTabIndex]
    }
    
    var sections: [Section] {
        sectionsByTab[currentTab ?? TabItem(title: "")] ?? []
    }
    
    // MARK: - Initialization
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
    
    // MARK: - Public Methods
    
    // <<< CAMBIO: Nuevo método para obtener la versión más actualizada de un ContentModel.
    func getContentModel(by id: UUID) -> ContentModel? {
        return contentStore[id]
    }
    
    func getSection(at index: Int) -> Section? {
        guard let tab = currentTab,
              let sections = sectionsByTab[tab],
              sections.indices.contains(index) else {
            return nil
        }
        return sections[index]
    }
    
    func updateSection(_ section: Section, at index: Int) {
        guard let tab = currentTab,
              var sections = sectionsByTab[tab],
              sections.indices.contains(index) else {
            return
        }
        sections[index] = section
        sectionsByTab[tab] = sections
    }
    
    // <<< CAMBIO: getItem ahora devuelve la versión actualizada del contentStore si el item es identificable.
    func getItem(at indexPath: IndexPath) -> (any SectionItem)? {
        guard let section = getSection(at: indexPath.section) else { return nil }

        let baseItem: (any SectionItem)?
        switch section.type {
        case .carousel:
            baseItem = section.items[safe: indexPath.item]
        default:
            baseItem = section.items[safe: indexPath.item]
        }
        
        guard let item = baseItem else { return nil }

        // Si el item tiene un ID, devolvemos la versión fresca del store.
        if let identifiableItem = item as? any IdentifiableItem,
           let freshModel = contentStore[identifiableItem.id] {
            return freshModel
        }
        
        // Para items simples como InfoModel, devolvemos el original.
        return item
    }
    
    func updateCarouselItems(_ items: [ContentModel], at sectionIndex: Int) {
        guard var section = getSection(at: sectionIndex),
              section.type == .carousel else { return }
        
        section.items = items
        updateSection(section, at: sectionIndex)
        
        for model in items {
            updateContentModel(model)
        }
    }
    
    func updateItem(_ item: any SectionItem, at indexPath: IndexPath) {
        guard var section = getSection(at: indexPath.section) else { return }
        
        switch section.type {
        case .carousel:
            if let contentModel = item as? ContentModel,
               indexPath.item < section.items.count {
                section.items[indexPath.item] = contentModel
            }
            
        case .grid, .info, .list, .footer:
            if indexPath.item < section.items.count {
                section.items[indexPath.item] = item
            }
        }
        
        updateSection(section, at: indexPath.section)
        
        // Only update ContentModel globally (those with ID)
        if let contentModel = item as? ContentModel {
            updateContentModel(contentModel)
        }
    }
    
    // <<< CAMBIO: getHeader también devuelve la versión actualizada desde el store.
    func getHeader(for sectionIndex: Int) -> SectionHeader? {
        guard let section = getSection(at: sectionIndex), let header = section.header else { return nil }
        
        switch header {
        case .tabBar(let tabs, _):
            return .tabBar(tabs: tabs, selectedIndex: selectedTabIndex)
            
        case .list(let headerModel):
            // Si el header es de tipo .list, contiene un ContentModel. Hay que devolver el actualizado.
            if let freshModel = contentStore[headerModel.id] {
                return .list(freshModel)
            }
            return header
            
        case .title:
            return header
        }
    }
    
    func updateHeader(_ header: SectionHeader?, for sectionIndex: Int) {
        guard var section = getSection(at: sectionIndex) else { return }
        section.header = header
        updateSection(section, at: sectionIndex)
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
            if let contentModelId = (section.items.first as? ContentModel)?.id,
               let freshModel = contentStore[contentModelId] {
                return freshModel.isDetailsVisible ? 1 : 0
            }
            return 0
        default:
            return section.items.count
        }
    }
    
    func setSelectedTabIndex(_ index: Int, columnCount: Int) {
        guard index != selectedTabIndex, tabData.indices.contains(index) else { return }
        selectedTabIndex = index
        updateShoppingState(columnCount: columnCount, shouldNotify: true)
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
    
    // <<< CAMBIO RADICAL: Este método ahora es increíblemente rápido (O(1)).
    func updateContentModel(_ updatedModel: ContentModel) {
        // Simplemente actualiza el modelo en el diccionario. ¡Y ya está!
        // No más bucles anidados.
        guard !updatedModel.isShoppingPlaceholder else { return }
        contentStore[updatedModel.id] = updatedModel
    }
    
    func resetData() {
        shoppingPlaceholderId = nil
        // <<< CAMBIO: Limpiar el store al reiniciar.
        contentStore.removeAll()
        setupInitialData()
        selectedTabIndex = 0
    }
    
    func reloadTab(at index: Int) {
        guard tabData.indices.contains(index),
              let tab = tabData[safe: index] else { return }
        
        sectionsByTab[tab] = createSections(for: tab)
    }
    
    public func updateShoppingCellIndex(columnCount: Int) {
        currentShoppingCellIndex = nil
        
        guard let currentTab,
              let sections = sectionsByTab[currentTab],
              let gridSection = sections.first(where: { $0.type == .grid }) else {
            return
        }
        
        let realItemCount = gridSection.items.compactMap { $0 as? ContentModel }
            .filter { !$0.isShoppingPlaceholder }.count
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
        
        if finalIndex < realItemCount {
            currentShoppingCellIndex = finalIndex
        } else {
            currentShoppingCellIndex = nil
        }
    }
    
    // MARK: - Private Methods
    
    private func updateShoppingState(columnCount: Int, shouldNotify: Bool) {
        updateShoppingCellIndex(columnCount: columnCount)
        updateShoppingPlaceholderPosition(shouldNotify: shouldNotify)
    }
    
    private func updateShoppingPlaceholderPosition(shouldNotify: Bool) {
        guard let tab = currentTab,
              var sections = sectionsByTab[tab] else { return }
        
        guard let gridSectionIndex = sections.firstIndex(where: { $0.type == .grid }),
              var gridSection = sections[safe: gridSectionIndex] else { return }
        
        if let placeholderId = shoppingPlaceholderId {
            gridSection.items.removeAll {
                ($0 as? ContentModel)?.id == placeholderId
            }
            shoppingPlaceholderId = nil
        }
        
        if isShoppingEnabled,
           let shoppingIndex = currentShoppingCellIndex,
           shoppingIndex <= gridSection.items.count {
            let placeholder = ContentModel.emptyShoppingPlaceholder()
            shoppingPlaceholderId = placeholder.id
            gridSection.items.insert(placeholder, at: shoppingIndex)
        }
        
        sections[gridSectionIndex] = gridSection
        sectionsByTab[tab] = sections
        
        if shouldNotify {
            onSectionsDidUpdate?()
        }
    }
    
    private func setupInitialData() {
        // <<< CAMBIO: Limpiar el store al principio.
        contentStore.removeAll()
        for tab in tabData {
            sectionsByTab[tab] = createSections(for: tab)
        }
    }
    
    // <<< CAMBIO: Helper para registrar modelos en el store
    private func storeModels(_ models: [ContentModel]) {
        for model in models {
            contentStore[model.id] = model
        }
    }
    
    private func createSections(for tab: TabItem) -> [Section] {
        let prefix = tab.title.replacingOccurrences(of: "Categoría", with: "Contenido")
        
        let sharedModels = (0..<3).map { i in
            ContentModel.carouselItem(index: i, prefix: "\(prefix) (Compartido)", isHighlighted: true)
        }
        // <<< CAMBIO: Registrar en el store
        storeModels(sharedModels)
        
        var sections: [Section] = [
            createGeneralInfoSection(prefix: prefix),
            createCarouselSection(prefix: prefix, sharedItems: sharedModels)
        ]
        
        switch experience {
        case .list:
            let firstListItem = ContentModel.gridItem(index: 0, prefix: prefix, isValue: isValueEnabled)
            // <<< CAMBIO: Registrar en el store
            storeModels([firstListItem])
            sections.append(createListSection(item: firstListItem))
            
            for sharedModel in sharedModels {
                sections.append(createListSection(item: sharedModel))
            }
            
            let listItems = (1..<300).map { i -> ContentModel in
                ContentModel.gridItem(index: i, prefix: prefix, isValue: false)
            }
            // <<< CAMBIO: Registrar en el store
            storeModels(listItems)
            listItems.forEach { sections.append(createListSection(item: $0)) }
            
        case .grid, .carousel:
            let itemCount = 300 + (Int(tab.title.last?.wholeNumberValue ?? 1) * 3)
            sections.append(createGridSection(prefix: prefix, itemCount: itemCount, sharedItems: sharedModels))
        }
        
        sections.append(createFooterSection(prefix: prefix))
        return sections
    }
    
    private func createGeneralInfoSection(prefix: String) -> Section {
        let items: [any SectionItem] = [
            InfoModel(title: "\(prefix) Info Item 1", subtitle: "General info subtitle"),
            InfoModel(title: "\(prefix) Info Item 2", subtitle: "Another subtitle")
        ]
        return Section(type: .info, header: nil, items: items)
    }
    
    private func createCarouselSection(prefix: String, sharedItems: [ContentModel]) -> Section {
        var items: [any SectionItem] = sharedItems
        
        let regularItems = (0..<12).map { i in
            ContentModel.carouselItem(index: i, prefix: prefix, isHighlighted: i % 4 == 0)
        }
        // <<< CAMBIO: Registrar en el store
        storeModels(regularItems)
        
        items.append(contentsOf: regularItems)
        
        let header = SectionHeader.tabBar(tabs: self.tabData, selectedIndex: self.selectedTabIndex)
        return Section(type: .carousel, header: header, items: items)
    }
    
    private func createGridSection(prefix: String, itemCount: Int, sharedItems: [ContentModel]) -> Section {
        var items: [any SectionItem] = []
        
        let firstItem = ContentModel.gridItem(index: 0, prefix: prefix, isValue: isValueEnabled)
        // <<< CAMBIO: Registrar en el store
        storeModels([firstItem])
        items.append(firstItem)
        
        items.append(contentsOf: sharedItems)
        
        let remainingItems = (1..<itemCount).map { i in
            ContentModel.gridItem(index: i, prefix: prefix, isValue: false)
        }
        // <<< CAMBIO: Registrar en el store
        storeModels(remainingItems)
        items.append(contentsOf: remainingItems)
        
        let header = SectionHeader.title("Explorar Contenido")
        return Section(type: .grid, header: header, items: items)
    }
    
    private func createListSection(item: ContentModel) -> Section {
        let header = SectionHeader.list(item)
        return Section(type: .list, header: header, items: [item])
    }
    
    private func createFooterSection(prefix: String) -> Section {
        let items: [any SectionItem] = [
            FooterModel(title: "\(prefix) Footer", subtitle: "Additional footer details")
        ]
        return Section(type: .footer, header: .title("Test"), items: items)
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

// MARK: - ContentModel Factory Extensions
// ... (Sin cambios aquí)
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

// MARK: - Reusable Views & Headers
// =================================================================================
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
    
    // MARK: - Callbacks
    var onHeaderSelect: ((ContentModel) -> Void)?
    var onDetailsButtonTapped: (() -> Void)?
    
    // MARK: - Private Properties
    private var tapGestureRecognizer: UITapGestureRecognizer!
    private var currentModel: ContentModel?
    
    // Dynamic Constraints for sizing
    private var bottomConstraintWithButton: NSLayoutConstraint!
    private var bottomConstraintWithoutButton: NSLayoutConstraint!

    // MARK: - UI Components
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
    
    private lazy var detailsButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(detailsButtonAction), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Constants
    private enum Constants {
        static let logoTopPadding: CGFloat = 12
        static let logoSize: CGFloat = 56
        static let horizontalPadding: CGFloat = 16
        static let tagTopPadding: CGFloat = 12
        static let stackTopPadding: CGFloat = 8
        static let stackSpacing: CGFloat = 4
        static let bottomPadding: CGFloat = 12
    }
    
    // MARK: - Initializers
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupDefaultStyle()
        setupTapGesture()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Configuration
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
            detailsButton.isHidden = true
            tagLabel.isHidden = true
        } else {
            spinner.stopAnimating()
            detailsButton.isHidden = !model.isSelected
            updateTagVisibility(for: model.tag)
        }
        
        if model.isSelected && !model.isLoading {
            let title = model.isDetailsVisible ? "Hide Details" : "Show Details"
            detailsButton.setTitle(title, for: .normal)
        }
        
        // Activate the correct constraint based on button visibility
        if detailsButton.isHidden {
            bottomConstraintWithButton.isActive = false
            bottomConstraintWithoutButton.isActive = true
        } else {
            bottomConstraintWithoutButton.isActive = false
            bottomConstraintWithButton.isActive = true
        }
    }
    
    // MARK: - Private Methods
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
        guard let model = currentModel else { return }
        onHeaderSelect?(model)
    }
    
    @objc private func detailsButtonAction() {
        onDetailsButtonTapped?()
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
        addSubview(spinner)
        addSubview(detailsButton)
        
        // Define the two bottom constraints for dynamic height
        bottomConstraintWithButton = detailsButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Constants.bottomPadding)
        bottomConstraintWithoutButton = textContentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Constants.bottomPadding)
        
        // Set an initial state (configure will update it)
        bottomConstraintWithoutButton.isActive = true
        
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
            
            detailsButton.topAnchor.constraint(equalTo: textContentStack.bottomAnchor, constant: 12),
            detailsButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Constants.horizontalPadding),
            detailsButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Constants.horizontalPadding),
            detailsButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
}

// MARK: - Protocols & Base Implementations
// =================================================================================
@MainActor
protocol CellRegistrationProtocol: AnyObject {
    static var reuseIdentifier: String { get }
}

extension UICollectionReusableView: CellRegistrationProtocol {
    static var reuseIdentifier: String {
        String(describing: self)
    }
}


// MARK: - Collection View Cells
// =================================================================================
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

import UIKit

// MARK: - TabBarView Corregido
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
        
        scrollToMakeTabVisible(at: indexPath, animated: true)
        
        updateIndicatorPosition(animated: true)
    }
}

// MARK: - TabCell mejorado
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

// MARK: - TabBarHeaderView actualizado
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

// MARK: - Custom Layout
// =================================================================================
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
    private let infoLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Detalles de la celda expandida"
        label.textAlignment = .center
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .label
        label.numberOfLines = 0
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .systemGray5
        contentView.layer.cornerRadius = 12
        contentView.addSubview(infoLabel)
        
        let verticalPadding: CGFloat = 20.0
        let horizontalPadding: CGFloat = 16.0
        
        NSLayoutConstraint.activate([
            infoLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: verticalPadding),
            infoLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -verticalPadding),
            infoLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: horizontalPadding),
            infoLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -horizontalPadding)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(with model: ContentModel) {
        // Can use the model to configure the label text in the future
    }
}

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
    
    // MARK: - Data Source Configuration
    private func configureDataSource() {
        dataSource = DataSource(collectionView: collectionView) { [weak self] (collectionView, indexPath, itemIdentifier) -> UICollectionViewCell? in
            guard let self = self else { return nil }
            
            // NOTE: No changes here, but getItem now returns the fresh model automatically
            guard let item = self.sectionDataManager.getItem(at: indexPath) else { return nil }
            
            guard let section = self.sectionDataManager.getSection(at: indexPath.section) else { return nil }
            
            switch section.type {
            case .info:
                guard let model = item as? InfoModel else { return nil }
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: InfoCell.reuseIdentifier, for: indexPath) as! InfoCell
                cell.configure(with: model)
                return cell
                
            case .carousel:
                let items = section.items.compactMap { item -> ContentModel? in
                    guard let identifiable = item as? any IdentifiableItem else { return nil }
                    // Fetch the fresh model from the store for the carousel items
                    return self.sectionDataManager.getContentModel(by: identifiable.id)
                }
                
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CarouselCell.reuseIdentifier, for: indexPath) as! CarouselCell
                cell.configure(with: items)
                
                cell.onItemSelect = { [weak self] selectedModel in
                    guard let self = self else { return }
                    var updatedModel = selectedModel
                    updatedModel.isSelected.toggle()
                    
                    // This call is now O(1) and super fast
                    self.sectionDataManager.updateContentModel(updatedModel)
                    
                    // We still reload the sections to refresh UI, but it's fast now
                    self.reloadSectionsContainingModel(updatedModel)
                }
                return cell
                
            case .grid:
                guard let model = item as? ContentModel else { return nil }
                
                if self.sectionDataManager.shouldUseShoppingCell(at: indexPath) {
                    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ShoppingCell.reuseIdentifier, for: indexPath) as! ShoppingCell
                    cell.configure(with: model)
                    return cell
                } else if self.sectionDataManager.shouldUseValueCell(at: indexPath) {
                    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ValueCell.reuseIdentifier, for: indexPath) as! ValueCell
                    cell.configure(with: model)
                    return cell
                } else {
                    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TitleSubtitleCell.reuseIdentifier, for: indexPath) as! TitleSubtitleCell
                    cell.configure(with: model)
                    return cell
                }
                
            case .list:
                guard let model = item as? ContentModel else { return nil }
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ListDetailCell.reuseIdentifier, for: indexPath) as! ListDetailCell
                cell.configure(with: model)
                return cell
                
            case .footer:
                guard let model = item as? FooterModel else { return nil }
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FooterCell.reuseIdentifier, for: indexPath) as! FooterCell
                cell.configure(with: model)
                return cell
            }
        }
        
        dataSource.supplementaryViewProvider = { [weak self] (collectionView, kind, indexPath) -> UICollectionReusableView? in
            guard let self = self, kind == UICollectionView.elementKindSectionHeader else {
                return collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "blankHeader", for: indexPath)
            }
            
            // NOTE: No changes here, but getHeader now returns the fresh model automatically
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
                    
                    // This call is now O(1) and super fast
                    self.sectionDataManager.updateContentModel(loadingModel)
                    self.reloadSectionsContainingModel(loadingModel)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        var finishedModel = loadingModel
                        finishedModel.isLoading = false
                        
                        self.sectionDataManager.updateContentModel(finishedModel)
                        self.reloadSectionsContainingModel(finishedModel)
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
        case .info, .footer, .grid, .list:
            return section.items.map { item in
                let itemId = (item as? (any IdentifiableItem))?.id ?? UUID()
                return ItemIdentifier(
                    id: UUID(), // ID for the identifier itself
                    sectionId: section.id,
                    type: .single(itemId) // ID for the model
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
    
    private func reloadSectionsContainingModel(_ model: ContentModel) {
        var snapshot = dataSource.snapshot()
        var sectionsToReload: [Section] = []
        
        // This is now the only iteration, and it's over a much smaller dataset (just the visible sections)
        for section in snapshot.sectionIdentifiers {
            var containsModel = false
            
            // Check header
            if let header = section.header, case .list(let headerModel) = header, headerModel.id == model.id {
                containsModel = true
            }
            
            // Check items
            if !containsModel {
                containsModel = section.items.contains { ($0 as? ContentModel)?.id == model.id }
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
        
        if let oldIndex = previouslyExpanded, !isCollapsing {
            if let oldSection = sectionDataManager.getSection(at: oldIndex),
               var oldModel = sectionDataManager.getItem(at: IndexPath(item: 0, section: oldIndex)) as? ContentModel {
                oldModel.isDetailsVisible = false
                sectionDataManager.updateContentModel(oldModel)
            }
        }
        
        if var currentModel = sectionDataManager.getItem(at: IndexPath(item: 0, section: sectionIndex)) as? ContentModel {
            currentModel.isDetailsVisible.toggle()
            sectionDataManager.updateContentModel(currentModel)
        }
        
        expandedListSection = isCollapsing ? nil : sectionIndex
        applySnapshot()
    }
    
    // MARK: - Layout Creation
    // ... (No changes in layout creation methods)
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
        
        // NOTE: getItem(at:) now returns the fresh model from the central store
        guard let item = sectionDataManager.getItem(at: indexPath) as? ContentModel,
              !item.isShoppingPlaceholder else {
            return
        }
        
        var updatedModel = item
        updatedModel.isSelected.toggle()
        
        // This call is now O(1) and super fast
        sectionDataManager.updateContentModel(updatedModel)
        
        // This call is now much faster because the underlying data lookups are gone
        reloadSectionsContainingModel(updatedModel)
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
        
        if collectionView.numberOfSections > 0 && collectionView.numberOfItems(inSection: 0) > 0 {
            let topOffset = CGPoint(x: 0, y: -collectionView.adjustedContentInset.top)
            collectionView.setContentOffset(topOffset, animated: false)
        }
    }
    
    func tabBarViewRequiresLayoutUpdate() {
        collectionView.collectionViewLayout.invalidateLayout()
    }
}


// MARK: - Utility Extensions
// =================================================================================
extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
