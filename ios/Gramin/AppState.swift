import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLocked = false
    @Published var isBusy = false
    @Published var errorMessage: String?
    @Published var profile: UserProfile?
    @Published var wallets: [Wallet] = []
    @Published var cards: [BankCard] = []
    @Published var transactions: [Transaction] = []
    @Published var notifications: [NotificationItem] = []
    @Published var selectedTab = 0
    @Published var darkMode = false
    @Published var faceIDEnabled = UserDefaults.standard.bool(forKey: "faceIDEnabled")
    @Published var appLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? "ru"
    @Published var availableUpdate: AppUpdate?
    private(set) var token: String?

    func restoreSession() async {
        guard let saved = KeychainStore.read("gramin-token") else { return }
        token = saved; isAuthenticated = true
        if faceIDEnabled { isLocked = true }
        await refresh()
    }

    func checkForUpdates() async {
        availableUpdate = await UpdateService.latest()
    }

    func authenticate(username: String, password: String) async {
        struct Body: Encodable { let username: String; let password: String }
        await perform {
            let result: AuthToken = try await APIClient.shared.request("/api/auth/login", method: "POST",
                                                                       body: Body(username: username, password: password))
            self.accept(result)
            await self.refresh()
        }
    }

    func register(firstName: String, lastName: String, username: String, password: String, birthDate: Date) async {
        struct Body: Encodable {
            let firstName, lastName, username, password, birthDate: String
        }
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"
        let body = Body(firstName: firstName, lastName: lastName, username: username,
                        password: password, birthDate: formatter.string(from: birthDate))
        await perform {
            let result: AuthToken = try await APIClient.shared.request("/api/auth/register", method: "POST", body: body)
            self.accept(result)
            await self.refresh()
        }
    }

    private func accept(_ auth: AuthToken) {
        token = auth.accessToken; KeychainStore.save(auth.accessToken, key: "gramin-token")
        withAnimation(.spring) { isAuthenticated = true; isLocked = false }
        Task { await NotificationService.requestPermission(); await NotificationService.scheduleWeeklyReport() }
    }

    func refresh() async {
        guard let token else { return }
        do {
            async let profileRequest: UserProfile = APIClient.shared.request("/api/me", token: token)
            async let walletRequest: [Wallet] = APIClient.shared.request("/api/wallets", token: token)
            async let cardRequest: [BankCard] = APIClient.shared.request("/api/cards", token: token)
            async let transactionRequest: [Transaction] = APIClient.shared.request("/api/transactions", token: token)
            async let notificationRequest: [NotificationItem] = APIClient.shared.request("/api/notifications", token: token)
            let values = try await (profileRequest, walletRequest, cardRequest, transactionRequest, notificationRequest)
            profile = values.0; wallets = values.1; cards = values.2; transactions = values.3; notifications = values.4
        } catch { handle(error) }
    }

    func topUp(amount: Double, currency: String) async {
        struct Body: Encodable { let amount: Double; let currency: String }
        await mutate(path: "/api/wallets/top-up", body: Body(amount: amount, currency: currency), notice: "Баланс пополнен")
    }

    func exchange(amount: Double, from: String, to: String) async {
        struct Body: Encodable { let fromCurrency, toCurrency: String; let amount: Double }
        await mutate(path: "/api/exchange", body: Body(fromCurrency: from, toCurrency: to, amount: amount), notice: "Обмен выполнен")
    }

    func transfer(amount: Double, currency: String, recipient: String, confirmLarge: Bool = false) async -> Bool {
        struct Body: Encodable { let recipient, currency: String; let amount: Double; let confirmLarge: Bool }
        guard let token else { return false }
        do {
            let _: JSONValue = try await APIClient.shared.request("/api/transfers", method: "POST",
                body: Body(recipient: recipient, currency: currency, amount: amount, confirmLarge: confirmLarge), token: token)
            await NotificationService.showLocal(title: "Перевод отправлен", body: "\(amount) \(currency) → \(recipient)")
            await refresh(); return true
        } catch { handle(error); return false }
    }

    func createCard(currency: String, design: String, pin: String) async {
        struct Body: Encodable { let currency, design, pin: String }
        await mutate(path: "/api/cards", body: Body(currency: currency, design: design, pin: pin), notice: "Карта создана")
    }

    func toggleFreeze(_ card: BankCard) async {
        guard let token else { return }
        await perform {
            let _: BankCard = try await APIClient.shared.request("/api/cards/\(card.id)/freeze", method: "POST", token: token)
            await self.refresh()
        }
    }

    func updateCardPIN(_ card: BankCard, pin: String) async {
        struct Body: Encodable { let pin: String }
        guard let token else { return }
        await perform {
            let _: EmptyResponse = try await APIClient.shared.request("/api/cards/\(card.id)/pin", method: "PUT", body: Body(pin: pin), token: token)
        }
    }

    func updateCardLimit(_ card: BankCard, amount: Double) async {
        struct Body: Encodable { let amount: Double }
        guard let token else { return }
        await perform {
            let _: BankCard = try await APIClient.shared.request("/api/cards/\(card.id)/limit", method: "PUT", body: Body(amount: amount), token: token)
            await self.refresh()
        }
    }

    func closeCard(_ card: BankCard) async {
        guard let token else { return }
        await perform {
            let _: EmptyResponse = try await APIClient.shared.request("/api/cards/\(card.id)", method: "DELETE", token: token)
            await self.refresh()
        }
    }

    func pay(provider: String, account: String, category: String, amount: Double, currency: String) async {
        struct Body: Encodable { let provider, account, category, currency: String; let amount: Double }
        await mutate(path: "/api/payments", body: Body(provider: provider, account: account, category: category,
                                                        currency: currency, amount: amount), notice: "Оплата выполнена")
    }

    private func mutate(path: String, body: Encodable, notice: String) async {
        guard let token else { return }
        await perform {
            let _: JSONValue = try await APIClient.shared.request(path, method: "POST", body: body, token: token)
            await NotificationService.showLocal(title: notice, body: "Операция сохранена в Gramin")
            await self.refresh()
        }
    }

    func unlock() async {
        if await BiometricService.authenticate() { withAnimation { isLocked = false } }
    }

    func lockIfNeeded() { if faceIDEnabled { isLocked = true } }
    func setFaceID(_ enabled: Bool) { faceIDEnabled = enabled; UserDefaults.standard.set(enabled, forKey: "faceIDEnabled") }
    func setLanguage(_ value: String) { appLanguage = value; UserDefaults.standard.set(value, forKey: "appLanguage") }

    func logout() {
        KeychainStore.delete("gramin-token"); token = nil; profile = nil; wallets = []; cards = []; transactions = []
        withAnimation { isAuthenticated = false; isLocked = false }
    }

    private func perform(_ action: () async throws -> Void) async {
        isBusy = true; errorMessage = nil
        do { try await action() } catch { handle(error) }
        isBusy = false
    }

    private func handle(_ error: Error) {
        errorMessage = error.localizedDescription
        if case APIError.unauthorized = error { logout() }
    }
}

enum JSONValue: Codable {
    case string(String), number(Double), bool(Bool), object([String: JSONValue]), array([JSONValue]), null
    init(from decoder: Decoder) throws {
        let box = try decoder.singleValueContainer()
        if box.decodeNil() { self = .null }
        else if let value = try? box.decode(Bool.self) { self = .bool(value) }
        else if let value = try? box.decode(Double.self) { self = .number(value) }
        else if let value = try? box.decode(String.self) { self = .string(value) }
        else if let value = try? box.decode([String: JSONValue].self) { self = .object(value) }
        else { self = .array(try box.decode([JSONValue].self)) }
    }
    func encode(to encoder: Encoder) throws {
        var box = encoder.singleValueContainer()
        switch self {
        case .string(let value): try box.encode(value)
        case .number(let value): try box.encode(value)
        case .bool(let value): try box.encode(value)
        case .object(let value): try box.encode(value)
        case .array(let value): try box.encode(value)
        case .null: try box.encodeNil()
        }
    }
}
