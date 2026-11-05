import Foundation

enum RouteMode { case drive, walk, transit }

/// Голосовая команда про карты: «как добраться до …», «где ближайший …».
enum MapCommand {
    case route(destination: String, mode: RouteMode)
    case search(query: String)

    var confirmation: String {
        switch self {
        case .route(let d, _): return "Строю маршрут: \(d)"
        case .search(let q): return "Ищу рядом: \(q)"
        }
    }

    /// Возвращает команду, если фраза похожа на навигацию. Иначе nil — тогда фраза уходит в нейронку.
    static func parse(_ raw: String) -> MapCommand? {
        var t = raw.replacingOccurrences(of: "ё", with: "е").replacingOccurrences(of: "Ё", with: "Е")
        t = t.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        t = t.replacingRegex("^чарли[,\\s]+", with: "")

        let nearby = "(ближайш\\p{L}*|рядом(?:\\s+со\\s+мной)?|поблизости|неподалеку|около\\s+меня|от\\s+меня|тут|здесь)"

        // 1) «как добраться до …», «построй маршрут до …»
        let routePattern = "^(?:а\\s+)?(?:как\\s+(?:мне\\s+|лучше\\s+|быстрее\\s+)*(?:добраться|доехать|проехать|дойти|пройти)|(?:построй|проложи|сделай|покажи|открой|включи)(?:\\s+мне)?\\s+маршрут|маршрут|навигация|навигатор|отвези\\s+меня|поехали|едем)\\s*(?:до|ко|к|на|во|в)?\\s+(.+)$"
        if let m = t.firstMatch(routePattern), m.count > 1 {
            var dest = m[1]

            var mode = RouteMode.drive
            if dest.firstMatch("пешком|пешеход") != nil { mode = .walk }
            else if dest.firstMatch("общественн|автобус|метро|трамва|транспорт") != nil { mode = .transit }
            dest = dest.replacingRegex("(?:на\\s+)?(?:общественном\\s+транспорте|автобусе|метро|трамвае)|пешком|на\\s+машине|на\\s+авто\\w*|на\\s+такси", with: " ")

            if dest.firstMatch(nearby) != nil {
                let q = dest.replacingRegex(nearby, with: " ").cleaned
                return q.isEmpty ? nil : .search(query: q)
            }
            dest = dest.cleaned
            return dest.isEmpty ? nil : .route(destination: dest.capitalizedFirst, mode: mode)
        }

        // 2) «где ближайший …», «найди … рядом», «покажи … на карте»
        let searchPattern = "^(?:а\\s+)?(?:где|найди|найти|покажи|подскажи|ищи)(?:\\s+мне)?(?:\\s+где)?\\s+(?:находится\\s+|есть\\s+)?(.+)$"
        if let m = t.firstMatch(searchPattern), m.count > 1 {
            let q = m[1]
            let hasNearby = q.firstMatch(nearby) != nil
            let hasMap = q.firstMatch("на\\s+карте") != nil
            guard hasNearby || hasMap else { return nil }
            let cleaned = q.replacingRegex("на\\s+карте", with: " ").replacingRegex(nearby, with: " ").cleaned
            return cleaned.isEmpty ? nil : .search(query: cleaned)
        }
        return nil
    }
}

private extension String {
    func firstMatch(_ pattern: String) -> [String]? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = self as NSString
        guard let m = re.firstMatch(in: self, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return (0..<m.numberOfRanges).map { i in
            let r = m.range(at: i)
            return r.location == NSNotFound ? "" : ns.substring(with: r)
        }
    }

    func replacingRegex(_ pattern: String, with template: String) -> String {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return self }
        return re.stringByReplacingMatches(in: self, range: NSRange(location: 0, length: (self as NSString).length), withTemplate: template)
    }

    /// Схлопывает лишние пробелы и убирает висящие предлоги по краям.
    var cleaned: String {
        var s = replacingRegex("\\s+", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacingRegex("^(?:до|к|ко|на|в|во)\\s+", with: "")
        s = s.replacingRegex("\\s+(?:до|к|ко|на|в|во)$", with: "")
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
