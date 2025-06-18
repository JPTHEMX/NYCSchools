func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        // 1. Obtiene los datos para la sección actual.
        let data = sections[section]
        
        // 2. Configura el header de cálculo con esos datos.
        sizingHeader.configure(logo: nil, title: data.title, subtitle: data.subtitle)
        
        // 3. El resto de la lógica de cálculo es IDÉNTICA. Funciona para cualquier vista.
        let targetSize = CGSize(width: collectionView.bounds.width, height: UIView.layoutFittingCompressedSize.height)
        let calculatedSize = sizingHeader.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        
        return calculatedSize
    }
