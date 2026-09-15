import Foundation

struct Amount: Codable, Hashable, Comparable {
    let value: Double
    init(_ value: Double) { self.value = value }
    init(from decoder: Decoder) throws {
        let box = try decoder.singleValueContainer()
        if let value = try? box.decode(Double.self) { self.value = value; return }
        if let value = try? box.decode(Int.self) { self.value = Double(value); return }
        let text = try box.decode(String.self)
        guard let value = Double(text) else { throw DecodingError.dataCorruptedError(in: box, debugDescription: "Invalid amount") }
        self.value = value
    }
    func encode(to encoder: Encoder) throws {
        var box = encoder.singleValueContainer(); try box.encode(value)
    }
    static func < (lhs: Amount, rhs: Amount) -> Bool { lhs.value < rhs.value }
}

struct AuthToken: Codable { let accessToken: String; let tokenType: String }

struct UserProfile: Codable, Identifiable {
    let id: String
    let firstName: String
    let lastName: String
    let username: String
    let birthDate: String
    let avatarURL: String?
    var initials: String { String(firstName.prefix(1)) + String(lastName.prefix(1)) }
}

struct Wallet: Codable, Identifiable {
    let id: String
    let currency: String
    let balance: Amount
}

struct BankCard: Codable, Identifiable {
    let id: String
    let number: String
    let currency: String
    let design: String
    let expiry: String
    let cvv: String
    let frozen: Bool
    let closed: Bool
    let dailyLimit: Amount
    var masked: String { "••••  ••••  ••••  \(number.suffix(4))" }
}

struct Transaction: Codable, Identifiable {
    let id: String
    let kind: String
    let amount: Amount
    let currency: String
    let category: String
    let title: String
    let counterparty: String?
    let createdAt: Date
}

struct NotificationItem: Codable, Identifiable {
    let id: String
    let title: String
    let body: String
    let kind: String
    let read: Bool
    let createdAt: Date
}

struct AnalyticsResponse: Codable {
    struct Category: Codable, Identifiable { var id: String { name }; let name: String; let amount: Amount }
    struct Day: Codable, Identifiable { var id: String { date }; let date: String; let amount: Amount }
    let period: String
    let currency: String
    let total: Amount
    let categories: [Category]
    let daily: [Day]
}

struct EmptyResponse: Codable {}

extension JSONDecoder {
    static var gramin: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

extension JSONEncoder {
    static var gramin: JSONEncoder {
        let encoder = JSONEncoder(); encoder.keyEncodingStrategy = .convertToSnakeCase; return encoder
    }
}
