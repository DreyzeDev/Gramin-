import Foundation

struct AppUpdate: Identifiable {
    let version: String
    let downloadURL: URL
    var id: String { version }
}

enum UpdateService {
    private struct Release: Decodable {
        struct Asset: Decodable {
            let name: String
            let browserDownloadURL: URL

            enum CodingKeys: String, CodingKey {
                case name
                case browserDownloadURL = "browser_download_url"
            }
        }

        let tagName: String
        let htmlURL: URL
        let assets: [Asset]

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
            case assets
        }
    }

    static func latest() async -> AppUpdate? {
        guard let endpoint = URL(string: "https://api.github.com/repos/DreyzeDev/Gramin-/releases/latest") else {
            return nil
        }

        do {
            var request = URLRequest(url: endpoint)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("Gramin-iOS", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 8

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }

            let release = try JSONDecoder().decode(Release.self, from: data)
            let latestVersion = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
            guard latestVersion.compare(currentVersion, options: .numeric) == .orderedDescending else { return nil }

            let ipa = release.assets.first { $0.name == "Gramin-unsigned.ipa" }
            return AppUpdate(version: latestVersion, downloadURL: ipa?.browserDownloadURL ?? release.htmlURL)
        } catch {
            return nil
        }
    }
}
