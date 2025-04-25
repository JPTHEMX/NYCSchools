import UIKit

// MARK: - Data Structure

struct CellData {
    let size: CGSize
    let color: UIColor
}

// MARK: - Header View

@MainActor
class MyHeaderView: UICollectionReusableView {
    static let identifier = "MyHeaderView"

    lazy var textField: UITextField = {
        let field = UITextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.placeholder = "Enter text here..."
        field.borderStyle = .roundedRect
        field.backgroundColor = .white
        // Initially hidden, ViewController will manage visibility based on section
        field.isHidden = true
        field.accessibilityIdentifier = "StickyHeaderTextField"
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.returnKeyType = .done
        field.addTarget(self, action: #selector(textFieldReturnPressed), for: .primaryActionTriggered)
        return field
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        addSubview(textField)
        clipsToBounds = true // Important for sticky behavior visuals
        setupConstraints()
        // Default background, ViewController might override
        backgroundColor = .systemGray5
    }

    func setupConstraints() {
         // Defensive removal of existing constraints for the text field
         self.constraints.filter { $0.firstItem === textField || $0.secondItem === textField }.forEach { removeConstraint($0) }
         NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 15),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -15),
            textField.centerYAnchor.constraint(equalTo: centerYAnchor),
            textField.heightAnchor.constraint(equalToConstant: 34) // Standard text field height
         ])
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        // Reset state when reused
        textField.isHidden = true
        textField.text = nil
        // Reset background to default in case it was changed
        backgroundColor = .systemGray5
    }

    @objc func textFieldReturnPressed() {
        textField.resignFirstResponder() // Dismiss keyboard on return key press
    }
}

// MARK: - Sticky Header Layout

@MainActor
class StickyHeaderFlowLayout: UICollectionViewFlowLayout {
    var stickyHeaderSection: Int = 0
    let stickyHeaderZIndex: Int = 1000
    let standardHeaderZIndex: Int = 100

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        // 1. Obtener atributos base de super
        guard let superAttributes = super.layoutAttributesForElements(in: rect),
              let collectionView = self.collectionView else { return nil }

        // 2. Crear copias mutables
        var mutableAttributes = superAttributes.compactMap { $0.copy() as? UICollectionViewLayoutAttributes }

        let contentInsetTop = collectionView.adjustedContentInset.top
        let effectiveOffsetY = collectionView.contentOffset.y + contentInsetTop
        let stickyHeaderIndexPath = IndexPath(item: 0, section: stickyHeaderSection)

        var stickyHeaderAttrs: UICollectionViewLayoutAttributes?
        var needsToAddStickyHeader = false // Flag

        // 3. Iterar UNA VEZ para encontrar/modificar la cabecera pegajosa y establecer zIndex de otras
        for attributes in mutableAttributes {
            if attributes.representedElementKind == UICollectionView.elementKindSectionHeader {
                if attributes.indexPath == stickyHeaderIndexPath {
                    // --- Encontramos la CABECERA PEGAJOSA en el conjunto inicial ---
                    stickyHeaderAttrs = attributes // Guardamos referencia para posible uso posterior

                    // Aplicar lógica pegajosa DIRECTAMENTE al atributo en el array
                    let originalStickyHeaderY = super.layoutAttributesForSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, at: stickyHeaderIndexPath)?.frame.origin.y ?? attributes.frame.origin.y
                    let stickyY = max(effectiveOffsetY, originalStickyHeaderY)

                    attributes.frame.origin.y = stickyY
                    attributes.zIndex = stickyHeaderZIndex
                    // --- Fin lógica pegajosa ---

                } else {
                    // Es una cabecera estándar
                    attributes.zIndex = standardHeaderZIndex
                }
            }
            // No necesitamos modificar celdas aquí
        }

        // 4. Si la cabecera pegajosa NO estaba en el conjunto inicial (fuera de 'rect')
        if stickyHeaderAttrs == nil {
            // Intenta obtenerla explícitamente de 'super'
            if let fetchedStickyAttrs = super.layoutAttributesForSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, at: stickyHeaderIndexPath)?.copy() as? UICollectionViewLayoutAttributes {

                // --- Aplicar lógica pegajosa ---
                let originalStickyHeaderY = super.layoutAttributesForSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, at: stickyHeaderIndexPath)?.frame.origin.y ?? fetchedStickyAttrs.frame.origin.y
                let stickyY = max(effectiveOffsetY, originalStickyHeaderY)
                fetchedStickyAttrs.frame.origin.y = stickyY
                fetchedStickyAttrs.zIndex = stickyHeaderZIndex
                 // --- Fin lógica pegajosa ---

                // Si debe ser visible en la 'rect' actual, márcala para añadirla
                if fetchedStickyAttrs.frame.intersects(rect) {
                    stickyHeaderAttrs = fetchedStickyAttrs // Guarda los atributos calculados
                    needsToAddStickyHeader = true
                }
            }
        }

        // 5. Añadir la cabecera pegajosa al array si fue necesario y no está ya
        if needsToAddStickyHeader, let attrsToAdd = stickyHeaderAttrs {
             // Comprobación extra para evitar duplicados
             if !mutableAttributes.contains(where: { $0.indexPath == attrsToAdd.indexPath && $0.representedElementKind == attrsToAdd.representedElementKind }) {
                 mutableAttributes.append(attrsToAdd)
             }
        }

        // --- NO HAY BUCLE deltaY ---

        // 6. Devolver los atributos modificados
        return mutableAttributes
    }

    // shouldInvalidateLayout sigue igual (importante)
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        let oldBounds = collectionView?.bounds ?? .zero
        return newBounds.origin.y != oldBounds.origin.y || newBounds.size != oldBounds.size
    }

    // layoutAttributesForSupplementaryView sigue igual (maneja un solo elemento)
    override func layoutAttributesForSupplementaryView(ofKind elementKind: String, at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard let attributes = super.layoutAttributesForSupplementaryView(ofKind: elementKind, at: indexPath)?.copy() as? UICollectionViewLayoutAttributes else { return nil }

        if elementKind == UICollectionView.elementKindSectionHeader {
            if indexPath.section == stickyHeaderSection {
                guard let collectionView = self.collectionView else { return attributes }
                let contentInsetTop = collectionView.adjustedContentInset.top
                let effectiveOffsetY = collectionView.contentOffset.y + contentInsetTop
                let originalY = super.layoutAttributesForSupplementaryView(ofKind: elementKind, at: indexPath)?.frame.origin.y ?? attributes.frame.origin.y
                attributes.frame.origin.y = max(effectiveOffsetY, originalY)
                attributes.zIndex = stickyHeaderZIndex
            } else {
                attributes.zIndex = standardHeaderZIndex
            }
        }
        return attributes
    }
}

// MARK: - Keyboard Handling Protocol

@MainActor
protocol KeyboardHandling: UIViewController {
    // The scroll view to adjust (e.g., UICollectionView, UITableView)
    var scrollableViewForKeyboardAdjustment: UIScrollView? { get }
    // Stores the original bottom inset before keyboard adjustment
    var originalScrollViewBottomInset: CGFloat { get set }
    // Flag to prevent concurrent adjustments
    var isAdjustingViewForKeyboard: Bool { get set }

    // Helper methods to get view/environment info
    func getKeyboardHandlingSafeAreaInsets() -> UIEdgeInsets
    func getKeyboardHandlingViewBounds() -> CGRect
    func convertKeyboardFrameToViewCoordinates(_ frame: CGRect) -> CGRect
    // Must be implemented by conforming class to identify the focused element
    func frameOfFocusedElementInView() -> CGRect?
    // Core logic for handling keyboard show/hide notifications
    func handleKeyboardChange_KBHandling(notification: Notification, isShowing: Bool)
}

extension KeyboardHandling {
    // Default implementations for helper methods
    func getKeyboardHandlingSafeAreaInsets() -> UIEdgeInsets {
        return self.view.safeAreaInsets
    }

    func getKeyboardHandlingViewBounds() -> CGRect {
        return self.view.bounds
    }

    func convertKeyboardFrameToViewCoordinates(_ frame: CGRect) -> CGRect {
        guard let window = self.view.window else { return frame }
        return self.view.convert(frame, from: window)
    }

    // Default implementation - conforming class *must* override if needed
    func frameOfFocusedElementInView() -> CGRect? { return nil }

    // Default implementation for the main keyboard handling logic
    func handleKeyboardChange_KBHandling(notification: Notification, isShowing: Bool) {
        // Prevent re-entrancy
        guard !self.isAdjustingViewForKeyboard else { return }
        self.isAdjustingViewForKeyboard = true

        // Ensure we have a scroll view and necessary keyboard info
        guard let scrollView = self.scrollableViewForKeyboardAdjustment,
              let userInfo = notification.userInfo,
              let keyboardFrameEnd = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              keyboardFrameEnd.height > 0, // Ignore zero-height frames
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval,
              let curveValue = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int else {
            // Fallback: If hiding or info is missing, reset insets smoothly
            if !isShowing, let currentScrollView = self.scrollableViewForKeyboardAdjustment {
                 UIView.animate(withDuration: 0.25) { // Use a default duration
                     currentScrollView.contentInset.bottom = self.originalScrollViewBottomInset
                     currentScrollView.verticalScrollIndicatorInsets.bottom = self.originalScrollViewBottomInset
                 }
             }
            self.isAdjustingViewForKeyboard = false
            return
        }

        let viewBounds = getKeyboardHandlingViewBounds()
        let safeAreaInsets = getKeyboardHandlingSafeAreaInsets()
        // Calculate keyboard frame in the view controller's view coordinates
        let keyboardFrameInView = convertKeyboardFrameToViewCoordinates(keyboardFrameEnd)
        // Determine how much the keyboard overlaps the view
        let keyboardOverlap = max(0, viewBounds.maxY - keyboardFrameInView.minY)
        // Calculate the necessary bottom inset adjustment
        let currentOriginalInset = self.originalScrollViewBottomInset
        let newBottomInset = isShowing ? max(0, keyboardOverlap - safeAreaInsets.bottom) : currentOriginalInset

        var targetContentOffset = scrollView.contentOffset
        var needsOffsetAdjustment = false

        // If showing keyboard, check if the focused element needs scrolling into view
        if isShowing, let focusedElementFrameInView = self.frameOfFocusedElementInView() {
            let keyboardTopYInView = viewBounds.maxY - keyboardOverlap
            let padding: CGFloat = 10 // Desired space between focused element and keyboard
            // If the bottom of the focused element is below the keyboard top (minus padding)
            if focusedElementFrameInView.maxY > (keyboardTopYInView - padding) {
                // Calculate how much to scroll
                let scrollAmount = focusedElementFrameInView.maxY - (keyboardTopYInView - padding)
                targetContentOffset.y += scrollAmount
                needsOffsetAdjustment = true

                // Clamp the target offset within valid scroll bounds
                let contentInsetTop = scrollView.adjustedContentInset.top
                // Calculate max scroll offset considering the new bottom inset
                let maxOffsetY = max(-contentInsetTop, scrollView.contentSize.height + newBottomInset - scrollView.bounds.height)
                let minOffsetY = -contentInsetTop // Cannot scroll above the top content inset
                targetContentOffset.y = min(max(targetContentOffset.y, minOffsetY), maxOffsetY)
            }
        }

        // Prepare for animation using keyboard's curve and duration
        let animationOptions = UIView.AnimationOptions(rawValue: UInt(curveValue) << 16)
        // Check if actual changes are needed to avoid unnecessary animations
        let insetChanged = abs(scrollView.contentInset.bottom - newBottomInset) > 0.01
        let indicatorInsetChanged = abs(scrollView.verticalScrollIndicatorInsets.bottom - newBottomInset) > 0.01
        let offsetChanged = needsOffsetAdjustment && abs(scrollView.contentOffset.y - targetContentOffset.y) > 0.01

        // Only animate if something actually changed
        guard insetChanged || indicatorInsetChanged || offsetChanged else {
            self.isAdjustingViewForKeyboard = false
            return
        }

        UIView.animate(withDuration: duration, delay: 0, options: [animationOptions, .beginFromCurrentState], animations: {
            // Apply changes within the animation block
            if insetChanged { scrollView.contentInset.bottom = newBottomInset }
            if indicatorInsetChanged { scrollView.verticalScrollIndicatorInsets.bottom = newBottomInset }
            if offsetChanged { scrollView.setContentOffset(targetContentOffset, animated: false) } // Offset change within animation
        }) { _ in
            // Reset flag after animation completes
            self.isAdjustingViewForKeyboard = false
        }
    }
}


// MARK: - View Controller

@MainActor
class ViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, KeyboardHandling {

    // MARK: Properties
    private let cellIdentifier = "MyCell"
    private let numberOfSections = 10 // Total sections to generate data for
    private var sectionData: [[CellData]] = [] // Data source
    private var isInitialLayoutDone = false // Flag to generate data only once layout is stable
    private var tapGestureRecognizer: UITapGestureRecognizer?

    // IBOutlet allows connection from Storyboard, but programmatic setup is also provided
    @IBOutlet var collectionView: UICollectionView!

    // MARK: KeyboardHandling Conformance
    var scrollableViewForKeyboardAdjustment: UIScrollView? { self.collectionView }
    var originalScrollViewBottomInset: CGFloat = 0
    var isAdjustingViewForKeyboard: Bool = false

    // Provides the frame of the text field *if* it's the first responder
    func frameOfFocusedElementInView() -> CGRect? {
        guard let layout = collectionView.collectionViewLayout as? StickyHeaderFlowLayout,
              // Attempt to get the supplementary view for the sticky header section
              let headerView = collectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: layout.stickyHeaderSection)) as? MyHeaderView
        else {
            return nil // Header not found or not the correct type
        }
        // If the text field within that specific header is focused
        if headerView.textField.isFirstResponder {
             // Convert the text field's bounds to the main view's coordinate system
             return headerView.textField.convert(headerView.textField.bounds, to: self.view)
        }
        return nil // Text field is not the first responder
    }

    // MARK: Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionViewIfNeeded() // Ensure collection view exists
        setupCollectionViewDelegatesAndLayout() // Configure layout, delegates, registration
        setupKeyboardDismissTapGesture() // Add tap-to-dismiss keyboard gesture
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // These actions depend on the view having its final bounds
        saveOriginalInsetsIfNeeded()    // Store initial bottom inset
        generateDataAndReloadIfNeeded() // Generate data once layout is known
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        registerForKeyboardNotifications() // Start listening for keyboard events
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Clean up gesture recognizer when view disappears
        removeKeyboardDismissTapGesture()
        // Consider unregistering keyboard notifications here too if appropriate
        // NotificationCenter.default.removeObserver(self) // Simpler cleanup in deinit
    }

    deinit {
        // Essential cleanup to prevent memory leaks
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: Setup Methods
    private func setupCollectionViewIfNeeded() {
        // If collectionView is nil (not connected via Storyboard), create it programmatically
        if collectionView == nil {
            setupCollectionViewProgrammatically()
        }
        // Ensure it's definitely initialized now
        guard collectionView != nil else {
            fatalError("Error: CollectionView could not be initialized.")
        }
    }

    private func setupCollectionViewProgrammatically() {
        // Use the custom sticky layout
        let layout = StickyHeaderFlowLayout()
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        // Pin collection view to safe area layout guides
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor) // Adjust if tab bar exists
        ])
        collectionView.backgroundColor = .systemGroupedBackground // Default background
    }

    private func setupCollectionViewDelegatesAndLayout() {
        // Register cell and header view classes
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: cellIdentifier)
        collectionView.register(MyHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: MyHeaderView.identifier)

        // Configure the sticky layout properties
        if let stickyLayout = collectionView.collectionViewLayout as? StickyHeaderFlowLayout {
            stickyLayout.stickyHeaderSection = 1 // Make the first section sticky
            // Set default spacing and insets
            stickyLayout.minimumInteritemSpacing = 10
            stickyLayout.minimumLineSpacing = 10
            // IMPORTANT: sectionInset here is the *default*. Delegate method can override it.
            stickyLayout.sectionInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        } else if collectionView.collectionViewLayout is UICollectionViewFlowLayout {
             // If it's a standard FlowLayout (e.g., from Storyboard without custom class set),
             // replace it with our sticky layout.
             let stickyLayout = StickyHeaderFlowLayout()
             stickyLayout.stickyHeaderSection = 1
             stickyLayout.minimumInteritemSpacing = 10
             stickyLayout.minimumLineSpacing = 10
             stickyLayout.sectionInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
             collectionView.setCollectionViewLayout(stickyLayout, animated: false)
             print("Replaced layout with StickyHeaderFlowLayout")
        }


        // Assign delegates and data source
        collectionView.delegate = self
        collectionView.dataSource = self
        // Set background and keyboard dismissal mode
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.keyboardDismissMode = .interactive // Allow dragging down keyboard
    }

    private func saveOriginalInsetsIfNeeded() {
        // Store the initial adjusted bottom content inset once the view is in the window
        guard originalScrollViewBottomInset == 0, collectionView != nil, view.window != nil else { return }
        originalScrollViewBottomInset = self.collectionView.adjustedContentInset.bottom
    }

    private func generateDataAndReloadIfNeeded() {
        // Generate data and reload only once, after initial layout
        guard !isInitialLayoutDone, collectionView != nil, view.bounds.width > 0 else { return }
        generateExampleData()
        if !sectionData.isEmpty {
            collectionView.reloadData()
        }
        isInitialLayoutDone = true
    }

    // MARK: Keyboard Notification Handling
    private func registerForKeyboardNotifications() {
        // Remove existing observers first to prevent duplicates
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        // Add new observers
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        // Determine if the keyboard is appearing or changing size significantly
        let isShowing: Bool
        if let keyboardFrameEnd = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
           let screenHeight = view.window?.screen.bounds.height {
            // Consider keyboard showing if its origin is above the bottom of the screen and has height
            isShowing = keyboardFrameEnd.origin.y < screenHeight && keyboardFrameEnd.height > 0
        } else {
            isShowing = true // Assume showing if info is missing
        }
        // Call the KeyboardHandling protocol's implementation
        handleKeyboardChange_KBHandling(notification: notification, isShowing: isShowing)
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        // Call the KeyboardHandling protocol's implementation for hiding
        handleKeyboardChange_KBHandling(notification: notification, isShowing: false)
    }

    // MARK: Keyboard Dismiss Gesture
    private func setupKeyboardDismissTapGesture() {
        // Add a tap gesture to the main view to dismiss the keyboard
        guard tapGestureRecognizer == nil else { return }
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false // Allow taps to pass through to buttons etc.
        view.addGestureRecognizer(tapGesture)
        self.tapGestureRecognizer = tapGesture
    }

    private func removeKeyboardDismissTapGesture() {
        // Clean up the gesture recognizer
        if let gesture = tapGestureRecognizer {
            view.removeGestureRecognizer(gesture)
            tapGestureRecognizer = nil
        }
    }

    @objc private func dismissKeyboard() {
        // Tell the view to resign first responder status for any subview
        view.endEditing(true)
    }

    // MARK: - UICollectionViewDataSource Methods
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return sectionData.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard section < sectionData.count else { return 0 }
        return sectionData[section].count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // Dequeue reusable cell
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath)

        // Safely access data
        guard indexPath.section < sectionData.count,
              indexPath.item < sectionData[indexPath.section].count else {
            // Fallback for invalid index path (shouldn't normally happen)
            cell.backgroundColor = .systemRed
            cell.contentView.subviews.forEach { $0.removeFromSuperview() } // Clear previous content
            return cell
        }

        let data = sectionData[indexPath.section][indexPath.item]
        cell.backgroundColor = data.color // Set background color from data
        cell.layer.cornerRadius = 4      // Basic styling

        // --- Add/Update a label inside the cell for debugging info ---
        let tagForLabel = 1001 // Unique tag to find the label later
        let label: UILabel
        if let existingLabel = cell.contentView.viewWithTag(tagForLabel) as? UILabel {
            label = existingLabel // Reuse existing label
        } else {
            // Create and configure a new label if it doesn't exist
            label = UILabel()
            label.tag = tagForLabel
            label.font = UIFont.systemFont(ofSize: 9)
            label.textAlignment = .center
            label.textColor = .darkText
            label.backgroundColor = UIColor.white.withAlphaComponent(0.7) // Semi-transparent background
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.5
            label.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(label)
            // Center the label within the cell content view
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 2),
                label.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -2),
                label.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                label.heightAnchor.constraint(lessThanOrEqualTo: cell.contentView.heightAnchor, multiplier: 0.8) // Limit height
            ])
        }
        // Update label text with section, item, and size info
        label.text = "S\(indexPath.section) I\(indexPath.item) \(Int(data.size.width))x\(Int(data.size.height))"
        // --- End label configuration ---

        return cell
     }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        // We only care about section headers
        guard kind == UICollectionView.elementKindSectionHeader else {
            // Return an empty view for other kinds (like footers if registered)
            return UICollectionReusableView()
        }

        // Dequeue our custom header view
        guard let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: MyHeaderView.identifier, for: indexPath) as? MyHeaderView else {
            fatalError("Could not dequeue MyHeaderView with identifier \(MyHeaderView.identifier)")
        }

        // Determine if this header is for the designated sticky section
        let stickySectionIndex = (collectionView.collectionViewLayout as? StickyHeaderFlowLayout)?.stickyHeaderSection ?? -1 // Default to invalid index
        let isStickySection = (indexPath.section == stickySectionIndex)

        // Configure the header based on whether it's the sticky one
        headerView.backgroundColor = isStickySection ? .systemGreen : .systemBlue.withAlphaComponent(0.8)
        headerView.textField.isHidden = !isStickySection // Show text field ONLY in sticky header

        // If a non-sticky header somehow gained focus, resign it
        if !isStickySection && headerView.textField.isFirstResponder {
             headerView.textField.resignFirstResponder()
        }

        return headerView
    }

    // MARK: - UICollectionViewDelegate Methods
     func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        // Dismiss keyboard when user starts scrolling
        view.endEditing(true)
    }

    // MARK: - UICollectionViewDelegateFlowLayout Methods
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        // Return size from data source
        guard indexPath.section < sectionData.count,
              indexPath.item < sectionData[indexPath.section].count else {
            return CGSize(width: 50, height: 50) // Default size for invalid index
        }
        return sectionData[indexPath.section][indexPath.item].size
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        let defaultHeaderHeight: CGFloat = 50.0 // Standard height for visible headers

        // Check if this section is the designated sticky one
        if let stickyLayout = collectionViewLayout as? StickyHeaderFlowLayout,
           section == stickyLayout.stickyHeaderSection {
            // *Always* return the desired size for the sticky header, even if section is empty
            return CGSize(width: collectionView.bounds.width, height: defaultHeaderHeight)
        } else {
            // For *non-sticky* sections, check if they are empty
            guard section < sectionData.count else { return .zero } // Invalid section index
            let numberOfItems = sectionData[section].count
            // Return size zero if empty, otherwise return default size
            return numberOfItems == 0 ? .zero : CGSize(width: collectionView.bounds.width, height: defaultHeaderHeight)
        }
    }

    // --- NEW/MODIFIED: Control Section Insets ---
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        // Get the default inset defined in the layout object
        let defaultInsets = (collectionViewLayout as? StickyHeaderFlowLayout)?.sectionInset ?? UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)

        // Determine if this is the sticky section
        let isStickySection = (collectionViewLayout as? StickyHeaderFlowLayout)?.stickyHeaderSection == section

        // Check if the section is empty
        let isEmpty = (section < sectionData.count && sectionData[section].isEmpty)

        // If the section is empty AND it's NOT the sticky section, collapse its insets
        if isEmpty && !isStickySection {
            return .zero // No vertical space for empty, non-sticky sections
        } else {
            // Otherwise (sticky section or non-empty section), use the default insets
            return defaultInsets
        }
    }
    // --- End Section Inset Control ---


    // MARK: - Data Generation
    private func generateExampleData() {
        // Ensure collection view exists and has a valid width
        guard let collectionView = self.collectionView, collectionView.bounds.width > 0 else {
            sectionData = []
            return
        }
        sectionData.removeAll() // Clear existing data

        // Get layout details to calculate available width for cells
        let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout
        // Use default inset from layout, but delegate method `insetForSectionAt` will override for empty sections
        let sectionInsets = layout?.sectionInset ?? UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        let contentInsets = collectionView.adjustedContentInset // Consider safe area etc.
        // Calculate width available within section padding
        let availableWidth = collectionView.bounds.width - contentInsets.left - contentInsets.right - sectionInsets.left - sectionInsets.right

        guard availableWidth > 0 else {
             print("Warning: Available width for cells is zero or negative (\(availableWidth)). Check layout and insets.")
             return
        }

        // Generate data for the specified number of sections
        for section in 0..<numberOfSections {
            var itemsInSection: [CellData] = []
            var numberOfItems = Int.random(in: 5...15) // Default random number of items

            // --- Make specific sections empty ---
            switch section {
            case 0: // Sticky section - make empty for testing
                numberOfItems = 10
            case 1: // Another empty section
                numberOfItems = 0
            case 2: // Another empty section
                numberOfItems = 0
            default: // Other sections keep the random number of items
                break
            }
            // --- End empty section logic ---

            // Generate items for the section
            for item in 0..<numberOfItems {
                var width: CGFloat
                let height: CGFloat
                let color: UIColor

                // Example logic for varied cell sizes and colors
                if section % 3 == 0 { // Tall teal cells for sections 3, 6, 9
                    width = CGFloat.random(in: 50...150)
                    height = 160
                    color = .systemTeal
                } else if item % 4 == 0 { // Small square indigo cells
                    width = 40
                    height = 40
                    color = .systemIndigo
                } else if item % 3 == 0 { // Wide orange cells
                    width = 180
                    height = 60
                    color = .systemOrange
                } else { // Default gray cells
                    width = CGFloat.random(in: 60...120)
                    height = 80
                    color = .lightGray.withAlphaComponent(0.7)
                }
                // Ensure cell width doesn't exceed available space
                width = min(width, availableWidth)

                itemsInSection.append(CellData(size: CGSize(width: width, height: height), color: color))
            }
            // Add the generated items (or empty array) to the main data source
            sectionData.append(itemsInSection)
        }
    }
}

///////////////////////

class MockCollectionViewDataSourceDelegate: NSObject, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    var numberOfSections: Int = 1
    var itemsPerSection: [Int] = [1]
    var headerSizes: [Int: CGSize] = [:]
    var sectionInsets: [Int: UIEdgeInsets] = [:]
    var defaultHeaderSize: CGSize = .zero
    var defaultSectionInset: UIEdgeInsets = .zero

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return numberOfSections
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard section < itemsPerSection.count else { return 0 }
        return itemsPerSection[section]
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        return UICollectionViewCell()
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        return UICollectionReusableView()
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return headerSizes[section] ?? defaultHeaderSize
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return sectionInsets[section] ?? defaultSectionInset
    }
}

@MainActor
class StickyHeaderFlowLayoutTests: XCTestCase {

    var layout: StickyHeaderFlowLayout!
    var collectionView: UICollectionView!
    var mockDelegate: MockCollectionViewDataSourceDelegate!

    let standardHeaderHeight: CGFloat = 50.0
    let stickySectionIndex: Int = 0

    override func setUpWithError() throws {
        try super.setUpWithError()

        layout = StickyHeaderFlowLayout()
        layout.stickyHeaderSection = stickySectionIndex
        layout.sectionInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)

        let frame = CGRect(x: 0, y: 0, width: 375, height: 600)
        collectionView = UICollectionView(frame: frame, collectionViewLayout: layout)
        collectionView.backgroundColor = .white

        mockDelegate = MockCollectionViewDataSourceDelegate()
        mockDelegate.defaultSectionInset = layout.sectionInset
        mockDelegate.defaultHeaderSize = CGSize(width: frame.width, height: standardHeaderHeight)

        collectionView.dataSource = mockDelegate
        collectionView.delegate = mockDelegate
    }

    override func tearDownWithError() throws {
        layout = nil
        collectionView = nil
        mockDelegate = nil
        try super.tearDownWithError()
    }

    private func setupMockData(sections: Int, items: [Int], stickyHeaderVisible: Bool, emptyNonStickySections: [Int] = []) {
        mockDelegate.numberOfSections = sections
        mockDelegate.itemsPerSection = items
        mockDelegate.headerSizes = [:]
        mockDelegate.sectionInsets = [:]

        for section in 0..<sections {
            let isEmpty = items[section] == 0
            let isSticky = section == stickySectionIndex

            if isSticky {
                mockDelegate.headerSizes[section] = CGSize(width: collectionView.bounds.width, height: standardHeaderHeight)
            } else if isEmpty {
                mockDelegate.headerSizes[section] = .zero
            } else {
                mockDelegate.headerSizes[section] = CGSize(width: collectionView.bounds.width, height: standardHeaderHeight)
            }

             if isEmpty && !isSticky {
                 mockDelegate.sectionInsets[section] = .zero
             } else {
                 mockDelegate.sectionInsets[section] = layout.sectionInset
             }
        }
        layout.invalidateLayout()
    }

    func testStickyHeader_Attributes_WhenNotScrolled() throws {
        setupMockData(sections: 2, items: [5, 5], stickyHeaderVisible: true)
        collectionView.contentOffset = .zero

        layout.prepare()

        let attributes = layout.layoutAttributesForSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: stickySectionIndex))

        let unwrappedAttributes = try XCTUnwrap(attributes, "Sticky header attributes should exist after prepare()")

        XCTAssertEqual(unwrappedAttributes.frame.origin.y, 0, accuracy: 0.01, "Sticky header should be at its original Y position (0)")
        XCTAssertEqual(unwrappedAttributes.zIndex, layout.stickyHeaderZIndex, "Sticky header should have high zIndex")
        XCTAssertEqual(unwrappedAttributes.frame.height, standardHeaderHeight, "Height should be defined by the delegate")
    }

    func testStickyHeader_Attributes_WhenScrolledPastOrigin() throws {
        setupMockData(sections: 2, items: [5, 5], stickyHeaderVisible: true)
        let scrollOffsetY: CGFloat = 100.0
        collectionView.contentOffset = CGPoint(x: 0, y: scrollOffsetY)
         let effectiveOffsetY = collectionView.contentOffset.y + collectionView.adjustedContentInset.top

        layout.prepare()

        let attributes = layout.layoutAttributesForSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: stickySectionIndex))

        let unwrappedAttributes = try XCTUnwrap(attributes, "Sticky header attributes should not be nil after prepare()")

        XCTAssertEqual(unwrappedAttributes.frame.origin.y, effectiveOffsetY, accuracy: 0.01, "Sticky header should stick to the scroll offset Y")
        XCTAssertEqual(unwrappedAttributes.zIndex, layout.stickyHeaderZIndex)
        XCTAssertEqual(unwrappedAttributes.frame.height, standardHeaderHeight)
    }

    func testStickyHeader_Attributes_VisibleWhenSectionIsEmpty() throws {
        setupMockData(sections: 2, items: [0, 5], stickyHeaderVisible: true)
        collectionView.contentOffset = .zero

        layout.prepare()

        let attributes = layout.layoutAttributesForSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: stickySectionIndex))

        let unwrappedAttributes = try XCTUnwrap(attributes, "Sticky header MUST exist even if its section is empty, after prepare()")

        XCTAssertEqual(unwrappedAttributes.frame.origin.y, 0, accuracy: 0.01)
        XCTAssertEqual(unwrappedAttributes.zIndex, layout.stickyHeaderZIndex)
        XCTAssertGreaterThan(unwrappedAttributes.frame.height, 0, "Sticky header height should not be zero")
        XCTAssertEqual(unwrappedAttributes.frame.height, standardHeaderHeight)
    }

    func testStandardHeader_Attributes_WhenSectionNotEmpty() throws {
        let standardSection = 1
        setupMockData(sections: 2, items: [5, 5], stickyHeaderVisible: true)
        collectionView.contentOffset = .zero

        layout.prepare()

        let attributes = layout.layoutAttributesForSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: standardSection))

        XCTAssertNotNil(attributes, "Attributes for standard header should not be nil after prepare()")

        XCTAssertEqual(attributes?.zIndex, layout.standardHeaderZIndex, "Standard header should have low zIndex")
        XCTAssertEqual(attributes?.frame.height, standardHeaderHeight)
    }

    func testStandardHeader_Attributes_WhenSectionIsEmpty() throws {
        let emptyStandardSection = 1
        setupMockData(sections: 2, items: [5, 0], stickyHeaderVisible: true, emptyNonStickySections: [emptyStandardSection])
        collectionView.contentOffset = .zero

        let sizeFromDelegate = mockDelegate.collectionView(collectionView, layout: layout, referenceSizeForHeaderInSection: emptyStandardSection)
        let attributes = layout.layoutAttributesForSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: emptyStandardSection))

        XCTAssertEqual(sizeFromDelegate, .zero, "Delegate must return zero size for empty standard section header")
        XCTAssertTrue(attributes == nil || attributes?.frame.height == 0, "Attributes for empty standard header should be nil or have zero height")
    }

     func testLayoutAttributesForElements_IncludesStickyAndStandardHeadersCorrectly() throws {
         let standardSection = 1
         setupMockData(sections: 2, items: [5, 5], stickyHeaderVisible: true)
         let scrollOffsetY: CGFloat = 100.0
         collectionView.contentOffset = CGPoint(x: 0, y: scrollOffsetY)
         let effectiveOffsetY = collectionView.contentOffset.y + collectionView.adjustedContentInset.top

         let rect = CGRect(x: 0, y: scrollOffsetY, width: collectionView.bounds.width, height: 200)

         let attributesArray = layout.layoutAttributesForElements(in: rect)
         XCTAssertNotNil(attributesArray)

         let stickyAttrs = attributesArray?.first { $0.representedElementKind == UICollectionView.elementKindSectionHeader && $0.indexPath.section == stickySectionIndex }
         XCTAssertNotNil(stickyAttrs, "Array should contain sticky header attributes")
         let unwrappedSticky = try XCTUnwrap(stickyAttrs) // Unwrap safely
         XCTAssertEqual(unwrappedSticky.frame.origin.y, effectiveOffsetY, accuracy: 0.01, "Sticky header should be stuck at Y")
         XCTAssertEqual(unwrappedSticky.zIndex, layout.stickyHeaderZIndex, "Sticky header should have high zIndex")

         let standardAttrs = attributesArray?.first { $0.representedElementKind == UICollectionView.elementKindSectionHeader && $0.indexPath.section == standardSection }
         XCTAssertNotNil(standardAttrs, "Array should contain standard header attributes")
         XCTAssertEqual(standardAttrs?.zIndex, layout.standardHeaderZIndex, "Standard header should have low zIndex")
     }

    func testLayoutAttributesForElements_AddsStickyHeaderIfNotInitiallyPresent() throws {
        setupMockData(sections: 2, items: [5, 5], stickyHeaderVisible: true)
        let scrollOffsetY: CGFloat = 200.0
        collectionView.contentOffset = CGPoint(x: 0, y: scrollOffsetY)
        let effectiveOffsetY = collectionView.contentOffset.y + collectionView.adjustedContentInset.top

        let rect = CGRect(x: 0, y: scrollOffsetY + 10, width: collectionView.bounds.width, height: 100)

        let attributesArray = layout.layoutAttributesForElements(in: rect)
        XCTAssertNotNil(attributesArray)

        let stickyAttrs = attributesArray?.first { $0.representedElementKind == UICollectionView.elementKindSectionHeader && $0.indexPath.section == stickySectionIndex }
        XCTAssertNotNil(stickyAttrs, "Sticky header should be added to attributes array even if not originally in rect")
        let unwrappedSticky = try XCTUnwrap(stickyAttrs) // Unwrap safely
        XCTAssertEqual(unwrappedSticky.frame.origin.y, effectiveOffsetY, accuracy: 0.01, "Added sticky header should be stuck at Y")
        XCTAssertEqual(unwrappedSticky.zIndex, layout.stickyHeaderZIndex, "Added sticky header should have high zIndex")
    }

    func testShouldInvalidateLayout_ReturnsTrue_OnBoundsYChange() {
        let oldBounds = CGRect(x: 0, y: 0, width: 300, height: 500)
        let newBounds = CGRect(x: 0, y: 100, width: 300, height: 500)
        collectionView.bounds = oldBounds

        XCTAssertTrue(layout.shouldInvalidateLayout(forBoundsChange: newBounds), "Should invalidate if bounds Y changes")
    }

     func testShouldInvalidateLayout_ReturnsTrue_OnBoundsSizeChange() {
        let oldBounds = CGRect(x: 0, y: 0, width: 300, height: 500)
        let newBounds = CGRect(x: 0, y: 0, width: 350, height: 500)
        collectionView.bounds = oldBounds

        XCTAssertTrue(layout.shouldInvalidateLayout(forBoundsChange: newBounds), "Should invalidate if bounds size changes")
    }

    func testShouldInvalidateLayout_ReturnsFalse_OnNoRelevantBoundsChange() {
        let oldBounds = CGRect(x: 0, y: 0, width: 300, height: 500)
        let newBounds = CGRect(x: 0, y: 0, width: 300, height: 500)
        collectionView.bounds = oldBounds

        XCTAssertFalse(layout.shouldInvalidateLayout(forBoundsChange: newBounds), "Should not invalidate if neither Y nor size changes")
    }
}

/////////////////////////////

import XCTest
@testable import testaaaaaaa // Replace with your actual module name

@MainActor
class ViewControllerLayoutTests: XCTestCase {

    var viewController: ViewController!
    var collectionView: UICollectionView!
    var layout: StickyHeaderFlowLayout!

    let defaultHeaderHeight: CGFloat = 50.0
    let collectionViewWidth: CGFloat = 375.0

    override func setUpWithError() throws {
        try super.setUpWithError()

        viewController = ViewController()

        viewController.loadViewIfNeeded()

        layout = StickyHeaderFlowLayout()
        layout.stickyHeaderSection = 0
        layout.sectionInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)

        let frame = CGRect(x: 0, y: 0, width: collectionViewWidth, height: 600)
        collectionView = UICollectionView(frame: frame, collectionViewLayout: layout)

        viewController.collectionView = collectionView
        collectionView.collectionViewLayout = layout

        collectionView.delegate = viewController
        collectionView.dataSource = viewController
    }

    override func tearDownWithError() throws {
        viewController = nil
        collectionView = nil
        layout = nil
        try super.tearDownWithError()
    }

    private func setupSectionData(_ data: [[CellData]]) {
        viewController.sectionData = data
    }

    func testReferenceSize_ForStickyHeader_WhenSectionNotEmpty() throws {
        let stickySection = 0
        layout.stickyHeaderSection = stickySection
        let testData = [
            [CellData(size: .zero, color: .red)],
            [CellData(size: .zero, color: .blue)]
        ]
        setupSectionData(testData)
        let expectedSize = CGSize(width: collectionViewWidth, height: defaultHeaderHeight)

        let actualSize = viewController.collectionView(collectionView, layout: layout, referenceSizeForHeaderInSection: stickySection)

        XCTAssertEqual(actualSize, expectedSize, "Sticky header should always have default size when section is not empty")
    }

    func testReferenceSize_ForStickyHeader_WhenSectionIsEmpty() throws {
        let stickySection = 0
        layout.stickyHeaderSection = stickySection
        let testData = [
            [],
            [CellData(size: .zero, color: .blue)]
        ]
        setupSectionData(testData)
        let expectedSize = CGSize(width: collectionViewWidth, height: defaultHeaderHeight)

        let actualSize = viewController.collectionView(collectionView, layout: layout, referenceSizeForHeaderInSection: stickySection)

        XCTAssertEqual(actualSize, expectedSize, "Sticky header should *always* have default size, even when its section is empty")
    }

    func testReferenceSize_ForNonStickyHeader_WhenSectionNotEmpty() throws {
        let nonStickySection = 1
        layout.stickyHeaderSection = 0
        let testData = [
            [CellData(size: .zero, color: .red)],
            [CellData(size: .zero, color: .blue)]
        ]
        setupSectionData(testData)
        let expectedSize = CGSize(width: collectionViewWidth, height: defaultHeaderHeight)

        let actualSize = viewController.collectionView(collectionView, layout: layout, referenceSizeForHeaderInSection: nonStickySection)

        XCTAssertEqual(actualSize, expectedSize, "Non-sticky, non-empty header should have default size")
    }

    func testReferenceSize_ForNonStickyHeader_WhenSectionIsEmpty() throws {
        let nonStickyEmptySection = 1
        layout.stickyHeaderSection = 0
        let testData = [
            [CellData(size: .zero, color: .red)],
            []
        ]
        setupSectionData(testData)
        let expectedSize = CGSize.zero

        let actualSize = viewController.collectionView(collectionView, layout: layout, referenceSizeForHeaderInSection: nonStickyEmptySection)

        XCTAssertEqual(actualSize, expectedSize, "Non-sticky, empty header should have zero size")
    }

    func testReferenceSize_ForInvalidSection() throws {
        let invalidSection = 5
        layout.stickyHeaderSection = 0
        let testData = [
            [CellData(size: .zero, color: .red)],
            []
        ]
        setupSectionData(testData)
        let expectedSize = CGSize.zero

        let actualSize = viewController.collectionView(collectionView, layout: layout, referenceSizeForHeaderInSection: invalidSection)

        XCTAssertEqual(actualSize, expectedSize, "Header size for invalid section should be zero")
    }
}

/////////////////////

import XCTest
@testable import testaaaaaaa // Replace with your actual module name

@MainActor
class ViewControllerDataSourceTests: XCTestCase { // Or add to ViewControllerLayoutTests

    var viewController: ViewController!
    var collectionView: UICollectionView!
    var layout: UICollectionViewFlowLayout! // Can use standard layout for this test

    let cellIdentifier = "MyCell" // Matches ViewController's identifier
    let labelTag = 1001          // Matches ViewController's label tag

    override func setUpWithError() throws {
        try super.setUpWithError()

        viewController = ViewController()
        viewController.loadViewIfNeeded()

        // Use a standard layout, StickyHeaderFlowLayout specifics aren't needed for cellForItemAt
        layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 50, height: 50) // Provide a default item size

        let frame = CGRect(x: 0, y: 0, width: 375, height: 600)
        collectionView = UICollectionView(frame: frame, collectionViewLayout: layout)

        // *** Crucial: Register the cell class ***
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: cellIdentifier)

        viewController.collectionView = collectionView
        collectionView.collectionViewLayout = layout

        collectionView.delegate = viewController
        collectionView.dataSource = viewController
    }

    override func tearDownWithError() throws {
        viewController = nil
        collectionView = nil
        layout = nil
        try super.tearDownWithError()
    }

    private func setupSectionData(_ data: [[CellData]]) {
        viewController.sectionData = data
        // Reload data is needed so the collection view knows about the new item counts
        // when dequeueReusableCell is implicitly called by cellForItemAt
        collectionView.reloadData()
    }

    // MARK: - Tests for cellForItemAt

    func testCellForItemAt_WithValidIndexPath_ConfiguresCellCorrectly() throws {
        // Arrange
        let testIndexPath = IndexPath(item: 1, section: 0)
        let expectedColor = UIColor.systemTeal
        let expectedSize = CGSize(width: 100, height: 80)
        let expectedCornerRadius: CGFloat = 4.0
        let testData = [
            [
                CellData(size: CGSize(width: 50, height: 50), color: .systemRed),
                CellData(size: expectedSize, color: expectedColor), // Data for testIndexPath
                CellData(size: CGSize(width: 60, height: 60), color: .systemBlue)
            ]
        ]
        setupSectionData(testData)
        let expectedLabelText = "S\(testIndexPath.section) I\(testIndexPath.item) \(Int(expectedSize.width))x\(Int(expectedSize.height))"

        // Act
        // Directly call the dataSource method
        let cell = viewController.collectionView(collectionView, cellForItemAt: testIndexPath)

        // Assert
        XCTAssertNotNil(cell, "Cell should not be nil")
        XCTAssertEqual(cell.backgroundColor, expectedColor, "Cell background color should match data")
        XCTAssertEqual(cell.layer.cornerRadius, expectedCornerRadius, "Cell corner radius should be set")

        // Assert Label configuration
        let label = cell.contentView.viewWithTag(labelTag) as? UILabel
        XCTAssertNotNil(label, "Label with tag \(labelTag) should exist in the cell")
        XCTAssertEqual(label?.text, expectedLabelText, "Label text should be configured correctly")
        // Optional: Check other label properties if critical
        // XCTAssertEqual(label?.font, UIFont.systemFont(ofSize: 9))
        // XCTAssertEqual(label?.textAlignment, .center)
    }

    func testCellForItemAt_WithInvalidSection_ReturnsFallbackCell() throws {
        // Arrange
        let invalidIndexPath = IndexPath(item: 0, section: 5) // Section 5 does not exist
        let testData = [
            [CellData(size: .zero, color: .red)]
        ]
        setupSectionData(testData)

        // Act
        let cell = viewController.collectionView(collectionView, cellForItemAt: invalidIndexPath)

        // Assert
        XCTAssertNotNil(cell)
        XCTAssertEqual(cell.backgroundColor, .systemRed, "Fallback cell background should be red")
        // Check if subviews were removed (label should not be present)
        let label = cell.contentView.viewWithTag(labelTag)
        XCTAssertNil(label, "Label should not be present in fallback cell")
        XCTAssertTrue(cell.contentView.subviews.isEmpty, "Fallback cell content view should be empty")
    }

    func testCellForItemAt_WithInvalidItem_ReturnsFallbackCell() throws {
        // Arrange
        let invalidIndexPath = IndexPath(item: 5, section: 0) // Item 5 does not exist in section 0
        let testData = [
            [CellData(size: .zero, color: .red)] // Only one item in section 0
        ]
        setupSectionData(testData)

        // Act
        let cell = viewController.collectionView(collectionView, cellForItemAt: invalidIndexPath)

        // Assert
        XCTAssertNotNil(cell)
        XCTAssertEqual(cell.backgroundColor, .systemRed, "Fallback cell background should be red")
        let label = cell.contentView.viewWithTag(labelTag)
        XCTAssertNil(label, "Label should not be present in fallback cell")
         XCTAssertTrue(cell.contentView.subviews.isEmpty, "Fallback cell content view should be empty")
    }

    func testCellForItemAt_LabelIsReusedAndUpdated() throws {
        // Arrange
        let indexPath1 = IndexPath(item: 0, section: 0)
        let indexPath2 = IndexPath(item: 1, section: 0) // Different item in the same section

        let size1 = CGSize(width: 10, height: 10)
        let size2 = CGSize(width: 20, height: 20)

        let testData = [
            [
                CellData(size: size1, color: .green),
                CellData(size: size2, color: .purple)
            ]
        ]
        setupSectionData(testData)

        let expectedLabelText1 = "S\(indexPath1.section) I\(indexPath1.item) \(Int(size1.width))x\(Int(size1.height))"
        let expectedLabelText2 = "S\(indexPath2.section) I\(indexPath2.item) \(Int(size2.width))x\(Int(size2.height))"

        // Act
        // 1. Get cell for the first index path
        let cell1 = viewController.collectionView(collectionView, cellForItemAt: indexPath1)
        let label1 = cell1.contentView.viewWithTag(labelTag) as? UILabel
        let initialLabelObjectIdentifier = ObjectIdentifier(label1!) // Store identity of the first label

        // 2. Simulate reuse by getting cell for the second index path.
        //    UICollectionView might reuse the same cell instance or a different one.
        //    The test focuses on the *logic within cellForItemAt* finding/updating the label.
        let cell2 = viewController.collectionView(collectionView, cellForItemAt: indexPath2)
        let label2 = cell2.contentView.viewWithTag(labelTag) as? UILabel

        // Assert
        XCTAssertNotNil(label1, "Label should exist for first cell")
        XCTAssertEqual(label1?.text, expectedLabelText1, "Label text should match data for first index path")

        XCTAssertNotNil(label2, "Label should exist for second cell (potentially reused)")
        XCTAssertEqual(label2?.text, expectedLabelText2, "Label text should be updated for the second index path")

        // Optional: If cell1 and cell2 happen to be the same instance (due to reuse simulation),
        // check if the label object itself is the same instance, confirming reuse logic.
        if cell1 === cell2 {
             let finalLabelObjectIdentifier = ObjectIdentifier(label2!)
             XCTAssertEqual(initialLabelObjectIdentifier, finalLabelObjectIdentifier, "Label instance should be reused if the cell instance is reused")
        }
    }
}
