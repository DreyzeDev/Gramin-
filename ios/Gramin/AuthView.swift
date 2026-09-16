import SwiftUI
import PhotosUI

struct AuthView: View {
    @EnvironmentObject private var state: AppState
    @State private var mode = 0
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var username = ""
    @State private var password = ""
    @State private var birthDate = Calendar.current.date(byAdding: .year, value: -18, to: .now) ?? .now
    @State private var avatarItem: PhotosPickerItem?
    @State private var avatarData: Data?

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            Circle().fill(.primary.opacity(0.05)).frame(width: 360).blur(radius: 2).offset(x: 170, y: -330)
            ScrollView {
                VStack(spacing: 28) {
                    Spacer(minLength: 45)
                    logo
                    Picker("Режим", selection: $mode) {
                        Text("Войти").tag(0); Text("Регистрация").tag(1)
                    }.pickerStyle(.segmented)

                    VStack(spacing: 14) {
                        if mode == 1 {
                            PhotosPicker(selection: $avatarItem, matching: .images) {
                                HStack {
                                    Group {
                                        if let avatarData, let image = UIImage(data: avatarData) {
                                            Image(uiImage: image).resizable().scaledToFill()
                                        } else { Image(systemName: "person.crop.circle.badge.plus").font(.title2) }
                                    }.frame(width: 52, height: 52).clipShape(Circle())
                                    Text("Добавить аватар").font(.headline)
                                    Spacer()
                                }.padding(12).background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
                            }.onChange(of: avatarItem) { _, item in
                                Task {
                                    avatarData = try? await item?.loadTransferable(type: Data.self)
                                    if let avatarData { UserDefaults.standard.set(avatarData, forKey: "localAvatar") }
                                }
                            }
                            HStack(spacing: 12) {
                                field("Имя", text: $firstName)
                                field("Фамилия", text: $lastName)
                            }
                            DatePicker("Дата рождения", selection: $birthDate, displayedComponents: .date)
                                .padding(16).background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
                        }
                        field("@username", text: $username, content: .username)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                        SecureField("Пароль — минимум 8 символов", text: $password)
                            .textContentType(mode == 0 ? .password : .newPassword)
                            .padding(16).background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
                    }

                    Button {
                        Task {
                            if mode == 0 { await state.authenticate(username: username, password: password) }
                            else { await state.register(firstName: firstName, lastName: lastName, username: username,
                                                        password: password, birthDate: birthDate) }
                        }
                    } label: {
                        HStack {
                            if state.isBusy { ProgressView().tint(Color(.systemBackground)) }
                            Text(mode == 0 ? "Войти в Gramin" : "Создать демо-счёт")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(state.isBusy || normalizedUsername.count < 4 || password.count < 8 ||
                              (mode == 1 && (firstName.trimmingCharacters(in: .whitespaces).count < 2 ||
                                             lastName.trimmingCharacters(in: .whitespaces).count < 2)))

                    Text("Gramin использует только виртуальные деньги")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding(24)
            }
        }
        .alert("Не удалось выполнить действие", isPresented: .constant(state.errorMessage != nil)) {
            Button("OK") { state.errorMessage = nil }
        } message: { Text(state.errorMessage ?? "") }
    }

    private var logo: some View {
        VStack(spacing: 12) {
            Image("WelcomeMonochrome")
                .resizable()
                .scaledToFit()
                .frame(height: 190)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            Text("Gramin").font(.system(size: 42, weight: .bold, design: .rounded))
            Text("Ваши финансы. Только проще.").foregroundStyle(.secondary)
        }
    }

    private func field(_ title: String, text: Binding<String>, content: UITextContentType? = nil) -> some View {
        TextField(title, text: text).textContentType(content).padding(16)
            .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
    }

    private var normalizedUsername: String {
        username.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
    }
}

struct LockView: View {
    @EnvironmentObject private var state: AppState
    @State private var pin = ""
    @State private var shake = false
    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "lock.circle.fill").font(.system(size: 76))
            Text("Gramin заблокирован").font(.title.bold())
            Text("Используйте Face ID или код приложения").foregroundStyle(.secondary)
            SecureField("••••", text: $pin).keyboardType(.numberPad).multilineTextAlignment(.center)
                .font(.title.monospaced()).frame(width: 150).padding()
                .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
                .offset(x: shake ? -8 : 0)
                .onChange(of: pin) { _, value in
                    if value.count == 4 {
                        if value == KeychainStore.read("gramin-pin") { withAnimation { state.isLocked = false } }
                        else { withAnimation(.default.repeatCount(3, autoreverses: true)) { shake.toggle() }; pin = "" }
                    }
                }
            Button("Разблокировать Face ID") { Task { await state.unlock() } }.buttonStyle(PrimaryButtonStyle())
            Spacer()
            Button("Выйти из аккаунта", role: .destructive) { state.logout() }
        }.padding(28).task { await state.unlock() }
    }
}
