import SwiftUI

struct OnboardingView: View {
    @Environment(AppStore.self) private var store
    @State private var step: Int

    private let totalSteps = 4

    init() {
        var initial = 0
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-onboarding-step"), arguments.indices.contains(index + 1) {
            initial = min(max(Int(arguments[index + 1]) ?? 0, 0), 3)
        }
        #endif
        _step = State(initialValue: initial)
    }

    var body: some View {
        @Bindable var store = store

        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                topBar

                ScrollView {
                    VStack(spacing: 24) {
                        switch step {
                        case 0:
                            welcomeStep
                                .transition(stepTransition)
                        case 1:
                            householdStep(store: $store)
                                .transition(stepTransition)
                        case 2:
                            batchStep(store: $store)
                                .transition(stepTransition)
                        default:
                            aiStep(store: $store)
                                .transition(stepTransition)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                    .lockedScrollWidth()
                }
                .scrollIndicators(.hidden)
                .verticalOnlyScroll()
                .scrollDismissesKeyboard(.interactively)

                bottomBar(store: $store)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: step)
    }

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            BrandMark(size: 34)
            VStack(alignment: .leading, spacing: 0) {
                Text("Semana Lista")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ink)
                Text("Batch cooking real")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(Color.inkFaint)
            }

            Spacer()

            HStack(spacing: 5) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Capsule()
                        .fill(index == step ? Color.terracotta : Color.line)
                        .frame(width: index == step ? 18 : 6, height: 6)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }

    // MARK: - Paso 0

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingHero()

            VStack(alignment: .leading, spacing: 10) {
                Text("Cocina una vez.\nCome toda la semana.")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .tracking(-1)
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Tu menú de 7 días, la compra con las cantidades exactas y un único día de cocina. Sin lentejas y alubias a la vez.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                featureRow(symbol: "calendar", title: "Menú de 7 días", text: "Comida y cena, montadas con lo que cocinas.")
                featureRow(symbol: "cart", title: "Compra sin cuentas", text: "Cantidades sumadas por ración y agrupadas por pasillo.")
                featureRow(symbol: "flame", title: "Cocina en orden", text: "Legumbre, arroz, pollo… una cosa detrás de otra.")
            }
        }
    }

    private func featureRow(symbol: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.terracotta)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.terracottaSoft))
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t(title))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ink)
                Text(L10n.t(text))
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Color.inkSoft)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Paso 1

    private func householdStep(store: Bindable<AppStore>) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            ScreenHeader(
                eyebrow: "Paso 1 · La mesa",
                title: "¿Para quién cocinas?",
                subtitle: "Calculamos las raciones de cada comida y las cantidades de la compra."
            )

            VStack(spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Comensales")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.ink)
                        Text("raciones por comida")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Color.inkFaint)
                    }
                    Spacer()
                    HStack(spacing: 16) {
                        stepButton(symbol: "minus") {
                            store.wrappedValue.settings.people = max(1, store.wrappedValue.settings.people - 1)
                        }
                        Text("\(store.wrappedValue.settings.people)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ink)
                            .monospacedDigit()
                            .frame(minWidth: 38)
                            .contentTransition(.numericText())
                        stepButton(symbol: "plus") {
                            store.wrappedValue.settings.people = min(8, store.wrappedValue.settings.people + 1)
                        }
                    }
                }
            }
            .card()

            VStack(alignment: .leading, spacing: 12) {
                Text("¿Algo que evitar?")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ink)
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(Diet.allCases) { diet in
                        SelectChip(title: diet.label, selected: store.wrappedValue.settings.diets.contains(diet)) {
                            store.wrappedValue.settings.toggleDiet(diet)
                        }
                    }
                }

                Text("La vegana no incluye carne, pescado, huevo ni lácteos.")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(Color.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()

            VStack(spacing: 12) {
                inputRow(icon: "exclamationmark.triangle", placeholder: "Alergias (ej.: frutos secos, lactosa)", text: store.settings.allergies)
                Hairline()
                inputRow(icon: "hand.raised", placeholder: "No me gustan (ej.: lentejas, arroz, pollo)", text: store.settings.dislikes)
            }
            .card()
        }
    }

    // MARK: - Paso 2

    private func batchStep(store: Bindable<AppStore>) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            ScreenHeader(
                eyebrow: "Paso 2 · El día",
                title: "Tu tarde de cocina",
                subtitle: "Elige cuándo cocinas y cuánto tiempo quieres estar entre fogones."
            )

            VStack(alignment: .leading, spacing: 14) {
                Text("Día de batch")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ink)

                HStack(spacing: 6) {
                    ForEach(AppWeekday.allCases) { weekday in
                        let selected = store.wrappedValue.settings.batchWeekday == weekday
                        Button {
                            store.wrappedValue.settings.batchWeekday = weekday
                        } label: {
                            Text(weekday.short)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(selected ? .white : Color.inkSoft)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(selected ? AnyShapeStyle(AppGradient.brand) : AnyShapeStyle(Color.paper))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Hairline()

                HStack {
                    Label("Hora de empezar", systemImage: "clock")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ink)
                    Spacer()
                    DatePicker(
                        "",
                        selection: startTimeBinding(store: store),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .tint(.terracotta)
                }
            }
            .card()

            VStack(alignment: .leading, spacing: 12) {
                Text("Tiempo disponible")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ink)

                HStack(spacing: 8) {
                    budgetButton(hours: 3, minutes: 180, store: store)
                    budgetButton(hours: 4, minutes: 240, store: store)
                    budgetButton(hours: 5, minutes: 300, store: store)
                }

                Text("Incluye organización, enfriado y guardado. La IA ajusta el número de preparaciones a tu tiempo.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Color.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()

            VStack(alignment: .leading, spacing: 12) {
                Text("¿Algo más que deba saber?")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ink)
                TextField("Ej.: comidas para llevar al trabajo, poco picante…", text: store.settings.notes, axis: .vertical)
                    .font(.system(size: 14, design: .rounded))
                    .lineLimit(2...4)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.paper))
            }
            .card()
        }
    }

    // MARK: - Paso 3

    private func aiStep(store: Bindable<AppStore>) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            ScreenHeader(
                eyebrow: "Paso 3 · La IA",
                title: "Menús con IA",
                subtitle: "Conecta tu proveedor. La app envía tus preferencias y recibe un menú semanal en JSON."
            )

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.olive)
                Text("Tu clave se guarda en el Keychain de este iPhone y solo se envía al proveedor que elijas. No pasa por ningún servidor nuestro.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Color.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(13)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.oliveSoft.opacity(0.6)))

            VStack(spacing: 14) {
                HStack {
                    Text("Proveedor")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ink)
                    Spacer()
                    Menu {
                        ForEach(APIProvider.allCases) { provider in
                            Button(provider.name) {
                                store.wrappedValue.selectProvider(provider)
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(store.wrappedValue.settings.provider.name)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.terracotta)
                    }
                }

                Hairline()

                HStack(spacing: 10) {
                    Image(systemName: "key")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.inkFaint)
                    SecureField(store.wrappedValue.settings.provider.keyHint, text: store.apiKey)
                        .font(.system(size: 14, design: .monospaced))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Hairline()

                HStack(spacing: 10) {
                    Image(systemName: "cpu")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.inkFaint)
                    TextField("Modelo", text: store.settings.model)
                        .font(.system(size: 13, design: .monospaced))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                ModelPresetMenu(provider: store.wrappedValue.settings.provider, model: store.settings.model)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .card()

            if let link = keyURL(for: store.wrappedValue.settings.provider) {
                Link(destination: link) {
                    HStack(spacing: 6) {
                        Text("Consigue una clave de \(store.wrappedValue.settings.provider.name)")
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.terracotta)
                }
            }

            Text("La IA puede equivocarse con alérgenos o cantidades. Revisa siempre la lista antes de comprar.")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Color.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Barra inferior

    private func bottomBar(store: Bindable<AppStore>) -> some View {
        VStack(spacing: 10) {
            if step == 0 {
                Button("Empezar") {
                    step = 1
                }
                .buttonStyle(PrimaryButtonStyle())
            } else if step < 3 {
                HStack(spacing: 12) {
                    Button {
                        step -= 1
                    } label: {
                        Text("Atrás")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.inkSoft)
                            .frame(width: 70)
                    }
                    .buttonStyle(.plain)

                    Button("Continuar") {
                        step += 1
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            } else {
                Button {
                    store.wrappedValue.finishOnboarding()
                    Task { await store.wrappedValue.regenerate() }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "sparkles")
                        Text("Generar mi semana")
                    }
                }
                .buttonStyle(PrimaryButtonStyle(enabled: store.wrappedValue.hasAPIKey))
                .disabled(!store.wrappedValue.hasAPIKey)

                Button("Usar un plan base sin IA") {
                    store.wrappedValue.startWithLocalPlan()
                }
                .buttonStyle(SecondaryButtonStyle())

                Button("Atrás") {
                    step -= 1
                }
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.inkSoft)
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(
            LinearGradient(
                colors: [Color.paper.opacity(0), Color.paper.opacity(0.92), Color.paper],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Piezas

    private func stepButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.terracotta)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.terracottaSoft))
        }
        .buttonStyle(.plain)
    }

    private func inputRow(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(Color.inkFaint)
            TextField(L10n.t(placeholder), text: text)
                .font(.system(size: 13, design: .rounded))
                .textInputAutocapitalization(.sentences)
        }
    }

    private func budgetButton(hours: Int, minutes: Int, store: Bindable<AppStore>) -> some View {
        let selected = store.wrappedValue.settings.timeBudget == minutes
        return Button {
            store.wrappedValue.settings.timeBudget = minutes
        } label: {
            VStack(spacing: 2) {
                Text("\(hours) h")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                Text(hours == 3 ? L10n.t("exprés") : hours == 4 ? L10n.t("ideal") : L10n.t("con calma"))
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(selected ? .white : Color.inkSoft)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selected ? AnyShapeStyle(AppGradient.brand) : AnyShapeStyle(Color.paper))
            )
        }
        .buttonStyle(.plain)
    }

    private func startTimeBinding(store: Bindable<AppStore>) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: store.wrappedValue.settings.startHour,
                    minute: store.wrappedValue.settings.startMinute,
                    second: 0,
                    of: .now
                ) ?? .now
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                store.wrappedValue.settings.startHour = components.hour ?? 10
                store.wrappedValue.settings.startMinute = components.minute ?? 0
            }
        )
    }

    private func keyURL(for provider: APIProvider) -> URL? {
        switch provider {
        case .openai: URL(string: "https://platform.openai.com/api-keys")
        case .openrouter: URL(string: "https://openrouter.ai/keys")
        case .groq: URL(string: "https://console.groq.com/keys")
        case .opencodeGo: URL(string: "https://opencode.ai/console/go")
        case .custom: nil
        }
    }
}

// MARK: - Marca y hero

struct BrandMark: View {
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .fill(AppGradient.brand)
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.28), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
            Image(systemName: "fork.knife")
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: Color.terracotta.opacity(0.3), radius: 10, y: 5)
    }
}

struct OnboardingHero: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.terracotta.opacity(0.12))
                .frame(width: 270, height: 270)
                .blur(radius: 45)

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.terracotta.opacity(0.14))
                .frame(width: 300, height: 235)
                .rotationEffect(.degrees(6))
                .offset(x: 7, y: 5)

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.olive.opacity(0.12))
                .frame(width: 305, height: 235)
                .rotationEffect(.degrees(-5))
                .offset(x: -7, y: 3)

            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    Text("DOMINGO · 10:00")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(Color.terracotta)
                    Spacer()
                    HStack(spacing: 3) {
                        Image(systemName: "sparkles")
                        Text("1 tarde")
                    }
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(AppGradient.brand))
                }

                Text("Todo cocinado")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ink)

                VStack(spacing: 7) {
                    heroRow(emoji: "🫘", title: L10n.t("Lentejas"), time: "35 min", highlight: true)
                    heroRow(emoji: "🍚", title: L10n.t("Arroz"), time: "20 min", highlight: false)
                    heroRow(emoji: "🍗", title: L10n.t("Pollo al horno"), time: "40 min", highlight: false)
                }

                HStack {
                    Label("14 comidas", systemImage: "takeoutbag.and.cup.and.straw")
                    Spacer()
                    Text("3 h 02")
                }
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.inkSoft)
            }
            .padding(18)
            .frame(width: 292)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(AppGradient.card)
                    .shadow(color: Color(hex: 0x0A2540).opacity(0.14), radius: 24, y: 13)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(AppGradient.stroke, lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity)
        .frame(height: 252)
        .padding(.top, 8)
    }

    private func heroRow(emoji: String, title: String, time: String, highlight: Bool) -> some View {
        HStack(spacing: 9) {
            Text(emoji)
                .font(.system(size: 15))
                .frame(width: 28, height: 28)
                .background(Circle().fill(highlight ? Color.terracottaSoft : Color.paper))
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ink)
            Spacer()
            Text(time)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Color.inkFaint)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(highlight ? Color.paperDeep.opacity(0.55) : Color.clear)
        )
    }
}
