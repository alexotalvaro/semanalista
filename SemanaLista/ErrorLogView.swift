import SwiftUI

// MARK: - Ajustes

struct ErrorLogCard: View {
    @Environment(ErrorLog.self) private var errorLog
    @State private var showAll = false
    @State private var confirmClear = false

    var body: some View {
        SettingsCard(title: "Registro de errores", symbol: "exclamationmark.triangle") {
            Text("Aquí se guardan los fallos de la app —IA, red, archivos, fotos o cierres inesperados— para poder revisarlos.")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Color.inkFaint)
                .fixedSize(horizontal: false, vertical: true)

            if errorLog.entries.isEmpty {
                HStack(spacing: 9) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.olive)
                    Text("No hay errores registrados.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.inkSoft)
                    Spacer()
                }
                .padding(11)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Color.oliveSoft.opacity(0.7))
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(errorLog.entries.prefix(3))) { entry in
                        ErrorLogPreviewRow(entry: entry)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        showAll = true
                    } label: {
                        HStack(spacing: 5) {
                            Text(L10n.format("Ver todos (%lld)", errorLog.entries.count))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.terracotta)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    ShareLink(item: errorLog.exportText()) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.terracotta)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.terracottaSoft.opacity(0.8)))
                    }
                    .accessibilityLabel(L10n.t("Compartir registro"))

                    Button {
                        confirmClear = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.inkSoft)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.paper))
                            .overlay(Circle().stroke(Color.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.t("Borrar registro"))
                }
            }
        }
        .sheet(isPresented: $showAll) {
            ErrorLogSheet()
        }
        .confirmationDialog(
            "¿Borrar todo el registro?",
            isPresented: $confirmClear,
            titleVisibility: .visible
        ) {
            Button(L10n.t("Borrar"), role: .destructive) {
                errorLog.clear()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(L10n.format("Se eliminarán los %lld errores guardados. Esta acción no se puede deshacer.", errorLog.entries.count))
        }
    }
}

// MARK: - Fila compacta

private struct ErrorLogPreviewRow: View {
    let entry: LoggedError

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: entry.category.symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.terracotta)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.terracottaSoft.opacity(0.8)))

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.summary)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(entry.formattedDate) · \(entry.context)")
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(Color.inkFaint)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Hoja completa

struct ErrorLogSheet: View {
    @Environment(ErrorLog.self) private var errorLog
    @Environment(\.dismiss) private var dismiss
    @State private var confirmClear = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 10) {
                        if errorLog.entries.isEmpty {
                            EmptyHint(
                                symbol: "checkmark.seal",
                                title: "Sin errores",
                                text: "No hay errores registrados."
                            )
                        } else {
                            Text("Copia el registro y envíalo para revisarlo.")
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(Color.inkFaint)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)

                            ForEach(errorLog.entries) { entry in
                                ErrorLogDetailRow(entry: entry)
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                    .lockedScrollWidth()
                }
                .scrollIndicators(.hidden)
                .verticalOnlyScroll()
            }
            .navigationTitle(L10n.t("Registro de errores"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button(L10n.t("Cerrar")) {
                        dismiss()
                    }

                    ShareLink(item: errorLog.exportText()) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel(L10n.t("Compartir registro"))
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        confirmClear = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(errorLog.entries.isEmpty)
                    .accessibilityLabel(L10n.t("Borrar registro"))
                }
            }
            .confirmationDialog(
                "¿Borrar todo el registro?",
                isPresented: $confirmClear,
                titleVisibility: .visible
            ) {
                Button(L10n.t("Borrar"), role: .destructive) {
                    errorLog.clear()
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text(L10n.format("Se eliminarán los %lld errores guardados. Esta acción no se puede deshacer.", errorLog.entries.count))
            }
        }
    }
}

private struct ErrorLogDetailRow: View {
    let entry: LoggedError

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: entry.category.symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.terracotta)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.terracottaSoft.opacity(0.8)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.summary)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("\(entry.formattedDate) · \(entry.category.title)")
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(Color.inkFaint)
                }

                Spacer(minLength: 0)
            }

            Text(entry.context)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Color.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            if !entry.details.isEmpty {
                Text(entry.details)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Color.inkFaint)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.paper)
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 12, radius: 16)
    }
}
