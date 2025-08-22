import UIKit

class NumberCell: UICollectionViewCell {

    static let reuseIdentifier = "NumberCell"

    let numberLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.font = UIFont.preferredFont(forTextStyle: .title2)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.textColor = .white
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        contentView.addSubview(numberLabel)
        contentView.backgroundColor = .systemBlue
        contentView.layer.cornerRadius = 12
        contentView.clipsToBounds = true

        NSLayoutConstraint.activate([
            numberLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            numberLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            numberLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            numberLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8)
        ])
    }
}

import UIKit

class ViewController: UIViewController {

    enum Section {
        case main
    }

    var carousel: UICollectionView!
    var dataSource: UICollectionViewDiffableDataSource<Section, String>!
    private var carouselHeightConstraint: NSLayoutConstraint!
    
    private let minCellHeight: CGFloat = 184
    private let cellWidth: CGFloat = 132
    private let sectionVerticalInsets: CGFloat = 10
    private let cellPadding: CGFloat = 8

    let numbersInEnglish = [
        "One", "Two", "Three", "Four", "Five", "Six",
        "Seven (has more text)", "Eight", "Nine", "Ten",
        "Eleven is a slightly longer word", "Twelve"
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupCarousel()
        setupDataSource()
        applyInitialSnapshot()
        
        updateCarouselAndItsHeight()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory {
            updateCarouselAndItsHeight()
        }
    }

    private func updateCarouselAndItsHeight() {
        let maxCellHeight = calculateMaxCellHeight()
        let newLayout = createLayout(with: maxCellHeight)
        carousel.setCollectionViewLayout(newLayout, animated: true)
        let totalHeight = maxCellHeight + (sectionVerticalInsets * 2)
        carouselHeightConstraint.constant = totalHeight
    }
    
    private func setupCarousel() {
        let initialLayout = UICollectionViewFlowLayout()
        
        carousel = UICollectionView(frame: .zero, collectionViewLayout: initialLayout)
        carousel.translatesAutoresizingMaskIntoConstraints = false
        carousel.backgroundColor = .systemGray4
        carousel.register(NumberCell.self, forCellWithReuseIdentifier: NumberCell.reuseIdentifier)
        view.addSubview(carousel)

        let initialHeight = minCellHeight + (sectionVerticalInsets * 2)
        carouselHeightConstraint = carousel.heightAnchor.constraint(equalToConstant: initialHeight)
        
        NSLayoutConstraint.activate([
            carousel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            carousel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            carousel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            carouselHeightConstraint
        ])
    }

    private func calculateMaxCellHeight() -> CGFloat {
        var maxHeight: CGFloat = 0.0

        let sizingLabel = UILabel()
        sizingLabel.font = UIFont.preferredFont(forTextStyle: .title2)
        sizingLabel.numberOfLines = 0
        sizingLabel.textAlignment = .center

        let textWidth = cellWidth - (cellPadding * 2)

        for text in numbersInEnglish {
            sizingLabel.text = "\(text) Text Example"
            let labelSize = sizingLabel.systemLayoutSizeFitting(
                CGSize(width: textWidth, height: UIView.layoutFittingCompressedSize.height)
            )
            let cellHeight = labelSize.height + (cellPadding * 2)
            
            if cellHeight > maxHeight {
                maxHeight = cellHeight
            }
        }
        
        return max(minCellHeight, maxHeight)
    }

    private func createLayout(with cellHeight: CGFloat) -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .absolute(cellWidth),
            heightDimension: .absolute(cellHeight)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .absolute(cellWidth),
            heightDimension: .absolute(cellHeight)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 16
        section.contentInsets = NSDirectionalEdgeInsets(top: sectionVerticalInsets, leading: 16, bottom: sectionVerticalInsets, trailing: 16)
        section.orthogonalScrollingBehavior = .continuous
        
        return UICollectionViewCompositionalLayout(section: section)
    }

    private func setupDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Section, String>(collectionView: carousel) {
            (collectionView, indexPath, numberText) -> UICollectionViewCell? in
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: NumberCell.reuseIdentifier,
                for: indexPath) as? NumberCell else {
                fatalError("Cannot create new cell")
            }
            cell.numberLabel.text = "\(numberText) Text Example"
            return cell
        }
    }

    private func applyInitialSnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, String>()
        snapshot.appendSections([.main])
        snapshot.appendItems(numbersInEnglish, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: false)
    }
}


