func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
    // ... caché y lógica de la sección 0 sin cambios ...

    // Para la sección 1 (TextCell)
    let targetWidth = collectionView.bounds.width - 32 // Ancho disponible para el contenido

    // 1. Obtén el modelo de datos para esta celda
    let model = textCellModel
    
    // 2. Calcula la altura de cada componente de texto
    let titleHeight = heightForText(
        model.title,
        font: model.titleFont,
        style: .headline, // Importante para que UIFontMetrics haga su magia
        width: targetWidth
    )
    
    let descriptionHeight = heightForText(
        model.description,
        font: model.descriptionFont,
        style: .subheadline,
        width: targetWidth
    )
    
    let buttonHeight = heightForText(
        model.buttonTitle,
        font: model.buttonFont,
        style: .callout,
        width: targetWidth
    )

    // 3. Suma las alturas de todos los componentes y los espaciados verticales (padding)
    let verticalPadding: CGFloat = 16 // top padding
                             + 8   // espacio title-description
                             + 12  // espacio MÍNIMO description-button (podría ser más)
                             + 16  // bottom padding
                             + buttonHeight // El "buttonHeight" calculado aquí incluye su padding interno. O usa un valor fijo, ej: 44.

    // A menudo para el botón, es mejor usar un alto fijo o un cálculo basado en su configuración.
    // Un valor fijo como 44-50 es común.
    let fixedButtonHeight: CGFloat = 50 
    
    let totalHeight = verticalPadding + titleHeight + descriptionHeight //+ fixedButtonHeight
    
    let calculatedSize = CGSize(width: collectionView.bounds.width - 32, height: totalHeight)
    
    cellCache[indexPath] = calculatedSize
    return calculatedSize
}

// Función auxiliar para calcular la altura de un texto escalado dinámicamente
private func heightForText(_ text: String?, font baseFont: UIFont, style: UIFont.TextStyle, width: CGFloat) -> CGFloat {
    guard let text = text, !text.isEmpty else { return 0 }
    
    // Escala la fuente primero, tal como lo hace la celda
    let metrics = UIFontMetrics(forTextStyle: style)
    let scaledFont = metrics.scaledFont(for: baseFont)
    
    // Prepara el bounding box para el cálculo
    let aRect = CGSize(width: width, height: .greatestFiniteMagnitude)
    
    // Calcula la altura del texto con la fuente escalada
    let boundingBox = text.boundingRect(
        with: aRect,
        options: .usesLineFragmentOrigin,
        attributes: [.font: scaledFont],
        context: nil
    )
    
    return ceil(boundingBox.height) // ceil() para redondear hacia arriba y evitar cortes de píxeles
}
