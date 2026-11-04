import Foundation

enum LocaleFormatting {
    static func currency(_ amount: Double, code: String = "USD", locale: Locale = .current) -> String {
        amount.formatted(.currency(code: code).locale(locale))
    }

    static func percentage(_ change: Double, locale: Locale = .current) -> String {
        (change / 100)
            .formatted(.percent.precision(.fractionLength(2)).locale(locale))
    }
}
