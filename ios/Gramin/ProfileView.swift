import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var state: AppState
    @State private var serverURL = UserDefaults.standard.string(forKey: "serverURL") ?? "http://127.0.0.1:8000"
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
                Toggle("Тёмная тема", isOn: $state.darkMode)
            }
            Section("Сервер") {
                TextField("https://api.example.com", text: $serverURL).textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("Сохранить адрес") { UserDefaults.standard.set(serverURL, forKey: "serverURL"); Task { await state.refresh() } }
                Text("Для теста на iPhone укажите публичный HTTPS-адрес развёрнутого API.").font(.caption).foregroundStyle(.secondary)
            }
            Section("О приложении") {
                LabeledContent("Версия", value: "0.1.0")
                Label("Только виртуальные деньги", systemImage: "testtube.2")
            }
            Section { Button("Выйти", role: .destructive) { state.logout() } }
        }.graminBackground().navigationTitle("Профиль")
    }
}
