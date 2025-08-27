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

    // Propiedades para cachear la altura
    private var cachedGridCellHeight: CGFloat?
    private var shouldRecalculateGridHeight = true
    
    // La celda de medición persistente ha sido eliminada. Se creará on-demand.
    
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
        // Reemplazar el layout por uno nuevo es la forma más robusta de asegurar una actualización completa.
        collectionView.setCollectionViewLayout(createLayout(), animated: true)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.horizontalSizeClass != traitCollection.horizontalSizeClass ||
           previousTraitCollection?.verticalSizeClass != traitCollection.verticalSizeClass {
            shouldRecalculateGridHeight = true
            collectionView.setCollectionViewLayout(createLayout(), animated: true)
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
    
    private func configureCellContent(_ cell: TitleSubtitleCell, at indexPath: IndexPath) {
        let logoImage = UIImage(systemName: "photo.fill")
        
        if indexPath.item == 5 {
            cell.configure(logo: logoImage, tag: "Exclusive", title: "Cell \(indexPath.item)", subtitle: "This is a subtitle", description: "And finally")
        } else if indexPath.item == 2 {
            cell.configure(logo: logoImage, tag: nil, title: "Cell \(indexPath.item) (No Tag)", subtitle: "Subtitle for cell \(indexPath.item).", description: "This cell demonstrates how the layout adapts when the tag view is hidden from view.")
        } else {
            cell.configure(logo: logoImage, tag: "New", title: "Cell \(indexPath.item)", subtitle: "Subtitle \(indexPath.item)", description: "A standard description for a standard cell.")
        }
    }
}

// MARK: - Layout Creation & Data Source
extension ViewController: UICollectionViewDataSource {
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, layoutEnvironment -> NSCollectionLayoutSection? in
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
        }
        return layout
    }

    private func createListSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(100))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = cellSpacing
        section.contentInsets = NSDirectionalEdgeInsets(top: cellSpacing, leading: 16, bottom: cellSpacing, trailing: 16)
        return section
    }

    // EN: ViewController.swift

    // EN: ViewController.swift

    private func createCarouselSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(180)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        // --- CAMBIO CLAVE 1: Aplicamos los márgenes horizontales al grupo ---
        // En lugar de aplicar los insets a la sección, los aplicamos aquí.
        // Así, solo el contenido del grupo (la celda) tendrá estos márgenes.
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: itemSize, subitems: [item])
        group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        
        let section = NSCollectionLayoutSection(group: group)
        
        // --- CAMBIO CLAVE 2: Ajustamos los márgenes de la sección ---
        // La sección ahora solo necesita espaciado vertical. Sus bordes izquierdo y
        // derecho coincidirán con los del UICollectionView.
        section.contentInsets = NSDirectionalEdgeInsets(top: cellSpacing, leading: 0, bottom: cellSpacing, trailing: 0)

        // --- El Header no cambia, pero ahora se comportará como queremos ---
        // Como la sección ya no tiene márgenes horizontales, el header
        // (que es un hijo de la sección) se extenderá de borde a borde.
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
        let columnCount = (traitCollection.horizontalSizeClass == .compact && traitCollection.verticalSizeClass == .regular) ? 2 : 3
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
            var maxHeight: CGFloat = 0
            
            // Creamos una nueva celda de medición cada vez que se recalcula.
            // Esto asegura que no hay estado residual y que las fuentes están actualizadas.
            let sizingGridCell = TitleSubtitleCell()
            sizingGridCell.setSpacerActive(false) // Desactivar spacer para la medición.
            
            if let gridSectionIndex = sections.firstIndex(of: .grid) {
                for itemIndex in 0..<sections[gridSectionIndex].itemCount {
                    let indexPath = IndexPath(item: itemIndex, section: gridSectionIndex)
                    configureCellContent(sizingGridCell, at: indexPath)
                    
                    let requiredSize = sizingGridCell.systemLayoutSizeFitting(
                        CGSize(width: cellWidth, height: 0),
                        withHorizontalFittingPriority: .required,
                        verticalFittingPriority: .fittingSizeLevel
                    )
                    
                    if requiredSize.height > maxHeight {
                        maxHeight = requiredSize.height
                    }
                }
            }
            
            // La instancia 'sizingGridCell' será descartada al final de este bloque 'if'.
            // No es necesario restaurar su estado.
            
            cachedGridCellHeight = (maxHeight > 0) ? maxHeight : 184.0
            shouldRecalculateGridHeight = false
        }

        let finalHeight = cachedGridCellHeight ?? 184.0

        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(finalHeight))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: columnCount)
        group.interItemSpacing = .fixed(cellSpacing)
        
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = cellSpacing
        section.contentInsets = NSDirectionalEdgeInsets(top: cellSpacing, leading: sectionInset, bottom: cellSpacing, trailing: sectionInset)
        
        return section
    }
    
    private func createFooterSection() -> NSCollectionLayoutSection {
        return createListSection()
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return sections.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return sections[section].itemCount
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let sectionType = sections[indexPath.section]

        switch sectionType {
        case .generalInfo, .footer:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TitleCell.reuseIdentifier, for: indexPath) as! TitleCell
            cell.configure(title: "Simple Cell for \(sectionType) section (\(indexPath.item))")
            cell.backgroundColor = .systemGray5; cell.layer.cornerRadius = 12
            return cell
        case .carousel:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CarouselCell.reuseIdentifier, for: indexPath) as! CarouselCell
            cell.configure(title: "Carousel Cell")
            cell.backgroundColor = .systemBlue; cell.layer.cornerRadius = 12
            return cell
        case .grid:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TitleSubtitleCell.reuseIdentifier, for: indexPath) as! TitleSubtitleCell
            configureCellContent(cell, at: indexPath)
            cell.backgroundColor = .systemGray6; cell.layer.cornerRadius = 12
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionHeader, sections[indexPath.section] == .carousel else { return UICollectionReusableView() }
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: TitleHeaderView.reuseIdentifier, for: indexPath) as! TitleHeaderView
        header.configure(title: "Header for Carousel")
        return header
    }
}











import UIKit

final class TitleSubtitleCell: UICollectionViewCell {
    static let reuseIdentifier = "TitleSubtitleCell"

    // MARK: - Vistas (Views)
    
    private let logoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .systemGray4 // Placeholder
        imageView.layer.cornerRadius = 8
        imageView.image = UIImage(systemName: "photo.fill") // Imagen por defecto
        return imageView
    }()

    let tagLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .white
        label.backgroundColor = .systemRed
        label.textAlignment = .center
        label.layer.cornerRadius = 8
        label.layer.masksToBounds = true
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .headline)
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        return label
    }()
    
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        return label
    }()

    // <-- CAMBIO CLAVE 1: Añadir una vista espaciadora
    // Esta vista no tiene contenido y su única función es estirarse para absorber
    // cualquier espacio vertical sobrante que el CollectionView imponga a la celda.
    private let spacerView = UIView()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - API de Configuración

    func configure(logo: UIImage?, tag: String?, title: String, subtitle: String, description: String) {
        logoImageView.image = logo ?? UIImage(systemName: "photo.fill")
        titleLabel.text = title
        subtitleLabel.text = subtitle
        descriptionLabel.text = description
        
        // Lógica para mostrar u ocultar el tagLabel
        if let tagText = tag, !tagText.isEmpty {
            tagLabel.text = " \(tagText) " // Añadimos padding interno
            tagLabel.isHidden = false
        } else {
            tagLabel.text = nil
            tagLabel.isHidden = true
        }
        
        // Ocultar etiquetas si no tienen contenido para un layout más robusto
        subtitleLabel.isHidden = subtitle.isEmpty
        descriptionLabel.isHidden = description.isEmpty
    }

    // MARK: - Configuración del Layout (UI Setup)

    func setSpacerActive(_ isActive: Bool) {
        spacerView.isHidden = !isActive
    }

    
    private func setupUI() {
        
        // Desactivamos `translatesAutoresizingMaskIntoConstraints` para todas las vistas
        [logoImageView, tagLabel, titleLabel, subtitleLabel, descriptionLabel, spacerView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        // Colores de fondo para depuración. Puedes comentarlos o eliminarlos.
        titleLabel.backgroundColor = .systemBlue
        subtitleLabel.backgroundColor = .systemGreen
        descriptionLabel.backgroundColor = .systemOrange
        spacerView.backgroundColor = .clear // El espaciador debe ser invisible

        // 1. Crear el Stack View para el contenido de texto principal
        // <-- CAMBIO CLAVE 2: Añadir `spacerView` al final del Stack View
        let textContentStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, descriptionLabel, spacerView])
        textContentStack.axis = .vertical
        textContentStack.alignment = .fill
        textContentStack.distribution = .fill // Ahora `fill` es correcto
        textContentStack.spacing = 4
        textContentStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Esta configuración es CORRECTA y muy importante. Evita que las etiquetas
        // se estiren entre sí. Ahora, el `spacerView` será el único que se estire
        // porque tiene una prioridad de "abrazo" (hugging) mucho más baja por defecto (250).
        [titleLabel, subtitleLabel, descriptionLabel].forEach { label in
            label.setContentHuggingPriority(.required, for: .vertical)
            label.setContentCompressionResistancePriority(.required, for: .vertical)
        }

        // 2. Añadir todas las vistas a la jerarquía
        contentView.addSubview(logoImageView)
        contentView.addSubview(tagLabel)
        contentView.addSubview(textContentStack)
        
        // 3. Activar las Restricciones (Constraints)
        // Estas restricciones no cambian, siguen siendo correctas.
        NSLayoutConstraint.activate([
            // --- Logo ---
            logoImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 48.0),
            logoImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8.0),
            logoImageView.widthAnchor.constraint(equalToConstant: 56.0),
            logoImageView.heightAnchor.constraint(equalToConstant: 56.0),
            
            // --- Tag ---
            tagLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 84.0),
            tagLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8.0),
            tagLabel.leadingAnchor.constraint(greaterThanOrEqualTo: logoImageView.trailingAnchor),

            // --- Bloque de Texto (Stack View) ---
            textContentStack.topAnchor.constraint(equalTo: tagLabel.bottomAnchor, constant: 6.0),
            textContentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8.0),
            textContentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8.0),
            
            // La restricción final que completa la cadena vertical y hace que la celda sea auto-dimensionable
            textContentStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8.0)
        ])
        
        setSpacerActive(true)
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




// EN: TitleHeaderView.swift

import UIKit

class TitleHeaderView: UICollectionReusableView {
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
        
        if traitCollection.horizontalSizeClass != previousTraitCollection?.horizontalSizeClass ||
           traitCollection.verticalSizeClass != previousTraitCollection?.verticalSizeClass {
            updatePaddingForCurrentTraits()
        }
    }
    
    private func updatePaddingForCurrentTraits() {
        let horizontalPadding = padding(for: traitCollection)
        titleLabelLeadingConstraint.constant = horizontalPadding
        titleLabelTrailingConstraint.constant = -horizontalPadding // Recuerda el signo negativo para el trailing
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
    
    /// Devuelve el padding horizontal basado en el trait collection actual.
    private func padding(for traits: UITraitCollection) -> CGFloat {
        // Caso para iPhone
        if traits.userInterfaceIdiom == .phone {
            // Si es iPhone y está en orientación landscape (.compact verticalSizeClass), el padding es 0.
            return traits.verticalSizeClass == .compact ? 0.0 : 16.0
        }
        
        // Caso para iPad y otros (Mac, etc.)
        // Para iPad, siempre será 16.0, tanto en portrait como en landscape.
        return 16.0
    }

    func configure(title: String) {
        titleLabel.text = title
        accessibilityLabel = title
        isAccessibilityElement = true
    }
}
