import AVFoundation
import Observation
import OdakCore

/// Ambient sounds, synthesised live so the app ships with no audio files. Up to two sounds mix,
/// each with its own volume. Playback keeps going with the screen locked (background audio) and
/// mixes with Spotify.
@MainActor @Observable
final class SoundEngine {
    static let maxMix = 2

    private(set) var volumes: [SoundID: Double] = [:]
    private(set) var isPlaying = false

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private let synth = Synth()
    @ObservationIgnored private var node: AVAudioSourceNode?

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
                if !self.isPlaying { self.engine.pause() }
            }
        } else {
            engine.pause()
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
        if isPlaying, volumes.isEmpty { stop() } else if isPlaying { synth.fadeIn() }
    }
}

/// Real-time noise synthesis. Runs on the audio thread, so it only does arithmetic on preallocated state.
final class Synth: @unchecked Sendable {
    var sampleRate: Float = 48_000
    private var voices: [Voice] = SoundID.allCases.map(Voice.init)
    private var master: Float = 1
    private var masterTarget: Float = 1

    func set(_ volumes: [SoundID: Double]) {
        for v in voices { v.target = Float(volumes[v.sound] ?? 0) }
        masterTarget = 1
    }

    func fadeOut() { masterTarget = 0 }
    func fadeIn() { masterTarget = 1 }

    func render(frames: Int, into buffers: UnsafeMutableAudioBufferListPointer) {
        let step = 1 / (sampleRate * 0.8)
        for i in 0..<frames {
            master += (masterTarget - master) * step * 4
            var s: Float = 0
            for v in voices where v.target > 0 || v.gain > 0.0001 {
                v.gain += (v.target - v.gain) * step * 4
                s += v.next(sampleRate) * v.gain
            }
            s = max(-1, min(1, s * master))
            for b in buffers {
                b.mData?.assumingMemoryBound(to: Float.self)[i] = s
            }
        }
    }
}

private final class Voice {
    let sound: SoundID
    var target: Float = 0
    var gain: Float = 0

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
        seed = UInt32(truncatingIfNeeded: sound.rawValue.hashValue) | 1
    }

    @inline(__always) private func white() -> Float {
        seed ^= seed << 13; seed ^= seed >> 17; seed ^= seed << 5
        return Float(seed) / Float(UInt32.max) * 2 - 1
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
        case .brownNoise:
            return brown * 3.2

        case .rain:
            // high-passed pink hiss plus scattered drops
            hpOut = 0.97 * (hpOut + pink - hpPrev); hpPrev = pink
            if chance(28, sr) { burst = 0.25 + (white() + 1) * 0.2; burstDecay = 0.992 }
            burst *= burstDecay
            return hpOut * 0.75 + burst * w * 0.6

        case .waves:
            // brown surf swelling on a slow, uneven swell
            phase += 1 / (sr * 9); if phase > 1 { phase -= 1 }
            let swell = sin(phase * twoPi) * 0.5 + 0.5
            let env = 0.15 + 0.85 * swell * swell
            lp += 0.08 * (pink - lp)
            return (brown * 2.4 + lp * 0.9) * env

        case .fire:
            // low rumble with crackles
            lp += 0.02 * (brown - lp)
            if chance(9, sr) { burst = 0.4 + (white() + 1) * 0.4; burstDecay = 0.985 }
            burst *= burstDecay
            return lp * 5 + burst * w

        case .forest:
            // leaves in a light breeze and the odd bird
            phase += 1 / (sr * 6); if phase > 1 { phase -= 1 }
            let breeze = 0.35 + 0.3 * sin(phase * twoPi)
            if toneEnv < 0.001, chance(0.4, sr) {
                toneFreq = 2600 + (white() + 1) * 900; toneSweep = 1 + (white() * 0.00004); toneEnv = 0.18
            }
            toneFreq *= toneSweep
            tonePhase += toneFreq / sr; if tonePhase > 1 { tonePhase -= 1 }
            toneEnv *= 0.99985
            phase2 += 14 / sr; if phase2 > 1 { phase2 -= 1 }
            let trill = max(0, sin(phase2 * twoPi))
            return pink * breeze * 0.5 + sin(tonePhase * twoPi) * toneEnv * trill * 0.5

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

        case .cafe:
            // murmur of voices and a cup now and then
            lp += 0.04 * (pink - lp)
            phase += (3 + (white() + 1)) / sr; if phase > 1 { phase -= 1 }
            let syllables = 0.55 + 0.45 * sin(phase * twoPi)
            if toneEnv < 0.001, chance(0.12, sr) { toneFreq = 2200 + (white() + 1) * 800; toneEnv = 0.12 }
            tonePhase += toneFreq / sr; if tonePhase > 1 { tonePhase -= 1 }
            toneEnv *= 0.9996
            return lp * syllables * 2.2 + brown * 0.8 + sin(tonePhase * twoPi) * toneEnv
        }
    }
}
