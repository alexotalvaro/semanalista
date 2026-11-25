import SwiftUI
import UIKit
import Photos

// MARK: - Exportación

struct SharePayload: Identifiable {
    let id = UUID()
    let urls: [URL]
}

struct MenuPDFDocument {
    let data: Data
    let pageCount: Int
}

enum MenuExportError: LocalizedError {
    case pdfGeneration
    case imageGeneration
    case galleryPermission
    case gallerySave

    var errorDescription: String? {
        switch self {
        case .pdfGeneration: L10n.t("No se pudo generar el PDF del menú.")
        case .imageGeneration: L10n.t("No se pudieron generar las imágenes del menú.")
        case .galleryPermission: L10n.t("No hay permiso para añadir fotos a la galería.")
        case .gallerySave: L10n.t("No se pudieron guardar las imágenes en la galería.")
        }
    }
}

private enum MenuExportFiles {
    static func prepare() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SemanaLista", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        if let contents = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            for url in contents {
                try? FileManager.default.removeItem(at: url)
            }
        }
        return directory
    }

    static func slug(for plan: WeekPlan) -> String {
        let base = "\(L10n.t("Menu-Semanal"))-\(plan.rangeLabel)"
        var slug = base
            .folding(options: [.diacriticInsensitive], locale: Date.spanishLocale)
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-")).inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        while slug.contains("--") {
            slug = slug.replacingOccurrences(of: "--", with: "-")
        }
        slug = slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return slug.isEmpty ? L10n.t("Menu-Semanal") : slug
    }
}

enum MenuPDFExporter {
    /// Genera el PDF del menú en la carpeta temporal y devuelve las URLs listas
    /// para compartir con WhatsApp, Archivos, Correo, etc.
    static func export(plan: WeekPlan) throws -> SharePayload {
        let document = MenuPDFRenderer.render(plan: plan)
        let directory = try MenuExportFiles.prepare()
        let url = directory.appendingPathComponent(MenuExportFiles.slug(for: plan) + ".pdf")
        try document.data.write(to: url, options: .atomic)
        return SharePayload(urls: [url])
    }
}

enum MenuImageExporter {
    /// Genera una imagen PNG por página, a partir del mismo PDF numerado,
    /// para que el diseño sea idéntico al documento.
    static func export(plan: WeekPlan) throws -> SharePayload {
        let document = MenuPDFRenderer.render(plan: plan)
        guard let provider = CGDataProvider(data: document.data as CFData),
              let pdf = CGPDFDocument(provider) else {
            throw MenuExportError.imageGeneration
        }

        let directory = try MenuExportFiles.prepare()
        let base = MenuExportFiles.slug(for: plan)
        var urls: [URL] = []

        for index in 1...document.pageCount {
            guard let page = pdf.page(at: index) else {
                throw MenuExportError.imageGeneration
            }

            let box = page.getBoxRect(.mediaBox)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 3
            format.opaque = true

            let renderer = UIGraphicsImageRenderer(size: box.size, format: format)
            let image = renderer.image { context in
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: box.size))

                context.cgContext.saveGState()
                context.cgContext.translateBy(x: 0, y: box.height)
                context.cgContext.scaleBy(x: 1, y: -1)
                context.cgContext.drawPDFPage(page)
                context.cgContext.restoreGState()
            }

            guard let data = image.pngData() else {
                throw MenuExportError.imageGeneration
            }

            let suffix: String
            if document.pageCount > 1 {
                suffix = AppLanguage.isEnglish
                    ? "-page-\(index)-of-\(document.pageCount)"
                    : "-pagina-\(index)-de-\(document.pageCount)"
            } else {
                suffix = ""
            }
            let url = directory.appendingPathComponent("\(base)\(suffix).png")
            try data.write(to: url, options: .atomic)
            urls.append(url)
        }

        return SharePayload(urls: urls)
    }
}

enum MenuGallerySaver {
    /// Añade a Fotos una imagen por página. Solo solicita permiso de escritura.
    static func save(plan: WeekPlan) async throws -> Int {
        let payload = try MenuImageExporter.export(plan: plan)

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw MenuExportError.galleryPermission
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                for url in payload.urls {
                    _ = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
                }
            } completionHandler: { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? MenuExportError.gallerySave)
                }
            }
        }

        return payload.urls.count
    }
}

// MARK: - Renderer

enum MenuPDFRenderer {
    private static let pageSize = CGSize(width: 595.28, height: 841.89) // A4

    /// Genera el PDF. Si ocupa más de una página, se vuelve a dibujar con la
    /// numeración «Página X de Y» en el pie.
    static func render(plan: WeekPlan) -> MenuPDFDocument {
        let unnumbered = makePDF(plan: plan, totalPages: nil)
        let pages = pageCount(of: unnumbered)

        guard pages > 1 else {
            return MenuPDFDocument(data: unnumbered, pageCount: pages)
        }

        let numbered = makePDF(plan: plan, totalPages: pages)
        return MenuPDFDocument(data: numbered, pageCount: pages)
    }

    private static func makePDF(plan: WeekPlan, totalPages: Int?) -> Data {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "\(L10n.t("Menú semanal")) · \(plan.title)",
            kCGPDFContextAuthor as String: "Semana Lista",
            kCGPDFContextCreator as String: "Semana Lista"
        ]

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(origin: .zero, size: pageSize),
            format: format
        )

        return renderer.pdfData { context in
            PDFCanvas(context: context, totalPages: totalPages).draw(plan: plan)
        }
    }

    private static func pageCount(of data: Data) -> Int {
        guard let provider = CGDataProvider(data: data as CFData),
              let document = CGPDFDocument(provider) else {
            return 1
        }
        return max(1, document.numberOfPages)
    }
}

// MARK: - Dibujo

private final class PDFCanvas {
    private let context: UIGraphicsPDFRendererContext
    private let size = CGSize(width: 595.28, height: 841.89)
    private let margin: CGFloat = 34

    private var cursorY: CGFloat = 0
    private var footerDrawn = false
    private var activePlan: WeekPlan?
    private var pageNumber = 0
    private let totalPages: Int?

    init(context: UIGraphicsPDFRendererContext, totalPages: Int?) {
        self.context = context
        self.totalPages = totalPages
    }

    private var contentWidth: CGFloat { size.width - margin * 2 }
    private var ctx: CGContext { context.cgContext }

    // MARK: Flujo

    func draw(plan: WeekPlan) {
        activePlan = plan
        beginFirstPage(plan: plan)

        var index = 0
        while index < plan.days.count {
            let end = min(index + 2, plan.days.count)
            let row = Array(plan.days[index..<end])

            ensureSpace(PDFMetrics.dayCardHeight + PDFMetrics.rowGap)

            for (column, day) in row.enumerated() {
                let rect = CGRect(
                    x: margin + CGFloat(column) * (PDFMetrics.cardWidth + PDFMetrics.columnGap),
                    y: cursorY,
                    width: PDFMetrics.cardWidth,
                    height: PDFMetrics.dayCardHeight
                )
                drawDayCard(day: day, index: index + column, plan: plan, in: rect)
            }

            cursorY += PDFMetrics.dayCardHeight + PDFMetrics.rowGap
            index = end
        }

        if !plan.days.isEmpty {
            cursorY -= PDFMetrics.rowGap
        }

        drawNotes(plan: plan)
        finishPage()
    }

    // MARK: Páginas

    private func beginFirstPage(plan: WeekPlan) {
        context.beginPage()
        pageNumber = 1
        footerDrawn = false
        fillBackground()

        var y = margin
        drawHero(plan: plan, in: CGRect(x: margin, y: y, width: contentWidth, height: PDFMetrics.heroHeight))
        y += PDFMetrics.heroHeight + 10
        drawStats(plan: plan, in: CGRect(x: margin, y: y, width: contentWidth, height: PDFMetrics.statsHeight))
        y += PDFMetrics.statsHeight + 13
        drawSectionTitle(at: y)
        y += 18 + 7

        cursorY = y
    }

    private func beginContinuationPage() {
        finishPage()
        context.beginPage()
        pageNumber += 1
        footerDrawn = false
        fillBackground()

        let plan = activePlan
        drawText(
            L10n.t("MENÚ SEMANAL · CONTINUACIÓN"),
            in: CGRect(x: margin, y: margin + 5, width: contentWidth * 0.6, height: 12),
            font: .bold(8, kern: 1.8),
            color: PDFPalette.blue
        )
        drawText(
            plan?.rangeLabel ?? "",
            in: CGRect(x: margin + contentWidth * 0.6, y: margin + 5, width: contentWidth * 0.4, height: 12),
            font: .medium(8),
            color: PDFPalette.inkFaint,
            alignment: .right
        )
        drawHairline(y: margin + 24)
        cursorY = margin + 36
    }

    private func ensureSpace(_ height: CGFloat) {
        if cursorY + height > PDFMetrics.contentBottom {
            beginContinuationPage()
        }
    }

    private func finishPage() {
        guard !footerDrawn else { return }
        footerDrawn = true
        drawFooter()
    }

    private func fillBackground() {
        PDFPalette.paper.setFill()
        ctx.fill(CGRect(origin: .zero, size: size))
    }

    // MARK: Cabecera

    private func drawHero(plan: WeekPlan, in rect: CGRect) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 24)

        ctx.saveGState()
        ctx.addPath(path.cgPath)
        ctx.clip()
        drawGradient(
            in: rect,
            colors: [PDFPalette.navy, PDFPalette.deepBlue, PDFPalette.blue],
            start: CGPoint(x: rect.minX, y: rect.minY),
            end: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        PDFPalette.white.withAlphaComponent(0.055).setFill()
        ctx.fillEllipse(in: CGRect(x: rect.maxX - 150, y: rect.minY - 90, width: 250, height: 250))
        PDFPalette.white.withAlphaComponent(0.04).setFill()
        ctx.fillEllipse(in: CGRect(x: rect.maxX - 40, y: rect.maxY - 70, width: 160, height: 160))
        PDFPalette.white.withAlphaComponent(0.10).setStroke()
        ctx.setLineWidth(1)
        ctx.strokeEllipse(in: CGRect(x: rect.maxX - 128, y: rect.minY - 68, width: 205, height: 205))
        ctx.restoreGState()

        let left = rect.minX + 20
        let textWidth = rect.width - 40

        drawText(
            "SEMANA LISTA",
            in: CGRect(x: left, y: rect.minY + 13, width: textWidth * 0.5, height: 10),
            font: .bold(6.5, kern: 1.8),
            color: PDFPalette.white.withAlphaComponent(0.62)
        )

        let badgeText = plan.source.isAI ? L10n.t("MENÚ CON IA") : L10n.t("PLAN BASE")
        let badgeFont = PDFTextFont.bold(6, kern: 0.9)
        let badgeTextWidth = (badgeText as NSString).size(withAttributes: [
            .font: badgeFont.font,
            .kern: badgeFont.kern
        ]).width
        let badgeWidth = max(55, badgeTextWidth + 18)
        drawPill(
            text: badgeText,
            in: CGRect(x: rect.maxX - 20 - badgeWidth, y: rect.minY + 10, width: badgeWidth, height: 15),
            fill: PDFPalette.white.withAlphaComponent(0.14),
            textColor: PDFPalette.white.withAlphaComponent(0.92),
            font: badgeFont
        )

        drawText(
            L10n.t("MENÚ SEMANAL"),
            in: CGRect(x: left, y: rect.minY + 31, width: textWidth, height: 10),
            font: .bold(7.5, kern: 2.2),
            color: PDFPalette.white.withAlphaComponent(0.72)
        )

        let titleFont = PDFTextFont.fitting(
            plan.title,
            width: textWidth,
            height: 46,
            start: 19.5,
            minimum: 15,
            weight: .bold
        )
        drawText(
            plan.title,
            in: CGRect(x: left, y: rect.minY + 43, width: textWidth, height: 46),
            font: titleFont,
            color: PDFPalette.white,
            lineLimit: 2
        )

        let dividerY = rect.maxY - 22
        PDFPalette.white.withAlphaComponent(0.18).setFill()
        ctx.fill(CGRect(x: left, y: dividerY, width: textWidth, height: 0.8))

        let meta = "\(plan.rangeLabel)  ·  \(L10n.format("%lld personas · %lld comidas", plan.people, plan.mealCount))"
        drawText(
            meta,
            in: CGRect(x: left, y: dividerY + 7, width: textWidth, height: 12),
            font: .medium(8.5),
            color: PDFPalette.white.withAlphaComponent(0.82)
        )
    }

    private func drawStats(plan: WeekPlan, in rect: CGRect) {
        drawRoundedCard(rect: rect, radius: 18, fill: PDFPalette.white, border: PDFPalette.line)

        let stats: [(String, String)] = [
            ("\(plan.days.count)", L10n.t("DÍAS")),
            ("\(plan.mealCount)", L10n.t("COMIDAS")),
            ("\(plan.preps.count)", L10n.t("PREPARACIONES")),
            (durationLabel(plan.totalMinutes), L10n.t("DE COCINA"))
        ]

        let columnWidth = rect.width / CGFloat(stats.count)
        for (index, stat) in stats.enumerated() {
            let columnX = rect.minX + CGFloat(index) * columnWidth

            if index > 0 {
                PDFPalette.line.setFill()
                ctx.fill(CGRect(x: columnX, y: rect.minY + 12, width: 0.8, height: rect.height - 24))
            }

            drawText(
                stat.0,
                in: CGRect(x: columnX, y: rect.minY + 8, width: columnWidth, height: 16),
                font: .bold(13.5),
                color: index == 3 ? PDFPalette.cyanDeep : PDFPalette.blue,
                alignment: .center
            )
            drawText(
                stat.1,
                in: CGRect(x: columnX, y: rect.minY + 26, width: columnWidth, height: 9),
                font: .bold(5.8, kern: 0.9),
                color: PDFPalette.inkFaint,
                alignment: .center
            )
        }
    }

    private func drawSectionTitle(at y: CGFloat) {
        drawText(
            L10n.t("EL MENÚ"),
            in: CGRect(x: margin, y: y, width: 160, height: 13),
            font: .bold(8, kern: 2),
            color: PDFPalette.inkSoft
        )
        drawText(
            L10n.t("Comida y cena de cada día"),
            in: CGRect(x: margin + 160, y: y + 1, width: contentWidth - 160, height: 12),
            font: .medium(7.5),
            color: PDFPalette.inkFaint,
            alignment: .right
        )
    }

    // MARK: Tarjetas de día

    private func drawDayCard(day: DayPlan, index: Int, plan: WeekPlan, in rect: CGRect) {
        let date = plan.mealDate(index)
        let isToday = Calendar.current.isDateInToday(date)

        drawRoundedCard(
            rect: rect,
            radius: 16,
            fill: PDFPalette.white,
            border: isToday ? PDFPalette.blue.withAlphaComponent(0.45) : PDFPalette.line
        )

        let weekday = WeekDates.appWeekday(of: date)
        let padding: CGFloat = 12
        var y = rect.minY + 10

        let badgeRect = CGRect(x: rect.minX + padding, y: y, width: 19, height: 19)
        let badgePath = UIBezierPath(roundedRect: badgeRect, cornerRadius: 6.5)
        ctx.saveGState()
        ctx.addPath(badgePath.cgPath)
        ctx.clip()
        drawGradient(
            in: badgeRect,
            colors: [PDFPalette.lightBlue, PDFPalette.blue, PDFPalette.deepBlue],
            start: CGPoint(x: badgeRect.minX, y: badgeRect.minY),
            end: CGPoint(x: badgeRect.maxX, y: badgeRect.maxY)
        )
        ctx.restoreGState()

        drawText(
            weekday.short,
            in: CGRect(x: badgeRect.minX, y: badgeRect.minY + 4.5, width: badgeRect.width, height: 11),
            font: .bold(8.5),
            color: PDFPalette.white,
            alignment: .center
        )

        drawText(
            weekday.name.uppercased(),
            in: CGRect(x: badgeRect.maxX + 7, y: y + 2, width: 100, height: 10),
            font: .bold(7, kern: 1.2),
            color: PDFPalette.blue
        )
        if isToday {
            drawText(
                L10n.t("HOY"),
                in: CGRect(x: badgeRect.maxX + 7, y: y + 11, width: 90, height: 8),
                font: .bold(5.5, kern: 0.8),
                color: PDFPalette.cyanDeep
            )
        } else {
            drawText(
                date.capitalizedSpanish(short: true),
                in: CGRect(x: rect.maxX - padding - 79, y: y + 5, width: 79, height: 9),
                font: .medium(6.8),
                color: PDFPalette.inkFaint,
                alignment: .right
            )
        }

        y += 22
        PDFPalette.line.withAlphaComponent(0.9).setFill()
        ctx.fill(CGRect(x: rect.minX + padding, y: y, width: rect.width - padding * 2, height: 0.7))

        y += 7
        drawMealRow(
            meal: day.lunch,
            slotLabel: MealSlot.lunch.label.uppercased(),
            slotColor: PDFPalette.blue,
            slotBackground: PDFPalette.softBlue,
            x: rect.minX + padding,
            y: y,
            width: rect.width - padding * 2
        )

        y += 22 + 6
        drawMealRow(
            meal: day.dinner,
            slotLabel: MealSlot.dinner.label.uppercased(),
            slotColor: PDFPalette.cyanDeep,
            slotBackground: PDFPalette.softCyan,
            x: rect.minX + padding,
            y: y,
            width: rect.width - padding * 2
        )
    }

    private func drawMealRow(
        meal: Meal,
        slotLabel: String,
        slotColor: UIColor,
        slotBackground: UIColor,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat
    ) {
        let chipWidth: CGFloat = 36
        let chipHeight: CGFloat = 11

        drawPill(
            text: slotLabel,
            in: CGRect(x: x, y: y + 1.5, width: chipWidth, height: chipHeight),
            fill: slotBackground,
            textColor: slotColor,
            font: .bold(5.6, kern: 0.5)
        )

        let titleX = x + chipWidth + 6
        let titleWidth = width - chipWidth - 6
        let title = meal.title.isEmpty ? L10n.t("Por concretar") : meal.title
        let titleFont = PDFTextFont.fitting(
            title,
            width: titleWidth,
            height: 22,
            start: 9.3,
            minimum: 7.6,
            weight: .semibold
        )

        drawText(
            title,
            in: CGRect(x: titleX, y: y - 0.5, width: titleWidth, height: 22),
            font: titleFont,
            color: PDFPalette.ink,
            lineLimit: 2
        )
    }

    // MARK: Notas

    private func drawNotes(plan: WeekPlan) {
        let notes = plan.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let night = plan.nightBefore.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !notes.isEmpty || !night.isEmpty else { return }

        let padding: CGFloat = 14
        let columnGap: CGFloat = 18
        let bothColumns = !notes.isEmpty && !night.isEmpty
        let columnWidth = bothColumns
            ? (contentWidth - padding * 2 - columnGap) / 2
            : contentWidth - padding * 2

        let bodyFont = PDFTextFont.regular(7.4)
        let gap: CGFloat = 9
        var available = PDFMetrics.contentBottom - cursorY - gap
        if available < 52 {
            beginContinuationPage()
            available = PDFMetrics.contentBottom - cursorY - gap
        }
        let maximumBodyHeight = max(24, available - 36)

        let notesHeight = notes.isEmpty ? 0 : min(
            measure(notes, width: columnWidth, font: bodyFont, lineSpacing: 1.7).height,
            maximumBodyHeight
        )
        let nightHeight = night.isEmpty ? 0 : min(
            measure(night, width: columnWidth, font: bodyFont, lineSpacing: 1.7).height,
            maximumBodyHeight
        )

        let cardHeight = 12 + 10 + 4 + max(notesHeight, nightHeight) + 10
        let rect = CGRect(x: margin, y: cursorY, width: contentWidth, height: cardHeight)
        drawRoundedCard(rect: rect, radius: 16, fill: PDFPalette.white, border: PDFPalette.line)

        if bothColumns {
            let dividerX = rect.minX + padding + columnWidth + columnGap / 2
            PDFPalette.line.setFill()
            ctx.fill(CGRect(x: dividerX, y: rect.minY + 12, width: 0.8, height: rect.height - 24))
        }

        let firstX = rect.minX + padding
        if !notes.isEmpty {
            drawText(
                L10n.t("NOTAS DE LA SEMANA"),
                in: CGRect(x: firstX, y: rect.minY + 12, width: columnWidth, height: 9),
                font: .bold(6.5, kern: 1.2),
                color: PDFPalette.blue
            )
            drawText(
                notes,
                in: CGRect(x: firstX, y: rect.minY + 26, width: columnWidth, height: notesHeight),
                font: bodyFont,
                color: PDFPalette.inkSoft,
                lineSpacing: 1.7
            )
        }

        if !night.isEmpty {
            let secondX = bothColumns ? firstX + columnWidth + columnGap : firstX
            drawText(
                L10n.t("ANTES DE DORMIR"),
                in: CGRect(x: secondX, y: rect.minY + 12, width: columnWidth, height: 9),
                font: .bold(6.5, kern: 1.2),
                color: PDFPalette.cyanDeep
            )
            drawText(
                night,
                in: CGRect(x: secondX, y: rect.minY + 26, width: columnWidth, height: nightHeight),
                font: bodyFont,
                color: PDFPalette.inkSoft,
                lineSpacing: 1.7
            )
        }

        cursorY = rect.maxY + 10
    }

    // MARK: Pie

    private func drawFooter() {
        drawHairline(y: PDFMetrics.footerLineY)

        drawText(
            "SEMANA LISTA",
            in: CGRect(x: margin, y: PDFMetrics.footerLineY + 7, width: 140, height: 9),
            font: .bold(6.2, kern: 1.5),
            color: PDFPalette.blue
        )

        if let totalPages, totalPages > 1 {
            drawText(
                L10n.format("Página %lld de %lld", pageNumber, totalPages),
                in: CGRect(x: margin, y: PDFMetrics.footerLineY + 7, width: contentWidth, height: 9),
                font: .bold(6.2, kern: 0.4),
                color: PDFPalette.inkSoft,
                alignment: .center
            )
        }

        let dateText = Date.now.formatted(
            .dateTime.locale(Date.appLocale).day().month(.abbreviated).year()
        ).capitalized
        drawText(
            L10n.format("Generado el %@", dateText),
            in: CGRect(x: size.width - margin - 160, y: PDFMetrics.footerLineY + 7, width: 160, height: 9),
            font: .medium(6.2),
            color: PDFPalette.inkFaint,
            alignment: .right
        )

        drawText(
            L10n.t("Los menús generados pueden contener errores. Revisa alérgenos, cocción y conservación antes de comer."),
            in: CGRect(x: margin, y: PDFMetrics.footerLineY + 18, width: contentWidth, height: 8),
            font: .regular(5.7),
            color: PDFPalette.inkFaint,
            alignment: .center
        )
    }

    // MARK: Primitivas

    private func drawRoundedCard(rect: CGRect, radius: CGFloat, fill: UIColor, border: UIColor) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: radius)
        fill.setFill()
        ctx.addPath(path.cgPath)
        ctx.fillPath()

        border.setStroke()
        ctx.addPath(path.cgPath)
        ctx.setLineWidth(0.8)
        ctx.strokePath()
    }

    private func drawGradient(in rect: CGRect, colors: [UIColor], start: CGPoint, end: CGPoint) {
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors.map(\.cgColor) as CFArray,
            locations: nil
        ) else { return }
        ctx.drawLinearGradient(
            gradient,
            start: start,
            end: end,
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
    }

    private func drawHairline(y: CGFloat) {
        PDFPalette.line.setFill()
        ctx.fill(CGRect(x: margin, y: y, width: contentWidth, height: 0.8))
    }

    private func drawPill(text: String, in rect: CGRect, fill: UIColor, textColor: UIColor, font: PDFTextFont) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: rect.height / 2)
        fill.setFill()
        ctx.addPath(path.cgPath)
        ctx.fillPath()

        let height = font.font.lineHeight
        drawText(
            text,
            in: CGRect(x: rect.minX, y: rect.midY - height / 2 - 0.3, width: rect.width, height: height + 1),
            font: font,
            color: textColor,
            alignment: .center
        )
    }

    private func drawText(
        _ text: String,
        in rect: CGRect,
        font: PDFTextFont,
        color: UIColor,
        alignment: NSTextAlignment = .left,
        lineSpacing: CGFloat = 0,
        lineLimit: Int = 0
    ) {
        guard !text.isEmpty else { return }
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineSpacing = lineSpacing
        paragraph.lineBreakMode = .byWordWrapping

        var attributes: [NSAttributedString.Key: Any] = [
            .font: font.font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        if font.kern != 0 {
            attributes[.kern] = font.kern
        }

        var target = rect
        if lineLimit > 0 {
            target.size.height = min(
                rect.height,
                ceil(font.font.lineHeight * CGFloat(lineLimit) + lineSpacing * CGFloat(max(0, lineLimit - 1)))
            )
        }

        (text as NSString).draw(
            with: target,
            options: [.usesLineFragmentOrigin, .usesFontLeading, .truncatesLastVisibleLine],
            attributes: attributes,
            context: nil
        )
    }

    private func measure(_ text: String, width: CGFloat, font: PDFTextFont, lineSpacing: CGFloat = 0) -> CGRect {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        paragraph.lineBreakMode = .byWordWrapping
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font.font,
            .paragraphStyle: paragraph
        ]
        if font.kern != 0 {
            attributes[.kern] = font.kern
        }
        return (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
    }

    private func durationLabel(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours == 0 { return "\(mins) min" }
        if mins == 0 { return "\(hours) h" }
        return "\(hours) h \(mins)"
    }
}

// MARK: - Métricas y estilos

private enum PDFMetrics {
    static let columnGap: CGFloat = 11
    static let cardWidth: CGFloat = (595.28 - 34 * 2 - columnGap) / 2
    static let rowGap: CGFloat = 9
    static let dayCardHeight: CGFloat = 100
    static let heroHeight: CGFloat = 120
    static let statsHeight: CGFloat = 42
    static let contentBottom: CGFloat = 776
    static let footerLineY: CGFloat = 782
}

private enum PDFPalette {
    static let paper = UIColor(rgb: 0xF3F7FE)
    static let white = UIColor.white
    static let ink = UIColor(rgb: 0x0B1B33)
    static let inkSoft = UIColor(rgb: 0x52637B)
    static let inkFaint = UIColor(rgb: 0x8797AC)
    static let blue = UIColor(rgb: 0x2E6BFF)
    static let lightBlue = UIColor(rgb: 0x4F8DFF)
    static let deepBlue = UIColor(rgb: 0x1746C8)
    static let navy = UIColor(rgb: 0x071A33)
    static let cyanDeep = UIColor(rgb: 0x0AA7C2)
    static let softBlue = UIColor(rgb: 0xE8F0FF)
    static let softCyan = UIColor(rgb: 0xDEF6FA)
    static let line = UIColor(rgb: 0xDCE7F5)
}

private struct PDFTextFont {
    let font: UIFont
    let kern: CGFloat

    static func bold(_ size: CGFloat, kern: CGFloat = 0) -> PDFTextFont {
        PDFTextFont(font: rounded(size, weight: .bold), kern: kern)
    }

    static func semibold(_ size: CGFloat, kern: CGFloat = 0) -> PDFTextFont {
        PDFTextFont(font: rounded(size, weight: .semibold), kern: kern)
    }

    static func medium(_ size: CGFloat, kern: CGFloat = 0) -> PDFTextFont {
        PDFTextFont(font: rounded(size, weight: .medium), kern: kern)
    }

    static func regular(_ size: CGFloat, kern: CGFloat = 0) -> PDFTextFont {
        PDFTextFont(font: rounded(size, weight: .regular), kern: kern)
    }

    /// Reduce el cuerpo de letra lo justo para que el texto entre en el alto
    /// disponible (normalmente dos líneas).
    static func fitting(
        _ text: String,
        width: CGFloat,
        height: CGFloat,
        start: CGFloat,
        minimum: CGFloat,
        weight: UIFont.Weight,
        lineSpacing: CGFloat = 0
    ) -> PDFTextFont {
        var size = start
        while size > minimum {
            let font = rounded(size, weight: weight)
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = lineSpacing
            let measured = (text as NSString).boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font, .paragraphStyle: paragraph],
                context: nil
            ).height
            if measured <= height { break }
            size -= 0.3
        }
        return PDFTextFont(font: rounded(size, weight: weight), kern: 0)
    }

    private static func rounded(_ size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - Share sheet

final class SaveMenuImagesActivity: UIActivity {
    private let plan: WeekPlan
    private let completion: (Result<Int, Error>) -> Void

    init(plan: WeekPlan, completion: @escaping (Result<Int, Error>) -> Void) {
        self.plan = plan
        self.completion = completion
        super.init()
    }

    override var activityType: UIActivity.ActivityType? {
        UIActivity.ActivityType("com.alejandro.semanalista.saveMenuImages")
    }

    override var activityTitle: String? {
        L10n.t("Guardar imagen en Fotos")
    }

    override var activityImage: UIImage? {
        UIImage(systemName: "photo.badge.arrow.down") ?? UIImage(systemName: "square.and.arrow.down")
    }

    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        true
    }

    override func perform() {
        Task { @MainActor in
            do {
                let count = try await MenuGallerySaver.save(plan: plan)
                completion(.success(count))
                activityDidFinish(true)
            } catch {
                completion(.failure(error))
                activityDidFinish(false)
            }
        }
    }
}

struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
