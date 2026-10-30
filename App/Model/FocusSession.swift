import Foundation

enum BlockMode: String, Codable, CaseIterable, Identifiable {
    case selected, all, none
    var id: String { rawValue }
    var title: String {
        switch self {
        case .selected: String(localized: "Seçtiklerim")
        case .all: String(localized: "Tümü")
        case .none: String(localized: "Yok")
        }
    }
}

/// What the user set up on the Odak screen; remembered between launches.
struct FocusSettings: Codable, Equatable {
    var task = ""
    var minutes = 45
    var blockMode: BlockMode = .selected
    var silenceCalls = true
    var allowFavorites = true
    var strict = false
    var stopMusicAtEnd = true
    /// The user confirmed they created the "Derin" Focus and its two shortcuts.
    var focusShortcutsReady = false
    var ambient: [String: Double] = ["rain": 0.3]
    /// The chosen music: a Spotify playlist ID (suggested or from the account) or an added list's link.
    var spotifyPlaylist: String?

    static let presets = [25, 45, 60, 90]
}

/// A running focus session. Times are stored as dates so the countdown survives backgrounding and relaunch.
struct FocusSession: Codable, Equatable, Identifiable {
    var id = UUID()
    var task: String
    var plannedMinutes: Int
    var start: Date
    /// Planned end; pushed later by the length of a break.
    var end: Date
    var strict: Bool
    var blockMode: BlockMode
    var silenceCalls: Bool
    var breakUsed = false
    var breakStartedAt: Date?
    var lookAways = 0
    var lastReturn: Date
    /// Seconds the phone was locked (screen off) during the session. Optional so sessions saved by older builds still load.
    var screenOffSeconds: TimeInterval?
    /// When the phone was locked, while it still is.
    var lockedAt: Date?

    static let breakLength: TimeInterval = 5 * 60
    /// Shorter sessions get no break: pausing 5 minutes of a 25-minute block defeats its purpose.
    static let minutesForBreak = 45

    init(task: String, minutes: Int, strict: Bool, blockMode: BlockMode, silenceCalls: Bool, now: Date = .now) {
        self.task = task
        plannedMinutes = minutes
        start = now
        end = now.addingTimeInterval(TimeInterval(minutes * 60))
        self.strict = strict
        self.blockMode = blockMode
        self.silenceCalls = silenceCalls
        lastReturn = now
    }

    var isOnBreak: Bool { breakStartedAt != nil }

    var allowsBreak: Bool { plannedMinutes >= Self.minutesForBreak }

    func remaining(at now: Date) -> TimeInterval {
        max(0, end.timeIntervalSince(breakStartedAt ?? now))
    }

    func focusedMinutes(at now: Date) -> Int {
        let total = TimeInterval(plannedMinutes * 60)
        return Int(((total - remaining(at: now)) / 60).rounded(.down))
    }

    func progress(at now: Date) -> Double {
        1 - remaining(at: now) / TimeInterval(plannedMinutes * 60)
    }

    func breakRemaining(at now: Date) -> TimeInterval {
        guard let b = breakStartedAt else { return 0 }
        return max(0, Self.breakLength - now.timeIntervalSince(b))
    }

    mutating func startBreak(at now: Date) {
        guard allowsBreak, !breakUsed, breakStartedAt == nil else { return }
        breakUsed = true
        breakStartedAt = now
    }

    mutating func endBreak(at now: Date) {
        guard let b = breakStartedAt else { return }
        let paused = min(now.timeIntervalSince(b), Self.breakLength)
        end = end.addingTimeInterval(paused)
        breakStartedAt = nil
        lastReturn = b.addingTimeInterval(paused)
    }

    mutating func screenLocked(at t: Date) {
        if lockedAt == nil { lockedAt = t }
    }

    mutating func screenUnlocked(at t: Date) {
        guard let l = lockedAt else { return }
        lockedAt = nil
        screenOffSeconds = (screenOffSeconds ?? 0) + Self.overlap(l, t, start, end)
    }

    /// Whole minutes the screen was off, counting a lock that is still going on.
    func screenOffMinutes(at now: Date) -> Int {
        let ongoing = lockedAt.map { Self.overlap($0, now, start, end) } ?? 0
        return Int((((screenOffSeconds ?? 0) + ongoing) / 60).rounded(.down))
    }

    private static func overlap(_ a: Date, _ b: Date, _ lo: Date, _ hi: Date) -> TimeInterval {
        max(0, min(b, hi).timeIntervalSince(max(a, lo)))
    }
}
