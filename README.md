//
//  ViewController.swift
//  test
//
//  Created by Juan Pablo Granados Garcia on 4/8/25.
//

import UIKit
import Foundation

// MARK: - Infrastructure & Protocols

enum ImageType: Sendable {
    case hero
    case logo
    case `default`

    var timeoutInterval: TimeInterval {
        switch self { case .hero: 30.0; case .logo, .default: 60.0 }
    }
    var compressionTargetSizeBytes: Int? {
        switch self { case .hero, .default: 500_000; case .logo: nil }
    }
    var compressionMinQuality: CGFloat {
        switch self { case .hero, .default: 0.1; case .logo: 1.0 }
    }
}

struct DataValue: Sendable {
    let data: Data
    let url: URL
}

enum ImageLoadingError: Error, Sendable, Equatable {
    case badURL
    case networkError(String)
    case badServerResponse(statusCode: Int)
    case decompressionFailed
    case compressionFailed
    case cancelled
    case unknown(String)
}

let validHttpOkStatus = 200...299

protocol ImageLoading: Sendable {
    func loadImage(from url: URL, type: ImageType) async throws -> DataValue
    func cancelLoad(for url: URL) async
    func loadImage(from urlString: String?, type: ImageType) async throws -> DataValue
    func cancelLoad(for urlString: String?) async
}

extension ImageLoading {
    func loadImage(from urlString: String?, type: ImageType = .default) async throws -> DataValue {
        guard let urlString = urlString, let url = URL(string: urlString) else { throw ImageLoadingError.badURL }
        return try await loadImage(from: url, type: type)
    }

    func cancelLoad(for urlString: String?) async {
        guard let urlString = urlString, let url = URL(string: urlString) else { return }
        await cancelLoad(for: url)
    }
}

// MARK: - DataLoader (Actor)

actor DataLoader {
    // Explicitly use URLCache.shared for potential inter-module caching
    private let dataCache: URLCache = URLCache.shared
    private let session: URLSession
    // Active tasks (download + processing) keyed by URL
    private var activeProcessingTasks = [URL: Task<DataValue, Error>]()

    // Session configured to ignore its own HTTP cache, relying on our logic
    private static let configuredSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = nil // Don't use URLSession's built-in HTTP cache
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        print("DataLoader's URLSession configured to ignore HTTP cache.")
        return URLSession(configuration: configuration)
    }()

    // Standard init using the configured session
    init() {
        self.session = Self.configuredSession
        // Optional: Configure URLCache.shared limits here if needed globally
        // dataCache.memoryCapacity = 200 * 1024 * 1024 // 200MB RAM
        // dataCache.diskCapacity = 500 * 1024 * 1024 // 500MB Disk
        print("DataLoader using URLCache.shared. Mem: \(dataCache.memoryCapacity / 1024 / 1024)MB, Disk: \(dataCache.diskCapacity / 1024 / 1024)MB")
    }

    // Testable init (used in DataLoaderTests if modified)
    init(session: URLSession) {
         self.session = session
         print("DataLoader initialized with injected session.")
    }


    /// Main function for loading, processing, and caching image data.
    func load(from url: URL, type: ImageType) async throws -> DataValue {
        let cacheRequest = URLRequest(url: url) // Simple request as cache key

        // 1. Check URLCache (for processed data)
        if let cachedResponse = dataCache.cachedResponse(for: cacheRequest) {
            print("[Cache HIT (URLCache)]: \(url.lastPathComponent)")
            return DataValue(data: cachedResponse.data, url: url)
        }
        print("[Cache MISS (URLCache)]: \(url.lastPathComponent)")

        // 2. Check/Join Active Processing Task
        if let existingTask = activeProcessingTasks[url] {
            print("[Task JOIN]: \(url.lastPathComponent)")
            return try await handleExistingTask(existingTask, for: url)
        }

        // 3. Create New Task
        print("[Task NEW]: \(url.lastPathComponent)")
        let newTask = Task<DataValue, Error> {
            let networkRequest = URLRequest(url: url, timeoutInterval: type.timeoutInterval)
            print("--> Fetching \(url.lastPathComponent) (Timeout: \(type.timeoutInterval)s)")

            // A. Download Raw Data
            let (rawData, httpResponse) = try await performNetworkRequest(networkRequest)
            try Task.checkCancellation() // Check after network

            // B. Process Data (decode/compress)
            let processedData = try processImageData(rawData: rawData, type: type, url: url)
            try Task.checkCancellation() // Check after processing

            // C. Store PROCESSED data in URLCache
            let responseToCache = CachedURLResponse(response: httpResponse, data: processedData, storagePolicy: .allowed)
            self.dataCache.storeCachedResponse(responseToCache, for: cacheRequest) // Use simple request as key
            print("--> Stored processed in URLCache: \(url.lastPathComponent)")

            return DataValue(data: processedData, url: url)
        }

        activeProcessingTasks[url] = newTask

        // Await result and handle cleanup/errors
        do {
            let result = try await newTask.value
            activeProcessingTasks[url] = nil // Clear on success
            print("[Task SUCCESS]: \(url.lastPathComponent)")
            return result
        } catch {
            activeProcessingTasks[url] = nil // Clear on failure/cancellation
            print("[Task FAILED/CANCELLED] final: \(url.lastPathComponent): \(error)")
            throw mapError(error)
        }
    }

    // Helper to await an existing task
    private func handleExistingTask(_ task: Task<DataValue, Error>, for url: URL) async throws -> DataValue {
        do { return try await task.value }
        catch { activeProcessingTasks[url] = nil; throw mapError(error) } // Clean up if joined task failed
    }

    // Helper for network request logic
    private func performNetworkRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            guard validHttpOkStatus.contains(httpResponse.statusCode) else { throw ImageLoadingError.badServerResponse(statusCode: httpResponse.statusCode) }
            return (data, httpResponse)
        } catch let error as URLError where error.code == .cancelled { throw ImageLoadingError.cancelled }
          catch let error as URLError { throw error } // Return URLError directly
          catch { throw ImageLoadingError.networkError(String(describing: error)) }
    }

    // Helper for image processing logic
    private func processImageData(rawData: Data, type: ImageType, url: URL) throws -> Data {
        print("--> Processing \(url.lastPathComponent)")
        guard let image = UIImage(data: rawData) else { throw ImageLoadingError.decompressionFailed }
        guard let processedData = image.processData(type: type) else { throw ImageLoadingError.compressionFailed }
        print("--> Processed \(url.lastPathComponent) to \(processedData.count) bytes")
        return processedData
    }

    /// Cancels an active processing task for the URL.
     func cancel(url: URL) { // Method inside actor doesn't need async keyword itself
         if let task = activeProcessingTasks[url] {
             print("[Task CANCEL REQ]: \(url.lastPathComponent)")
             task.cancel()
             // Task will be removed from dict when it completes with cancellation error
         }
     }

    // Maps various errors to ImageLoadingError or preserves URLError
    private func mapError(_ error: Error) -> Error {
        // Priorizar CancellationError explícito
        if error is CancellationError {
            return ImageLoadingError.cancelled
        }
        // Mantener nuestro .cancelled si ya está mapeado
        if let imageError = error as? ImageLoadingError, imageError == .cancelled {
            return imageError
        }
        // Mapear URLError.cancelled también
        if let urlError = error as? URLError, urlError.code == .cancelled {
            return ImageLoadingError.cancelled
        }

        // Preservar otros errores específicos si ya son del tipo correcto
        if let imageError = error as? ImageLoadingError {
            return imageError
        }
        if let urlError = error as? URLError {
            return urlError
        } // Mantener otros URLErrors

        // Envolver el resto
        return ImageLoadingError.unknown(String(describing: error))
    }

    // MARK: - Test Helpers (Internal or Public)

    /// Checks if a response for the URL exists in the cache (for testing).
    func isDataCached(for url: URL) -> Bool {
        let request = URLRequest(url: url)
        return dataCache.cachedResponse(for: request) != nil
    }

    /// Stores data directly into the cache (for testing pre-population).
    /// NOTE: Use with caution, bypasses normal loading logic.
    func storeDataInCacheForTest(data: Data, for url: URL, response: HTTPURLResponse) {
         let request = URLRequest(url: url)
         let cachedResponse = CachedURLResponse(response: response, data: data)
         dataCache.storeCachedResponse(cachedResponse, for: request)
         print("[Test Helper]: Stored data directly in cache for \(url.lastPathComponent)")
    }

    /// Removes all cached responses (for testing cleanup).
    func removeAllCacheForTest() {
        dataCache.removeAllCachedResponses()
        print("[Test Helper]: Removed all cached responses.")
    }

     /// Allow resetting tasks for tests without exposing the dictionary
     func resetActiveTasksForTest() {
         activeProcessingTasks.values.forEach { $0.cancel() } // Cancel existing
         activeProcessingTasks.removeAll()
         print("[Test Helper]: Reset active tasks.")
     }
}

// MARK: - ImageLoader Facade

final class ImageLoader: ImageLoading, @unchecked Sendable {
    private let loader = DataLoader()
    static let shared = ImageLoader()
    private init() {}

    func loadImage(from url: URL, type: ImageType = .default) async throws -> DataValue {
        return try await loader.load(from: url, type: type)
    }

    func cancelLoad(for url: URL) async {
         await loader.cancel(url: url)
    }
}

// MARK: - UIImage Extension

extension UIImage {
    func processData(type: ImageType) -> Data? {
        if let targetSize = type.compressionTargetSizeBytes {
            return self.jpegDataIfExceeds(maxSizeBytes: targetSize, minCompressionQuality: type.compressionMinQuality)
        } else {
            return self.pngData()
        }
    }

    private func jpegDataIfExceeds(maxSizeBytes: Int, minCompressionQuality: CGFloat) -> Data? {
        guard var currentData = self.jpegData(compressionQuality: 1.0) else { return nil }
        if currentData.count <= maxSizeBytes { return currentData }
        var currentQuality = 0.9
        while currentQuality >= minCompressionQuality {
            guard let compressed = self.jpegData(compressionQuality: currentQuality) else { return currentData }
            if compressed.count >= currentData.count && currentQuality < 0.9 { return currentData }
            currentData = compressed
            if currentData.count <= maxSizeBytes { return currentData }
            currentQuality -= 0.1
        }
        return currentData
    }
}

// MARK: - AsyncImageView (UI Component)

@MainActor
class AsyncImageView: UIImageView {
    private let imageLoader: ImageLoading
    private var currentLoadTask: Task<Void, Error>?
    private var expectedURL: URL?

    enum LoadResult: Equatable {
        case success(url: URL, image: UIImage)
        case failure(url: URL?, error: Error)
        case cancelled(url: URL?)
        case cleared

        static func == (lhs: AsyncImageView.LoadResult, rhs: AsyncImageView.LoadResult) -> Bool {
            switch (lhs, rhs) {
            case (.success(let u1, let i1), .success(let u2, let i2)):
                return u1 == u2 && i1.pngData() == i2.pngData()
            case (.failure(let u1, let e1), .failure(let u2, let e2)):
                return u1 == u2 && String(describing: e1) == String(describing: e2)
            case (.cancelled(let u1), .cancelled(let u2)):
                return u1 == u2
            case (.cleared, .cleared):
                return true
            default:
                return false
            }
        }
    }

    init(frame: CGRect = .zero, imageLoader: ImageLoading = ImageLoader.shared) {
        self.imageLoader = imageLoader
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        self.imageLoader = ImageLoader.shared
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        clipsToBounds = true
    }

    func loadImage(
        url: URL?,
        type: ImageType,
        fallbackURL: URL? = nil,
        transition: Bool = true,
        completion: (@MainActor (LoadResult) -> Void)? = nil
    ) {
        let urlToLoad = url
        let previousExpectedURL = self.expectedURL
        self.expectedURL = urlToLoad

        if previousExpectedURL != urlToLoad {
            cancelCurrentLoad()
        } else if let img = image, let currentURL = expectedURL {
            completion?(LoadResult.success(url: currentURL, image: img))
            return
        }

        if previousExpectedURL != urlToLoad || self.image == nil {
            resetVisualState()
            if previousExpectedURL != urlToLoad {
                layer.removeAllAnimations()
            }
        }

        guard let targetURL = urlToLoad else {
            completion?(LoadResult.cleared)
            return
        }

        currentLoadTask = Task(priority: .userInitiated) { [weak self] in
            guard let self = self else {
                Task { @MainActor in completion?(LoadResult.cancelled(url: targetURL)) }
                return
            }
            
            var finalResult: Result<Data, Error>?
            var isFallbackBeingAttempted = false

            do {
                let dataValue = try await self.imageLoader.loadImage(from: targetURL, type: type)
                try await MainActor.run {
                    guard self.expectedURL == dataValue.url else {
                        throw ImageLoadingError.cancelled
                    }
                }
                try Task.checkCancellation()
                finalResult = .success(dataValue.data)
            } catch let urlError as URLError where urlError.code == .timedOut && type == .hero {
                await MainActor.run {
                    guard self.expectedURL == targetURL else {
                        finalResult = .failure(ImageLoadingError.cancelled)
                        return
                    }
                    if let fallback = fallbackURL {
                        isFallbackBeingAttempted = true
                        self.expectedURL = fallback
                        self.loadImage(
                            url: fallback,
                            type: .logo,
                            fallbackURL: nil,
                            transition: transition,
                            completion: completion
                        )
                    } else {
                        finalResult = .failure(urlError)
                    }
                }
                if isFallbackBeingAttempted { return }
            } catch is CancellationError {
                finalResult = .failure(ImageLoadingError.cancelled)
            } catch let urlError as URLError {
                finalResult = .failure(urlError)
            } catch let error as ImageLoadingError where error == .cancelled {
                finalResult = .failure(error)
            } catch {
                finalResult = .failure(error)
            }

            await MainActor.run {
                guard let result = finalResult, self.expectedURL == targetURL else { return }
                
                switch result {
                case .success(let data):
                    if let img = self.applyImageAndReturn(data, transition: transition, url: targetURL) {
                        completion?(LoadResult.success(url: targetURL, image: img))
                    } else {
                        completion?(LoadResult.failure(url: targetURL, error: ImageLoadingError.decompressionFailed))
                    }
                case .failure(let error):
                    if error is CancellationError || (error as? ImageLoadingError) == .cancelled {
                        completion?(LoadResult.cancelled(url: targetURL))
                    } else {
                        self.applyErrorState(url: targetURL)
                        completion?(LoadResult.failure(url: targetURL, error: error))
                    }
                }
            }
        }
    }

    // ✅ SOLUCIÓN: Método mejorado con actualización forzada del layout
    @discardableResult
    private func applyImageAndReturn(_ data: Data, transition: Bool, url: URL) -> UIImage? {
        guard self.expectedURL == url else { return nil }
        guard let loadedImage = UIImage(data: data) else {
            applyErrorState(url: url)
            return nil
        }
        
        // Closure para forzar actualización del layout
        let forceLayoutUpdate = { [weak self] in
            guard let self = self else { return }
            
            // Actualizar la vista actual
            self.setNeedsLayout()
            self.layoutIfNeeded()
            self.setNeedsDisplay()
            
            // Actualizar la supervista (contentView de la celda)
            self.superview?.setNeedsLayout()
            self.superview?.layoutIfNeeded()
            
            // Si está en una celda, actualizar la celda completa
            if let cell = self.findContainingCell() {
                cell.setNeedsLayout()
                cell.layoutIfNeeded()
                cell.contentView.setNeedsLayout()
                cell.contentView.layoutIfNeeded()
            }
        }
        
        if transition && self.image == nil {
            // Con transición: actualizar después de la animación
            UIView.transition(
                with: self,
                duration: 0.25,
                options: [.transitionCrossDissolve, .allowUserInteraction],
                animations: {
                    self.image = loadedImage
                },
                completion: { _ in
                    forceLayoutUpdate()
                }
            )
        } else {
            // Sin transición: actualizar inmediatamente
            self.image = loadedImage
            // Usar async para asegurar que el cambio se procese
            DispatchQueue.main.async {
                forceLayoutUpdate()
            }
        }
        
        return loadedImage
    }
    
    // Helper para encontrar la celda contenedora
    private func findContainingCell() -> UICollectionViewCell? {
        var view: UIView? = self.superview
        while view != nil {
            if let cell = view as? UICollectionViewCell {
                return cell
            }
            view = view?.superview
        }
        return nil
    }
    
    private func applyErrorState(url: URL) {
        guard self.expectedURL == url else { return }
        resetVisualState()
        // Opcionalmente mostrar imagen de error
        // self.image = UIImage(systemName: "photo.badge.exclamationmark")
        // self.tintColor = .systemGray3
    }
    
    private func resetVisualState() {
        image = nil
    }

    func cancelCurrentLoad() {
        if currentLoadTask != nil {
            let urlToCancel = self.expectedURL
            currentLoadTask?.cancel()
            currentLoadTask = nil
            if let url = urlToCancel {
                Task { await imageLoader.cancelLoad(for: url) }
            }
        }
    }
    
    func prepareForReuse() {
        let previousURL = self.expectedURL
        cancelCurrentLoad()
        if previousURL != nil {
            resetVisualState()
            layer.removeAllAnimations()
        }
        self.expectedURL = nil
    }
    
    private var logID: String {
        String(format: "%p", self)
    }
}

// MARK: - Base CollectionViewCell

class BaseOfferCollectionViewCell: UICollectionViewCell {
    static let baseReuseIdentifier = "BaseOfferCollectionViewCell"
    let heroBackgroundView = AsyncImageView()
    let logoForegroundView = AsyncImageView()
    private var configurationID: String?
    
    // ✅ Flags para rastrear cargas pendientes
    private var pendingHeroLoad = false
    private var pendingLogoLoad = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
        setupUI()
    }

    private func commonInit() {
        contentView.clipsToBounds = true
        contentView.backgroundColor = .systemBackground
        contentView.addSubview(heroBackgroundView)
        contentView.addSubview(logoForegroundView)
        heroBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        logoForegroundView.translatesAutoresizingMaskIntoConstraints = false
    }

    open func setupUI() {
        heroBackgroundView.contentMode = .scaleAspectFill
        logoForegroundView.contentMode = .scaleAspectFit
        
        NSLayoutConstraint.activate([
            heroBackgroundView.topAnchor.constraint(equalTo: contentView.topAnchor),
            heroBackgroundView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            heroBackgroundView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            heroBackgroundView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            logoForegroundView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            logoForegroundView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            logoForegroundView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.6),
            logoForegroundView.heightAnchor.constraint(lessThanOrEqualTo: contentView.heightAnchor, multiplier: 0.4),
        ])
    }

    // ✅ SOLUCIÓN: Configuración mejorada con callbacks y actualización de layout
    final func configure(with offer: Offer) {
        let heroUrlString = offer.getHeroImageURL()
        guard let logoUrlString = offer.getLogoImageURL(),
              let logoUrl = URL(string: logoUrlString) else {
            heroBackgroundView.loadImage(url: nil, type: .hero)
            logoForegroundView.loadImage(url: nil, type: .logo)
            configurationID = "INVALID_LOGO"
            return
        }
        
        let heroUrl = heroUrlString.flatMap { URL(string: $0) }
        configurationID = "\(heroUrlString ?? "nil")|\(logoUrlString)"
        
        // Marcar cargas pendientes
        pendingHeroLoad = true
        pendingLogoLoad = true
        
        // Cargar imagen hero con callback
        heroBackgroundView.loadImage(
            url: heroUrl,
            type: .hero,
            fallbackURL: logoUrl
        ) { [weak self] result in
            guard let self = self else { return }
            self.pendingHeroLoad = false
            
            if case .success = result {
                self.updateLayoutAfterImageLoad()
            }
        }
        
        // Cargar imagen logo con callback
        logoForegroundView.loadImage(
            url: logoUrl,
            type: .logo
        ) { [weak self] result in
            guard let self = self else { return }
            self.pendingLogoLoad = false
            
            if case .success = result {
                self.updateLayoutAfterImageLoad()
            }
        }
    }
    
    // ✅ Método para forzar actualización del layout después de cargar imagen
    private func updateLayoutAfterImageLoad() {
        // Ejecutar en el siguiente ciclo del run loop para asegurar que todos los cambios se apliquen
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Forzar actualización del layout de la celda
            self.setNeedsLayout()
            self.layoutIfNeeded()
            
            // Forzar actualización del contentView
            self.contentView.setNeedsLayout()
            self.contentView.layoutIfNeeded()
            
            // Forzar redibujado si es necesario
            self.contentView.setNeedsDisplay()
            
            // Si ambas imágenes han cargado, hacer una actualización final
            if !self.pendingHeroLoad && !self.pendingLogoLoad {
                self.performFinalLayoutUpdate()
            }
        }
    }
    
    // Actualización final cuando ambas imágenes están cargadas
    private func performFinalLayoutUpdate() {
        // Invalidar el layout de la collection view si es necesario
        if let collectionView = self.superview as? UICollectionView {
            // Solo invalidar si la celda es visible
            if collectionView.visibleCells.contains(self) {
                UIView.performWithoutAnimation {
                    self.setNeedsLayout()
                    self.layoutIfNeeded()
                }
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        heroBackgroundView.prepareForReuse()
        logoForegroundView.prepareForReuse()
        configurationID = nil
        pendingHeroLoad = false
        pendingLogoLoad = false
    }
    
    // Override para asegurar que el layout se actualice correctamente
    override func layoutSubviews() {
        super.layoutSubviews()
        // Asegurar que las subvistas estén correctamente posicionadas
        contentView.layoutIfNeeded()
    }
    
    private var logID: String {
        String(format: "%p", self)
    }
}

// MARK: - Example ViewController Usage

// --- Define your real Offer struct/class ---
struct Offer: Hashable {
    let id = UUID(); let name: String
    func getHeroImageURL() -> String? { return id.uuidString.first == "A" ? nil : "https://picsum.photos/seed/\(id.uuidString)_hero/600/400?blur=1" }
    func getLogoImageURL() -> String? { return "https://picsum.photos/seed/\(id.uuidString)_logo/200/100" } // Assumed non-nil
}
func generateDummyOffers(count: Int) -> [Offer] { (1...count).map { Offer(name: "Offer \($0)") } }
// --- End Offer Definition ---

// --- Optional: Subclass BaseOfferCollectionViewCell for custom layout ---
// class MyCoolOfferCell: BaseOfferCollectionViewCell {
//      static let customReuseId = "MyCoolOfferCell"
//      override func setupUI() { /* Custom Layout */ }
// }
// --- End Subclass ---

class ViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UICollectionViewDataSourcePrefetching {

    private var collectionView: UICollectionView!
    private var offers: [Offer] = []
    let cellReuseIdentifier = BaseOfferCollectionViewCell.baseReuseIdentifier // Or your subclass identifier
    let cellClassToRegister = BaseOfferCollectionViewCell.self             // Or your subclass

    override func viewDidLoad() { super.viewDidLoad(); setupCollectionView(); loadOffers() }

    func setupCollectionView() {
        let layout = UICollectionViewFlowLayout(); layout.minimumLineSpacing = 15
        layout.sectionInset = UIEdgeInsets(top: 15, left: 15, bottom: 15, right: 15)
        let padding: CGFloat = 30; let availableWidth = view.bounds.width - padding
        layout.itemSize = CGSize(width: availableWidth, height: availableWidth * 0.55)
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.dataSource = self; collectionView.delegate = self; collectionView.prefetchDataSource = self
        collectionView.register(cellClassToRegister, forCellWithReuseIdentifier: cellReuseIdentifier)
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView); NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }
    func loadOffers() { self.offers = generateDummyOffers(count: 300); self.collectionView.reloadData() }

    // MARK: - DataSource
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { offers.count }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellReuseIdentifier, for: indexPath) as? BaseOfferCollectionViewCell else { fatalError() }
        guard indexPath.item < offers.count else { return cell }
        cell.configure(with: offers[indexPath.item]); return cell
    }

    // MARK: - Prefetching
     func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
         for indexPath in indexPaths {
             guard indexPath.item < offers.count else { continue }
             let offer = offers[indexPath.item]
             if let url = offer.getHeroImageURL().flatMap(URL.init) { Task(priority: .low) { _ = try? await ImageLoader.shared.loadImage(from: url, type: .hero) } }
             if let url = offer.getLogoImageURL().flatMap(URL.init) { Task(priority: .low) { _ = try? await ImageLoader.shared.loadImage(from: url, type: .logo) } }
         }
     }
     func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
         for indexPath in indexPaths {
             guard indexPath.item < offers.count else { continue }
             let offer = offers[indexPath.item]
             if let url = offer.getHeroImageURL().flatMap(URL.init) { Task { await ImageLoader.shared.cancelLoad(for: url) } }
             if let url = offer.getLogoImageURL().flatMap(URL.init) { Task { await ImageLoader.shared.cancelLoad(for: url) } }
         }
     }

    // MARK: - DelegateFlowLayout
     func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let padding: CGFloat = 30; let availableWidth = view.bounds.width - padding
        return CGSize(width: availableWidth, height: availableWidth * 0.55)
     }

    // MARK: - Delegate
     func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {} // Cancellation in prepareForReuse
}
