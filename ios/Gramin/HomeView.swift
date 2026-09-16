import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var state: AppState
    @State private var sheet: ActionSheet?
    @State private var showNotifications = false

    enum ActionSheet: String, Identifiable { case transfer, topUp, exchange; var id: String { rawValue } }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 22) {
                header
                balanceBlock
                quickActions
                if let card = state.cards.first { MiniCardView(card: card) }
                transactions
            }.padding(.horizontal, 18).padding(.bottom, 30)
        }
        .background(Color(.systemGroupedBackground))
        .refreshable { await state.refresh() }
        .sheet(item: $sheet) { item in
            switch item {
            case .transfer: TransferSheet()
            case .topUp: TopUpSheet()
            case .exchange: ExchangeSheet()
            }
        }
        .sheet(isPresented: $showNotifications) { NotificationsView() }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Добро пожаловать").font(.subheadline).foregroundStyle(.secondary)
                Text(state.profile?.firstName ?? "Gramin").font(.title2.bold())
            }
            Spacer()
            Button { showNotifications = true } label: {
                Image(systemName: "bell.fill").frame(width: 46, height: 46)
                    .background(.background, in: Circle()).overlay(alignment: .topTrailing) {
                        if !state.notifications.isEmpty { Circle().fill(.primary).frame(width: 9, height: 9).padding(3) }
                    }
            }.foregroundStyle(.primary)
        }.padding(.top, 14)
    }

    private var balanceBlock: some View {
        GraminCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Общий баланс").foregroundStyle(.secondary)
                AmountText(amount: totalAZN, currency: "AZN").font(.system(size: 36, weight: .bold, design: .rounded))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(state.wallets) { item in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.currency).font(.caption.bold()).foregroundStyle(.secondary)
                                AmountText(amount: item.balance.value, currency: item.currency).font(.subheadline.bold())
                            }.padding(.horizontal, 13).padding(.vertical, 10)
                                .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 13))
                        }
                    }
                }
            }
        }
    }

    private var totalAZN: Double {
        let rates = ["AZN": 1.0, "USD": 1.7, "EUR": 1.85, "RUB": 0.018]
        return state.wallets.reduce(0) { $0 + $1.balance.value * (rates[$1.currency] ?? 1) }
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            action("Перевести", "arrow.up.right", .transfer)
            action("Пополнить", "plus", .topUp)
            action("Обменять", "arrow.left.arrow.right", .exchange)
        }
    }

    private func action(_ title: String, _ icon: String, _ value: ActionSheet) -> some View {
        Button { sheet = value } label: {
            VStack(spacing: 10) {
                Image(systemName: icon).font(.headline).frame(width: 44, height: 44).background(.primary, in: Circle()).foregroundStyle(Color(.systemBackground))
                Text(title).font(.caption.bold()).lineLimit(1)
            }.frame(maxWidth: .infinity).padding(.vertical, 14).background(.background, in: RoundedRectangle(cornerRadius: 20))
        }.foregroundStyle(.primary).buttonStyle(.plain)
    }

    private var transactions: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text("Последние операции").font(.title3.bold()); Spacer(); Text("Все").font(.subheadline).foregroundStyle(.secondary) }
            if state.transactions.isEmpty {
                ContentUnavailableView("Операций пока нет", systemImage: "clock.arrow.circlepath", description: Text("Пополните демо-счёт, чтобы начать"))
                    .frame(height: 180)
            } else {
                ForEach(state.transactions.prefix(6)) { TransactionRow(transaction: $0) }
            }
        }
    }
}

struct TransactionRow: View {
    let transaction: Transaction
    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon).frame(width: 42, height: 42).background(.primary.opacity(0.07), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.title).font(.subheadline.bold()).lineLimit(1)
                Text(transaction.createdAt, style: .date).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            AmountText(amount: transaction.amount.value, currency: transaction.currency)
                .font(.subheadline.bold()).foregroundStyle(.primary)
        }.padding(.vertical, 3)
    }
    private var icon: String {
        switch transaction.category { case "mobile": "iphone"; case "internet": "wifi"; case "utilities": "bolt.fill"; case "transfer": "arrow.left.arrow.right"; default: "banknote.fill" }
    }
}

struct NotificationsView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List(state.notifications) { item in
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.title).font(.headline); Text(item.body).foregroundStyle(.secondary); Text(item.createdAt, style: .relative).font(.caption).foregroundStyle(.tertiary)
                }.padding(.vertical, 5)
            }.navigationTitle("Уведомления").toolbar { Button("Готово") { dismiss() } }
        }
    }
}

