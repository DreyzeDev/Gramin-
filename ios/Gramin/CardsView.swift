import SwiftUI

struct CardsView: View {
    @EnvironmentObject private var state: AppState
    @State private var showCreate = false
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if state.cards.isEmpty {
                    ContentUnavailableView("Нет виртуальных карт", systemImage: "creditcard", description: Text("Создайте первую карту Gramin"))
                        .frame(height: 360)
                } else {
                    TabView {
                        ForEach(state.cards) { card in MiniCardView(card: card).padding(.horizontal, 18) }
                    }.frame(height: 250).tabViewStyle(.page(indexDisplayMode: .always))
                    ForEach(state.cards) { card in CardControls(card: card) }
                }
                Button("Создать новую карту") { showCreate = true }.buttonStyle(PrimaryButtonStyle()).padding(.horizontal, 18)
            }.padding(.vertical)
        }.background(Color(.systemGroupedBackground)).navigationTitle("Карты")
            .sheet(isPresented: $showCreate) { CreateCardSheet() }
    }
}

struct MiniCardView: View {
    let card: BankCard
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous).fill(gradient).shadow(color: .black.opacity(0.18), radius: 18, y: 10)
            VStack(alignment: .leading) {
                HStack { Text("GRAMIN").font(.headline.weight(.black)).tracking(2); Spacer(); Image(systemName: "wave.3.right") }
                Spacer()
                Text(card.masked).font(.system(.title3, design: .monospaced).weight(.semibold))
                HStack { Text(card.expiry); Spacer(); Text(card.currency).font(.headline) }
            }.padding(24).foregroundStyle(foreground)
            if card.frozen { RoundedRectangle(cornerRadius: 28).fill(.ultraThinMaterial); Label("Заморожена", systemImage: "snowflake").font(.headline) }
        }.frame(height: 205).animation(.easeInOut, value: card.frozen)
    }
    private var gradient: LinearGradient {
        switch card.design {
        case "snow": LinearGradient(colors: [.white, Color(white: 0.88)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "graphite": LinearGradient(colors: [Color(white: 0.35), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
        default: LinearGradient(colors: [.black, Color(white: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    private var foreground: Color { card.design == "snow" ? .black : .white }
}

struct CardControls: View {
    @EnvironmentObject private var state: AppState
    let card: BankCard
    @State private var reveal = false
    @State private var showSettings = false
    var body: some View {
        GraminCard {
            VStack(spacing: 16) {
                HStack { Text("Карта •\(card.number.suffix(4))").font(.headline); Spacer(); Text(card.currency).foregroundStyle(.secondary) }
                if reveal {
                    HStack { Text(card.number.chunked); Spacer(); Text("CVV \(card.cvv)") }.font(.caption.monospaced()).transition(.blurReplace)
                }
                HStack {
                    Button { withAnimation { reveal.toggle() } } label: { Label(reveal ? "Скрыть" : "Реквизиты", systemImage: "eye") }
                    Spacer()
                    Button { Task { await state.toggleFreeze(card) } } label: { Label(card.frozen ? "Разморозить" : "Заморозить", systemImage: "snowflake") }
                }.font(.subheadline.bold())
                Button { showSettings = true } label: {
                    Label("Настройки карты", systemImage: "slider.horizontal.3").frame(maxWidth: .infinity)
                }.font(.subheadline.bold())
            }
        }.padding(.horizontal, 18).sheet(isPresented: $showSettings) { CardSettingsSheet(card: card) }
    }
}

struct CardSettingsSheet: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    let card: BankCard
    @State private var pin = ""
    @State private var limit = ""
    @State private var confirmClose = false
    var body: some View {
        SheetShell(title: "Настройки карты") {
            VStack(alignment: .leading) {
                Text("Дневной лимит").font(.caption).foregroundStyle(.secondary)
                TextField("\(card.dailyLimit.value)", text: $limit).keyboardType(.decimalPad).padding(16)
                    .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
                Button("Сохранить лимит") { Task { await state.updateCardLimit(card, amount: Double(limit) ?? card.dailyLimit.value) } }
                    .buttonStyle(PrimaryButtonStyle())
            }
            VStack(alignment: .leading) {
                Text("Сменить PIN").font(.caption).foregroundStyle(.secondary)
                SecureField("4 цифры", text: $pin).keyboardType(.numberPad).padding(16)
                    .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
                Button("Обновить PIN") { Task { await state.updateCardPIN(card, pin: pin); pin = "" } }
                    .buttonStyle(PrimaryButtonStyle()).disabled(pin.count != 4)
            }
            Button("Закрыть карту", role: .destructive) { confirmClose = true }
                .frame(maxWidth: .infinity).padding()
        }.alert("Закрыть карту без возможности восстановления?", isPresented: $confirmClose) {
            Button("Отмена", role: .cancel) {}
            Button("Закрыть", role: .destructive) { Task { await state.closeCard(card); dismiss() } }
        }
    }
}

struct CreateCardSheet: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var currency = "AZN"
    @State private var design = "obsidian"
    @State private var pin = ""
    private let designs = [("obsidian", "Чёрная"), ("snow", "Белая"), ("graphite", "Графит")]
    var body: some View {
        SheetShell(title: "Новая карта") {
            Picker("Валюта", selection: $currency) { ForEach(currencies, id: \.self) { Text($0) } }.pickerStyle(.segmented)
            Picker("Дизайн", selection: $design) { ForEach(designs, id: \.0) { Text($0.1).tag($0.0) } }.pickerStyle(.segmented)
            SecureField("PIN из 4 цифр", text: $pin).keyboardType(.numberPad).font(.title2.monospaced()).multilineTextAlignment(.center).padding()
            Button("Выпустить карту") { Task { await state.createCard(currency: currency, design: design, pin: pin); dismiss() } }
                .buttonStyle(PrimaryButtonStyle()).disabled(pin.count != 4)
        }
    }
}

private extension String {
    var chunked: String { stride(from: 0, to: count, by: 4).map { start in let a = index(startIndex, offsetBy: start); let b = index(a, offsetBy: min(4, count - start)); return String(self[a..<b]) }.joined(separator: " ") }
}
