import Foundation

private let systemLocaleRegionSuffix: String = {
    let identifier = Locale.current.identifier
    if let range = identifier.range(of: "_") {
        return String(identifier[range.lowerBound...])
    } else {
        return ""
    }
}()

let usEnglishLocale = Locale(identifier: "en_US")

func localeWithStrings(_ strings: PresentationStrings) -> Locale {
    let code = strings.languageCode + systemLocaleRegionSuffix
    return Locale(identifier: code)
}