import UIKit
import Foundation

// MARK: - Data Models (Adjusted)

struct Offer: Hashable {
    let id = UUID()
    let name: String
    let category: Category
    let heroURLString: String?
    let logoURLString: String? // Assumed non-nil for configure logic

    func getHeroImageURL() -> String? { heroURLString }
    func getLogoImageURL() -> String? { logoURLString }

    init(id: UUID = UUID(), name: String, category: Category, heroURLString: String? = nil, logoURLString: String?) {
         self.id = id
         self.name = name
         self.category = category
         self.heroURLString = heroURLString
         self.logoURLString = logoURLString
     }
}

struct ItemModel {
    var title: String?
    var image: UIImage? // Will store the LOGO image
    var isLoading: Bool = false
}

struct Item: Hashable {
    let offer: Offer
    var model: ItemModel

    func hash(into hasher: inout Hasher) { hasher.combine(offer.id) }
    static func == (lhs: Item, rhs: Item) -> Bool { lhs.offer.id == rhs.offer.id }
}

enum Category: String, CaseIterable, Hashable {
    case one = "Section One"
    case two = "Section Two"
    case trew = "Section Three"
}

// MARK: - Reload Delegate Protocol

protocol ReloadDataProtocol: AnyObject {
    // func reloadItem(at indexPath: IndexPath) // Preferred
    func reloadList() // Fallback
}

// MARK: - WalletViewModel (Using internal state & sync cache check)

final class WalletViewModel {
    weak var delegate: ReloadDataProtocol?
    var counter: Int = 0
    private(set) var itemsByCategory: [Category: [Item]] = [:]
    private(set) var categories: [Category] = []

    private let imageLoader: ImageLoading
    private var loadingURLs = Set<URL>()
    private let taskLock = NSLock()

    init(offers: [Offer] = [], imageLoader: ImageLoading = ImageLoader.shared) {
        self.imageLoader = imageLoader
        processOffers(offers)
    }

    func processOffers(_ newOffers: [Offer]) {
        clearLoadingTasks()

        var groupedItems: [Category: [Item]] = [:]
        for offer in newOffers {
            let item = Item(offer: offer, model: ItemModel(title: offer.name, isLoading: false))
            groupedItems[offer.category, default: []].append(item)
        }

        self.categories = Category.allCases.filter { groupedItems.keys.contains($0) }
        self.itemsByCategory = groupedItems
        self.counter = 0

        delegate?.reloadList()
    }

    // MARK: - Data Source Accessors

    func numberOfSections() -> Int {
        return categories.count
    }

    func numberOfItems(in section: Int) -> Int {
        guard let category = category(for: section) else { return 0 }
        return itemsByCategory[category]?.count ?? 0
    }

    func category(for section: Int) -> Category? {
        guard section < categories.count else { return nil }
        return categories[section]
    }

    func getItemModel(at indexPath: IndexPath) -> ItemModel? {
        guard let category = category(for: indexPath.section),
              var itemsInCategory = itemsByCategory[category],
              indexPath.row < itemsInCategory.count
        else {
            return nil
        }

        var item = itemsInCategory[indexPath.row]

        if let existingImage = item.model.image {
            return item.model
        }

        if let logoUrlString = item.offer.getLogoImageURL(), let url = URL(string: logoUrlString) {
            let request = URLRequest(url: url)
            if let cachedResponse = URLCache.shared.cachedResponse(for: request),
               let cachedImage = UIImage(data: cachedResponse.data)
            {
                item.model.image = cachedImage
                itemsByCategory[category]![indexPath.row].model.image = cachedImage
                return item.model
            } else {
                launchLoadingTaskIfNeeded(for: url, at: indexPath)
            }
        }

        return item.model
    }

    // MARK: - Async Image Loading Logic

    private func launchLoadingTaskIfNeeded(for url: URL, at indexPath: IndexPath) {
        taskLock.lock()
        let shouldStart = !loadingURLs.contains(url)
        if shouldStart {
            loadingURLs.insert(url)
        }
        taskLock.unlock()

        guard shouldStart else { return }

        setItemLoadingState(isLoading: true, at: indexPath)
        // delegate?.reloadItem(at: indexPath) // Optional: If using specific reload

        Task(priority: .background) {
            var loadedImage: UIImage? = nil
            var loadSucceeded = false

            defer {
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.taskLock.lock()
                    self.loadingURLs.remove(url)
                    self.taskLock.unlock()
                    if !loadSucceeded { // Ensure isLoading is false if load failed/cancelled
                         self.setItemLoadingState(isLoading: false, at: indexPath)
                    }
                }
            }

            do {
                let dataValue = try await self.imageLoader.loadImage(from: url, type: .logo)
                if let img = UIImage(data: dataValue.data) {
                    loadedImage = img
                    loadSucceeded = true
                } else {
                    throw ImageLoadingError.decompressionFailed
                }
            } catch is CancellationError {
                // Ignored for UI update, defer handles cleanup
            } catch {
                print("Error loading logo \(url.lastPathComponent): \(error)")
            }

            if let finalImage = loadedImage {
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.updateItemModel(image: finalImage, isLoading: false, at: indexPath)
                    self.counter += 1 // Increment counter on successful load
                    self.delegate?.reloadList() // Trigger global reload
                }
            }
        }
    }

    // MARK: - Cancellation

    func cancelLoad(for indexPath: IndexPath) {
         guard let item = getItem(at: indexPath),
               let logoUrlString = item.offer.getLogoImageURL(),
               let url = URL(string: logoUrlString) else { return }

         taskLock.lock()
         let isLoading = loadingURLs.contains(url)
         taskLock.unlock()

         if isLoading {
            Task { await imageLoader.cancelLoad(for: url) }
            setItemLoadingState(isLoading: false, at: indexPath)
            // delegate?.reloadItem(at: indexPath) // Optional: If using specific reload
         }
    }

    // MARK: - Internal Helpers

    private func getItem(at indexPath: IndexPath) -> Item? {
        guard let category = category(for: indexPath.section),
              let itemsInCategory = itemsByCategory[category],
              indexPath.row < itemsInCategory.count else {
            return nil
        }
        return itemsInCategory[indexPath.row]
    }

    private func setItemLoadingState(isLoading: Bool, at indexPath: IndexPath) {
        guard let category = category(for: indexPath.section),
              itemsByCategory[category] != nil,
              indexPath.row < itemsByCategory[category]!.count else {
            return
        }
        itemsByCategory[category]![indexPath.row].model.isLoading = isLoading
    }

    private func updateItemModel(image: UIImage?, isLoading: Bool, at indexPath: IndexPath) {
         guard let category = category(for: indexPath.section),
               itemsByCategory[category] != nil,
               indexPath.row < itemsByCategory[category]!.count else {
             return
         }
         itemsByCategory[category]![indexPath.row].model.image = image
         itemsByCategory[category]![indexPath.row].model.isLoading = isLoading
    }

    func clearLoadingTasks() {
        Task { @MainActor in
            taskLock.lock()
            let urlsToCancel = loadingURLs
            loadingURLs.removeAll()
            taskLock.unlock()

            urlsToCancel.forEach { url in Task { await imageLoader.cancelLoad(for: url) } }

            for category in categories {
                guard itemsByCategory[category] != nil else { continue }
                for i in 0..<itemsByCategory[category]!.count {
                    itemsByCategory[category]![i].model.isLoading = false
                }
            }
        }
    }
}
