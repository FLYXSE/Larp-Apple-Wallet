import UIKit

enum ImageStore {
    static let directoryName = "CardImages"
    static let maxOutputWidth: CGFloat = 1600
    static let jpegQuality: CGFloat = 0.85

    private static var cache: [String: UIImage] = [:]

    private static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    }

    static var imagesDirectory: URL {
        documentsDirectory.appendingPathComponent(directoryName, isDirectory: true)
    }

    /// Сохраняет обложку и возвращает относительный путь (`CardImages/<uuid>.jpg`).
    static func save(_ image: UIImage, id: UUID) -> String? {
        let directory = imagesDirectory
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        } catch {
            return nil
        }

        let prepared = resample(image)
        guard let data = prepared.jpegData(compressionQuality: jpegQuality) else {
            return nil
        }

        let fileName = "\(id.uuidString).jpg"
        let url = directory.appendingPathComponent(fileName)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            return nil
        }
        let relativePath = "\(directoryName)/\(fileName)"
        cache[relativePath] = prepared
        return relativePath
    }

    static func load(relativePath: String) -> UIImage? {
        guard !relativePath.isEmpty else { return nil }
        if let cached = cache[relativePath] {
            return cached
        }
        let url = documentsDirectory.appendingPathComponent(relativePath)
        guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else {
            return nil
        }
        cache[relativePath] = image
        return image
    }

    static func delete(relativePath: String?) {
        guard let relativePath = relativePath, !relativePath.isEmpty else { return }
        cache.removeValue(forKey: relativePath)
        let url = documentsDirectory.appendingPathComponent(relativePath)
        try? FileManager.default.removeItem(at: url)
    }

    /// Нормализует ориентацию и уменьшает ширину до `maxOutputWidth`.
    static func resample(_ image: UIImage) -> UIImage {
        guard image.size.width > 0, image.size.height > 0 else { return image }
        let pixelWidth = image.size.width * image.scale
        guard pixelWidth > maxOutputWidth else {
            return normalized(image)
        }
        let ratio = maxOutputWidth / pixelWidth
        let targetSize = CGSize(
            width: floor(image.size.width * ratio),
            height: floor(image.size.height * ratio)
        )
        return render(image, size: targetSize)
    }

    static func normalized(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up, image.size.width > 0, image.size.height > 0 else {
            return image
        }
        return render(image, size: image.size)
    }

    private static func render(_ image: UIImage, size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
