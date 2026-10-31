import Foundation

private final class ResourceAnchor: NSObject {}

enum CoreResources {
    static let bundle: Bundle? = {
        let name = "Zone51Control_Zone51Core.bundle"
        let executableDirectory = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
        let candidates = [Bundle.main.resourceURL, Bundle.main.bundleURL,
            Bundle(for: ResourceAnchor.self).bundleURL.deletingLastPathComponent(),
            Bundle.main.bundleURL.deletingLastPathComponent(), executableDirectory,
            executableDirectory.deletingLastPathComponent().appendingPathComponent("Resources")]
        return candidates.compactMap { $0 }.compactMap { Bundle(url: $0.appendingPathComponent(name)) }.first
    }()
}
