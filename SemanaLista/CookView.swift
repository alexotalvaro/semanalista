import SwiftUI

struct CookView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @State private var expanded: Set<String> = []

    private var progress: Double { store.cookProgress }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        header
                        hero
                        sequenceCard
                        nightBeforeCard

                        HStack(alignment: .firstTextBaseline) {
                            Text("PASO A PASO")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .tracking(1.6)
                                .foregroundStyle(Color.inkFaint)
                            Spacer()
                            Text("\(store.cookDoneCount) de \(store.timeline.count)")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.inkFaint)
                                .contentTransition(.numericText())
                        }
                        .padding(.top, 4)

                        VStack(spacing: 0) {
                            ForEach(Array(store.timeline.enumerated()), id: \.element.id) { index, block in
                                TimelineRow(
                                    block: block,
                                    checked: store.cookChecked.contains(block.id),
                                    expanded: expanded.contains(block.id),
                                    isLast: index == store.timeline.count - 1,
                                    onCheck: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            store.toggleCook(block)
                                        }
                                    },
                                    onTap: {
                                        guard block.isPrep else { return }
                                        withAnimation(.easeInOut(duration: 0.22)) {
                                            if expanded.contains(block.id) {
                                                expanded.remove(block.id)
                                            } else {
                                                expanded.insert(block.id)
                                            }
                                        }
                                    }
                                )
                            }
                        }

                        finishCard
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                    .lockedScrollWidth()
                }
                .scrollIndicators(.hidden)
                .verticalOnlyScroll()
            }
            .navigationBarHidden(true)
            .animation(.spring(response: 0.4, dampingFraction: 0.9), value: progress)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            ScreenHeader(
                eyebrow: "Día de cocina",
                title: "Cocina en orden",
                subtitle: store.plan.startDate.capitalizedSpanish()
            )

            if store.cookDoneCount > 0 {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        store.resetCooking()
                    }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.inkSoft)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.card))
                        .overlay(Circle().stroke(Color.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.t("Reiniciar progreso de cocina"))
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                HStack(spacing: 5) {
                    Circle()
                        .fill(progress >= 0.999 ? Color(hex: 0x67E8F9) : Color.white.opacity(0.85))
                        .frame(width: 6, height: 6)
                    Text(progress >= 0.999 ? "SEMANA LISTA" : "BATCH DAY")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.4)
                        .foregroundStyle(Color.white.opacity(0.85))
                }

                Spacer()

                Text("\(store.plan.preps.count) preparaciones")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.62))
            }

            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text(store.plan.startDateForCooking.timeLabel)
                    .font(.system(size: 39, weight: .bold, design: .rounded))
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.4))
                Text(store.plan.endDate.timeLabel)
                    .font(.system(size: 39, weight: .bold, design: .rounded))
                Spacer(minLength: 0)
            }
            .foregroundStyle(Color.white)

            Text("\(durationLabel(store.plan.totalMinutes)) · \(store.plan.mealCount) comidas · sin fuegos en paralelo")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.68))

            VStack(spacing: 6) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.16))
                        Capsule()
                            .fill(progress >= 0.999
                                  ? AppGradient.cyan
                                  : LinearGradient(
                                        colors: [Color(hex: 0x93C5FD), Color.white],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                            .frame(width: max(0, proxy.size.width * progress))
                    }
                }
                .frame(height: 5)

                HStack {
                    Text(progress >= 0.999 ? "¡Todo cocinado!" : "\(store.cookDoneCount) de \(store.timeline.count) pasos")
                    Spacer()
                    Text("\(Int(progress * 100))%")
                }
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.6))
            }
        }
        .padding(18)
        .background(
            ZStack {
                AppGradient.hero
                Circle()
                    .fill(Color(hex: 0x67E8F9).opacity(0.22))
                    .frame(width: 180, height: 180)
                    .blur(radius: 34)
                    .offset(x: 135, y: 75)
                Circle()
                    .fill(Color(hex: 0x2E6BFF).opacity(0.25))
                    .frame(width: 150, height: 150)
                    .blur(radius: 30)
                    .offset(x: -120, y: -70)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: Color(hex: 0x0A2540).opacity(0.28), radius: 24, y: 14)
    }

    private var sequenceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.terracotta)
                Text("ORDEN DE COCINA")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.3)
                    .foregroundStyle(Color.inkFaint)
                Spacer()
                if store.plan.preps.contains(where: { $0.category == .legumbre }) {
                    Text("1 legumbre")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.olive)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.oliveSoft))
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(Array(store.plan.orderedPreps.enumerated()), id: \.element.id) { index, prep in
                        HStack(spacing: 3) {
                            Text(prep.emoji)
                                .font(.system(size: 11))
                            Text(shortName(prep.name))
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.inkSoft)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.paper))
                        .overlay(Capsule().stroke(Color.line, lineWidth: 1))

                        if index < store.plan.orderedPreps.count - 1 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(Color.inkFaint.opacity(0.6))
                        }
                    }
                }
                .padding(.vertical, 1)
            }

            Text("Una preparación detrás de otra. Si algo se adelanta, apaga el fuego y espera: no hace falta cocinar dos guisos a la vez.")
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(Color.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 14, radius: 20)
    }

    private var nightBeforeCard: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "moon.stars")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.olive)
                .frame(width: 34, height: 34)
                .background(
                    Circle().fill(
                        colorScheme == .dark
                            ? Color.olive.opacity(0.16)
                            : Color.white.opacity(0.7)
                    )
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("La noche antes")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ink)
                Text(store.plan.nightBefore)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Color.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppGradient.cyanSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.olive.opacity(0.16), lineWidth: 1)
        )
    }

    private var finishCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 9) {
                Text("🧊")
                    .font(.system(size: 18))
                Text("Al terminar")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ink)
                Spacer()
                Text("\(store.plan.mealCount) comidas")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.terracottaDeep)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.terracottaSoft))
            }

            VStack(alignment: .leading, spacing: 9) {
                finishRow("Deja enfriar sin tapar antes de cerrar el táper.")
                finishRow("Etiqueta con el nombre y la fecha de cocción.")
                finishRow("Nevera 4 días como máximo; congela lo que no vayas a comer.")
            }

            if !store.plan.notes.isEmpty {
                Hairline()
                Text(store.plan.notes)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Color.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card()
    }

    private func finishRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.olive)
                .padding(.top, 2)
            Text(L10n.t(text))
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Color.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func shortName(_ name: String) -> String {
        let words = name.split(separator: " ")
        return words.prefix(2).joined(separator: " ")
    }

    private func durationLabel(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours == 0 { return "\(mins) min" }
        return "\(hours) h \(String(format: "%02d", mins)) min"
    }
}

struct TimelineRow: View {
    let block: TimelineBlock
    let checked: Bool
    let expanded: Bool
    let isLast: Bool
    let onCheck: () -> Void
    let onTap: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(block.start.timeLabel)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(block.isPrep ? Color.ink : Color.inkFaint)
                    .monospacedDigit()
                Text(block.end.timeLabel)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.inkFaint)
                    .monospacedDigit()
            }
            .frame(width: 42)
            .padding(.top, 13)

            VStack(spacing: 0) {
                Circle()
                    .fill(checked ? Color.olive : (block.isPrep ? Color.terracotta : Color.inkFaint))
                    .frame(width: 8, height: 8)
                    .overlay(Circle().stroke(Color.paper, lineWidth: 2))
                    .padding(.top, 15)

                if !isLast {
                    Rectangle()
                        .fill(Color.line)
                        .frame(width: 1.5)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 12)

            content
                .padding(.bottom, 8)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 9) {
                Text(block.emoji)
                    .font(.system(size: block.isPrep ? 20 : 15))
                    .frame(width: block.isPrep ? 38 : 30, height: block.isPrep ? 38 : 30)
                    .background(Circle().fill(Color.paperDeep.opacity(0.6)))

                VStack(alignment: .leading, spacing: 4) {
                    Text(block.title)
                        .font(.system(size: block.isPrep ? 14 : 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(checked ? Color.inkFaint : Color.ink)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 6) {
                        if let prep = block.prep {
                            CategoryTag(category: prep.category, compact: true)
                            Text("\(prep.servings) raciones · \(prep.tupperCount) táperes")
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.inkFaint)
                        } else {
                            Text(block.subtitle)
                                .font(.system(size: 9, design: .rounded))
                                .foregroundStyle(Color.inkFaint)
                        }
                    }
                }

                Spacer(minLength: 2)

                Button(action: onCheck) {
                    Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 21, weight: .regular))
                        .foregroundStyle(checked ? Color.olive : Color.inkFaint.opacity(0.55))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(checked ? L10n.t("Desmarcar paso") : L10n.t("Marcar paso como hecho"))
            }

            if block.isPrep, expanded, let prep = block.prep {
                Hairline()
                    .padding(.vertical, 9)
                    .padding(.leading, 47)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(prep.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 7) {
                            Text("\(index + 1).")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.terracotta)
                                .frame(width: 14, alignment: .trailing)
                            Text(step)
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(Color.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    HStack(alignment: .top, spacing: 7) {
                        Image(systemName: "flame")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.terracotta)
                            .frame(width: 14, alignment: .trailing)
                            .padding(.top, 2)
                        Text(prep.reheat)
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(Color.inkFaint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.leading, 47)
            }

            if block.isPrep, !expanded {
                HStack(spacing: 3) {
                    Text("Ver los \(block.minutes) min de cocina")
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                }
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(Color.inkFaint)
                .padding(.leading, 47)
                .padding(.top, 7)
            }
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(checked ? Color.card.opacity(0.55) : Color.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(Color.line.opacity(checked ? 0.5 : 0.9), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .opacity(checked ? 0.72 : 1)
    }
}
