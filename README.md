func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard selectedTabIndex != indexPath.item else { return }

        selectedTabIndex = indexPath.item
        delegate?.tabBarView(didSelectTabAt: indexPath.item)
        
        collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
        
        collectionView.performBatchUpdates({
            let context = UICollectionViewFlowLayoutInvalidationContext()
            context.invalidateItems(at: [indexPath])
            collectionView.collectionViewLayout.invalidateLayout(with: context)
        }, completion: { [weak self] _ in
            self?.updateIndicatorPosition(animated: true)
        })
    }
