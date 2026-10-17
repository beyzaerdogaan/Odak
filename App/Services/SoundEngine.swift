import AVFoundation
import Observation
import OdakCore

/// Ambient sounds. Rain, forest, waves and fire are real recordings bundled with the app (credits in
/// `Resources/Sounds/KAYNAKLAR.md`); the rest are synthesised live. Up to two sounds mix, each with its own
/// volume. Playback keeps going with the screen locked (background audio) and mixes with Spotify.
@MainActor @Observable
final class SoundEngine {
    static let maxMix = 2

    private(set) var volumes: [SoundID: Double] = [:]
    private(set) var isPlaying = false

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private let synth = Synth()
    @ObservationIgnored private var node: AVAudioSourceNode?
    @ObservationIgnored private var loading: Set<SoundID> = []

    var active: [SoundID] { SoundID.allCases.filter { volumes[$0] != nil } }

    func toggle(_ sound: SoundID, volume: Double = 0.3) {
        if volumes[sound] != nil {
            volumes[sound] = nil
        } else {
            if volumes.count >= Self.maxMix, let first = active.first { volumes[first] = nil }
            volumes[sound] = volume
        }
        sync()
    }

    func setVolume(_ v: Double, for sound: SoundID) {
        guard volumes[sound] != nil else { return }
        volumes[sound] = v
        sync()
    }

    func restore(_ saved: [String: Double]) {
        volumes = Dictionary(uniqueKeysWithValues: saved.compactMap { k, v in SoundID(rawValue: k).map { ($0, v) } }.prefix(Self.maxMix).map { $0 })
        synth.set(volumes)
    }

    var saved: [String: Double] { Dictionary(uniqueKeysWithValues: volumes.map { ($0.key.rawValue, $0.value) }) }

    func play() {
        guard !volumes.isEmpty else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            if node == nil {
                let format = engine.outputNode.inputFormat(forBus: 0)
                let synth = synth
                synth.sampleRate = Float(format.sampleRate)
                let node = Self.makeNode(synth)
                engine.attach(node)
                engine.connect(node, to: engine.mainMixerNode,
                               format: AVAudioFormat(standardFormatWithSampleRate: format.sampleRate, channels: 2))
                self.node = node
            }
            synth.set(volumes)
            loadRecordings()
            if !engine.isRunning { try engine.start() }
            isPlaying = true
        } catch {
            isPlaying = false
        }
    }

    /// Fades out over a second, then stops the engine.
    func stop(fade: Bool = true) {
        guard isPlaying else { return }
        isPlaying = false
        if fade {
            synth.fadeOut()
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.2))
                if !self.isPlaying { self.engine.pause(); self.releaseUnusedRecordings() }
            }
        } else {
            engine.pause()
            releaseUnusedRecordings()
        }
    }

    /// Built outside the main actor so the render callback is not tied to it; it runs on the audio thread.
    nonisolated private static func makeNode(_ synth: Synth) -> AVAudioSourceNode {
        AVAudioSourceNode { _, _, frameCount, bufferList -> OSStatus in
            synth.render(frames: Int(frameCount), into: UnsafeMutableAudioBufferListPointer(bufferList))
            return noErr
        }
    }

    private func sync() {
        synth.set(volumes)
        loadRecordings()
        releaseUnusedRecordings()
        if isPlaying, volumes.isEmpty { stop() } else if isPlaying { synth.fadeIn() }
    }

    /// Decodes the recordings of the chosen sounds off the main thread; a sound stays silent until its recording is in.
    private func loadRecordings() {
        for sound in active where sound.recording != nil && !synth.hasRecording(sound) && !loading.contains(sound) {
            loading.insert(sound)
            Task {
                let loop = await Task.detached(priority: .userInitiated) { Recording(sound) }.value
                loading.remove(sound)
                guard let loop else { return }
                synth.attach(loop, to: sound)
                if volumes[sound] == nil { releaseUnusedRecordings() }
            }
        }
    }

    /// Frees deselected recordings once they have faded out.
    private func releaseUnusedRecordings() {
        guard SoundID.allCases.contains(where: { volumes[$0] == nil && synth.hasRecording($0) }) else { return }
        Task {
            try? await Task.sleep(for: .seconds(3))
            for sound in SoundID.allCases where volumes[sound] == nil {
                synth.detach(sound, stopped: !engine.isRunning)
            }
        }
    }
}

extension SoundID {
    /// The bundled recording this sound plays, if it isn't synthesised.
    var recording: String? {
        switch self {
        case .rain: "ambient-rain"
        case .forest: "ambient-forest"
        case .waves: "ambient-waves"
        case .fire: "ambient-fire"
        default: nil
        }
    }
}

/// A bundled recording decoded into memory as interleaved 16-bit stereo. Its last two seconds are crossfaded into
/// its first two, so it loops with no seam.
final class Recording: @unchecked Sendable {
    let samples: UnsafeMutableBufferPointer<Int16>
    let frames: Int
    let sampleRate: Float

    init?(_ sound: SoundID) {
        guard let name = sound.recording,
              let url = Bundle.main.url(forResource: name, withExtension: "m4a"),
              let file = try? AVAudioFile(forReading: url),
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: buffer)) != nil,
              let data = buffer.floatChannelData else { return nil }
        let rate = Float(file.processingFormat.sampleRate)
        let channels = Int(file.processingFormat.channelCount)
        // skip the encoder's padding at both ends, then fold the tail over the head
        let trim = Int(rate * 0.1), fade = Int(rate * 2)
        let frames = Int(buffer.frameLength) - 2 * trim - fade
        guard frames > fade else { return nil }
        let samples = UnsafeMutableBufferPointer<Int16>.allocate(capacity: frames * 2)
        for c in 0..<2 {
            let ch = data[min(c, channels - 1)]
            for i in 0..<frames {
                var x = ch[trim + i]
                if i < fade {
                    let t = Float(i) / Float(fade) * .pi / 2
                    x = x * sin(t) + ch[trim + frames + i] * cos(t)
                }
                samples[i * 2 + c] = Int16(max(-1, min(1, x)) * 32767)
            }
        }
        self.samples = samples
        self.frames = frames
        sampleRate = rate
    }

    deinit { samples.deallocate() }
}

/// Real-time noise synthesis. Runs on the audio thread, so it only does arithmetic on preallocated state.
final class Synth: @unchecked Sendable {
    var sampleRate: Float = 48_000
    private var voices: [Voice] = SoundID.allCases.map(Voice.init)
    private var master: Float = 1
    private var masterTarget: Float = 1
    /// Owns the loaded recordings; voices only point at them. Touched on the main thread only.
    private var recordings: [SoundID: Recording] = [:]

    func set(_ volumes: [SoundID: Double]) {
        for v in voices { v.target = Float(volumes[v.sound] ?? 0) }
        masterTarget = 1
    }

    func fadeOut() { masterTarget = 0 }
    func fadeIn() { masterTarget = 1 }

    func hasRecording(_ sound: SoundID) -> Bool { recordings[sound] != nil }

    func attach(_ recording: Recording, to sound: SoundID) {
        recordings[sound] = recording
        voices.first { $0.sound == sound }?.start(recording)
    }

    /// Only once the voice has faded out (the audio thread skips a silent voice) or the engine has stopped;
    /// otherwise it stays for the next call.
    func detach(_ sound: SoundID, stopped: Bool) {
        guard recordings[sound] != nil, let v = voices.first(where: { $0.sound == sound }),
              stopped || (v.target == 0 && v.gain <= 0.0001) else { return }
        v.recording = nil
        recordings[sound] = nil
    }

    func render(frames: Int, into buffers: UnsafeMutableAudioBufferListPointer) {
        let step = 1 / (sampleRate * 0.8)
        for i in 0..<frames {
            master += (masterTarget - master) * step * 4
            var l: Float = 0, r: Float = 0
            for v in voices where v.target > 0 || v.gain > 0.0001 {
                if let rec = v.recording {
                    v.gain += (v.target - v.gain) * step * 4
                    let (a, b) = v.play(rec, sampleRate)
                    l += a * v.gain; r += b * v.gain
                } else if !v.recorded {
                    v.gain += (v.target - v.gain) * step * 4
                    let m = v.next(sampleRate) * v.gain
                    l += m; r += m
                }
                // a recording still loading stays silent with its gain at zero, so it fades in once it arrives
            }
            l = max(-1, min(1, l * master))
            r = max(-1, min(1, r * master))
            for (c, b) in buffers.enumerated() {
                b.mData?.assumingMemoryBound(to: Float.self)[i] = buffers.count == 1 ? (l + r) / 2 : c == 0 ? l : r
            }
        }
    }
}

private final class Voice {
    let sound: SoundID
    let recorded: Bool
    var target: Float = 0
    var gain: Float = 0
    /// Kept alive by `Synth.recordings`; a plain pointer so the audio thread does no reference counting.
    unowned(unsafe) var recording: Recording?
    private var position: Double = 0

    // generator state
    private var seed: UInt32
    private var brown: Float = 0
    private var p0: Float = 0, p1: Float = 0, p2: Float = 0
    private var lp: Float = 0, lp2: Float = 0, hpPrev: Float = 0, hpOut: Float = 0
    private var phase: Float = 0, phase2: Float = 0
    private var burst: Float = 0, burstDecay: Float = 0.999
    private var tone: Float = 0, toneFreq: Float = 0, toneEnv: Float = 0, tonePhase: Float = 0, toneSweep: Float = 0

    init(_ sound: SoundID) {
        self.sound = sound
        recorded = sound.recording != nil
        seed = UInt32(truncatingIfNeeded: sound.rawValue.hashValue) | 1
    }

    @inline(__always) private func white() -> Float {
        seed ^= seed << 13; seed ^= seed >> 17; seed ^= seed << 5
        return Float(seed) / Float(UInt32.max) * 2 - 1
    }

    func start(_ recording: Recording) {
        // a random spot, so the loop doesn't open the same way every time
        position = Double((white() + 1) / 2) * Double(recording.frames - 1)
        gain = 0
        self.recording = recording
    }

    /// The next stereo frame of the recording, resampled to the output rate.
    @inline(__always) func play(_ rec: Recording, _ sr: Float) -> (Float, Float) {
        let i = Int(position), j = i + 1 == rec.frames ? 0 : i + 1
        let f = Float(position - Double(i))
        let s = rec.samples
        let l = Float(s[i * 2]) + (Float(s[j * 2]) - Float(s[i * 2])) * f
        let r = Float(s[i * 2 + 1]) + (Float(s[j * 2 + 1]) - Float(s[i * 2 + 1])) * f
        position += Double(rec.sampleRate / sr)
        if position >= Double(rec.frames) { position -= Double(rec.frames) }
        return (l / 32768, r / 32768)
    }

    @inline(__always) private func chance(_ perSecond: Float, _ sr: Float) -> Bool {
        (white() + 1) / 2 < perSecond / sr
    }

    func next(_ sr: Float) -> Float {
        let w = white()
        brown = (brown + 0.02 * w) / 1.02
        p0 = 0.99765 * p0 + w * 0.0990460
        p1 = 0.96300 * p1 + w * 0.2965164
        p2 = 0.57000 * p2 + w * 1.0526913
        let pink = (p0 + p1 + p2 + w * 0.1848) * 0.11
        let twoPi: Float = 2 * .pi

        switch sound {
        case .rain, .forest, .waves, .fire:
            return 0 // recorded, see `play`

        case .brownNoise:
            return brown * 3.2

        case .winterNight:
            // wind: pink noise through a slowly wandering low-pass
            phase += 1 / (sr * 11); if phase > 1 { phase -= 1 }
            let gust = 0.5 + 0.5 * sin(phase * twoPi)
            let k: Float = 0.004 + 0.03 * gust
            lp += k * (pink - lp)
            lp2 += k * (lp - lp2)
            return lp2 * (3 + 5 * gust)

        case .library:
            // a quiet room with an occasional page turn
            lp += 0.05 * (pink - lp)
            if chance(0.08, sr) { burst = 0.35; burstDecay = 0.99985 }
            burst *= burstDecay
            hpOut = 0.9 * (hpOut + w - hpPrev); hpPrev = w
            return lp * 0.5 + hpOut * burst * 0.25

        case .summerNight:
            // crickets chirping over a warm, still night
            lp += 0.01 * (pink - lp)
            phase += 1 / (sr * 0.85); if phase > 1 { phase -= 1 }
            let gate: Float = phase < 0.22 ? sin(phase / 0.22 * .pi) : 0
            phase2 += 30 / sr; if phase2 > 1 { phase2 -= 1 }
            let pulse = max(0, sin(phase2 * twoPi))
            tonePhase += 4400 / sr; if tonePhase > 1 { tonePhase -= 1 }
            // a second, farther cricket a little out of step
            toneSweep += 1 / (sr * 1.1); if toneSweep > 1 { toneSweep -= 1 }
            let gate2: Float = toneSweep < 0.18 ? sin(toneSweep / 0.18 * .pi) : 0
            toneFreq += 3900 / sr; if toneFreq > 1 { toneFreq -= 1 }
            let chirp = sin(tonePhase * twoPi) * gate * pulse * pulse * 0.16
                + sin(toneFreq * twoPi) * gate2 * pulse * 0.07
            return lp * 1.6 + chirp

        case .stream:
            // water running over stones: shimmering mid noise and small bubbles
            lp += 0.25 * (w - lp)
            hpOut = 0.92 * (hpOut + lp - hpPrev); hpPrev = lp
            let ripple = max(0.2, 0.7 + brown * 5)
            if toneEnv < 0.002, chance(7, sr) { toneFreq = 500 + (white() + 1) * 450; toneEnv = 0.09 }
            toneFreq *= 1.00004
            tonePhase += toneFreq / sr; if tonePhase > 1 { tonePhase -= 1 }
            toneEnv *= 0.9992
            return hpOut * ripple * 0.8 + sin(tonePhase * twoPi) * toneEnv

        case .distantStorm:
            // soft rain with thunder rolling far away now and then
            hpOut = 0.9 * (hpOut + pink - hpPrev); hpPrev = pink
            lp += 0.15 * (hpOut - lp)
            if burst < 0.01, chance(0.045, sr) { burst = 0.6 + (white() + 1) * 0.3 }
            burst *= 0.999992
            tone += (burst - tone) * 0.00008
            lp2 += 0.02 * (brown - lp2)
            return lp * 2 + lp2 * tone * 6
        }
    }
}
