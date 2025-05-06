import UIKit

@MainActor
final class VisibilityMonitor {

    static let shared = VisibilityMonitor()

    private struct TrackingInfo {
        weak var view: UIView?               // The target view to calculate visibility for
        weak var parentCell: UIView?         // The UITableViewCell or UICollectionViewCell hosting the view
        weak var parentScrollView: UIScrollView? // The UITableView or UICollectionView containing the cell
        let updateHandler: (CGFloat) -> Void
    }

    private var trackedItems = [AnyHashable: TrackingInfo]()
    private var timer: Timer?
    private let checkInterval: TimeInterval = 0.2 // e.g., 200ms

    private init() {}

    func register(
        view: UIView,
        parentCell: UIView,
        parentScrollView: UIScrollView?,
        identifier: AnyHashable,
        updateHandler: @escaping (CGFloat) -> Void
    ) {
        trackedItems[identifier] = TrackingInfo(
            view: view,
            parentCell: parentCell,
            parentScrollView: parentScrollView,
            updateHandler: updateHandler
        )
        if timer == nil {
            startTimer()
        }
    }

    func unregister(identifier: AnyHashable) {
       if trackedItems.removeValue(forKey: identifier) != nil {
           if trackedItems.isEmpty {
               stopTimer()
           }
       }
    }

    private func startTimer() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(
            timeInterval: checkInterval,
            target: self,
            selector: #selector(timerTick),
            userInfo: nil,
            repeats: true
        )
        Task { // Perform an initial check
             await performVisibilityCheck()
         }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    @objc private func timerTick() {
       Task {
            await performVisibilityCheck()
       }
    }

    @MainActor
    private func performVisibilityCheck() async {
       guard !trackedItems.isEmpty else { return }

       let itemsToCheck = trackedItems // Iterate on a copy if modification occurs during iteration
       var resultsToNotify = [AnyHashable: CGFloat]()

       for (id, info) in itemsToCheck {
            guard let targetView = info.view, let hostingCell = info.parentCell else {
                resultsToNotify[id] = 0.0 // View or cell gone, ensure handler gets 0
                continue
            }

            var isParentCellEffectivelyVisible = true // Assume visible

            // Optimization: Check if the hosting cell is among the *visible* cells of its parent scroll view
            if let tableView = info.parentScrollView as? UITableView {
                if !tableView.visibleCells.contains(where: { $0 === hostingCell }) {
                    isParentCellEffectivelyVisible = false
                }
            } else if let collectionView = info.parentScrollView as? UICollectionView {
                if !collectionView.visibleCells.contains(where: { $0 === hostingCell }) {
                    isParentCellEffectivelyVisible = false
                }
            } else {
                // Not a UITableView or UICollectionView, or no parentScrollView.
                // Fallback to just checking if the target view is in a window.
                if targetView.window == nil {
                     isParentCellEffectivelyVisible = false
                }
            }


            if !isParentCellEffectivelyVisible {
                resultsToNotify[id] = 0.0 // If parent cell isn't visible, the view inside isn't either
            } else {
                // Parent cell is visible (or check is not applicable), proceed with geometry calculation
                // Final check for window, in case parentScrollView checks didn't cover it
                if targetView.window == nil {
                    resultsToNotify[id] = 0.0
                } else {
                    resultsToNotify[id] = targetView.calculateVisiblePercentage()
                }
            }
        }

         for (id, percentage) in resultsToNotify {
            if let info = trackedItems[id] { // Re-fetch in case it was unregistered during awaits
                 info.updateHandler(percentage)
             }
        }

        // Clean up items where the view or parentCell has been deallocated
        trackedItems = trackedItems.filter { $1.view != nil && $1.parentCell != nil }

        if trackedItems.isEmpty && timer != nil {
            stopTimer()
        }
    }
}

extension UIView {
   func calculateVisiblePercentage() -> CGFloat {
       guard !self.isHidden, self.alpha > 0, self.superview != nil, let window = self.window else {
           return 0.0
       }

       let frameInWindow = self.convert(self.bounds, to: window)
       let windowBounds = window.bounds
       var visibleRectInWindow = frameInWindow.intersection(windowBounds)

       if visibleRectInWindow.isNull || visibleRectInWindow.width <= 0 || visibleRectInWindow.height <= 0 {
           return 0.0
       }

       var currentSuperview = self.superview
       while let superview = currentSuperview, superview != window {
            if superview.clipsToBounds {
                 let superviewBoundsInWindow = superview.convert(superview.bounds, to: window)
                visibleRectInWindow = visibleRectInWindow.intersection(superviewBoundsInWindow)
                if visibleRectInWindow.isNull || visibleRectInWindow.width <= 0 || visibleRectInWindow.height <= 0 {
                    return 0.0
                }
            }
            currentSuperview = superview.superview
       }

       let originalArea = self.bounds.width * self.bounds.height
       guard originalArea > 0 else { return 0.0 }

       let visibleArea = visibleRectInWindow.width * visibleRectInWindow.height
       return max(0.0, min(1.0, visibleArea / originalArea))
   }
}

@MainActor
protocol VisibilityTrackableCell: UIView {
    var trackableViewForVisibility: UIView { get }
    var visibilityTrackingIdentifier: AnyHashable? { get set }
    func visibilityDidChange(percentage: CGFloat)

    // Default implemented methods
    func registerForVisibilityTrackingIfNeeded()
    func unregisterFromVisibilityTracking()
    func performPrepareForReuseTrackingCleanup()
    func performDidMoveToWindowTrackingCheck(window: UIWindow?)
}

extension VisibilityTrackableCell {

    // Helper to find the parent UITableView or UICollectionView
    private func findParentTrackableScrollView() -> UIScrollView? {
        var responder: UIResponder? = self
        while let currentResponder = responder {
            if let tableView = currentResponder as? UITableView {
                return tableView
            }
            if let collectionView = currentResponder as? UICollectionView {
                return collectionView
            }
            responder = currentResponder.next
        }
        return nil
    }

    func registerForVisibilityTrackingIfNeeded() {
        guard let id = visibilityTrackingIdentifier, self.window != nil else {
            return
        }
        let targetView = self.trackableViewForVisibility
        let parentScrollView = self.findParentTrackableScrollView()

        VisibilityMonitor.shared.register(
            view: targetView,
            parentCell: self, // 'self' is the VisibilityTrackableCell instance
            parentScrollView: parentScrollView,
            identifier: id
        ) { [weak self] percentage in
            self?.visibilityDidChange(percentage: percentage)
        }
    }

    func unregisterFromVisibilityTracking() {
        guard let id = visibilityTrackingIdentifier else { return }
        VisibilityMonitor.shared.unregister(identifier: id)
    }

    func performPrepareForReuseTrackingCleanup() {
        unregisterFromVisibilityTracking()
        self.visibilityTrackingIdentifier = nil
    }

    func performDidMoveToWindowTrackingCheck(window: UIWindow?) {
        if window != nil {
            registerForVisibilityTrackingIfNeeded()
        } else {
            unregisterFromVisibilityTracking()
        }
    }
}

// Example UITableViewCell
class MyTrackableTableCell: UITableViewCell, VisibilityTrackableCell {

    var trackableViewForVisibility: UIView {
        return self.specificView
    }
    var visibilityTrackingIdentifier: AnyHashable?

    let specificView: UIView = { /* ... setup ... */
        let view = UIView()
        view.backgroundColor = .systemIndigo
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(specificView)
        NSLayoutConstraint.activate([ // Basic constraints
            specificView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            specificView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            specificView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5),
            specificView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configureCell(dataId: String) {
        self.visibilityTrackingIdentifier = dataId
        visibilityDidChange(percentage: 0) // Reset visual state
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        performPrepareForReuseTrackingCleanup()
    }
    override func didMoveToWindow() {
        super.didMoveToWindow()
        performDidMoveToWindowTrackingCheck(window: self.window)
    }

    @MainActor
    func visibilityDidChange(percentage: CGFloat) {
        // Update cell UI based on percentage
        self.specificView.alpha = max(0.1, percentage) // Example update
        self.specificView.layer.borderColor = percentage > 0.5 ? UIColor.green.cgColor : UIColor.clear.cgColor
        self.specificView.layer.borderWidth = percentage > 0.5 ? 2.0 : 0.0
    }
}

// Example UICollectionViewCell (structure is very similar to UITableViewCell example)
class MyTrackableCollectionCell: UICollectionViewCell, VisibilityTrackableCell {
    var trackableViewForVisibility: UIView { return self.mainContent }
    var visibilityTrackingIdentifier: AnyHashable?
    let mainContent: UIView = { /* ... setup ... */
        let view = UIView()
        view.backgroundColor = .systemOrange
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(mainContent)
        NSLayoutConstraint.activate([ // Basic constraints
            mainContent.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            mainContent.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            mainContent.topAnchor.constraint(equalTo: contentView.topAnchor),
            mainContent.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configureCell(contentId: String) {
        self.visibilityTrackingIdentifier = contentId
        visibilityDidChange(percentage: 0) // Reset visual state
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        performPrepareForReuseTrackingCleanup()
    }
    override func didMoveToWindow() {
        super.didMoveToWindow()
        performDidMoveToWindowTrackingCheck(window: self.window)
    }

    @MainActor
    func visibilityDidChange(percentage: CGFloat) {
        self.mainContent.transform = percentage > 0.7 ? CGAffineTransform(scaleX: 1.05, y: 1.05) : .identity
        self.mainContent.layer.shadowOpacity = percentage > 0.3 ? 0.3 : 0.0
        self.mainContent.layer.shadowRadius = percentage > 0.3 ? 5 : 0
    }
}
