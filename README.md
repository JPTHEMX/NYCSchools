import UIKit

class NumberCell: UICollectionViewCell {

    static let reuseIdentifier = "NumberCell"

    let numberLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        
        // Usar una fuente que responde a los cambios de accesibilidad
        label.font = UIFont.preferredFont(forTextStyle: .title2) // Un poco más grande para llenar mejor la celda
        label.adjustsFontForContentSizeCategory = true
        
        // Es crucial permitir múltiples líneas para que el texto pueda "envolverse" y crecer verticalmente
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

        // --- Restricciones clave ---
        
        // 1. Establecer la altura MÍNIMA de la celda.
        // La celda siempre tendrá al menos 184 puntos de alto.
        let minHeightConstraint = contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 184)
        // La prioridad debe ser alta, pero no requerida (1000) para evitar conflictos.
        // 999 es un valor seguro que le da flexibilidad al sistema de Auto Layout.
        minHeightConstraint.priority = .defaultHigh
        minHeightConstraint.isActive = true
        
        // 2. Anclar la etiqueta a los bordes de la celda con padding.
        // Esto hace que la etiqueta EMPUJE las paredes de la celda.
        // Si el texto de la etiqueta necesita más altura, forzará a la celda a crecer.
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

    // --- Propiedades ---
    var carousel: UICollectionView!
    var dataSource: UICollectionViewDiffableDataSource<Section, String>!
    
    // 1. VOLVEMOS a tener la propiedad para la restricción de altura
    private var carouselHeightConstraint: NSLayoutConstraint!
    
    // Constantes para el layout, esto facilita el cálculo
    private let minCellHeight: CGFloat = 184
    private let sectionVerticalInsets: CGFloat = 10 // top + bottom

    let numbersInEnglish = [
        "One", "Two", "Three", "Four", "Five", "Six",
        "Seven", "Eight", "Nine", "Ten", "Eleven", "Twelve"
    ]

    // --- Ciclo de Vida ---
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupCarousel()
        setupDataSource()
        applyInitialSnapshot()
    }
    
    // 2. VOLVEMOS a necesitar viewDidLayoutSubviews para ajustes finos si fuera necesario
    // aunque con el cálculo inicial correcto, a menudo no es ni siquiera visible el cambio.
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateCarouselHeight()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory {
            DispatchQueue.main.async {
                // Forzamos el recálculo y luego actualizamos la altura.
                self.carousel.collectionViewLayout.invalidateLayout()
                self.updateCarouselHeight()
            }
        }
    }
    
    private func setupCarousel() {
        let layout = createLayout()
        
        carousel = UICollectionView(frame: .zero, collectionViewLayout: layout)
        carousel.translatesAutoresizingMaskIntoConstraints = false
        carousel.backgroundColor = .systemGray4
        // Dejamos isScrollEnabled en true (comportamiento por defecto) o false.
        // El scroll ya está controlado por `orthogonalScrollingBehavior`.
        view.addSubview(carousel)
        carousel.register(NumberCell.self, forCellWithReuseIdentifier: NumberCell.reuseIdentifier)

        // 3. CALCULAR la altura inicial correctamente
        let initialHeight = minCellHeight + (sectionVerticalInsets * 2) // *2 para top y bottom
        
        // Creamos la restricción con este valor preciso
        carouselHeightConstraint = carousel.heightAnchor.constraint(equalToConstant: initialHeight)
        
        // La activamos
        NSLayoutConstraint.activate([
            carousel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            carousel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            carousel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            carouselHeightConstraint
        ])
    }
    
    // 4. VOLVEMOS a tener nuestro método para actualizar la altura dinámicamente
    private func updateCarouselHeight() {
        let newHeight = carousel.collectionViewLayout.collectionViewContentSize.height
        
        guard newHeight > 0, carouselHeightConstraint.constant != newHeight else {
            return
        }
        
        carouselHeightConstraint.constant = newHeight
    }

    private func createLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .absolute(132),
            heightDimension: .estimated(minCellHeight)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .absolute(132),
            heightDimension: .estimated(minCellHeight)
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
