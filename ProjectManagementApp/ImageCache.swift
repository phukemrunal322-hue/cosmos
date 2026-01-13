import SwiftUI
import Combine

// MARK: - Image Caching

class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()
    
    private init() {}
    
    func get(forKey key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }
    
    func set(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
}

class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    private var task: URLSessionDataTask?
    
    func load(url: URL) {
        if let cachedImage = ImageCache.shared.get(forKey: url.absoluteString) {
            self.image = cachedImage
            return
        }
        
        task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, let loadedImage = UIImage(data: data) else { return }
            
            DispatchQueue.main.async {
                ImageCache.shared.set(loadedImage, forKey: url.absoluteString)
                self.image = loadedImage
            }
        }
        task?.resume()
    }
    
    func cancel() {
        task?.cancel()
    }
}

struct CachedAsyncImage<Placeholder: View>: View {
    let url: URL?
    let placeholder: Placeholder
    @StateObject private var loader = ImageLoader()
    
    init(url: URL?, @ViewBuilder placeholder: () -> Placeholder) {
        self.url = url
        self.placeholder = placeholder()
    }
    
    var body: some View {
        Group {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholder
            }
        }
        .onAppear {
            if let url = url {
                print("🖼️ CachedAsyncImage appearing for: \(url.absoluteString)")
                loader.load(url: url)
            }
        }
        .onDisappear {
            loader.cancel()
        }
        .onChange(of: url) { newUrl in
            if let newUrl = newUrl {
                print("🖼️ CachedAsyncImage URL changed to: \(newUrl.absoluteString)")
                loader.load(url: newUrl)
            }
        }
    }
}

