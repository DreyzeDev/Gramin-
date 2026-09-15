import SwiftUI

let currencies = ["AZN", "USD", "EUR", "RUB"]

struct SheetShell<Content: View>: View {
    let title: String
    let content: Content
    @Environment(\.dismiss) private var dismiss
    init(title: String, @ViewBuilder content: () -> Content) { self.title = title; self.content = content() }
    var body: some View {
        NavigationStack {
            ScrollView { VStack(spacing: 18) { content }.padding(20) }
                .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Закрыть") { dismiss() } }
        }.presentationDetents([.medium, .large]).presentationCornerRadius(30)
    }
}

struct TopUpSheet: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var currency = "AZN"
    var body: some View {
        SheetShell(title: "Демо-пополнение") {
            Text("Средства виртуальные и не имеют денежной ценности.").font(.footnote).foregroundStyle(.secondary)
            Picker("Валюта", selection: $currency) { ForEach(currencies, id: \.self) { Text($0) } }.pickerStyle(.segmented)
            TextField("Сумма", text: $amount).keyboardType(.decimalPad).font(.largeTitle.bold()).multilineTextAlignment(.center).padding()
            Button("Пополнить") { Task { await state.topUp(amount: Double(amount) ?? 0, currency: currency); dismiss() } }
                .buttonStyle(PrimaryButtonStyle()).disabled((Double(amount) ?? 0) <= 0)
        }
    }
}

struct ExchangeSheet: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var from = "AZN"
    @State private var to = "USD"
    var body: some View {
        SheetShell(title: "Обмен валют") {
            HStack {
                currencyPicker("Отдаёте", value: $from)
                Image(systemName: "arrow.right")
                currencyPicker("Получаете", value: $to)
            }
            TextField("Сумма", text: $amount).keyboardType(.decimalPad).font(.largeTitle.bold()).multilineTextAlignment(.center).padding()
            Text("Фиксированный демо-курс · без комиссии").font(.footnote).foregroundStyle(.secondary)
            Button("Обменять") { Task { await state.exchange(amount: Double(amount) ?? 0, from: from, to: to); dismiss() } }
                .buttonStyle(PrimaryButtonStyle()).disabled(from == to || (Double(amount) ?? 0) <= 0)
        }
    }
    private func currencyPicker(_ title: String, value: Binding<String>) -> some View {
        VStack(alignment: .leading) { Text(title).font(.caption).foregroundStyle(.secondary); Picker(title, selection: value) { ForEach(currencies, id: \.self) { Text($0) } } }
            .padding().background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct TransferSheet: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var recipient = ""
    @State private var amount = ""
    @State private var currency = "AZN"
    @State private var confirmLarge = false
    var body: some View {
        SheetShell(title: "Новый перевод") {
            TextField("@username или номер карты", text: $recipient).textInputAutocapitalization(.never).padding(16)
                .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
            Picker("Валюта", selection: $currency) { ForEach(currencies, id: \.self) { Text($0) } }.pickerStyle(.segmented)
            TextField("Сумма", text: $amount).keyboardType(.decimalPad).font(.largeTitle.bold()).multilineTextAlignment(.center).padding()
            if aznEquivalent >= 5000 {
                Label("Комиссия за крупный перевод: 2%", systemImage: "exclamationmark.circle.fill")
                    .font(.footnote).foregroundStyle(.secondary)
                Toggle("Подтверждаю перевод", isOn: $confirmLarge)
            }
            Button("Продолжить") {
                Task { if await state.transfer(amount: Double(amount) ?? 0, currency: currency, recipient: recipient, confirmLarge: confirmLarge) { dismiss() } }
            }.buttonStyle(PrimaryButtonStyle())
                .disabled(recipient.count < 4 || (Double(amount) ?? 0) <= 0 || (aznEquivalent >= 5000 && !confirmLarge))
        }
    }
    private var aznEquivalent: Double {
        let rates: [String: Double] = ["AZN": 1.0, "USD": 1.7, "EUR": 1.85, "RUB": 0.018]
        let rate = rates[currency] ?? 1.0
        return (Double(amount) ?? 0) * rate
    }
}
