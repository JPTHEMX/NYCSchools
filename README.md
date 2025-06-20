func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        // 1. Revisar si el tamaño ya está en la caché
        if let cachedSize = headerSizeCache[section] {
            return cachedSize
        }
        
        // 2. Si no, calcularlo
        let data = sectionData[section]
        sizingHeaderView.configure(with: data, section: section, delegate: nil)
        
        let targetWidth = collectionView.bounds.width
        
        let calculatedSize = sizingHeaderView.systemLayoutSizeFitting(
            CGSize(width: targetWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        
        // 3. Guardar el resultado en la caché
        headerSizeCache[section] = calculatedSize
        
        return calculatedSize
    }
