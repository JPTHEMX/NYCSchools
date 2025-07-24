import UIKit

@MainActor
func createLayoutWithMixedStickyHeaders() -> UICollectionViewLayout {
    let stickyHeaderSections: Set<Int> = [1, 3]

    let layout = UICollectionViewCompositionalLayout { (sectionIndex, layoutEnvironment) -> NSCollectionLayoutSection? in
        
        let isSticky = stickyHeaderSections.contains(sectionIndex)
        
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(100)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
        
        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(60)
        )
        let sectionHeader = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        
        if isSticky {
            sectionHeader.pinToVisibleBounds = true
            sectionHeader.zIndex = 2
            
            section.visibleItemsInvalidationHandler = { (visibleItems, scrollOffset, layoutEnvironment) in
                let stickyHeaders = visibleItems.filter {
                    $0.representedElementKind == UICollectionView.elementKindSectionHeader && stickyHeaderSections.contains($0.indexPath.section)
                }
                
                guard let currentHeader = stickyHeaders.first(where: { $0.indexPath.section == sectionIndex }) else {
                    return
                }

                currentHeader.transform = .identity
                
                let nextStickySectionIndex = stickyHeaderSections.filter({ $0 > sectionIndex }).min()
                
                guard let nextStickyIndex = nextStickySectionIndex,
                      let nextHeader = stickyHeaders.first(where: { $0.indexPath.section == nextStickyIndex }),
                      currentHeader.frame.maxY >= nextHeader.frame.minY else {
                    return
                }
                
                let yOffset = nextHeader.frame.minY - currentHeader.frame.maxY
                currentHeader.transform = CGAffineTransform(translationX: 0, y: yOffset)
            }
        }
        
        section.boundarySupplementaryItems = [sectionHeader]
        
        return section
    }
    
    return layout
}
