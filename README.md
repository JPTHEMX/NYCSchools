// MARK: - UIView Extensions
extension UIView {
    var firstViewController: UIViewController? {
        var responder: UIResponder? = self
        while responder != nil {
            if let viewController = responder as? UIViewController {
                return viewController
            }
            responder = responder?.next
        }
        return nil
    }

    private func isView(_ viewToCheck: UIView, occluding targetView: UIView, myFrameInWindow: CGRect, in window: UIWindow) -> Bool {
        if viewToCheck === targetView || viewToCheck.isHidden || viewToCheck.alpha <= 0 {
            return false
        }

        let viewToCheckFrameInWindow = viewToCheck.convert(viewToCheck.bounds, to: window)
        if viewToCheckFrameInWindow.isNull || viewToCheckFrameInWindow.isEmpty {
            return false
        }
        
        if let vc = viewToCheck.firstViewController,
           (vc.presentingViewController != nil || vc.navigationController?.presentingViewController != nil || vc.tabBarController?.presentingViewController != nil),
            myFrameInWindow.intersects(viewToCheckFrameInWindow) {
            return true
        }

        for subview in viewToCheck.subviews {
            if isView(subview, occluding: targetView, myFrameInWindow: myFrameInWindow, in: window) {
                return true
            }
        }
        return false
    }

    func isActuallyVisibleInWindowHierarchy(consideringOcclusion: Bool = true, inContextOf cachedWindow: UIWindow?) -> Bool {
        guard let window = cachedWindow ?? self.window, !self.isHidden, self.alpha > 0, self.superview != nil else {
            return false
        }

        let rectInWindow = self.convert(self.bounds, to: window)
        if rectInWindow.intersection(window.bounds).isNull {
            return false
        }
        
        var current: UIView? = self.superview
        while let c = current, c != window {
            if c.clipsToBounds {
                let selfBoundsInC = self.convert(self.bounds, to: c)
                if c.bounds.intersection(selfBoundsInC).isNull {
                    return false
                }
            }
            current = c.superview
        }

        if consideringOcclusion {
            let myFrameInWindow = self.convert(self.bounds, to: window)
            if myFrameInWindow.isNull || myFrameInWindow.isEmpty { return false }

            for rootViewCandidate in window.subviews {
                var isAncestorOrSelfVCView = false
                var testView: UIView? = self
                while let tv = testView {
                    if tv === rootViewCandidate || tv.firstViewController?.view === rootViewCandidate {
                        isAncestorOrSelfVCView = true
                        break
                    }
                    testView = tv.superview
                }
                if isAncestorOrSelfVCView { continue }

                if isView(rootViewCandidate, occluding: self, myFrameInWindow: myFrameInWindow, in: window) {
                    return false
                }
            }
        }
        return true
    }
    
    func calculateVisiblePercentage(inContextOf window: UIWindow, safeAreaAwareBounds: CGRect) -> CGFloat {
        guard self.superview != nil, !self.isHidden, self.alpha > 0 else {
            return 0.0
        }

        let rectInWindow = self.convert(self.bounds, to: window)
        var visibleRectInWindow = rectInWindow.intersection(safeAreaAwareBounds)

        if visibleRectInWindow.isNull ||
            visibleRectInWindow.isEmpty ||
            visibleRectInWindow.width <= 0 ||
            visibleRectInWindow.height <= 0 {
            return 0.0
        }

        var currentViewForClippingCheck: UIView? = self.superview
        while let superview = currentViewForClippingCheck, superview != window {
            if superview.clipsToBounds {
                let superviewRectInWindow = superview.convert(superview.bounds, to: window)
                visibleRectInWindow = visibleRectInWindow.intersection(superviewRectInWindow)
                if visibleRectInWindow.isNull || visibleRectInWindow.isEmpty { return 0.0 }
            }

            if let scrollView = superview as? UIScrollView {
                let scrollViewVisibleContentRect = CGRect(x: scrollView.contentOffset.x,
                                                          y: scrollView.contentOffset.y,
                                                          width: scrollView.bounds.width,
                                                          height: scrollView.bounds.height)
                let scrollViewVisibleRectInWindow = scrollView.convert(scrollViewVisibleContentRect, to: window)
                visibleRectInWindow = visibleRectInWindow.intersection(scrollViewVisibleRectInWindow)
                if visibleRectInWindow.isNull || visibleRectInWindow.isEmpty { return 0.0 }
            }
            currentViewForClippingCheck = superview.superview
        }

        if visibleRectInWindow.width <= 0 || visibleRectInWindow.height <= 0 { return 0.0 }

        let originalArea = self.bounds.width * self.bounds.height
        guard originalArea > 0 else { return 0.0 }

        let finalVisibleArea = visibleRectInWindow.width * visibleRectInWindow.height
        let percentage = finalVisibleArea / originalArea

        return max(0.0, min(1.0, percentage))
    }
    
    func findSuperview<T: UIView>(ofType type: T.Type) -> T? {
        var currentView = self.superview
        while let view = currentView {
            if let typedView = view as? T {
                return typedView
            }
            currentView = view.superview
        }
        return nil
    }
}

// MARK: - Protocols
@MainActor
protocol TargetImageViewContainer {
    var targetImageView: UIImageView? { get }
}

@MainActor
protocol VisibilityAwareCollectionViewDelegate: AnyObject {
    func collectionView(_ collectionView: UICollectionView,
                        didUpdateVisibilityPercentage percentage: CGFloat,
                        forImageViewAt indexPath: IndexPath,
                        inCell cell: UICollectionViewCell)
}


// MARK: - ImageCell
@MainActor
class ImageCell: UICollectionViewCell, TargetImageViewContainer {
    let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    var targetImageView: UIImageView? {
        return imageView
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        imageView.backgroundColor = .clear
    }
}


// MARK: - VisibilityMonitor
@MainActor
class VisibilityMonitor {

    private weak var scrollView: UIScrollView?
    private weak var delegate: VisibilityAwareCollectionViewDelegate?

    nonisolated(unsafe) private var visibilityTimer: Timer?
    private let timerInterval: TimeInterval
    nonisolated(unsafe) private var isActive: Bool = false
    
    private var lastReportedPercentages: [IndexPath: CGFloat] = [:]
    private weak var cachedWindow: UIWindow?
    private var cachedSafeAreaAwareBounds: CGRect = .zero

    deinit {
        let timerToInvalidateOnDeinit = visibilityTimer
        let deinitWork = {
            timerToInvalidateOnDeinit?.invalidate()
            NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
            NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
        }
        if Thread.isMainThread {
            deinitWork()
        } else {
            DispatchQueue.main.async(execute: deinitWork)
        }
        visibilityTimer = nil
    }
    
    init(scrollView: UIScrollView, delegate: VisibilityAwareCollectionViewDelegate, timerInterval: TimeInterval = 0.2) {
        self.scrollView = scrollView
        self.delegate = delegate
        self.timerInterval = timerInterval
    }

    func startMonitoring() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if self.isActive && self.visibilityTimer?.isValid == true {
                return
            }
            
            self.isActive = true
            self.visibilityTimer?.invalidate()
            self.visibilityTimer = nil
            self.lastReportedPercentages.removeAll()
            self.cachedWindow = nil
            self.startNewTimerAndObservers()
        }
    }

    func stopMonitoring() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.isActive = false
            self.visibilityTimer?.invalidate()
            self.visibilityTimer = nil
            self.removeNotificationObserversInternal()
            self.lastReportedPercentages.removeAll()
            self.cachedWindow = nil
        }
    }
    
    private func removeNotificationObserversInternal() {
        assert(Thread.isMainThread, "removeNotificationObserversInternal must be called on the main thread")
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    private func startNewTimerAndObservers() {
        assert(Thread.isMainThread, "startNewTimerAndObservers must be called on the main thread")

        guard isActive, let scrollView = self.scrollView, scrollView.window != nil, scrollView.superview != nil else {
            self.visibilityTimer?.invalidate()
            self.visibilityTimer = nil
            self.removeNotificationObserversInternal()
            return
        }

        if self.visibilityTimer?.isValid == true {
             self.visibilityTimer?.invalidate()
        }
        
        removeNotificationObserversInternal()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(appDidEnterBackground),
                                               name: UIApplication.didEnterBackgroundNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(appWillEnterForeground),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)

        let newTimer = Timer(timeInterval: timerInterval,
                             target: self,
                             selector: #selector(performVisibilityChecks),
                             userInfo: nil,
                             repeats: true)
        self.visibilityTimer = newTimer
        RunLoop.current.add(newTimer, forMode: .common)
        
        DispatchQueue.main.async { [weak self] in
            self?.performVisibilityChecks()
        }
    }

    @objc private func appDidEnterBackground() {
        if self.isActive {
            self.visibilityTimer?.invalidate()
            self.visibilityTimer = nil
            self.removeNotificationObserversInternal()
        }
    }

    @objc private func appWillEnterForeground() {
        if self.isActive {
            self.visibilityTimer?.invalidate()
            self.visibilityTimer = nil
            self.startNewTimerAndObservers()
        }
    }

    @objc func performVisibilityChecks() {
        guard self.isActive,
              let currentTimerInstance = self.visibilityTimer,
              currentTimerInstance.isValid
        else {
            return
        }
        
        guard let strongScrollView = self.scrollView,
              let window = strongScrollView.window,
              strongScrollView.superview != nil
        else {
            self.cachedWindow = nil
            return
        }

        if self.cachedWindow !== window || self.cachedSafeAreaAwareBounds == .zero {
            self.cachedWindow = window
            self.cachedSafeAreaAwareBounds = window.bounds.inset(by: window.safeAreaInsets)
        }
        let currentCachedWindow = self.cachedWindow
        let currentSafeAreaAwareBounds = self.cachedSafeAreaAwareBounds
        
        switch strongScrollView {
        case let collectionView as UICollectionView:
            let cellsToCheck = collectionView.visibleCells
            for cell in cellsToCheck {
                guard self.isActive, self.visibilityTimer?.isValid == true else {
                    break
                }
                
                guard let indexPath = collectionView.indexPath(for: cell) else { continue }

                if !cell.isActuallyVisibleInWindowHierarchy(consideringOcclusion: true, inContextOf: currentCachedWindow) {
                    let previousPercentage = self.lastReportedPercentages[indexPath] ?? -1.0
                    if previousPercentage != 0.0 {
                        self.delegate?.collectionView(collectionView,
                                                 didUpdateVisibilityPercentage: 0.0,
                                                 forImageViewAt: indexPath,
                                                 inCell: cell)
                        self.lastReportedPercentages[indexPath] = 0.0
                    }
                    continue
                }

                if let targetContainer = cell as? TargetImageViewContainer,
                   let imageViewToTrack = targetContainer.targetImageView,
                   let validWindow = currentCachedWindow { // Ensure window is valid
                    
                    guard self.isActive, self.visibilityTimer?.isValid == true else { break }
                    
                    let percentage = imageViewToTrack.calculateVisiblePercentage(
                        inContextOf: validWindow,
                        safeAreaAwareBounds: currentSafeAreaAwareBounds
                    )
                    
                    let previousPercentage = self.lastReportedPercentages[indexPath] ?? -1.0
                    if abs(percentage - previousPercentage) > 0.05 ||
                       (percentage == 0.0 && previousPercentage != 0.0) ||
                       (percentage == 1.0 && previousPercentage != 1.0) ||
                       (previousPercentage == -1.0 && percentage > 0.0)
                    {
                        if let strongDelegate = self.delegate, self.scrollView != nil {
                            strongDelegate.collectionView(collectionView,
                                                     didUpdateVisibilityPercentage: percentage,
                                                     forImageViewAt: indexPath,
                                                     inCell: cell)
                        }
                        self.lastReportedPercentages[indexPath] = percentage
                    }
                }
            }
        default:
            break
        }
    }
}
