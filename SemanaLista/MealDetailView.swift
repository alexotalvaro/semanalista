import SwiftUI

struct MealDetailSheet: View {
    let meal: Meal
    let date: Date
    let plan: WeekPlan

    @Environment(\.dismiss) private var dismiss

    private var preps: [Prep] {
        plan.prep(for: meal)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header

                        VStack(alignment: .leading, spacing: 10) {
                            sectionLabel("PREPARACIONES DEL BATCH")

                            VStack(spacing: 0) {
                                ForEach(Array(preps.enumerated()), id: \.element.id) { index, prep in
                                    NavigationLink(value: prep) {
                                        PrepLinkRow(prep: prep, portions: plan.people)
                                    }
                                    .buttonStyle(.plain)

                                    if index < preps.count - 1 {
                                        Hairline()
                                            .padding(.leading, 58)
                                    }
                                }
                            }
                            .card(padding: 0, radius: 20)

                            Text("Todo está cocinado. Calienta cada preparación por separado y monta el plato al momento.")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(Color.inkFaint)
                                .padding(.horizontal, 4)
                        }

                        if !meal.fresh.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                sectionLabel("PARA COMPLETAR")
                                VStack(spacing: 0) {
                                    ForEach(Array(meal.fresh.enumerated()), id: \.offset) { index, ingredient in
                                        HStack(spacing: 10) {
                                            Image(systemName: ingredient.aisle.symbol)
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundStyle(Color.olive)
                                                .frame(width: 26)
                                            Text(ingredient.name)
                                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                                .foregroundStyle(Color.ink)
                                            Spacer()
                                            Text(ingredient.formattedQuantity)
                                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                                .foregroundStyle(Color.inkSoft)
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 11)

                                        if index < meal.fresh.count - 1 {
                                            Hairline().padding(.leading, 50)
                                        }
                                    }
                                }
                                .card(padding: 0, radius: 20)
                            }
                        }

                        if !meal.note.isEmpty {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "lightbulb")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color.terracotta)
                                Text(meal.note)
                                    .font(.system(size: 13, design: .rounded))
                                    .foregroundStyle(Color.inkSoft)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.terracottaSoft.opacity(0.45))
                            )
                        }

                        HStack(spacing: 8) {
                            Image(systemName: "refrigerator")
                                .font(.system(size: 12))
                            Text("Pasa lo que vayas a comer a la nevera la noche anterior. No recalentar más de una vez.")
                                .font(.system(size: 10, design: .rounded))
                        }
                        .foregroundStyle(Color.inkFaint)
                        .padding(.horizontal, 4)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 6)
                    .padding(.bottom, 28)
                    .lockedScrollWidth()
                }
                .scrollIndicators(.hidden)
                .verticalOnlyScroll()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Detalle de la comida")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.inkSoft)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 19))
                            .foregroundStyle(Color.inkFaint)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationDestination(for: Prep.self) { prep in
                PrepDetailView(prep: prep)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: meal.slot.symbol)
                Text(meal.slot.label.uppercased())
                Text("·")
                Text(date.capitalizedSpanish())
            }
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .tracking(0.9)
            .foregroundStyle(Color.terracotta)

            Text(meal.title)
                .font(.system(size: 29, weight: .bold, design: .rounded))
                .tracking(-0.5)
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(plan.people) raciones · \(preps.count) preparaciones")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.inkFaint)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(L10n.t(text))
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .tracking(1.5)
            .foregroundStyle(Color.inkFaint)
            .padding(.horizontal, 4)
    }
}

struct PrepLinkRow: View {
    let prep: Prep
    let portions: Int

    var body: some View {
        HStack(spacing: 12) {
            Text(prep.emoji)
                .font(.system(size: 20))
                .frame(width: 42, height: 42)
                .background(Circle().fill(Color.paperDeep.opacity(0.7)))

            VStack(alignment: .leading, spacing: 4) {
                Text(prep.name)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ink)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 6) {
                    CategoryTag(category: prep.category, compact: true)
                    Text("\(portions) raciones")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.inkFaint)
                }
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.inkFaint)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

struct PrepDetailView: View {
    let prep: Prep

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    VStack(alignment: .leading, spacing: 10) {
                        sectionLabel(L10n.format("INGREDIENTES · %lld RACIONES", prep.servings))
                        VStack(spacing: 0) {
                            ForEach(Array(prep.ingredients.enumerated()), id: \.offset) { index, ingredient in
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(ingredient.pantry ? Color.oliveSoft : Color.terracottaSoft)
                                        .frame(width: 6, height: 6)
                                    Text(ingredient.name)
                                        .font(.system(size: 13, design: .rounded))
                                        .foregroundStyle(Color.ink)
                                    Spacer()
                                    Text(ingredient.formattedQuantity)
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Color.inkSoft)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)

                                if index < prep.ingredients.count - 1 {
                                    Hairline().padding(.leading, 30)
                                }
                            }
                        }
                        .card(padding: 0, radius: 20)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        sectionLabel("CÓMO SE HACE")
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(Array(prep.steps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 10) {
                                    Text("\(index + 1)")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                        .frame(width: 22, height: 22)
                                        .background(Circle().fill(Color.terracotta))
                                    Text(step)
                                        .font(.system(size: 13, design: .rounded))
                                        .foregroundStyle(Color.ink)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                        .card()
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        sectionLabel("PARA COMERLA")
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "flame")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.terracotta)
                                Text(prep.reheat)
                                    .font(.system(size: 13, design: .rounded))
                                    .foregroundStyle(Color.inkSoft)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Hairline()
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "refrigerator")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.olive)
                                Text("Aguanta hasta \(prep.storageDays) días en la nevera. Reparte en \(prep.tupperCount) táperes y etiqueta con la fecha.")
                                    .font(.system(size: 13, design: .rounded))
                                    .foregroundStyle(Color.inkSoft)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .card()
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)
                .padding(.bottom, 30)
                .lockedScrollWidth()
            }
            .scrollIndicators(.hidden)
            .verticalOnlyScroll()
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text(prep.emoji)
                    .font(.system(size: 30))
                    .frame(width: 60, height: 60)
                    .background(Circle().fill(Color.card))
                    .overlay(Circle().stroke(Color.line, lineWidth: 1))

                VStack(alignment: .leading, spacing: 6) {
                    Text(prep.name)
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                        .tracking(-0.4)
                        .foregroundStyle(Color.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    CategoryTag(category: prep.category)
                }
            }

            HStack(spacing: 6) {
                metaPill(L10n.format("%lld raciones", prep.servings), symbol: "takeoutbag.and.cup.and.straw")
                metaPill("\(prep.totalMinutes) min", symbol: "clock")
                metaPill(L10n.format("%lld táperes", prep.tupperCount), symbol: "square.stack.3d.up")
            }
        }
    }

    private func metaPill(_ text: String, symbol: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .semibold))
            Text(text)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(Color.inkSoft)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.card))
        .overlay(Capsule().stroke(Color.line, lineWidth: 1))
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(L10n.t(text))
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .tracking(1.4)
            .foregroundStyle(Color.inkFaint)
            .padding(.horizontal, 4)
    }
}
