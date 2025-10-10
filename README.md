extension UICollectionView {

    /// Hace scroll en el CollectionView para que el header de una sección específica sea visible.
    ///
    /// - Parameters:
    ///   - sectionIndex: El índice de la sección cuyo header se quiere mostrar.
    ///   - scrollPosition: La posición en la pantalla donde el header debería aparecer (top, centeredVertically, bottom).
    ///   - animated: Un booleano que indica si la transición de scroll debe ser animada.
    func scrollToHeader(atSection sectionIndex: Int, at scrollPosition: UICollectionView.ScrollPosition, animated: Bool) {
        // 1. Asegurarnos de que el layout y la sección son válidos.
        guard let layout = self.collectionViewLayout else {
            print("Error: No se pudo obtener el layout del CollectionView.")
            return
        }
        guard sectionIndex < self.numberOfSections else {
            print("Error: El índice de la sección (\(sectionIndex)) está fuera de los límites.")
            return
        }

        // 2. Obtener los atributos del layout para el header de la sección deseada.
        let headerIndexPath = IndexPath(item: 0, section: sectionIndex)
        guard let headerAttributes = layout.layoutAttributesForSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, at: headerIndexPath) else {
            // La sección podría no tener un header configurado.
            print("Advertencia: No se encontraron atributos de layout para el header en la sección \(sectionIndex).")
            // Opcional: podrías hacer scroll al primer item de la sección como alternativa.
            // if self.numberOfItems(inSection: sectionIndex) > 0 {
            //     self.scrollToItem(at: IndexPath(item: 0, section: sectionIndex), at: scrollPosition, animated: animated)
            // }
            return
        }

        // 3. Calcular el punto (offset) al que necesitamos hacer scroll.
        var targetOffset: CGPoint

        // Se asume un layout vertical. Para uno horizontal, usaríamos las propiedades .x y .width
        switch scrollPosition {
        case .top:
            // Queremos que el borde superior del header coincida con el borde superior del área visible del CollectionView.
            // Se resta `adjustedContentInset.top` para respetar el safe area y otros insets.
            targetOffset = CGPoint(x: self.contentOffset.x, y: headerAttributes.frame.origin.y - self.adjustedContentInset.top)

        case .centeredVertically:
            // Centramos el header en el área visible del CollectionView.
            let verticalCenter = (self.bounds.height / 2.0) - (headerAttributes.frame.height / 2.0)
            targetOffset = CGPoint(x: self.contentOffset.x, y: headerAttributes.frame.origin.y - verticalCenter)

        case .bottom:
            // Queremos que el borde inferior del header coincida con el borde inferior del área visible.
            let bottomPoint = headerAttributes.frame.origin.y + headerAttributes.frame.height
            targetOffset = CGPoint(x: self.contentOffset.x, y: bottomPoint - self.bounds.height + self.adjustedContentInset.bottom)
            
        default:
            // Para otras posiciones no especificadas, usamos la lógica de .top como valor por defecto.
            targetOffset = CGPoint(x: self.contentOffset.x, y: headerAttributes.frame.origin.y - self.adjustedContentInset.top)
        }

        // 4. Asegurarnos de que el offset calculado no se salga de los límites del contenido.
        let maxOffsetY = self.contentSize.height - self.bounds.height + self.adjustedContentInset.bottom
        let minOffsetY = -self.adjustedContentInset.top
        
        targetOffset.y = max(minOffsetY, min(targetOffset.y, maxOffsetY))

        // 5. Finalmente, aplicamos el scroll.
        self.setContentOffset(targetOffset, animated: animated)
    }
}
