import SwiftUI

@main
struct SemanaListaApp: App {
    @State private var store = AppStore()

    init() {
        ErrorLog.installGlobalHandlers()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(ErrorLog.shared)
                .tint(.terracotta)
        }
    }
}

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(ErrorLog.self) private var errorLog
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection = 0

    var body: some View {
        ZStack {
            if store.settings.onboarded {
                MainTabs(selection: $selection)
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }

            if store.isGenerating {
                GenerationOverlay()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: store.settings.onboarded)
        .animation(.easeInOut(duration: 0.2), value: store.isGenerating)
        .preferredColorScheme(store.appearance.colorScheme)
        .onAppear(perform: readLaunchArguments)
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                errorLog.markSessionActive()
            case .background:
                errorLog.markSessionFinished()
            default:
                break
            }
        }
        .task {
            if store.pendingLanguageRefresh, !store.isGenerating {
                store.pendingLanguageRefresh = false
                await store.regenerate()
            }
            #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("-mock-ai"), !store.isGenerating {
                await store.regenerate()
            }
            #endif
        }
    }

    private func readLaunchArguments() {
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-tab"), arguments.indices.contains(index + 1), let value = Int(arguments[index + 1]) {
            selection = min(max(value, 0), 3)
        }
    }
}

struct MainTabs: View {
    @Binding var selection: Int

    var body: some View {
        TabView(selection: $selection) {
            WeekView(goShopping: { selection = 1 })
                .tabItem {
                    Label("Semana", systemImage: "calendar")
                }
                .tag(0)

            ShoppingView()
                .tabItem {
                    Label("Compra", systemImage: "cart")
                }
                .tag(1)

            CookView()
                .tabItem {
                    Label("Cocina", systemImage: "flame")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Ajustes", systemImage: "slider.horizontal.3")
                }
                .tag(3)
        }
        .tint(.terracotta)
    }
}

struct GenerationOverlay: View {
    @Environment(AppStore.self) private var store
    @State private var pulse = false

    var body: some View {
        ZStack {
            Color(hex: 0x071A33).opacity(0.38)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(AppGradient.brand)
                        .frame(width: 82, height: 82)
                        .scaleEffect(pulse ? 1.07 : 0.94)
                        .shadow(color: Color.terracotta.opacity(0.35), radius: 24, y: 10)
                    Image(systemName: "sparkles")
                        .font(.system(size: 31, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(spacing: 6) {
                    Text("Cocinando tu semana")
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ink)

                    Text(store.generationStatus)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.inkSoft)
                        .multilineTextAlignment(.center)
                        .contentTransition(.opacity)
                        .frame(minHeight: 34)
                }

                ProgressView()
                    .tint(.terracotta)
                    .controlSize(.regular)

                Text("Menú, lista de la compra y tiempos de cocina.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Color.inkFaint)
            }
            .padding(28)
            .frame(maxWidth: 294)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: Color(hex: 0x071A33).opacity(0.24), radius: 36, y: 16)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(Color.white.opacity(0.65), lineWidth: 1)
            )
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
