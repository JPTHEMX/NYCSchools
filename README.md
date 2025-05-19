import UIKit

// MARK: - Data Model
struct SectionHeaderData {
    let id: Int
    var title: String
    var subtitle: String
    var imageName: String
    var isSelectedAndSticky: Bool = false
    var isDetailCellExpanded: Bool = false
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

            if currentStickyAttrs.frame.origin.y <= originalY && currentStickyAttrs.frame.origin.y >= effectiveOffsetY {
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

// MARK: - Custom Collection View Cell
class MyCell: UICollectionViewCell {
    static let reuseIdentifier = "MyCell"
    let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
        contentView.layer.borderColor = UIColor.lightGray.cgColor
        contentView.layer.borderWidth = 0.5
        contentView.backgroundColor = UIColor.systemGray6
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(text: String) {
        label.text = text
    }
}

// MARK: - Custom Collection Reusable View (Header)
@MainActor
protocol MyHeaderViewDelegate: AnyObject {
    func didTapSelectionToggleButton(inSection section: Int)
    func didTapDetailsActionButton(inSection section: Int)
}

class MyHeaderView: UICollectionReusableView {
    static let reuseIdentifier = "MyHeaderView"

    weak var delegate: MyHeaderViewDelegate?
    private var currentSection: Int = 0

    let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .darkGray
        return imageView
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.boldSystemFont(ofSize: 17)
        label.textColor = .black
        return label
    }()

    let subtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .gray
        return label
    }()

    let selectionToggleButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "plus.circle"), for: .normal)
        button.tintColor = .systemGray
        return button
    }()
    
    let detailsActionButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.titleLabel?.font = UIFont.systemFont(ofSize: 13)
        button.setTitleColor(.systemRed, for: .normal)
        button.setTitle("Show details", for: .normal)
        button.isHidden = true
        button.contentHorizontalAlignment = .leading
        return button
    }()
    
    private let mainContentStackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 10
        stack.alignment = .center
        return stack
    }()
    
    private let textStackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 2
        return stack
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .white
        
        textStackView.addArrangedSubview(titleLabel)
        textStackView.addArrangedSubview(subtitleLabel)
        
        mainContentStackView.addArrangedSubview(iconImageView)
        mainContentStackView.addArrangedSubview(textStackView)
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        mainContentStackView.addArrangedSubview(spacer)
        mainContentStackView.addArrangedSubview(selectionToggleButton)
        
        addSubview(mainContentStackView)
        addSubview(detailsActionButton)

        selectionToggleButton.addTarget(self, action: #selector(handleSelectionToggleButtonTap), for: .touchUpInside)
        detailsActionButton.addTarget(self, action: #selector(handleDetailsActionButtonTap), for: .touchUpInside)

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
            mainContentStackView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -10),

            detailsActionButton.topAnchor.constraint(equalTo: mainContentStackView.bottomAnchor, constant: 6),
            detailsActionButton.leadingAnchor.constraint(equalTo: textStackView.leadingAnchor),
            detailsActionButton.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -15),
            detailsButtonBottomConstraint
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handleSelectionToggleButtonTap() {
        delegate?.didTapSelectionToggleButton(inSection: currentSection)
    }

    @objc private func handleDetailsActionButtonTap() {
        delegate?.didTapDetailsActionButton(inSection: currentSection)
    }

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
            if data.isDetailCellExpanded {
                detailsActionButton.setTitle("Hide details", for: .normal)
            } else {
                detailsActionButton.setTitle("Show details", for: .normal)
            }
        } else {
            selectionToggleButton.setImage(UIImage(systemName: "plus.circle"), for: .normal)
            selectionToggleButton.tintColor = .systemGray
            
            detailsActionButton.isHidden = true
            detailsActionButton.setTitle("Show details", for: .normal)
        }
    }
}

// MARK: - Demo View Controller
@MainActor
class ViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, MyHeaderViewDelegate {

    var collectionView: UICollectionView!
    var stickyLayout: PushingStickyHeaderFlowLayout!
    var sectionData: [SectionHeaderData] = []

    var sectionsWithStickyHeaders: Set<Int> = [] {
        didSet {
            if oldValue != sectionsWithStickyHeaders {
                stickyLayout.stickyHeaderSections = sectionsWithStickyHeaders
                self.collectionView.collectionViewLayout.invalidateLayout()
            }
        }
    }
    let numberOfUniqueSectionModels = 10
    let totalSections = 30
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "Stepwise Sticky Headers"
        generateSectionData()
        setupCollectionView()
    }

    func generateSectionData() {
        for i in 0..<totalSections {
            sectionData.append(
                SectionHeaderData(
                    id: i,
                    title: "Title for Section \(i)",
                    subtitle: "Desc for \(i % numberOfUniqueSectionModels)",
                    imageName: i % 4 == 0 ? "doc.text.image.fill" : (i % 4 == 1 ? "mic.fill" : (i % 4 == 2 ? "play.tv.fill" : "headphones")),
                    isSelectedAndSticky: false,
                    isDetailCellExpanded: false
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
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.backgroundColor = .systemGray6

        collectionView.register(MyCell.self, forCellWithReuseIdentifier: MyCell.reuseIdentifier)
        collectionView.register(MyHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: MyHeaderView.reuseIdentifier)

        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return sectionData.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return sectionData[section].isDetailCellExpanded ? 1 : 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MyCell.reuseIdentifier, for: indexPath) as? MyCell else {
            fatalError("Unable to dequeue MyCell")
        }
        cell.configure(text: "Detail: Section \(indexPath.section)")
        cell.contentView.backgroundColor = .systemOrange.withAlphaComponent(0.1)
        cell.label.textColor = .systemOrange
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            guard let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: MyHeaderView.reuseIdentifier, for: indexPath) as? MyHeaderView else {
                fatalError("Unable to dequeue MyHeaderView")
            }
            let data = sectionData[indexPath.section]
            headerView.configure(with: data, section: indexPath.section, delegate: self)
            return headerView
        }
        return UICollectionReusableView()
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.bounds.width - (stickyLayout.sectionInset.left + stickyLayout.sectionInset.right), height: 400)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        let baseHeight: CGFloat = 60
        var detailsButtonHeight: CGFloat = 0
        
        if sectionData[section].isSelectedAndSticky {
            detailsButtonHeight = 30
        }
        return CGSize(width: collectionView.bounds.width, height: baseHeight + detailsButtonHeight)
    }

    // MARK: - MyHeaderViewDelegate

    func didTapSelectionToggleButton(inSection section: Int) {
        sectionData[section].isSelectedAndSticky.toggle()

        if sectionData[section].isSelectedAndSticky {
            sectionsWithStickyHeaders.insert(section)
        } else {
            sectionsWithStickyHeaders.remove(section)
            if sectionData[section].isDetailCellExpanded {
                sectionData[section].isDetailCellExpanded = false
                let indexPathForDetailCell = IndexPath(item: 0, section: section)
                 collectionView.performBatchUpdates({
                    if self.collectionView.numberOfItems(inSection: section) > 0 {
                        self.collectionView.deleteItems(at: [indexPathForDetailCell])
                    }
                    self.collectionView.reloadSections(IndexSet(integer: section))
                 }, completion: nil)
                return
            }
        }
        
        collectionView.performBatchUpdates({
             self.collectionView.collectionViewLayout.invalidateLayout()
             self.collectionView.reloadSections(IndexSet(integer: section))
        }, completion: nil)
    }

    func didTapDetailsActionButton(inSection section: Int) {
        guard sectionData[section].isSelectedAndSticky else { return }

        sectionData[section].isDetailCellExpanded.toggle()

        let indexPathForDetailCell = IndexPath(item: 0, section: section)
        
        collectionView.performBatchUpdates({
            self.collectionView.collectionViewLayout.invalidateLayout()

            if sectionData[section].isDetailCellExpanded {
                if self.collectionView.numberOfItems(inSection: section) == 0 {
                    self.collectionView.insertItems(at: [indexPathForDetailCell])
                }
            } else {
                if self.collectionView.numberOfItems(inSection: section) > 0 {
                    self.collectionView.deleteItems(at: [indexPathForDetailCell])
                }
            }
            self.collectionView.reloadSections(IndexSet(integer: section))
        }, completion: nil)
    }
}

