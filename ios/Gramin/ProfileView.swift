import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var state: AppState
    @State private var newPIN = ""
    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    Group {
                        if let data = UserDefaults.standard.data(forKey: "localAvatar"), let image = UIImage(data: data) {
                            Image(uiImage: image).resizable().scaledToFill()
                        } else {
                            Circle().fill(.primary).overlay(Text(state.profile?.initials ?? "G").font(.title.bold()).foregroundStyle(Color(.systemBackground)))
                        }
                    }.frame(width: 66, height: 66).clipShape(Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(state.profile?.firstName ?? "") \(state.profile?.lastName ?? "")").font(.title3.bold())
                        Text("@\(state.profile?.username ?? "")").foregroundStyle(.secondary)
                    }
                }.padding(.vertical, 8)
            }
            Section("Безопасность") {
                Toggle("Face ID", isOn: Binding(get: { state.faceIDEnabled }, set: { state.setFaceID($0) }))
                HStack {
                    SecureField("Новый PIN из 4 цифр", text: $newPIN).keyboardType(.numberPad)
                    Button("Сохранить") { if newPIN.count == 4 { KeychainStore.save(newPIN, key: "gramin-pin"); newPIN = "" } }.disabled(newPIN.count != 4)
                }
                Label("Крупные переводы подтверждаются отдельно", systemImage: "checkmark.shield.fill")
            }
            Section("Приложение") {
                Picker("Язык", selection: Binding(get: { state.appLanguage }, set: { state.setLanguage($0) })) {
                    Text("Русский").tag("ru"); Text("English").tag("en")
                }
                Toggle("Тёмная тема", isOn: Binding(get: { state.darkMode }, set: { state.setDarkMode($0) }))
            }
            Section("О приложении") {
                LabeledContent("Версия", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")
                Label("Только виртуальные деньги", systemImage: "testtube.2")
            }
            Section { Button("Выйти", role: .destructive) { state.logout() } }
        }.graminBackground().navigationTitle("Профиль")
    }
}
