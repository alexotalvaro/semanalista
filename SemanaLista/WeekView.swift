import SwiftUI

struct WeekView: View {
    @Environment(AppStore.self) private var store
    @Environment(ErrorLog.self) private var errorLog
    var goShopping: () -> Void = {}

    @State private var selectedMeal: SelectedMeal?
    @State private var confirmRegenerate = false
    @State private var sharePayload: SharePayload?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        header

                        if let notice = store.notice {
                            NoticeBanner(notice: notice) {
                                store.notice = nil
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        summaryCard
                        shoppingNudge

                        HStack(alignment: .firstTextBaseline) {
                            Text("TU MENÚ")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .tracking(1.6)
                                .foregroundStyle(Color.inkFaint)
                            Spacer()
                            Text("\(store.plan.mealCount) comidas · \(store.plan.people) personas")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.inkFaint)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .padding(.top, 4)

                        ForEach(Array(store.plan.days.enumerated()), id: \.offset) { index, day in
                            DayCard(
                                day: day,
                                index: index,
                                plan: store.plan,
                                onMeal: { meal in
                                    selectedMeal = SelectedMeal(
                                        id: "\(day.id)-\(meal.slot.rawValue)",
                                        meal: meal,
                                        date: store.plan.mealDate(index)
                                    )
                                }
                            )
                        }

                        disclaimer
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 26)
                    .lockedScrollWidth()
                }
                .scrollIndicators(.hidden)
                .verticalOnlyScroll()
            }
            .navigationBarHidden(true)
            .sheet(item: $selectedMeal) { selection in
                MealDetailSheet(
                    meal: selection.meal,
                    date: selection.date,
                    plan: store.plan
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $sharePayload) { payload in
                ActivityShareSheet(
                    items: payload.urls,
                    applicationActivities: [
                        SaveMenuImagesActivity(plan: store.plan) { result in
                            switch result {
                            case .success(let count):
                                store.notice = StoreNotice(
                                    kind: .success,
                                    text: count == 1
                                        ? L10n.t("Menú guardado en Fotos.")
                                        : L10n.format("Menú guardado en Fotos: %lld imágenes, una por página.", count)
                                )
                            case .failure(let error):
                                errorLog.log(
                                    error,
                                    context: L10n.t("Guardar el menú en Fotos"),
                                    category: .photos
                                )
                                store.notice = StoreNotice(
                                    kind: .warning,
                                    text: L10n.t("No se pudo guardar el menú en Fotos. Revisa el permiso en Ajustes › Semana Lista › Fotos.")
                                )
                            }
                        }
                    ]
                )
                .ignoresSafeArea()
            }
            .confirmationDialog(
                "¿Regenerar la semana?",
                isPresented: $confirmRegenerate,
                titleVisibility: .visible
            ) {
                Button(store.hasAPIKey ? L10n.t("Generar con IA") : L10n.t("Generar plan base")) {
                    Task { await store.regenerate() }
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text(store.hasAPIKey
                     ? L10n.t("Se hará una nueva petición a tu API y se sustituirá el menú, la compra y los tiempos actuales.")
                     : L10n.t("No hay clave de IA configurada: se generará el plan base."))
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.9), value: store.notice)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Fila superior separada del título: así la cabecera cabe igual en
            // un iPhone pequeño que en uno grande, sin comprimir el titular.
            HStack(alignment: .center, spacing: 10) {
                AIBadge(source: store.plan.source)

                Spacer(minLength: 4)

                HStack(spacing: 8) {
                    Button {
                        confirmRegenerate = true
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.terracotta)
                            .frame(width: 42, height: 42)
                            .background(Circle().fill(Color.card))
                            .overlay(Circle().stroke(Color.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Regenerar semana")

                    Button {
                        sharePDF()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.terracotta)
                            .frame(width: 42, height: 42)
                            .background(Circle().fill(Color.card))
                            .overlay(Circle().stroke(Color.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.t("Compartir menú"))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(store.plan.title)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .tracking(-1)
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(store.plan.subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 7) {
                Image(systemName: "calendar")
                    .font(.system(size: 11, weight: .semibold))
                Text(store.plan.rangeLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text("·")
                Text("\(store.plan.people) personas")
                    .lineLimit(1)
            }
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(Color.inkFaint)
        }
    }

    private var summaryCard: some View {
        HStack(spacing: 0) {
            stat(value: "\(store.plan.days.count)", label: L10n.t("días"), symbol: "calendar")
            statDivider
            stat(value: "\(store.plan.mealCount)", label: L10n.t("comidas"), symbol: "fork.knife")
            statDivider
            stat(value: "\(store.plan.preps.count)", label: L10n.t("preparaciones"), symbol: "takeoutbag.and.cup.and.straw")
            statDivider
            stat(value: durationLabel(store.plan.totalMinutes), label: L10n.t("de cocina"), symbol: "clock")
        }
        .card(padding: 14, radius: 22)
    }

    private func stat(value: String, label: String, symbol: String) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.terracotta)
                Text(value)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.inkFaint)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.line)
            .frame(width: 1, height: 26)
    }

    private var shoppingNudge: some View {
        Button(action: goShopping) {
            HStack(spacing: 12) {
                Image(systemName: "cart")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.terracotta)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.terracottaSoft))

                VStack(alignment: .leading, spacing: 2) {
                    Text("La compra de la semana")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ink)
                    Text(shoppingSubtitle)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Color.inkSoft)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.inkFaint)
            }
            .card(padding: 12, radius: 20)
        }
        .buttonStyle(.plain)
    }

    private var shoppingSubtitle: String {
        let total = store.shoppingItems.count
        if store.checkedCount == 0 {
            return L10n.format("%lld productos con cantidades exactas", total)
        }
        return L10n.format("%lld de %lld en el carrito", store.checkedCount, total)
    }

    private var disclaimer: some View {
        Text("Los menús generados por IA pueden contener errores. Revisa alérgenos, cocción y conservación antes de comer.")
            .font(.system(size: 10, design: .rounded))
            .foregroundStyle(Color.inkFaint)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.top, 8)
    }

    private func durationLabel(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours == 0 { return "\(mins) min" }
        return "\(hours) h \(String(format: "%02d", mins))"
    }

    private func sharePDF() {
        do {
            sharePayload = try MenuPDFExporter.export(plan: store.plan)
        } catch {
            errorLog.log(error, context: L10n.t("Compartir el menú en PDF"), category: .export)
            store.notice = StoreNotice(
                kind: .warning,
                text: L10n.t("No se pudo preparar el PDF del menú. Vuelve a intentarlo.")
            )
        }
    }
}

private struct SelectedMeal: Identifiable {
    let id: String
    let meal: Meal
    let date: Date
}

struct DayCard: View {
    let day: DayPlan
    let index: Int
    let plan: WeekPlan
    let onMeal: (Meal) -> Void

    private var date: Date { plan.mealDate(index) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(WeekDates.appWeekday(of: date).short)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(AppGradient.brand)
                    )
                    .shadow(color: Color.terracotta.opacity(0.22), radius: 6, y: 3)

                Text(WeekDates.appWeekday(of: date).name.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(Color.terracotta)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(date.capitalizedSpanish(short: true))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.inkFaint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 4)

                if Calendar.current.isDateInToday(date) {
                    Text("HOY")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .tracking(0.6)
                        .lineLimit(1)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(AppGradient.cyan))
                } else if index == 0 {
                    Text("DÍA DE COCINA")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .tracking(0.6)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .allowsTightening(true)
                        .foregroundStyle(Color.terracottaDeep)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.terracottaSoft))
                }
            }

            MealRow(meal: day.lunch, plan: plan) {
                onMeal(day.lunch)
            }

            Hairline()
                .padding(.leading, 50)

            MealRow(meal: day.dinner, plan: plan) {
                onMeal(day.dinner)
            }
        }
        .card(padding: 15, radius: 22)
    }
}

struct MealRow: View {
    let meal: Meal
    let plan: WeekPlan
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                VStack(spacing: 3) {
                    Image(systemName: meal.slot.symbol)
                        .font(.system(size: 12, weight: .semibold))
                    Text(meal.slot.label.uppercased())
                        .font(.system(size: 7, weight: .bold, design: .rounded))
                        .tracking(0.5)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .allowsTightening(true)
                }
                .foregroundStyle(meal.slot == .lunch ? Color.terracotta : Color.olive)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(meal.slot == .lunch ? Color.terracottaSoft.opacity(0.65) : Color.oliveSoft.opacity(0.65))
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(meal.title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ink)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    HStack(spacing: 4) {
                        ForEach(plan.prep(for: meal).prefix(3)) { prep in
                            Text(prep.emoji)
                                .font(.system(size: 11))
                        }
                        Text("\(plan.people) raciones")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.inkFaint)
                        if !meal.fresh.isEmpty {
                            Text("· +frescos")
                                .font(.system(size: 9, design: .rounded))
                                .foregroundStyle(Color.inkFaint)
                        }
                    }
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.inkFaint.opacity(0.8))
            }
        }
        .buttonStyle(.plain)
    }
}
