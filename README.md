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

    private func createCarouselSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(180))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: itemSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: cellSpacing, leading: 16, bottom: cellSpacing, trailing: 16)
        
        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(44))
        let sectionHeader = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
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
            
            let sizingGridCell = TitleSubtitleCell()
            sizingGridCell.setSpacerActive(false)
            
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
            cell.backgroundColor = .systemGray6
            cell.layer.cornerRadius = 12
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
    
    private let logoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .systemGray4
        imageView.layer.cornerRadius = 8
        imageView.image = UIImage(systemName: "photo.fill")
        return imageView
    }()

    let tagLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .callout)
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

    private let spacerView = UIView()

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
    
    func setSpacerActive(_ isActive: Bool) {
        spacerView.isHidden = !isActive
    }
    
    private func setupUI() {
        [logoImageView, tagLabel, titleLabel, subtitleLabel, descriptionLabel, spacerView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        titleLabel.backgroundColor = .systemBlue
        subtitleLabel.backgroundColor = .systemGreen
        descriptionLabel.backgroundColor = .systemOrange
        spacerView.backgroundColor = .clear

        let textContentStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, descriptionLabel, spacerView])
        textContentStack.axis = .vertical
        textContentStack.alignment = .fill
        textContentStack.distribution = .fill
        textContentStack.spacing = 4
        
        [titleLabel, subtitleLabel, descriptionLabel].forEach { label in
            label.setContentHuggingPriority(.required, for: .vertical)
            label.setContentCompressionResistancePriority(.required, for: .vertical)
        }

        contentView.addSubview(logoImageView)
        contentView.addSubview(tagLabel)
        contentView.addSubview(textContentStack)
        
        NSLayoutConstraint.activate([
            logoImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16.0),
            logoImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16.0),
            logoImageView.widthAnchor.constraint(equalToConstant: 56.0),
            logoImageView.heightAnchor.constraint(equalToConstant: 56.0),
            
            tagLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 4.0),
            tagLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16.0),
            tagLabel.leadingAnchor.constraint(greaterThanOrEqualTo: logoImageView.trailingAnchor, constant: 8.0),

            textContentStack.topAnchor.constraint(equalTo: tagLabel.bottomAnchor, constant: 12.0),
            textContentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16.0),
            textContentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16.0),
            textContentStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16.0)
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








