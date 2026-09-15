import Foundation

enum APIError: LocalizedError {
    case invalidURL, unauthorized, server(String), transport(String)
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Проверьте адрес сервера"
        case .unauthorized: return "Сессия истекла. Войдите снова"
        case .server(let message), .transport(let message): return message
        }
    }
}

actor APIClient {
    static let shared = APIClient()
    private let session: URLSession = .shared

    private var baseURL: URL? {
        let raw = UserDefaults.standard.string(forKey: "serverURL") ?? "http://127.0.0.1:8000"
        return URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func request<T: Decodable>(_ path: String, method: String = "GET", body: Encodable? = nil,
                               token: String? = nil) async throws -> T {
        guard let baseURL, let url = URL(string: path, relativeTo: baseURL) else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body { request.httpBody = try JSONEncoder.gramin.encode(AnyEncodable(body)) }
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.transport("Некорректный ответ сервера") }
            if http.statusCode == 401 { throw APIError.unauthorized }
            guard (200..<300).contains(http.statusCode) else {
                let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
                let detail = object?["detail"].map(String.init(describing:)) ?? "Ошибка сервера (\(http.statusCode))"
                throw APIError.server(detail)
            }
            if T.self == EmptyResponse.self && data.isEmpty { return EmptyResponse() as! T }
            return try JSONDecoder.gramin.decode(T.self, from: data)
        } catch let error as APIError { throw error }
        catch { throw APIError.transport(error.localizedDescription) }
    }
}

private struct AnyEncodable: Encodable {
    let encodeBlock: (Encoder) throws -> Void
    init(_ wrapped: Encodable) { encodeBlock = { encoder in try wrapped.encode(to: encoder) } }
    func encode(to encoder: Encoder) throws { try encodeBlock(encoder) }
}
