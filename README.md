import UIKit

class TitleSubtitleCell: UICollectionViewCell {
    static let reuseIdentifier = "TitleSubtitleCell"

    // MARK: - Views
    
    // Usamos nuestras nuevas clases personalizadas
    private let heroImageView = UIImageView(image: UIImage(systemName: "photo.fill")) // Placeholder
    private let logoImageView = UIImageView(image: UIImage(systemName: "person.crop.circle.fill")) // Placeholder
    let tagView = TagView() // Exponemos para configurar
    private let titleLabel = UILabel()
    private let subTitleLabel = UILabel()
    let slotView = SlotView() // Exponemos para configurar

    private let padding: CGFloat = 16.0

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupProperties()
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Configuration
    
    func configure(title: String, subtitle: String) {
        titleLabel.text = title
        subTitleLabel.text = subtitle
    }

    // MARK: - UI Setup

    private func setupProperties() {
        heroImageView.translatesAutoresizingMaskIntoConstraints = false
        heroImageView.contentMode = .scaleAspectFill
        heroImageView.clipsToBounds = true

        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        logoImageView.layer.cornerRadius = 28
        logoImageView.clipsToBounds = true

        tagView.translatesAutoresizingMaskIntoConstraints = false
        slotView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.numberOfLines = 0

        subTitleLabel.font = .preferredFont(forTextStyle: .subheadline)
        subTitleLabel.textColor = .secondaryLabel
        subTitleLabel.numberOfLines = 0
    }
    
    private func setupUI() {
        let textStack = UIStackView(arrangedSubviews: [titleLabel, subTitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 4
        
        let mainContentStack = UIStackView(arrangedSubviews: [textStack])
        mainContentStack.axis = .vertical
        mainContentStack.spacing = 8
        mainContentStack.translatesAutoresizingMaskIntoConstraints = false
        mainContentStack.isLayoutMarginsRelativeArrangement = true
        mainContentStack.layoutMargins = UIEdgeInsets(top: 0, left: padding, bottom: 0, right: padding)

        contentView.addSubview(heroImageView)
        contentView.addSubview(logoImageView)
        contentView.addSubview(tagView)
        contentView.addSubview(mainContentStack)
        contentView.addSubview(slotView)
        
        NSLayoutConstraint.activate([
            // Restricciones del Hero Image
            heroImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            heroImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            heroImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            heroImageView.heightAnchor.constraint(equalToConstant: 88.0),
            
            // Restricciones del Logo
            logoImageView.topAnchor.constraint(equalTo: heroImageView.bottomAnchor, constant: -40.0),
            logoImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8.0),
            logoImageView.widthAnchor.constraint(equalToConstant: 56.0),
            logoImageView.heightAnchor.constraint(equalToConstant: 56.0),

            // Restricciones del Tag (SIN ALTURA FIJA)
            tagView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16.0),
            tagView.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: -4.0),
            
            // Restricciones del Stack de Texto
            mainContentStack.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 4.0),
            mainContentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            // Asegurarse que el texto no se superponga con el tag
            mainContentStack.trailingAnchor.constraint(lessThanOrEqualTo: tagView.leadingAnchor, constant: -8),
            
            // Restricciones del Slot View (SIN ALTURA FIJA)
            slotView.topAnchor.constraint(equalTo: mainContentStack.bottomAnchor, constant: 8.0),
            slotView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            slotView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            // La restricción final que permite el auto-dimensionamiento
            slotView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8.0)
        ])
    }
}
