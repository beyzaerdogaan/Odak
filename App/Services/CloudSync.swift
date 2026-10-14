import FirebaseFirestore
import Foundation
import Observation
import OdakCore

/// Keeps a copy of the sky in Firestore at `users/{uid}` so it survives a lost phone or a reinstall
/// and follows the user to another iPhone. The phone's own JSON stays the source the app reads;
/// this only reconciles it with the account, and quietly retries later when there is no connection.
///
/// The document holds the sky as zlib-compressed JSON plus a revision number. The phone remembers
/// the last copy both sides agreed on (`base`), so when both changed in the meantime the two are
/// combined with `SkyProgress.merge` instead of one overwriting the other.
@MainActor @Observable
final class CloudSync {
    private(set) var lastSynced: Date?
    private(set) var isSyncing = false
    private(set) var failed = false

    private struct Stored: Codable {
        var uid: String
        var revision: Int
        var base: SkyProgress
        var synced: Date
    }

    private struct Outcome: @unchecked Sendable {
        var progress: SkyProgress
        var revision: Int
    }

    @ObservationIgnored private var stored: Stored?
    @ObservationIgnored private let file: URL

    init(folder: URL) {
        file = folder.appending(path: "cloud-sync.json")
        stored = (try? Data(contentsOf: file)).flatMap { try? JSONDecoder().decode(Stored.self, from: $0) }
        lastSynced = stored?.synced
    }

    /// True when this phone has changes the account does not have yet.
    func hasUnsyncedChanges(_ progress: SkyProgress, uid: String) -> Bool {
        guard let stored, stored.uid == uid else { return progress != SkyProgress() }
        return stored.base != progress
    }

    /// Reconciles `local` with the account and returns the sky both now hold.
    func sync(uid: String, local: SkyProgress) async throws -> SkyProgress {
        isSyncing = true
        defer { isSyncing = false }
        let known = stored?.uid == uid ? stored : nil
        let base = known?.base ?? SkyProgress()
        let baseRevision = known?.revision ?? 0
        let ref = Firestore.firestore().collection("users").document(uid)

        do {
            let outcome = try await Self.reconcile(ref: ref, base: base, baseRevision: baseRevision, local: local)
            remember(Stored(uid: uid, revision: outcome.revision, base: outcome.progress, synced: .now))
            failed = false
            return outcome.progress
        } catch {
            failed = true
            throw error
        }
    }

    /// Runs on Firestore's queue: reads the account's copy and writes the combined sky when it differs.
    nonisolated private static func reconcile(ref: DocumentReference, base: SkyProgress, baseRevision: Int,
                                              local: SkyProgress) async throws -> Outcome {
        let result = try await ref.firestore.runTransaction { tx, errorPointer -> Any? in
            do {
                let snap = try tx.getDocument(ref)
                let revision = snap.get("revision") as? Int ?? 0
                let remote = (snap.get("progress") as? Data).flatMap(decode)
                let next: SkyProgress
                if let remote {
                    if revision == baseRevision {
                        guard local != remote else { return Outcome(progress: remote, revision: revision) }
                        next = local
                    } else {
                        next = SkyProgress.merge(base: base, local: local, remote: remote)
                        if next == remote { return Outcome(progress: remote, revision: revision) }
                    }
                } else {
                    next = local
                }
                tx.setData(["progress": try encode(next), "revision": revision + 1,
                            "updatedAt": FieldValue.serverTimestamp(), "schema": 1], forDocument: ref)
                return Outcome(progress: next, revision: revision + 1)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
        guard let outcome = result as? Outcome else { throw CocoaError(.coderInvalidValue) }
        return outcome
    }

    /// Deletes the account's copy, for account deletion.
    func deleteRemote(uid: String) async throws {
        try await Firestore.firestore().collection("users").document(uid).delete()
    }

    /// Forgets the account on this phone (sign out, deletion).
    func forget() {
        stored = nil
        lastSynced = nil
        failed = false
        try? FileManager.default.removeItem(at: file)
    }

    private func remember(_ s: Stored) {
        stored = s
        lastSynced = s.synced
        if let data = try? JSONEncoder().encode(s) {
            try? data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
    }

    nonisolated private static func encode(_ p: SkyProgress) throws -> Data {
        try (JSONEncoder().encode(p) as NSData).compressed(using: .zlib) as Data
    }

    nonisolated private static func decode(_ data: Data) -> SkyProgress? {
        guard let raw = try? (data as NSData).decompressed(using: .zlib) as Data else { return nil }
        return try? JSONDecoder().decode(SkyProgress.self, from: raw)
    }
}
