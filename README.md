
import UIKit

// MARK: - Data Model
struct SectionHeaderData: Hashable {
    let id: Int
    var title: String
    var subtitle: String
    var imageName: String
    var isSelectedAndSticky: Bool = false
    var isDetailCellExpanded: Bool = false
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: SectionHeaderData, rhs: SectionHeaderData) -> Bool {
        lhs.id == rhs.id
    }
}

struct Item: Hashable {
    let sectionId: Int
}


// MARK: - Custom Sticky Header Flow Layout
@MainActor
class PushingStickyHeaderFlowLayout: UICollectionViewFlowLayout {

    var stickyHeaderSections: Set<Int> = []
    let stickyHeaderZIndex: Int = 1000
    let standardHeaderZIndex: Int = 100
    private var cachedOriginalHeaderAttributes: [IndexPath: UICollectionViewLayoutAttributes] = [:]

    override func prepare() {
        super.prepare()
    }

    override func invalidateLayout(with context: UICollectionViewLayoutInvalidationContext) {
        super.invalidateLayout(with: context)
        if context.invalidateEverything || context.invalidateDataSourceCounts {
            cachedOriginalHeaderAttributes.removeAll()
        }
    }

    private func originalAttributesForHeader(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        if let cached = cachedOriginalHeaderAttributes[indexPath] {
            return cached.copy() as? UICollectionViewLayoutAttributes
        }
        if let originalAttrs = super.layoutAttributesForSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, at: indexPath)?.copy() as? UICollectionViewLayoutAttributes {
            cachedOriginalHeaderAttributes[indexPath] = originalAttrs
            return originalAttrs.copy() as? UICollectionViewLayoutAttributes
        }
        return nil
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard let superLayoutAttributes = super.layoutAttributesForElements(in: rect),
              let collectionView = self.collectionView else { return nil }

        var allLayoutAttributes = superLayoutAttributes.compactMap { $0.copy() as? UICollectionViewLayoutAttributes }
        
        var stickyHeaderCandidateAttributes: [UICollectionViewLayoutAttributes] = []
        var nonStickyHeaderAttributes: [UICollectionViewLayoutAttributes] = []
        var cellAndOtherAttributes: [UICollectionViewLayoutAttributes] = []

        let sortedStickySectionIndexes = stickyHeaderSections.sorted()
        for sectionIndex in sortedStickySectionIndexes {
            let indexPath = IndexPath(item: 0, section: sectionIndex)
            if !allLayoutAttributes.contains(where: { $0.indexPath == indexPath && $0.representedElementKind == UICollectionView.elementKindSectionHeader }) {
                if let missingStickyAttrs = originalAttributesForHeader(at: indexPath) {
                     allLayoutAttributes.append(missingStickyAttrs)
                }
            }
        }

        var processedHeaderIndexPaths = Set<IndexPath>()
        for attributes in allLayoutAttributes {
            if attributes.representedElementKind == UICollectionView.elementKindSectionHeader {
                if processedHeaderIndexPaths.contains(attributes.indexPath) {
                    continue
                }
                processedHeaderIndexPaths.insert(attributes.indexPath)

                if stickyHeaderSections.contains(attributes.indexPath.section) {
                    stickyHeaderCandidateAttributes.append(attributes)
                } else {
                    attributes.zIndex = standardHeaderZIndex
                    nonStickyHeaderAttributes.append(attributes)
                }
            } else {
                cellAndOtherAttributes.append(attributes)
            }
        }
        
        stickyHeaderCandidateAttributes.sort { $0.indexPath.section < $1.indexPath.section }

        let contentInsetTop = collectionView.adjustedContentInset.top
        let effectiveOffsetY = collectionView.contentOffset.y + contentInsetTop
        var accumulatedStickyHeadersHeight: CGFloat = 0.0
        var finalProcessedStickyAttributes: [UICollectionViewLayoutAttributes] = []

        for currentStickyAttrs in stickyHeaderCandidateAttributes {
            guard let originalCurrentFrame = originalAttributesForHeader(at: currentStickyAttrs.indexPath)?.frame else {
                finalProcessedStickyAttributes.append(currentStickyAttrs)
                continue
            }
            let originalY = originalCurrentFrame.origin.y
            var stickyTargetY = effectiveOffsetY + accumulatedStickyHeadersHeight

            let nextSectionIndexToPushFrom = currentStickyAttrs.indexPath.section + 1
            if nextSectionIndexToPushFrom < collectionView.numberOfSections {
                let nextPotentialPusherHeaderIndexPath = IndexPath(item: 0, section: nextSectionIndexToPushFrom)
                if let originalNextPusherFrame = originalAttributesForHeader(at: nextPotentialPusherHeaderIndexPath)?.frame {
                    let originalNextPusherY = originalNextPusherFrame.origin.y
                    let pushLimitY = originalNextPusherY - originalCurrentFrame.height
                    stickyTargetY = min(stickyTargetY, pushLimitY)
                }
            }
            
            currentStickyAttrs.frame.origin.y = max(stickyTargetY, originalY)
            currentStickyAttrs.zIndex = stickyHeaderZIndex + currentStickyAttrs.indexPath.section
            finalProcessedStickyAttributes.append(currentStickyAttrs)

            if currentStickyAttrs.frame.origin.y >= effectiveOffsetY + accumulatedStickyHeadersHeight - 1 && currentStickyAttrs.frame.origin.y <= originalY + 1 {
                 accumulatedStickyHeadersHeight += currentStickyAttrs.frame.height
            }
        }
        
        let finalLayoutAttributes = cellAndOtherAttributes + nonStickyHeaderAttributes + finalProcessedStickyAttributes
        return finalLayoutAttributes.filter { $0.frame.intersects(rect) }
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return true
    }

    override func layoutAttributesForSupplementaryView(ofKind elementKind: String, at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard let attributes = originalAttributesForHeader(at: indexPath)?.copy() as? UICollectionViewLayoutAttributes else {
            return super.layoutAttributesForSupplementaryView(ofKind: elementKind, at: indexPath)
        }
        
        guard let collectionView = self.collectionView, elementKind == UICollectionView.elementKindSectionHeader else {
            return attributes
        }

        if stickyHeaderSections.contains(indexPath.section) {
            let contentInsetTop = collectionView.adjustedContentInset.top
            let effectiveOffsetY = collectionView.contentOffset.y + contentInsetTop
            let originalYForThisHeader = attributes.frame.origin.y
            var accumulatedHeightOfPreviousStickies: CGFloat = 0

            let sortedStickySectionIndexes = stickyHeaderSections.sorted()

            for sectionIdx in sortedStickySectionIndexes {
                if sectionIdx < indexPath.section {
                    let previousStickyIndexPath = IndexPath(item: 0, section: sectionIdx)
                    if let previousOriginalAttrs = originalAttributesForHeader(at: previousStickyIndexPath) {
                        if previousOriginalAttrs.frame.origin.y <= effectiveOffsetY + accumulatedHeightOfPreviousStickies {
                            accumulatedHeightOfPreviousStickies += previousOriginalAttrs.frame.height
                        }
                    }
                } else if sectionIdx == indexPath.section {
                    break
                }
            }
            
            var stickyTargetY = effectiveOffsetY + accumulatedHeightOfPreviousStickies
            
            let nextSectionIndexToPushFrom = indexPath.section + 1
            if nextSectionIndexToPushFrom < collectionView.numberOfSections {
                let nextPotentialPusherHeaderIndexPath = IndexPath(item: 0, section: nextSectionIndexToPushFrom)
                if let originalNextPusherFrame = originalAttributesForHeader(at: nextPotentialPusherHeaderIndexPath)?.frame {
                    let originalNextPusherY = originalNextPusherFrame.origin.y
                    let pushLimitY = originalNextPusherY - attributes.frame.height
                    stickyTargetY = min(stickyTargetY, pushLimitY)
                }
            }
            
            attributes.frame.origin.y = max(stickyTargetY, originalYForThisHeader)
            attributes.zIndex = stickyHeaderZIndex + indexPath.section

        } else {
            attributes.zIndex = standardHeaderZIndex
        }
        
        return attributes
    }
}

// MARK: - Custom Collection View Cell & Header
class MyCell: UICollectionViewCell {
    static let reuseIdentifier = "MyCell"
    let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .systemOrange.withAlphaComponent(0.1)
        contentView.layer.borderColor = UIColor.systemOrange.withAlphaComponent(0.5).cgColor
        contentView.layer.borderWidth = 1.0
        
        label.textColor = .systemOrange
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func configure(text: String) { label.text = text }
}

@MainActor
protocol MyHeaderViewDelegate: AnyObject {
    func didTapSelectionToggleButton(inSection section: Int)
    func didTapDetailsActionButton(inSection section: Int)
}

class MyHeaderView: UICollectionReusableView {
    static let reuseIdentifier = "MyHeaderView"
    weak var delegate: MyHeaderViewDelegate?
    private var currentSection: Int = 0

    let iconImageView = UIImageView()
    let titleLabel = UILabel()
    let subtitleLabel = UILabel()
    let selectionToggleButton = UIButton(type: .system)
    let detailsActionButton = UIButton(type: .system)
    private let mainContentStackView = UIStackView()
    private let textStackView = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupViews() {
        backgroundColor = .white

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .darkGray
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .boldSystemFont(ofSize: 17)
        titleLabel.textColor = .black
        
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textColor = .gray
        
        selectionToggleButton.translatesAutoresizingMaskIntoConstraints = false
        selectionToggleButton.setImage(UIImage(systemName: "plus.circle"), for: .normal)
        selectionToggleButton.tintColor = .systemGray
        selectionToggleButton.addTarget(self, action: #selector(handleSelectionToggleButtonTap), for: .touchUpInside)

        detailsActionButton.translatesAutoresizingMaskIntoConstraints = false
        detailsActionButton.titleLabel?.font = .systemFont(ofSize: 13)
        detailsActionButton.setTitleColor(.systemRed, for: .normal)
        detailsActionButton.setTitle("Show details", for: .normal)
        detailsActionButton.isHidden = true
        detailsActionButton.contentHorizontalAlignment = .leading
        detailsActionButton.addTarget(self, action: #selector(handleDetailsActionButtonTap), for: .touchUpInside)

        textStackView.axis = .vertical
        textStackView.spacing = 2
        textStackView.addArrangedSubview(titleLabel)
        textStackView.addArrangedSubview(subtitleLabel)
        
        mainContentStackView.translatesAutoresizingMaskIntoConstraints = false
        mainContentStackView.axis = .horizontal
        mainContentStackView.spacing = 10
        mainContentStackView.alignment = .center
        mainContentStackView.addArrangedSubview(iconImageView)
        mainContentStackView.addArrangedSubview(textStackView)
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        mainContentStackView.addArrangedSubview(spacer)
        mainContentStackView.addArrangedSubview(selectionToggleButton)
        
        addSubview(mainContentStackView)
        addSubview(detailsActionButton)
        
        let detailsButtonBottomConstraint = detailsActionButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10)
        detailsButtonBottomConstraint.priority = .defaultHigh

        NSLayoutConstraint.activate([
            iconImageView.widthAnchor.constraint(equalToConstant: 36),
            iconImageView.heightAnchor.constraint(equalToConstant: 36),
            selectionToggleButton.widthAnchor.constraint(equalToConstant: 30),
            selectionToggleButton.heightAnchor.constraint(equalToConstant: 30),
            mainContentStackView.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            mainContentStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 15),
            mainContentStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -15),
            detailsActionButton.topAnchor.constraint(equalTo: mainContentStackView.bottomAnchor, constant: 6),
            detailsActionButton.leadingAnchor.constraint(equalTo: textStackView.leadingAnchor),
            detailsActionButton.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -15),
            detailsButtonBottomConstraint
        ])
    }

    @objc private func handleSelectionToggleButtonTap() { delegate?.didTapSelectionToggleButton(inSection: currentSection) }
    @objc private func handleDetailsActionButtonTap() { delegate?.didTapDetailsActionButton(inSection: currentSection) }

    func configure(with data: SectionHeaderData, section: Int, delegate: MyHeaderViewDelegate?) {
        self.currentSection = section
        self.delegate = delegate
        titleLabel.text = data.title
        subtitleLabel.text = data.subtitle
        iconImageView.image = UIImage(systemName: data.imageName)

        if data.isSelectedAndSticky {
            selectionToggleButton.setImage(UIImage(systemName: "checkmark.circle.fill"), for: .normal)
            selectionToggleButton.tintColor = .systemGreen
            detailsActionButton.isHidden = false
            detailsActionButton.setTitle(data.isDetailCellExpanded ? "Hide details" : "Show details", for: .normal)
        } else {
            selectionToggleButton.setImage(UIImage(systemName: "plus.circle"), for: .normal)
            selectionToggleButton.tintColor = .systemGray
            detailsActionButton.isHidden = true
        }
    }
}

// MARK: - Demo View Controller
@MainActor
class ViewController: UIViewController, UICollectionViewDelegateFlowLayout, MyHeaderViewDelegate {

    typealias DataSource = UICollectionViewDiffableDataSource<SectionHeaderData, Item>
    typealias Snapshot = NSDiffableDataSourceSnapshot<SectionHeaderData, Item>
    
    var collectionView: UICollectionView!
    var stickyLayout: PushingStickyHeaderFlowLayout!
    var dataSource: DataSource!
    var sectionData: [SectionHeaderData] = []
    var stickyHeaderSections: Set<Int> = []
    
    let totalSections = 30

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "Stepwise Sticky Headers"
        generateSectionData()
        setupCollectionView()
        configureDataSource()
        updateSnapshot(animatingDifferences: false)
    }

    func generateSectionData() {
        for i in 0..<totalSections {
            sectionData.append(
                SectionHeaderData(
                    id: i,
                    title: "Title for Section \(i)",
                    subtitle: "Description for Section \(i)",
                    imageName: i % 4 == 0 ? "doc.text.image.fill" : (i % 4 == 1 ? "mic.fill" : (i % 4 == 2 ? "play.tv.fill" : "headphones"))
                )
            )
        }
    }

    func setupCollectionView() {
        stickyLayout = PushingStickyHeaderFlowLayout()
        stickyLayout.scrollDirection = .vertical
        stickyLayout.minimumLineSpacing = 0
        stickyLayout.sectionInset = .zero
        
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: stickyLayout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.delegate = self
        collectionView.backgroundColor = .systemGroupedBackground

        collectionView.register(MyCell.self, forCellWithReuseIdentifier: MyCell.reuseIdentifier)
        collectionView.register(MyHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: MyHeaderView.reuseIdentifier)

        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    func configureDataSource() {
        dataSource = DataSource(collectionView: collectionView) { (collectionView, indexPath, item) -> UICollectionViewCell? in
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MyCell.reuseIdentifier, for: indexPath) as? MyCell else {
                fatalError("Unable to dequeue MyCell")
            }
            cell.configure(text: "Detail: Section \(item.sectionId)")
            return cell
        }

        dataSource.supplementaryViewProvider = { [weak self] (collectionView, kind, indexPath) -> UICollectionReusableView? in
            guard let self, kind == UICollectionView.elementKindSectionHeader,
                  let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: MyHeaderView.reuseIdentifier, for: indexPath) as? MyHeaderView,
                  let sectionIdentifier = self.dataSource.snapshot().sectionIdentifiers[safe: indexPath.section] else {
                return nil
            }
            headerView.configure(with: sectionIdentifier, section: indexPath.section, delegate: self)
            return headerView
        }
    }
    
    func updateSnapshot(animatingDifferences: Bool = true, reconfiguring aSection: SectionHeaderData? = nil) {
        var snapshot = Snapshot()
        snapshot.appendSections(sectionData)
        
        for section in sectionData {
            if section.isDetailCellExpanded {
                let detailItem = Item(sectionId: section.id)
                snapshot.appendItems([detailItem], toSection: section)
            }
        }
        
        // Si se nos pide explícitamente recargar una sección, lo hacemos aquí.
        if let sectionToReconfigure = aSection {
            snapshot.reloadSections([sectionToReconfigure])
        }
        
        dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
    }
    
    // MARK: - Delegate Methods
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.bounds.width, height: 100)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        let baseHeight: CGFloat = 60
        var detailsButtonHeight: CGFloat = 0
        
        guard let sectionInfo = sectionData[safe: section] else {
            return CGSize(width: collectionView.bounds.width, height: baseHeight)
        }
        
        if sectionInfo.isSelectedAndSticky {
            detailsButtonHeight = 30
        }
        return CGSize(width: collectionView.bounds.width, height: baseHeight + detailsButtonHeight)
    }

    func didTapSelectionToggleButton(inSection sectionIndex: Int) {
        guard sectionData[safe: sectionIndex] != nil else { return }

        // 1. Modificar el estado del modelo.
        sectionData[sectionIndex].isSelectedAndSticky.toggle()
        
        let sectionToUpdate = sectionData[sectionIndex]
        let isNowSticky = sectionToUpdate.isSelectedAndSticky
        
        if isNowSticky {
            stickyHeaderSections.insert(sectionIndex)
        } else {
            stickyHeaderSections.remove(sectionIndex)
            if sectionToUpdate.isDetailCellExpanded {
                sectionData[sectionIndex].isDetailCellExpanded = false
            }
        }
        
        // 2. Informar al layout de los nuevos cambios de estado.
        stickyLayout.stickyHeaderSections = self.stickyHeaderSections
        
        // 3. Invalidar el layout para que recalcule los tamaños.
        collectionView.collectionViewLayout.invalidateLayout()
        
        // 4. Aplicar el snapshot, pidiendo explícitamente la recarga de la sección.
        //    Esto fuerza a que el `supplementaryViewProvider` se llame de nuevo para esta sección.
        updateSnapshot(animatingDifferences: true, reconfiguring: sectionToUpdate)
    }

    func didTapDetailsActionButton(inSection sectionIndex: Int) {
        guard sectionData[safe: sectionIndex] != nil, sectionData[sectionIndex].isSelectedAndSticky else { return }

        sectionData[sectionIndex].isDetailCellExpanded.toggle()
        let sectionToUpdate = sectionData[sectionIndex]

        // Invalidar el layout para el efecto de "empuje".
        collectionView.collectionViewLayout.invalidateLayout()
        
        // Al expandir/colapsar, el número de items cambia, lo que ya fuerza una
        // actualización del header. Pero para ser explícitos y robustos, podemos
        // recargarlo también.
        updateSnapshot(animatingDifferences: true, reconfiguring: sectionToUpdate)
    }
}

extension Collection {
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

