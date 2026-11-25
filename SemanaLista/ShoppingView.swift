import SwiftUI

struct ShoppingView: View {
    @Environment(AppStore.self) private var store
    @State private var showPantry = true

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        header
                        progressCard

                        ForEach(store.shoppingSections) { section in
                            ShoppingSectionCard(section: section) { item in
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                                    store.toggleShopping(item)
                                }
                            }
                        }

                        if !store.pantryItems.isEmpty {
                            pantryCard
                        }

                        footer
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
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ScreenHeader(
                    eyebrow: L10n.format("Semana %@", store.plan.rangeLabel),
                    title: "La compra",
                    subtitle: L10n.format("%lld personas · %lld productos · cantidades ya sumadas", store.plan.people, store.shoppingItems.count)
                )

                ShareLink(item: store.shareText) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.terracotta)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(Color.card))
                        .overlay(Circle().stroke(Color.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.t("Compartir compra"))
            }
        }
    }

    private var progressCard: some View {
        HStack(spacing: 15) {
            ZStack {
                Circle()
                    .stroke(Color.line, lineWidth: 7)
                Circle()
                    .trim(from: 0, to: store.shoppingProgress > 0 ? max(0.001, store.shoppingProgress) : 0)
                    .stroke(
                        store.shoppingProgress >= 0.999
                            ? AnyShapeStyle(AppGradient.cyan)
                            : AnyShapeStyle(AppGradient.brand),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5, dampingFraction: 0.85), value: store.shoppingProgress)

                if store.shoppingProgress >= 0.999 {
                    Image(systemName: "checkmark")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.olive)
                } else {
                    Text("\(Int(store.shoppingProgress * 100))%")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ink)
                }
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 3) {
                Text(store.shoppingProgress >= 0.999 ? "¡Compra lista!" : "\(store.checkedCount) de \(store.shoppingItems.count)")
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ink)
                    .contentTransition(.numericText())
                Text(store.shoppingProgress >= 0.999 ? "Ya puedes empezar a cocinar" : "productos en el carrito")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.inkSoft)
            }

            Spacer(minLength: 4)

            if store.checkedCount > 0 {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        store.resetShopping()
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Reset")
                            .font(.system(size: 8, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(Color.inkSoft)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.paper))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Desmarcar toda la lista")
            }
        }
        .card(padding: 15, radius: 24)
    }

    private var pantryCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    showPantry.toggle()
                }
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "cabinet")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.olive)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Despensa")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ink)
                        Text("Revisa lo que ya tienes en casa")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(Color.inkFaint)
                    }
                    Spacer()
                    Text("\(store.pantryItems.filter(\.checked).count)/\(store.pantryItems.count)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.inkFaint)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.inkFaint)
                        .rotationEffect(.degrees(showPantry ? 0 : -90))
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            if showPantry {
                Hairline()
                ForEach(Array(store.pantryItems.enumerated()), id: \.element.id) { index, item in
                    ShoppingRow(item: item, muted: true) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            store.toggleShopping(item)
                        }
                    }
                    if index < store.pantryItems.count - 1 {
                        Hairline().padding(.leading, 50)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.card.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.line, lineWidth: 1)
        )
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Text("Cantidades calculadas para \(store.plan.people) personas y \(store.plan.mealCount) comidas.")
            Text("Toca un producto para marcarlo. La lista se guarda automáticamente.")
        }
        .font(.system(size: 10, design: .rounded))
        .foregroundStyle(Color.inkFaint)
        .multilineTextAlignment(.center)
        .padding(.top, 6)
    }
}

struct ShoppingSectionCard: View {
    let section: ShoppingSection
    let onToggle: (ShoppingItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: section.aisle.symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.terracotta)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.terracottaSoft.opacity(0.6)))

                Text(section.aisle.title.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(Color.inkSoft)

                Spacer()

                let done = section.items.filter(\.checked).count
                Text("\(done)/\(section.items.count)")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.inkFaint)
            }
            .padding(.horizontal, 15)
            .padding(.top, 14)
            .padding(.bottom, 8)

            ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                ShoppingRow(item: item, muted: false) {
                    onToggle(item)
                }
                if index < section.items.count - 1 {
                    Hairline().padding(.leading, 50)
                }
            }
        }
        .card(padding: 0, radius: 22)
    }
}

struct ShoppingRow: View {
    let item: ShoppingItem
    let muted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(item.checked ? Color.terracotta : Color.line, lineWidth: 1.5)
                        .frame(width: 23, height: 23)
                    if item.checked {
                        Circle()
                            .fill(AppGradient.brand)
                            .frame(width: 23, height: 23)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }

                Text(item.name)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(item.checked ? Color.inkFaint : Color.ink)
                    .strikethrough(item.checked, color: Color.inkFaint)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 8)

                Text(item.quantityLabel)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(item.checked ? Color.inkFaint : (muted ? Color.inkSoft : Color.terracottaDeep))
                    .monospacedDigit()
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
            .opacity(item.checked ? 0.7 : 1)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: item.checked)
    }
}
