import UIKit

@MainActor
protocol DynamicFontScaling: AnyObject {
    var font: UIFont! { get set }
    var baseFont: UIFont! { get set }
    var textStyle: UIFont.TextStyle! { get set }
    func updateFont()
}

extension DynamicFontScaling {
    func updateFont() {
        guard let baseFont = self.baseFont, let textStyle = self.textStyle else { return }
        
        let metrics = UIFontMetrics(forTextStyle: textStyle)
        self.font = metrics.scaledFont(for: baseFont)
    }
}


import UIKit

class ScalableLabel: UILabel, DynamicFontScaling {
    
    var baseFont: UIFont!
    var textStyle: UIFont.TextStyle!
    
    func configure(with font: UIFont, forTextStyle textStyle: UIFont.TextStyle, textColor: UIColor = .label) {
        self.translatesAutoresizingMaskIntoConstraints = false
        self.baseFont = font
        self.textStyle = textStyle
        self.numberOfLines = 0
        self.textColor = textColor
        self.adjustsFontForContentSizeCategory = true
        updateFont()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateFont()
    }
}


import UIKit

class ScalableButton: UIButton, DynamicFontScaling {
    
    var font: UIFont! {
        get {
            return self.configuration?.titleTextAttributesTransformer?(.init()).font
        }
        set {
            self.configuration?.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = newValue
                return outgoing
            }
        }
    }
    
    var baseFont: UIFont!
    var textStyle: UIFont.TextStyle!
    
    func configure(with font: UIFont, forTextStyle textStyle: UIFont.TextStyle) {
        self.translatesAutoresizingMaskIntoConstraints = false
        self.baseFont = font
        self.textStyle = textStyle
        self.titleLabel?.adjustsFontForContentSizeCategory = true
        self.titleLabel?.numberOfLines = 0
        updateFont()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateFont()
    }
}

import UIKit

class GradientView: UIView {
    let gradientLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(gradientLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = self.bounds
    }
}

import UIKit

class BaseCollectionViewCell: UICollectionViewCell {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupUI() {
        self.contentView.backgroundColor = .clear
        self.contentView.layer.borderColor = UIColor.gray.withAlphaComponent(0.2).cgColor
        self.contentView.layer.borderWidth = 1.0
        self.contentView.clipsToBounds = true
        self.contentView.layer.cornerRadius = 8.0
    }
    
}

import UIKit

class GridCell: UICollectionViewCell {
    static let reuseIdentifier = "GridCell"

    let label: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.textColor = .white
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .systemBlue
        contentView.layer.cornerRadius = 8
        contentView.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(with number: Int) {
        label.text = "\(number)"
    }
}

import UIKit

class TextCell: BaseCollectionViewCell {
    
    static let reuseIdentifier = "TextCell"

    struct Model {
        var title: String?
        var description: String?
        var buttonTitle: String?
        var imageName: String?
        var titleFont: UIFont
        var descriptionFont: UIFont
        var buttonFont: UIFont
    }
    
    var onButtonTapped: (() -> Void)?

    private lazy var backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()

    private lazy var gradientView: GradientView = {
        let view = GradientView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.gradientLayer.colors = [UIColor(white: 0, alpha: 0.6).cgColor, UIColor.clear.cgColor]
        view.gradientLayer.locations = [0.0, 1.0]
        view.gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        view.gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        return view
    }()
    
    private lazy var titleLabel = ScalableLabel()
    private lazy var descriptionLabel = ScalableLabel()
    private lazy var actionButton = ScalableButton()
    
    override func setupUI() {
        super.setupUI()
        
        contentView.addSubview(backgroundImageView)
        contentView.addSubview(gradientView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(descriptionLabel)
        contentView.addSubview(actionButton)
        
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .medium
        actionButton.configuration = config
        actionButton.isUserInteractionEnabled = true
        actionButton.addTarget(self, action: #selector(didTapButton), for: .touchUpInside)
        
        let padding: CGFloat = 16
        
        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            gradientView.topAnchor.constraint(equalTo: contentView.topAnchor),
            gradientView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            gradientView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: padding),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            descriptionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            descriptionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            
            actionButton.topAnchor.constraint(greaterThanOrEqualTo: descriptionLabel.bottomAnchor, constant: 12),
            actionButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            actionButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            actionButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -padding)
        ])
    }
    
    func configure(with model: Model) {
        titleLabel.configure(with: model.titleFont, forTextStyle: .headline, textColor: .white)
        descriptionLabel.configure(with: model.descriptionFont, forTextStyle: .subheadline, textColor: .white.withAlphaComponent(0.9))
        actionButton.configure(with: model.buttonFont, forTextStyle: .callout)
        
        titleLabel.text = model.title
        descriptionLabel.text = model.description
        actionButton.configuration?.title = model.buttonTitle
        
        if let imageName = model.imageName {
            backgroundImageView.image = UIImage(named: imageName)
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        descriptionLabel.text = nil
        actionButton.configuration?.title = nil
        backgroundImageView.image = nil
        onButtonTapped = nil
    }
    
    @objc private func didTapButton() {
        onButtonTapped?()
    }
}

import UIKit

class HeaderView: UICollectionReusableView {
    static let reuseIdentifier = "HeaderView"

    private let titleLabel = ScalableLabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground
        
        let headerFont = UIFont.systemFont(ofSize: 18, weight: .semibold)
        titleLabel.configure(with: headerFont, forTextStyle: .headline)
        
        addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(with title: String) {
        titleLabel.text = title
    }
}

import UIKit

class ViewController: UIViewController {

    private let sectionHeaderTitle = "Important Information"
    
    private let textCellModel = TextCell.Model(
        title: "Discover Special Offers",
        description: "This is a sample text that spans multiple lines. Its size will change automatically when you adjust the accessibility settings on your device.",
        buttonTitle: "View Now",
        imageName: "background-sample",
        titleFont: UIFont(name: "AvenirNext-Bold", size: 24) ?? .systemFont(ofSize: 24, weight: .bold),
        descriptionFont: UIFont(name: "AvenirNext-Regular", size: 17) ?? .systemFont(ofSize: 17),
        buttonFont: UIFont(name: "AvenirNext-DemiBold", size: 16) ?? .systemFont(ofSize: 16, weight: .semibold)
    )

    var collectionView: UICollectionView!
    private var cellCache: [IndexPath: CGSize] = [:]
    private var headerCache: [IndexPath: CGSize] = [:]
    private var isFirstLayout = true

    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Accessibility"
        navigationController?.navigationBar.prefersLargeTitles = true
        view.backgroundColor = .systemBackground
        
        setupCollectionView()
        
        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: Self, _: UITraitCollection) in
                self.invalidateCachesAndLayout()
            }
        } else {
            // Fallback on earlier versions
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if isFirstLayout {
            isFirstLayout = false
            collectionView.collectionViewLayout.invalidateLayout()
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            self?.invalidateCachesAndLayout()
        }
    }

    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        
        collectionView.register(GridCell.self, forCellWithReuseIdentifier: GridCell.reuseIdentifier)
        collectionView.register(TextCell.self, forCellWithReuseIdentifier: TextCell.reuseIdentifier)
        collectionView.register(HeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: HeaderView.reuseIdentifier)
        
        collectionView.dataSource = self
        collectionView.delegate = self
        
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    private func invalidateCachesAndLayout() {
        cellCache.removeAll()
        headerCache.removeAll()
        collectionView.collectionViewLayout.invalidateLayout()
    }
    
    private func handleButtonTap() {
        let alert = UIAlertController(title: "Action Performed", message: "You have pressed the button.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension ViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return section == 0 ? 10 : 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch indexPath.section {
        case 0:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: GridCell.reuseIdentifier, for: indexPath) as! GridCell
            cell.configure(with: indexPath.item + 1)
            return cell
        case 1:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TextCell.reuseIdentifier, for: indexPath) as! TextCell
            cell.configure(with: textCellModel)
            cell.onButtonTapped = { [weak self] in
                self?.handleButtonTap()
            }
            return cell
        default:
            fatalError("Unknown section")
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionHeader, indexPath.section == 1 else {
            return UICollectionReusableView()
        }
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: HeaderView.reuseIdentifier, for: indexPath) as! HeaderView
        header.configure(with: sectionHeaderTitle)
        return header
    }
}

extension ViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if let cachedSize = cellCache[indexPath] {
            return cachedSize
        }
        
        let calculatedSize: CGSize
        
        if indexPath.section == 0 {
            let padding: CGFloat = 16
            let interitemSpacing: CGFloat = 10
            let availableWidth = collectionView.bounds.width - (padding * 2)
            let itemWidth = (availableWidth - interitemSpacing) / 2
            calculatedSize = CGSize(width: itemWidth, height: itemWidth)
        } else {
            let cell = TextCell()
            cell.configure(with: textCellModel)
            
            let targetWidth = collectionView.bounds.width - 32
            cell.frame = CGRect(x: 0, y: 0, width: targetWidth, height: 1000)
            cell.setNeedsLayout()
            cell.layoutIfNeeded()
            
            calculatedSize = cell.contentView.systemLayoutSizeFitting(
                CGSize(width: targetWidth, height: UIView.layoutFittingCompressedSize.height)
            )
        }
        
        cellCache[indexPath] = calculatedSize
        return calculatedSize
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        guard section == 1 else {
            return .zero
        }
        
        let indexPath = IndexPath(item: 0, section: section)
        if let cachedSize = headerCache[indexPath] {
            return cachedSize
        }
        
        let header = HeaderView()
        header.configure(with: sectionHeaderTitle)
        
        let targetWidth = collectionView.bounds.width
        header.frame = CGRect(x: 0, y: 0, width: targetWidth, height: 1000)
        header.setNeedsLayout()
        header.layoutIfNeeded()
        
        let calculatedSize = header.systemLayoutSizeFitting(
            CGSize(width: targetWidth, height: UIView.layoutFittingCompressedSize.height)
        )
        
        headerCache[indexPath] = calculatedSize
        return calculatedSize
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 10, left: 16, bottom: 20, right: 16)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 10
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return section == 0 ? 10 : 0
    }
}


