import UIKit

extension UICollectionView {

    /// Hace scroll para que el header de una sección sea visible.
    /// Si la sección no tiene un header, intentará hacer scroll al primer item de esa sección como alternativa.
    ///
    /// - Parameters:
    ///   - sectionIndex: El índice de la sección objetivo.
    ///   - scrollPosition: La posición en la pantalla donde el elemento debería aparecer.
    ///   - animated: Un booleano que indica si el scroll debe ser animado.
    func scrollToHeader(atSection sectionIndex: Int, at scrollPosition: UICollectionView.ScrollPosition, animated: Bool) {
        guard let layout = self.collectionViewLayout, sectionIndex < self.numberOfSections else { return }

        let headerIndexPath = IndexPath(item: 0, section: sectionIndex)
        
        // Intenta obtener los atributos del header primero
        if let headerAttributes = layout.layoutAttributesForSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, at: headerIndexPath) {
            
            // --- Lógica original para hacer scroll al header ---
            var targetOffset: CGPoint
            switch scrollPosition {
            case .top:
                targetOffset = CGPoint(x: self.contentOffset.x, y: headerAttributes.frame.origin.y - self.adjustedContentInset.top)
            case .centeredVertically:
                let verticalCenter = (self.bounds.height / 2.0) - (headerAttributes.frame.height / 2.0)
                targetOffset = CGPoint(x: self.contentOffset.x, y: headerAttributes.frame.origin.y - verticalCenter)
            case .bottom:
                let bottomPoint = headerAttributes.frame.origin.y + headerAttributes.frame.height
                targetOffset = CGPoint(x: self.contentOffset.x, y: bottomPoint - self.bounds.height + self.adjustedContentInset.bottom)
            default:
                targetOffset = CGPoint(x: self.contentOffset.x, y: headerAttributes.frame.origin.y - self.adjustedContentInset.top)
            }

            let maxOffsetY = self.contentSize.height - self.bounds.height + self.adjustedContentInset.bottom
            let minOffsetY = -self.adjustedContentInset.top
            targetOffset.y = max(minOffsetY, min(targetOffset.y, maxOffsetY))
            
            self.setContentOffset(targetOffset, animated: animated)
            
        } else {
            // --- NUEVO: Lógica de fallback si no se encuentra el header ---
            // Intenta hacer scroll al primer item de la sección.
            guard self.numberOfItems(inSection: sectionIndex) > 0 else { return }
            let firstItemIndexPath = IndexPath(item: 0, section: sectionIndex)
            
            // Usamos el método nativo para hacer scroll a un item.
            self.scrollToItem(at: firstItemIndexPath, at: scrollPosition, animated: animated)
        }
    }
}
