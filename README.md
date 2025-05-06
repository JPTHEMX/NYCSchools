import UIKit

@MainActor
protocol VisibilityMonitoring {
    func register(
        cell: VisibilityTrackableCell,
        identifier: AnyHashable,
        updateHandler: @escaping (CGFloat) -> Void
    )
    func unregister(identifier: AnyHashable)
}

@MainActor
final class VisibilityMonitor: VisibilityMonitoring {

    static let shared: VisibilityMonitoring = VisibilityMonitor()

    private struct TrackingInfo {
        weak var view: UIView?
        weak var trackingCell: UIView?
        weak var scrollView: UIScrollView?
        let updateHandler: (CGFloat) -> Void
    }

    private var trackedItems = [AnyHashable: TrackingInfo]()
    private var timer: Timer?
    private let checkInterval: TimeInterval = 0.2

    private init() { }

    func register(
        cell: VisibilityTrackableCell,
        identifier: AnyHashable,
        updateHandler: @escaping (CGFloat) -> Void
    ) {
        trackedItems[identifier] = TrackingInfo(
            view: cell.trackableViewForVisibility,
            trackingCell: cell,
            scrollView: cell.owningScrollViewForVisibilityCheck,
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
        Task {
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

    private func performVisibilityCheck() async {
       guard !trackedItems.isEmpty else { return }

       let itemsToCheck = trackedItems
       var results = [AnyHashable: CGFloat]()

       for (id, info) in itemsToCheck {
            guard let viewToTrack = info.view, let trackingCellAsView = info.trackingCell else {
                 continue
            }

            var isPotentiallyVisibleByScrollView = true
            if let scrollView = info.scrollView {
                if let tableView = scrollView as? UITableView, let cellInstance = trackingCellAsView as? UITableViewCell {
                    if !tableView.visibleCells.contains(cellInstance) {
                        isPotentiallyVisibleByScrollView = false
                    }
                } else if let collectionView = scrollView as? UICollectionView, let cellInstance = trackingCellAsView as? UICollectionViewCell {
                    if !collectionView.visibleCells.contains(cellInstance) {
                        isPotentiallyVisibleByScrollView = false
                    }
                }
            }

            if !isPotentiallyVisibleByScrollView || viewToTrack.window == nil {
                 results[id] = 0.0
             } else {
                results[id] = viewToTrack.calculateVisiblePercentage()
            }
        }

         for (id, percentage) in results {
            if let currentInfo = trackedItems[id] {
                 currentInfo.updateHandler(percentage)
             }
        }

        trackedItems = trackedItems.filter { $1.view != nil && $1.trackingCell != nil }

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
    var owningScrollViewForVisibilityCheck: UIScrollView? { get }

    func visibilityDidChange(percentage: CGFloat)
    func registerForVisibilityTrackingIfNeeded()
    func unregisterFromVisibilityTracking()
    func performPrepareForReuseTrackingCleanup()
    func performDidMoveToWindowTrackingCheck(window: UIWindow?)
}

extension VisibilityTrackableCell {

    var owningScrollViewForVisibilityCheck: UIScrollView? {
        var parent = self.superview
        while parent != nil {
            if let scrollView = parent as? UITableView {
                return scrollView
            }
            if let scrollView = parent as? UICollectionView {
                return scrollView
            }
            parent = parent?.superview
        }
        return nil
    }

    func registerForVisibilityTrackingIfNeeded() {
        guard let id = visibilityTrackingIdentifier, self.window != nil else {
            return
        }
        VisibilityMonitor.shared.register(cell: self, identifier: id) { [weak self] percentage in
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

class MyTrackableTableCell: UITableViewCell, VisibilityTrackableCell {

    var trackableViewForVisibility: UIView {
        return self.specificView
    }

    var visibilityTrackingIdentifier: AnyHashable?

    let specificView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemTeal
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 5
        view.layer.borderWidth = 0
        view.clipsToBounds = true
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupInternalView()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupInternalView() {
        contentView.addSubview(specificView)
        NSLayoutConstraint.activate([
            specificView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            specificView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            specificView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5),
            specificView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5),
            specificView.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    func configureCell(dataId: String) {
        self.visibilityTrackingIdentifier = dataId
        visibilityDidChange(percentage: 0)
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
        let alpha = max(0.2, CGFloat(percentage))
        let borderColor: UIColor = percentage > 0.5 ? .red : (percentage > 0 ? .yellow : .clear)
        let borderWidth: CGFloat = percentage > 0.5 ? 2.0 : (percentage > 0 ? 1.0 : 0.0)

        UIView.animate(withDuration: 0.15) {
             self.specificView.alpha = alpha
             self.specificView.layer.borderColor = borderColor.cgColor
             self.specificView.layer.borderWidth = borderWidth
        }
    }
}

class MyTrackableCollectionCell: UICollectionViewCell, VisibilityTrackableCell {

    var trackableViewForVisibility: UIView { return self.mainImageView }

    var visibilityTrackingIdentifier: AnyHashable?

    let mainImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.layer.borderWidth = 0
        iv.backgroundColor = .lightGray
        return iv
    }()

     override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(mainImageView)
        NSLayoutConstraint.activate([
            mainImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            mainImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            mainImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            mainImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configureCell(imageId: Int) {
        self.visibilityTrackingIdentifier = imageId
        visibilityDidChange(percentage: 0)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        performPrepareForReuseTrackingCleanup()
        mainImageView.image = nil
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        performDidMoveToWindowTrackingCheck(window: self.window)
    }

    @MainActor
    func visibilityDidChange(percentage: CGFloat) {
        let scale: CGFloat = 0.8 + (0.2 * percentage)
        mainImageView.layer.borderColor = percentage > 0.6 ? UIColor.blue.cgColor : UIColor.clear.cgColor
        mainImageView.layer.borderWidth = percentage > 0.6 ? 3.0 : 0.0

        UIView.animate(withDuration: 0.1) {
            self.mainImageView.transform = CGAffineTransform(scaleX: scale, y: scale)
        }
    }
}
