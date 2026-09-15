import SwiftUI
import Charts

struct AnalyticsView: View {
    @EnvironmentObject private var state: AppState
    @State private var period = "month"
    @State private var analytics: AnalyticsResponse?
    private let periods = [("week", "Неделя"), ("month", "Месяц"), ("year", "Год")]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Picker("Период", selection: $period) { ForEach(periods, id: \.0) { Text($0.1).tag($0.0) } }.pickerStyle(.segmented)
                GraminCard {
                    VStack(alignment: .leading) {
                        Text("Расходы").foregroundStyle(.secondary)
                        AmountText(amount: analytics?.total.value ?? 0, currency: "AZN").font(.system(size: 34, weight: .bold, design: .rounded))
                        if let items = analytics?.categories, !items.isEmpty {
                            Chart(items) { item in
                                SectorMark(angle: .value("Сумма", item.amount.value), innerRadius: .ratio(0.62), angularInset: 2)
                                    .foregroundStyle(by: .value("Категория", item.name))
                            }.frame(height: 220).chartLegend(position: .bottom, spacing: 10)
                        } else { emptyChart }
                    }
                }
                GraminCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Динамика расходов").font(.headline)
                        if let days = analytics?.daily, !days.isEmpty {
                            Chart(days) { day in
                                LineMark(x: .value("Дата", day.date), y: .value("AZN", day.amount.value)).interpolationMethod(.catmullRom)
                                AreaMark(x: .value("Дата", day.date), y: .value("AZN", day.amount.value)).opacity(0.12)
                            }.frame(height: 210).chartYAxis { AxisMarks(position: .leading) }
                        } else { emptyChart }
                    }
                }
            }.padding(18)
        }.background(Color(.systemGroupedBackground)).navigationTitle("Аналитика")
            .task(id: period) { await load() }
    }

    private var emptyChart: some View {
        ContentUnavailableView("Недостаточно данных", systemImage: "chart.bar", description: Text("Совершите несколько платежей"))
            .frame(height: 200)
    }
    private func load() async {
        guard let token = state.token else { return }
        analytics = try? await APIClient.shared.request("/api/analytics?period=\(period)", token: token)
    }
}

