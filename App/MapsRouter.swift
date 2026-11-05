import Foundation
import UIKit
import CoreLocation

/// Собирает ссылку для выбранных карт. Яндекс: маршрут по координатам (так требует его схема),
/// Apple и Google сами находят адрес по тексту.
@MainActor
enum MapsRouter {
    static func url(for command: MapCommand, provider: String, location: LocationOnce) async -> URL {
        var provider = provider
        if provider == "yandex", let probe = URL(string: "yandexmaps://"), !UIApplication.shared.canOpenURL(probe) {
            provider = "apple"   // Яндекс Карты не установлены
        }
        switch provider {
        case "yandex": return await yandex(command, location)
        case "google": return google(command)
        default: return apple(command)
        }
    }

    // MARK: Яндекс

    private static func yandex(_ command: MapCommand, _ location: LocationOnce) async -> URL {
        let loc = await location.request()
        let fallback = URL(string: "yandexmaps://")!
        switch command {
        case .search(let q):
            var s = "yandexmaps://maps.yandex.ru/?text=\(enc(q))"
            if let c = loc?.coordinate {
                s += "&ll=\(c.longitude),\(c.latitude)&spn=0.08,0.08"   // ll: долгота,широта
            }
            return URL(string: s) ?? fallback
        case .route(let dest, let mode):
            let rtt = mode == .walk ? "pd" : (mode == .transit ? "mt" : "auto")
            if let to = await geocode(dest, near: loc) {
                let from = loc.map { "\($0.coordinate.latitude),\($0.coordinate.longitude)" } ?? ""   // rtext: широта,долгота
                return URL(string: "yandexmaps://maps.yandex.ru/?rtext=\(from)~\(to.latitude),\(to.longitude)&rtt=\(rtt)") ?? fallback
            }
            // адрес не нашёлся — открываем поиск, маршрут строится одним нажатием
            return URL(string: "yandexmaps://maps.yandex.ru/?text=\(enc(dest))") ?? fallback
        }
    }

    private static func geocode(_ address: String, near: CLLocation?) async -> CLLocationCoordinate2D? {
        var region: CLRegion?
        if let near {
            region = CLCircularRegion(center: near.coordinate, radius: 50_000, identifier: "near")
        }
        let marks = try? await CLGeocoder().geocodeAddressString(address, in: region, preferredLocale: Locale(identifier: "ru_RU"))
        return marks?.first?.location?.coordinate
    }

    // MARK: Apple и Google

    private static func apple(_ command: MapCommand) -> URL {
        switch command {
        case .search(let q):
            return URL(string: "https://maps.apple.com/?q=\(enc(q))")!
        case .route(let dest, let mode):
            let flag = mode == .walk ? "w" : (mode == .transit ? "r" : "d")
            return URL(string: "https://maps.apple.com/?daddr=\(enc(dest))&dirflg=\(flag)")!
        }
    }

    private static func google(_ command: MapCommand) -> URL {
        switch command {
        case .search(let q):
            return URL(string: "https://www.google.com/maps/search/?api=1&query=\(enc(q))")!
        case .route(let dest, let mode):
            let m = mode == .walk ? "walking" : (mode == .transit ? "transit" : "driving")
            return URL(string: "https://www.google.com/maps/dir/?api=1&destination=\(enc(dest))&travelmode=\(m)")!
        }
    }

    private static func enc(_ s: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+#?")
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }
}
