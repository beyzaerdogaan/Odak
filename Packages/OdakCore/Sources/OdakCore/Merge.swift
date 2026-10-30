import Foundation

extension SkyProgress {
    /// Combines two copies of the same sky that both grew from `base`: this device's copy and the one in
    /// the user's account. Sessions are kept from both sides, earned things are unioned, and counters
    /// (Işık, boosters, meteor sessions) add up what each side gained or spent since `base`.
    ///
    /// With `base` = `SkyProgress()` this is the first sign-in: a sky earned on this phone before the
    /// account existed is added to the one already saved in the account, so nothing is lost.
    public static func merge(base: SkyProgress, local: SkyProgress, remote: SkyProgress) -> SkyProgress {
        if local == base || local == remote { return remote }
        if remote == base { return local }

        func changed<T: Equatable>(_ path: KeyPath<SkyProgress, T>) -> T {
            local[keyPath: path] != base[keyPath: path] ? local[keyPath: path] : remote[keyPath: path]
        }
        func added(_ path: KeyPath<SkyProgress, Int>) -> Int {
            base[keyPath: path] + (local[keyPath: path] - base[keyPath: path]) + (remote[keyPath: path] - base[keyPath: path])
        }
        func earliest(_ path: KeyPath<SkyProgress, [String: Date]>) -> [String: Date] {
            local[keyPath: path].merging(remote[keyPath: path]) { min($0, $1) }
        }
        func ordered(_ path: KeyPath<SkyProgress, [String]>) -> [String] {
            var seen = Set<String>()
            return (local[keyPath: path] + remote[keyPath: path]).filter { seen.insert($0).inserted }
        }
        func counters(_ path: KeyPath<SkyProgress, [String: Int]>, limit: (String) -> Int) -> [String: Int] {
            let keys = Set(local[keyPath: path].keys).union(remote[keyPath: path].keys)
            var out: [String: Int] = [:]
            for k in keys {
                let b = base[keyPath: path][k] ?? 0
                let v = b + ((local[keyPath: path][k] ?? 0) - b) + ((remote[keyPath: path][k] ?? 0) - b)
                out[k] = min(limit(k), max(0, v))
            }
            return out
        }

        var m = local
        m.light = max(0, added(\.light))
        var seenRecords = Set<UUID>()
        m.records = (local.records + remote.records).filter { seenRecords.insert($0.id).inserted }.sorted { $0.start < $1.start }
        m.litStars = earliest(\.litStars)
        m.completedConstellations = ordered(\.completedConstellations)
        m.dryStreak = max(local.dryStreak, remote.dryStreak)
        m.boosters = counters(\.boosters) { Booster(rawValue: $0)?.maxCount ?? .max }
        m.armedShootingStar = changed(\.armedShootingStar)
        m.armedBrightTicket = changed(\.armedBrightTicket)
        let lit = m.litStars
        m.telescopeTarget = changed(\.telescopeTarget).flatMap { lit[$0] == nil ? $0 : nil }
        m.armedTwinStar = changed(\.armedTwinStar)
        m.armedComet = changed(\.armedComet)
        m.cometMinutes = added(\.cometMinutes)
        m.rekindled = local.rekindled.union(remote.rekindled)
        m.ownedSounds = local.ownedSounds.union(remote.ownedSounds)
        m.ownedThemes = local.ownedThemes.union(remote.ownedThemes)
        m.selectedTheme = changed(\.selectedTheme)
        m.ownedDials = local.ownedDials.union(remote.ownedDials)
        m.selectedDial = changed(\.selectedDial)
        m.ownedIcons = local.ownedIcons.union(remote.ownedIcons)
        m.badges = earliest(\.badges)
        m.deepSky = earliest(\.deepSky)
        m.coveredDays = local.coveredDays.union(remote.coveredDays)
        m.meteorProgress = counters(\.meteorProgress) { _ in .max }
        m.journeyStartMinutes = [local.journeyStartMinutes, remote.journeyStartMinutes].compactMap { $0 }.min()
        m.reachedStops = ordered(\.reachedStops)

        // Promises: kept from both sides, except one that either side deleted since `base`.
        let baseIDs = Set(base.promises.map(\.id))
        let deleted = baseIDs.subtracting(local.promises.map(\.id)).union(baseIDs.subtracting(remote.promises.map(\.id)))
        var promises: [SelfPromise] = []
        for p in local.promises + remote.promises where !deleted.contains(p.id) {
            if let i = promises.firstIndex(where: { $0.id == p.id }) {
                if promises[i].celebratedAt == nil { promises[i].celebratedAt = p.celebratedAt }
            } else {
                promises.append(p)
            }
        }
        m.promises = promises

        // Constellations in progress: the same number as before, the ones with the most stars first.
        let slots = max(local.openConstellations.count, remote.openConstellations.count)
        let completed = Set(m.completedConstellations)
        let candidates = ordered(\.openConstellations).filter { !completed.contains($0) }
        let snapshot = m
        func litCount(_ id: String) -> Int { Catalog.constellation(id).map(snapshot.litCount(in:)) ?? 0 }
        let open = candidates.enumerated().sorted { a, b in
            let la = litCount(a.element), lb = litCount(b.element)
            return la != lb ? la > lb : a.offset < b.offset
        }.prefix(slots).map(\.element)
        m.openConstellations = Array(open)
        // Stars lit on different phones can finish a constellation together.
        for c in Catalog.constellations where !m.isComplete(c.id) && m.litCount(in: c) == c.stars.count {
            let finished = c.stars.compactMap { lit[$0.id] }.max() ?? .now
            m.completeConstellation(c, now: finished)
        }
        while m.openConstellations.count < slots,
              let next = Catalog.constellations.first(where: { !m.isComplete($0.id) && !m.openConstellations.contains($0.id) }) {
            m.openConstellations.append(next.id)
        }
        return m
    }
}
