import SwiftUI

struct SettingsView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        ScreenHeader(
                            eyebrow: "Tu configuración",
                            title: "Ajustes",
                            subtitle: "Cambia lo que necesites y vuelve a generar la semana para aplicarlo."
                        )
                        .padding(.bottom, 2)

                        if let notice = store.notice {
                            NoticeBanner(notice: notice) {
                                store.notice = nil
                            }
                        }

                        AppearanceCard()
                        HouseholdSettingsCard()
                        BatchSettingsCard()
                        AISettingsCard()
                        RegenerateCard()
                        PlanInfoCard()
                        ErrorLogCard()
                        AboutCard()
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                    .lockedScrollWidth()
                }
                .scrollIndicators(.hidden)
                .verticalOnlyScroll()
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Casa

struct HouseholdSettingsCard: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store

        SettingsCard(title: "La mesa", symbol: "person.2") {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Comensales")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ink)
                    Text("raciones por comida")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(Color.inkFaint)
                }
                Spacer()
                HStack(spacing: 14) {
                    smallStepButton(symbol: "minus") {
                        store.settings.people = max(1, store.settings.people - 1)
                    }
                    Text("\(store.settings.people)")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ink)
                        .monospacedDigit()
                        .frame(minWidth: 32)
                        .contentTransition(.numericText())
                    smallStepButton(symbol: "plus") {
                        store.settings.people = min(8, store.settings.people + 1)
                    }
                }
            }

            Hairline()

            FlowLayout(spacing: 7, lineSpacing: 7) {
                ForEach(Diet.allCases) { diet in
                    SelectChip(title: diet.label, selected: store.settings.diets.contains(diet)) {
                        store.settings.toggleDiet(diet)
                    }
                }
            }

            Text("La vegana no incluye carne, pescado, huevo ni lácteos.")
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(Color.inkFaint)
                .fixedSize(horizontal: false, vertical: true)

            Hairline()

            settingsField(
                title: "Alergias o intolerancias",
                placeholder: "Ej.: frutos secos, lactosa…",
                text: $store.settings.allergies
            )

            settingsField(
                title: "No me gusta",
                placeholder: "Ej.: lentejas, arroz, pollo…",
                text: $store.settings.dislikes
            )

            Text("Separa los alimentos con comas. Se aplican a todo el menú: preparaciones, frescos y títulos.")
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(Color.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Batch

struct BatchSettingsCard: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store

        SettingsCard(title: "Día de cocina", symbol: "flame") {
            Text("Elige el día en que vas a cocinar toda la semana.")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Color.inkFaint)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 5) {
                ForEach(AppWeekday.allCases) { weekday in
                    let selected = store.settings.batchWeekday == weekday
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            store.settings.batchWeekday = weekday
                        }
                    } label: {
                        Text(weekday.short)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(selected ? .white : Color.inkSoft)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(selected ? AnyShapeStyle(AppGradient.brand) : AnyShapeStyle(Color.paper))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Label("Hora de empezar", systemImage: "clock")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ink)
                Spacer()
                DatePicker("", selection: startTimeBinding(store: $store), displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .tint(.terracotta)
            }

            Hairline()

            VStack(alignment: .leading, spacing: 9) {
                Text("Tiempo disponible")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ink)

                HStack(spacing: 7) {
                    ForEach([180, 240, 300], id: \.self) { minutes in
                        let selected = store.settings.timeBudget == minutes
                        Button {
                            store.settings.timeBudget = minutes
                        } label: {
                            Text(minutes == 180 ? "3 h" : minutes == 240 ? "4 h" : "5 h")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(selected ? .white : Color.inkSoft)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .fill(selected ? AnyShapeStyle(AppGradient.brand) : AnyShapeStyle(Color.paper))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Hairline()

            settingsField(
                title: "Notas para la IA",
                placeholder: "Ej.: táper para el trabajo, poca sal…",
                text: $store.settings.notes
            )
        }
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
}

// MARK: - Apariencia

struct AppearanceCard: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        SettingsCard(title: "Apariencia", symbol: "circle.lefthalf.filled") {
            Text("Elige cómo se ve la app. Automático sigue el modo del iPhone.")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Color.inkFaint)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                ForEach(AppAppearance.allCases) { option in
                    let selected = store.appearance == option
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            store.appearance = option
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: option.symbol)
                                .font(.system(size: 16, weight: .semibold))
                            Text(option.label)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(selected ? .white : Color.inkSoft)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(selected ? AnyShapeStyle(AppGradient.brand) : AnyShapeStyle(Color.paper))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(selected ? Color.clear : Color.line, lineWidth: 1)
                        )
                        .shadow(color: selected ? Color.terracotta.opacity(0.2) : .clear, radius: 9, y: 4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.label)
                }
            }
        }
    }
}

// MARK: - IA

struct AISettingsCard: View {
    @Environment(AppStore.self) private var store
    @State private var showAdvanced = false

    var body: some View {
        @Bindable var store = store

        SettingsCard(title: "Inteligencia artificial", symbol: "sparkles") {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.settings.provider.name)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ink)
                    Text(store.hasAPIKey ? L10n.t("Clave guardada en el Keychain") : L10n.t("Sin clave: se usará el plan base"))
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(store.hasAPIKey ? Color.olive : Color.terracotta)
                }

                Spacer()

                Menu {
                    ForEach(APIProvider.allCases) { provider in
                        Button(provider.name) {
                            store.selectProvider(provider)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Cambiar")
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.terracotta)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.terracottaSoft.opacity(0.7)))
                }
            }

            HStack(spacing: 9) {
                Image(systemName: "key")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.inkFaint)
                SecureField(store.settings.provider.keyHint, text: $store.apiKey)
                    .font(.system(size: 13, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if store.hasAPIKey {
                    Button {
                        store.apiKey = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.inkFaint)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 11).fill(Color.paper))

            HStack(spacing: 9) {
                Image(systemName: "cpu")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.inkFaint)
                TextField("Modelo", text: $store.settings.model)
                    .font(.system(size: 12, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 11).fill(Color.paper))

            ModelPresetMenu(provider: store.settings.provider, model: $store.settings.model)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showAdvanced.toggle()
                }
            } label: {
                HStack(spacing: 5) {
                    Text("Conexión avanzada")
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(showAdvanced ? 0 : -90))
                }
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.inkSoft)
            }
            .buttonStyle(.plain)

            if showAdvanced {
                VStack(alignment: .leading, spacing: 5) {
                    Text("URL base compatible con OpenAI")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.inkFaint)
                    TextField("https://api.openai.com/v1", text: $store.settings.apiBaseURL)
                        .font(.system(size: 11, design: .monospaced))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 11).fill(Color.paper))
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if let link = keyURL(for: store.settings.provider) {
                Link(destination: link) {
                    HStack(spacing: 4) {
                        Text("Consigue una clave de \(store.settings.provider.name)")
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.terracotta)
                }
            }

            Text("La clave se guarda solo en este iPhone. Las peticiones van directamente al proveedor elegido.")
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(Color.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
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

// MARK: - Generar

struct RegenerateCard: View {
    @Environment(AppStore.self) private var store
    @State private var confirm = false

    var body: some View {
        VStack(spacing: 11) {
            Button {
                confirm = true
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "sparkles")
                    Text(store.hasAPIKey ? L10n.t("Generar nueva semana") : L10n.t("Generar plan base"))
                }
            }
            .buttonStyle(PrimaryButtonStyle(enabled: !store.isGenerating))
            .disabled(store.isGenerating)

            Button("Volver al plan de ejemplo") {
                withAnimation {
                    store.regenerateLocal()
                }
            }
            .buttonStyle(SecondaryButtonStyle())

            Text(store.hasAPIKey
                 ? L10n.format("Se hará una petición a %@ con tus preferencias actuales. Cada regeneración cambia la proteína y la base del menú.", store.settings.provider.name)
                 : L10n.t("Añade una clave arriba para que el menú lo diseñe la IA. Sin clave se usa el plan base, que también cambia los ingredientes en cada regeneración."))
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(Color.inkFaint)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppGradient.brandSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.terracotta.opacity(0.14), lineWidth: 1)
        )
        .confirmationDialog(
            "¿Sustituir la semana actual?",
            isPresented: $confirm,
            titleVisibility: .visible
        ) {
            Button("Sí, generar") {
                Task { await store.regenerate() }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se borrarán las marcas de la compra y el progreso de cocina.")
        }
    }
}

// MARK: - Info

struct PlanInfoCard: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        SettingsCard(title: "Plan actual", symbol: "doc.text") {
            infoRow("Origen", store.plan.source.label)
            Hairline()
            infoRow("Periodo", store.plan.rangeLabel)
            Hairline()
            infoRow("Día de cocina", "\(store.plan.startDate.capitalizedSpanish()) · \(store.plan.startDateForCooking.timeLabel)")
            Hairline()
            infoRow("Duración", L10n.format("%lld min · %lld preparaciones", store.plan.totalMinutes, store.plan.preps.count))
        }
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(L10n.t(title))
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Color.inkSoft)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct AboutCard: View {
    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                BrandMark(size: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Semana Lista")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ink)
                    Text("Versión \(version)")
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(Color.inkFaint)
                }
                Spacer()
            }

            Text("Menú semanal, compra exacta y un único día de cocina. Pensada para cocinar de verdad, no para fingir que cocinas.")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Color.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            Text("Revisa siempre alérgenos y tiempos de conservación. La IA propone; tú decides.")
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(Color.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

// MARK: - Piezas

struct SettingsCard<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder let content: Content

    init(title: String, symbol: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.symbol = symbol
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.terracotta)
                Text(L10n.t(title).uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.3)
                    .foregroundStyle(Color.inkFaint)
                Spacer()
            }

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

func settingsField(title: String, placeholder: String, text: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(L10n.t(title))
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.inkFaint)
        TextField(L10n.t(placeholder), text: text, axis: .vertical)
            .font(.system(size: 13, design: .rounded))
            .lineLimit(1...3)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 11).fill(Color.paper))
    }
}

func smallStepButton(symbol: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Image(systemName: symbol)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Color.terracotta)
            .frame(width: 30, height: 30)
            .background(Circle().fill(Color.terracottaSoft))
    }
    .buttonStyle(.plain)
}
