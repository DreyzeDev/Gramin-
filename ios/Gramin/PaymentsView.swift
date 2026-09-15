import SwiftUI

struct ServiceCategory: Identifiable {
    let id: String
    let title: String
    let icon: String
    let providers: [String]
}

private let serviceCategories = [
    ServiceCategory(id: "mobile", title: "Мобильная связь", icon: "iphone", providers: ["Azercell", "Bakcell", "Nar", "Другой оператор"]),
    ServiceCategory(id: "internet", title: "Интернет", icon: "wifi", providers: ["CityNet", "Baktelecom", "Другой провайдер"]),
    ServiceCategory(id: "utilities", title: "Коммунальные", icon: "bolt.fill", providers: ["Электричество", "Газ", "Вода"]),
    ServiceCategory(id: "subscriptions", title: "Игры и подписки", icon: "gamecontroller.fill", providers: ["App Store", "Игровой аккаунт", "Подписка"]),
    ServiceCategory(id: "taxes", title: "Штрафы и налоги", icon: "doc.text.fill", providers: ["Штраф", "Налог"]),
    ServiceCategory(id: "charity", title: "Благотворительность", icon: "heart.fill", providers: ["Помощь детям", "Защита животных", "Другой фонд"]),
]

struct PaymentsView: View {
    @State private var selected: ServiceCategory?
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(serviceCategories) { item in
                    Button { selected = item } label: {
                        VStack(alignment: .leading, spacing: 20) {
                            Image(systemName: item.icon).font(.title2).frame(width: 46, height: 46).background(.primary, in: Circle()).foregroundStyle(Color(.systemBackground))
                            Text(item.title).font(.headline).multilineTextAlignment(.leading)
                        }.frame(maxWidth: .infinity, minHeight: 130, alignment: .leading).padding(16)
                            .background(.background, in: RoundedRectangle(cornerRadius: 22))
                    }.buttonStyle(.plain).foregroundStyle(.primary)
                }
            }.padding(18)
        }.background(Color(.systemGroupedBackground)).navigationTitle("Оплата услуг")
            .sheet(item: $selected) { PayServiceSheet(category: $0) }
    }
}

struct PayServiceSheet: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    let category: ServiceCategory
    @State private var provider: String
    @State private var account = ""
    @State private var amount = ""
    @State private var currency = "AZN"

    init(category: ServiceCategory) { self.category = category; _provider = State(initialValue: category.providers.first ?? "") }

    var body: some View {
        SheetShell(title: category.title) {
            Picker("Поставщик", selection: $provider) { ForEach(category.providers, id: \.self) { Text($0) } }.pickerStyle(.menu)
                .frame(maxWidth: .infinity).padding().background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
            TextField("Лицевой счёт или номер", text: $account).keyboardType(.numbersAndPunctuation).padding(16)
                .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
            Picker("Валюта", selection: $currency) { ForEach(currencies, id: \.self) { Text($0) } }.pickerStyle(.segmented)
            TextField("Сумма", text: $amount).keyboardType(.decimalPad).font(.largeTitle.bold()).multilineTextAlignment(.center).padding()
            Button("Оплатить") { Task { await state.pay(provider: provider, account: account, category: category.id, amount: Double(amount) ?? 0, currency: currency); dismiss() } }
                .buttonStyle(PrimaryButtonStyle()).disabled(account.count < 2 || (Double(amount) ?? 0) <= 0)
        }
    }
}

