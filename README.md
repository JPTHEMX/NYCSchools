import UIKit
import Foundation

// MARK: - Data Models

// NOTE: Replace with your actual Offer struct/class, ensuring it has a 'category' property
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
    case trew = "Section Three" // Intended 'three'?
}

// MARK: - Reload Delegate Protocol

protocol ReloadDataProtocol: AnyObject {
    func reloadItem(at indexPath: IndexPath) // Preferred method
    // func reloadList() // Fallback option
}

// MARK: - WalletViewModel

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
        clearLoadingTasks() // Cancel previous tasks before processing

        var groupedItems: [Category: [Item]] = [:]
        for offer in newOffers {
            let item = Item(offer: offer, model: ItemModel(title: offer.name))
            groupedItems[offer.category, default: []].append(item)
        }

        self.categories = Category.allCases.filter { groupedItems.keys.contains($0) }
        self.itemsByCategory = groupedItems
        self.counter = 0 // Reset counter when offers change

        // Notify delegate for initial full reload
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
        return getItem(at: indexPath)?.model
    }

    // MARK: - Async Image Loading Logic

    func loadImageIfNeeded(for indexPath: IndexPath) {
        guard let item = getItem(at: indexPath),
              item.model.image == nil,
              !item.model.isLoading,
              let logoUrlString = item.offer.getLogoImageURL(),
              let url = URL(string: logoUrlString) else {
            return
        }

        taskLock.lock()
        let shouldStart = !loadingURLs.contains(url)
        if shouldStart { loadingURLs.insert(url) }
        taskLock.unlock()

        guard shouldStart else { return }

        setItemLoadingState(isLoading: true, at: indexPath)
        delegate?.reloadItem(at: indexPath) // Notify UI to show loading indicator

        Task(priority: .background) {
            var loadedImage: UIImage? = nil
            var loadSucceeded = false

            do {
                let dataValue = try await self.imageLoader.loadImage(from: url, type: .logo)
                if let img = UIImage(data: dataValue.data) {
                    loadedImage = img
                    loadSucceeded = true
                } else {
                    throw ImageLoadingError.decompressionFailed
                }
            } catch is CancellationError {
                print("ViewModel Task CANCELLED for \(url.lastPathComponent)")
            } catch {
                print("ViewModel Task Error loading logo \(url.lastPathComponent): \(error)")
            }

            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.taskLock.lock(); self.loadingURLs.remove(url); self.taskLock.unlock()

                self.updateItemModel(image: loadedImage, isLoading: false, at: indexPath)

                if loadSucceeded {
                    self.counter += 1
                    self.delegate?.reloadItem(at: indexPath) // Notify UI with the loaded image
                }
                // If load failed (loadedImage is nil), reloadItem was already called to set isLoading=false
            }
        }
    }

    func cancelLoad(for indexPath: IndexPath) {
         guard let item = getItem(at: indexPath),
               let logoUrlString = item.offer.getLogoImageURL(),
               let url = URL(string: logoUrlString) else { return }

         taskLock.lock(); let isLoading = loadingURLs.contains(url); taskLock.unlock()

         if isLoading {
            Task { await imageLoader.cancelLoad(for: url) }
            // Update model immediately to reflect cancellation attempt
            setItemLoadingState(isLoading: false, at: indexPath)
             // Optionally notify to hide loading indicator if reloadItem isn't guaranteed
             // delegate?.reloadItem(at: indexPath)
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
              indexPath.row < itemsByCategory[category]!.count else { return }
        itemsByCategory[category]![indexPath.row].model.isLoading = isLoading
    }

    private func updateItemModel(image: UIImage?, isLoading: Bool, at indexPath: IndexPath) {
         guard let category = category(for: indexPath.section),
               itemsByCategory[category] != nil,
               indexPath.row < itemsByCategory[category]!.count else { return }
         itemsByCategory[category]![indexPath.row].model.image = image
         itemsByCategory[category]![indexPath.row].model.isLoading = isLoading
    }

    func clearLoadingTasks() {
        Task { @MainActor in
            taskLock.lock(); let urlsToCancel = loadingURLs; loadingURLs.removeAll(); taskLock.unlock()
            urlsToCancel.forEach { url in Task { await imageLoader.cancelLoad(for: url) } }
            for category in categories {
                guard itemsByCategory[category] != nil else { continue }
                for i in 0..<itemsByCategory[category]!.count { itemsByCategory[category]![i].model.isLoading = false }
            }
        }
    }
}
