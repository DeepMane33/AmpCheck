import AVFoundation
import Accelerate
import UIKit

// MARK: - 🎙️ Real Microphone Tone Analyzer
//
// Replaces the old fake "Sound Test" (which returned Double.random()).
// It taps the hardware microphone, runs an FFT (vDSP) on every frame and
// measures the actual energy distribution of what is being played:
//
//   BASS   = 40 Hz  – 250 Hz   (low E string fundamental is ~82 Hz)
//   MID    = 250 Hz – 2000 Hz  (most guitar body/fret information)
//   TREBLE = 2000 Hz– 8000 Hz  (pick attack, string brightness)
//
// Design goals (honesty first):
//   • Long-duration analysis: the meter stays open while the player keeps
//     playing chords. The longer it listens, the more accurate the stats.
//   • Multi-strike: every chord strike (onset after a quiet gap) is scored
//     separately, so results show REPEATABILITY, not one lucky strum.
//   • Silence gate: if nothing is heard, NO result is ever fabricated.

// MARK: - 📋 Measured Tone Report

struct StrikeStat: Codable, Equatable {
    let bass: Double      // 0–10
    let mid: Double       // 0–10
    let treble: Double    // 0–10
    let level: Double     // 0–1
}

struct ToneReport: Codable, Equatable {
    let bass: Double           // 0–10 average across the whole session
    let mid: Double            // 0–10
    let treble: Double         // 0–10
    let bassShare: Double      // fraction of total spectral energy
    let midShare: Double
    let trebleShare: Double
    let centroidHz: Double     // spectral centroid = "center of gravity" of tone
    let level: Double          // 0–1 average loudness
    let seconds: Double        // usable audio actually measured
    let strikes: Int           // how many separate chord strikes were scored
    let consistency: Double?   // 0–1, nil when fewer than 2 strikes
    let sustainSeconds: Double // how long a chord rings before decaying
    let dynamics: Double       // peak/average ratio (punch vs compression)

    var qualityLabel: String {
        if seconds >= 15 { return "Excellent" }
        if seconds >= 8 { return "Good" }
        if seconds >= 3 { return "Basic" }
        return "Marginal"
    }

    /// Plain-language character of the measured tone (derived, not guessed).
    var toneCharacter: String {
        if bassShare > 0.5 {
            return "Bass-heavy & warm"
        } else if trebleShare >= 0.28 {
            return "Bright & clear"
        } else if midShare > 0.55 {
            return "Mid-forward & punchy"
        } else if midShare < 0.25 && bassShare > 0.40 {
            return "Scooped (V-shaped)"
        } else {
            return "Balanced"
        }
    }

    /// What the measurements suggest the amp handles well.
    var genreFit: [String] {
        var fits: [String] = []

        if bassShare > 0.5 && midShare < 0.35 {
            fits.append("Heavy rock & metal (thick low end)")
        }
        if midShare > 0.5 {
            fits.append("Blues & classic rock (mids carry the cut)")
        }
        if trebleShare >= 0.28 {
            fits.append("Funk, pop & clean playing ( clear attack )")
        }
        if abs(bassShare - 0.40) < 0.08 && abs(midShare - 0.40) < 0.10 {
            fits.append("Versatile all-rounder (even energy spread)")
        }
        if fits.isEmpty {
            fits.append("Rhythm playing with an even EQ curve")
        }
        return fits
    }

    var consistencyLabel: String {
        guard let c = consistency else {
            return "Single continuous pass — play several strikes for a reliability check"
        }
        if c >= 0.8 { return "Very consistent ✓ — readings repeat well" }
        if c >= 0.6 { return "Mostly consistent — decent repeatability" }
        return "Varies between strikes — try uniform strumming at one volume"
    }
}

// MARK: - 🎛️ Analyzer

final class AudioAnalyzer: ObservableObject {

    enum Phase: Equatable {
        case idle          // not started
        case requesting    // waiting for mic permission
        case listening     // meter open, gathering audio
        case tooQuiet      // listening, but no signal / not enough yet
        case denied        // user refused microphone access
        case failed        // audio engine could not start
        case done          // analysis captured
    }

    // Published, updated on the main thread.
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var liveBass: Double = 5
    @Published private(set) var liveMid: Double = 5
    @Published private(set) var liveTreble: Double = 5
    @Published private(set) var liveLevel: Double = 0
    @Published private(set) var liveCentroidHz: Double = 0
    @Published private(set) var audibleSeconds: Double = 0
    @Published private(set) var strikeCount: Int = 0
    @Published private(set) var lastStrike: StrikeStat?
    @Published private(set) var result: ToneReport?

    /// When true, live haptic pulses track the measured tone (bass = strong,
    /// treble = light tick). Set by SoundTestView from its toggle.
    var hapticsEnabled = false {
        didSet {
            if hapticsEnabled { heavyHaptic.prepare() }
        }
    }

    // MARK: Tuning

    private let fftSize = 2048
    /// Below this much audible audio the analyzer refuses to give an answer.
    private let minAudibleSeconds: Double = 3.0
    /// Security cap so a forgotten "listening" state can't run forever.
    private let maxAudibleSeconds: Double = 30.0
    /// RMS below this (~ -44 dBFS) is treated as silence / room noise.
    private let silenceRMS: Float = 0.006
    /// A quiet gap longer than this ends one chord strike and arms the next.
    private let strikeGapSeconds: Double = 0.30
    /// Reference energy shares that map to a "5" on the 0–10 scale. Guitar
    /// energy lives mostly in the low/mid region; these constants normalise it.
    private let referenceBassShare = 0.40
    private let referenceMidShare = 0.40
    private let referenceTrebleShare = 0.20

    // MARK: Audio plumbing

    private let engine = AVAudioEngine()
    private var fftSetups: [Int: FFTSetup] = [:]
    private var windowCache: [Int: [Float]] = [:]
    private var running = false
    private var finalized = false

    // Analysis accumulators (touched on the tap's serial audio queue)
    private var noiseFloor: Float = 0.001
    private var totalSeconds: Double = 0
    private var audibleSecondsLocal: Double = 0

    // Whole-session totals
    private var totalFrames = 0
    private var sumBassEnergy: Double = 0
    private var sumMidEnergy: Double = 0
    private var sumTrebleEnergy: Double = 0
    private var sumWeightedFreq: Double = 0   // Σ f·E for the spectral centroid
    private var sumEnergyForCentroid: Double = 0
    private var sumLevel: Double = 0

    // Per-strike accumulators
    private var strikeFrames = 0
    private var strikeSeconds: Double = 0
    private var strikeBass: Double = 0
    private var strikeMid: Double = 0
    private var strikeTreble: Double = 0
    private var strikeLevel: Double = 0
    private var strikePeakRMS: Float = 0
    private var strikeSustainFrames = 0
    private var quietSeconds: Double = 0
    private var strikes: [StrikeStat] = []
    private var strikeSustains: [Double] = []
    private var globalPeakRMS: Float = 0

    // Live smoothing
    private var emaBass: Double = 0.40
    private var emaMid: Double = 0.40
    private var emaTreble: Double = 0.20
    private var lastUIUpdate: CFAbsoluteTime = 0

    private let heavyHaptic = UIImpactFeedbackGenerator(style: .heavy)
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)

    // MARK: Lifecycle

    func start() {
        guard !running else { return }
        resetAnalysis()
        result = nil
        phase = .requesting

        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async { self?.handlePermission(granted) }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async { self?.handlePermission(granted) }
            }
        }
    }

    /// Stops the meter and produces the report if enough audio was measured.
    /// Call this whenever the player finishes their set of chords.
    func stop() {
        guard running else { return }
        running = false
        teardownEngine()

        if finalized { return } // auto-finalize already produced a report

        if audibleSecondsLocal >= minAudibleSeconds {
            finalizeResult()
        } else {
            phase = .tooQuiet
        }
    }

    func reset() {
        stop()
        result = nil
        audibleSeconds = 0
        strikeCount = 0
        phase = .idle
    }

    // MARK: Permission

    private func handlePermission(_ granted: Bool) {
        guard phase == .requesting else { return }
        if granted {
            beginListening()
        } else {
            phase = .denied
        }
    }

    private func beginListening() {
        let session = AVAudioSession.sharedInstance()
        do {
            // .measurement mode disables AGC/eq colouration so the spectrum
            // reflects the amp, not the phone's "improvements".
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            print("AmpCheck: audio session error: \(error)")
            phase = .failed
            return
        }

        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            phase = .failed
            return
        }

        input.removeTap(onBus: 0)
        running = true
        finalized = false
        input.installTap(onBus: 0, bufferSize: AVAudioFrameCount(fftSize), format: format) { [weak self] buffer, _ in
            self?.process(buffer: buffer, sampleRate: format.sampleRate)
        }

        do {
            engine.prepare()
            try engine.start()
            phase = .listening
        } catch {
            print("AmpCheck: engine start error: \(error)")
            running = false
            teardownEngine()
            phase = .failed
        }
    }

    private func teardownEngine() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(
            false, options: .notifyOthersOnDeactivation
        )
    }

    private func resetAnalysis() {
        noiseFloor = 0.001
        totalSeconds = 0
        audibleSecondsLocal = 0
        totalFrames = 0
        sumBassEnergy = 0
        sumMidEnergy = 0
        sumTrebleEnergy = 0
        sumWeightedFreq = 0
        sumEnergyForCentroid = 0
        sumLevel = 0
        strikeFrames = 0
        strikeBass = 0
        strikeMid = 0
        strikeTreble = 0
        strikeLevel = 0
        strikePeakRMS = 0
        strikeSustainFrames = 0
        strikeSeconds = 0
        quietSeconds = 0
        strikes = []
        strikeSustains = []
        globalPeakRMS = 0
        emaBass = referenceBassShare
        emaMid = referenceMidShare
        emaTreble = referenceTrebleShare
        audibleSeconds = 0
        strikeCount = 0
        lastStrike = nil
        finalized = false
    }

    // MARK: DSP (audio queue)

    private func process(buffer: AVAudioPCMBuffer, sampleRate: Double) {
        guard running, !finalized else { return }
        let n = Int(buffer.frameLength)
        guard n > 0, let channel = buffer.floatChannelData?[0] else { return }

        // 1. RMS level & noise gate
        var rms: Float = 0
        vDSP_rmsqv(channel, 1, &rms, vDSP_Length(n))
        if rms.isNaN || rms.isInfinite { rms = 0 }

        let interval = Double(n) / sampleRate
        totalSeconds += interval

        let gate = max(silenceRMS, noiseFloor * 3)
        let audible = rms > gate

        if !audible {
            // Track the room noise floor so the gate follows the environment.
            noiseFloor = noiseFloor * 0.95 + rms * 0.05
            quietSeconds += interval

            // A long-enough quiet gap closes the current chord strike...
            if strikeFrames > 0 && quietSeconds > strikeGapSeconds {
                closeStrike()
            }

            if audibleSecondsLocal < 0.05 && totalSeconds > 1.5 {
                phase = .tooQuiet
            }
        } else {
            quietSeconds = 0

            // 2. FFT → band energies + spectral centroid
            let magnitudes = runFFT(samples: channel, count: n)
            var bassE = 0.0, midE = 0.0, trebleE = 0.0
            var weighted = 0.0, totalE = 0.0
            let halfN = magnitudes.count
            let binHz = sampleRate / Double(fftSize)
            for bin in 1..<halfN {
                let freq = Double(bin) * binHz
                guard freq >= 40 && freq < 8000 else { continue }
                let e = Double(magnitudes[bin] * magnitudes[bin])
                totalE += e
                weighted += freq * e
                if freq < 250 {
                    bassE += e
                } else if freq < 2000 {
                    midE += e
                } else {
                    trebleE += e
                }
            }

            // 3. Accumulate (whole session + current strike)
            audibleSecondsLocal += interval
            totalFrames += 1
            sumBassEnergy += bassE
            sumMidEnergy += midE
            sumTrebleEnergy += trebleE
            sumWeightedFreq += weighted
            sumEnergyForCentroid += totalE
            sumLevel += Double(rms)

            strikeFrames += 1
            strikeBass += bassE
            strikeMid += midE
            strikeTreble += trebleE
            strikeLevel += Double(rms)

            if rms > strikePeakRMS { strikePeakRMS = rms }
            if strikePeakRMS > 0 && rms > strikePeakRMS * 0.1 {
                strikeSustainFrames += 1
            }
            if rms > globalPeakRMS { globalPeakRMS = rms }

            strikeSeconds += interval

            let total = bassE + midE + trebleE
            if total > 0 {
                emaBass = emaBass * 0.86 + (bassE / total) * 0.14
                emaMid = emaMid * 0.86 + (midE / total) * 0.14
                emaTreble = emaTreble * 0.86 + (trebleE / total) * 0.14
            }

            if totalE > 0, sumEnergyForCentroid > 0 {
                // Session-wide running centroid.
                _ = weighted // per-frame centroid contribution already summed
            }

            if totalSeconds >= 1.5 {
                phase = .listening
            }

            // 4. Long-session safety cap: package up what we have.
            if audibleSecondsLocal >= maxAudibleSeconds {
                closeStrike()
                finalized = true
                finalizeResult()
                DispatchQueue.main.async {
                    self.running = false
                    self.teardownEngine()
                }
                return
            }
        }

        // 5. Throttled UI publish + haptics.
        let now = CFAbsoluteTimeGetCurrent()
        if now - lastUIUpdate > 0.06 {
            lastUIUpdate = now
            publishLive(audible: audible, rms: rms, sampleRate: sampleRate)
        }
    }

    /// Computes the finished stat for the chord strike that just ended and
    /// stores it for the consistency check.
    private func closeStrike() {
        guard strikeFrames >= 4 else {
            strikeFrames = 0
            strikeBass = 0; strikeMid = 0; strikeTreble = 0; strikeLevel = 0
            return
        }
        let b = strikeBass, m = strikeMid, t = strikeTreble
        let total = b + m + t
        if total > 0 {
            let stat = StrikeStat(
                bass: score(share: b / total, reference: referenceBassShare),
                mid: score(share: m / total, reference: referenceMidShare),
                treble: score(share: t / total, reference: referenceTrebleShare),
                level: min(1.0, max(0.0, (20.0 * log10(Double(max(strikeLevel / Double(strikeFrames), 1e-7))) + 40.0) / 44.0))
            )
            strikes.append(stat)
            if strikeFrames > 0 {
                let sustain = Double(strikeSustainFrames) * strikeSeconds / Double(strikeFrames)
                strikeSustains.append(sustain)
            }
            let count = strikes.count
            let last = stat
            DispatchQueue.main.async {
                self.lastStrike = last
                self.strikeCount = count
            }
        }
        strikeFrames = 0
        strikeBass = 0; strikeMid = 0; strikeTreble = 0; strikeLevel = 0
        strikePeakRMS = 0
        strikeSustainFrames = 0
        strikeSeconds = 0
    }

    private func publishLive(audible: Bool, rms: Float, sampleRate: Double) {
        let db = 20.0 * log10(Double(max(rms, 1e-7)))
        let level = min(1.0, max(0.0, (db + 40.0) / 44.0))

        let centroid = sumEnergyForCentroid > 0
            ? sumWeightedFreq / sumEnergyForCentroid
            : 0.0
        let isFinalPhase = finalized

        DispatchQueue.main.async {
            guard !isFinalPhase else { return }
            if audible {
                self.liveBass = self.score(share: self.emaBass, reference: self.referenceBassShare)
                self.liveMid = self.score(share: self.emaMid, reference: self.referenceMidShare)
                self.liveTreble = self.score(share: self.emaTreble, reference: self.referenceTrebleShare)
                self.liveCentroidHz = centroid
            }
            self.liveLevel = audible ? level : 0
            self.audibleSeconds = self.audibleSecondsLocal
            self.strikeCount = self.strikes.count

            if self.hapticsEnabled && audible {
                self.heavyHaptic.impactOccurred(
                    intensity: CGFloat(min(1.0, 0.25 + self.emaBass / 0.7))
                )
                if self.emaTreble > self.referenceTrebleShare {
                    self.lightHaptic.impactOccurred(intensity: 0.5)
                }
            }
        }
    }

    private func finalizeResult() {
        guard totalFrames > 0 else {
            DispatchQueue.main.async {
                self.result = nil
                self.phase = .tooQuiet
            }
            return
        }

        let avgBass = sumBassEnergy / Double(totalFrames)
        let avgMid = sumMidEnergy / Double(totalFrames)
        let avgTreble = sumTrebleEnergy / Double(totalFrames)
        let avgLevel = sumLevel / Double(totalFrames)
        let centroid = sumEnergyForCentroid > 0 ? sumWeightedFreq / sumEnergyForCentroid : 0

        let sustainSeconds = strikeSustains.isEmpty
            ? 0.0
            : strikeSustains.reduce(0, +) / Double(strikeSustains.count)
        let dynamics = avgLevel > 0 ? Double(globalPeakRMS) / avgLevel : 1.0

        let total = avgBass + avgMid + avgTreble
        var bassScore = 5.0, midScore = 5.0, trebleScore = 5.0
        var bassShare = 0.40, midShare = 0.40, trebleShare = 0.20

        if total > 0 {
            bassShare = avgBass / total
            midShare = avgMid / total
            trebleShare = avgTreble / total
            bassScore = score(share: bassShare, reference: referenceBassShare)
            midScore = score(share: midShare, reference: referenceMidShare)
            trebleScore = score(share: trebleShare, reference: referenceTrebleShare)
        }

        // Repeatability: mean absolute deviation across the measured strikes.
        var consistency: Double? = nil
        if strikes.count >= 2 {
            let bands: [(StrikeStat) -> Double] = [
                { $0.bass }, { $0.mid }, { $0.treble }
            ]
            var totalMad = 0.0
            for accessor in bands {
                let values = strikes.map { accessor($0) }
                let mean = values.reduce(0, +) / Double(values.count)
                let mad = values.map { abs($0 - mean) }.reduce(0, +) / Double(values.count)
                totalMad += mad
            }
            let avgMad = totalMad / 3.0
            consistency = min(1.0, max(0.0, 1.0 - avgMad / 2.5))
        }

        let report = ToneReport(
            bass: bassScore,
            mid: midScore,
            treble: trebleScore,
            bassShare: bassShare,
            midShare: midShare,
            trebleShare: trebleShare,
            centroidHz: centroid,
            level: min(1.0, max(0.0, (20.0 * log10(Double(max(avgLevel, 1e-7))) + 40.0) / 44.0)),
            seconds: audibleSecondsLocal,
            strikes: max(strikes.count, totalFrames > 0 ? 1 : 0),
            consistency: consistency,
            sustainSeconds: sustainSeconds,
            dynamics: dynamics
        )

        DispatchQueue.main.async {
            self.result = report
            self.audibleSeconds = self.audibleSecondsLocal
            self.strikeCount = self.strikes.count
            self.phase = .done
        }
    }

    private func score(share: Double, reference: Double) -> Double {
        // Balanced-equal reference maps to 5; clamp keeps the scale sane.
        min(10, max(0.5, 5 * (share / reference)))
    }

    // MARK: FFT helpers

    private func window(for size: Int) -> [Float] {
        if let cached = windowCache[size] { return cached }
        var w = [Float](repeating: 0, count: size)
        let denominator = Float(size - 1)
        for i in 0..<size {
            w[i] = 0.5 - 0.5 * cos(2 * Float.pi * Float(i) / denominator)
        }
        windowCache[size] = w
        return w
    }

    private func fftSetup(for size: Int) -> FFTSetup? {
        if let cached = fftSetups[size] { return cached }
        let log2n = vDSP_Length(Int(log2(Double(size))))
        guard log2n > 0, let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return nil
        }
        fftSetups[size] = setup
        return setup
    }

    private func runFFT(samples: UnsafeMutablePointer<Float>, count: Int) -> [Float] {
        guard let setup = fftSetup(for: count) else { return [] }
        let halfN = count / 2
        var real = [Float](repeating: 0, count: count)
        var imag = [Float](repeating: 0, count: count)
        let windowValues = window(for: count)

        for i in 0..<count {
            real[i] = samples[i] * windowValues[i]
        }

        var magnitudes = [Float](repeating: 0, count: halfN)
        real.withUnsafeMutableBufferPointer { realBP in
            imag.withUnsafeMutableBufferPointer { imagBP in
                var split = DSPSplitComplex(realp: realBP.baseAddress!, imagp: imagBP.baseAddress!)
                let log2n = vDSP_Length(Int(log2(Double(count))))
                vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))

                var scale: Float = 0.5
                vDSP_vsmul(split.realp, 1, &scale, split.realp, 1, vDSP_Length(halfN))
                vDSP_vsmul(split.imagp, 1, &scale, split.imagp, 1, vDSP_Length(halfN))
                vDSP_zvabs(&split, 1, &magnitudes, 1, vDSP_Length(halfN))
            }
        }
        return magnitudes
    }

    deinit {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        fftSetups.forEach { vDSP_destroy_fftsetup($0.value) }
    }
}

// MARK: - 🥁 Real Metronome (used by Practice Mode)

/// A genuine audio metronome. The old play button only flipped a boolean;
/// this one schedules real click buffers through AVAudioEngine so beginners
/// actually hear the pulse at the tempo they set.
final class MetronomeEngine: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var beatCount = 0
    @Published private(set) var beatInBar = 0

    var tempo: Double = 120  // BPM

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let clickSeconds: Double = 0.045

    var beatsPerBar: Int = 4

    func start() {
        guard !isPlaying else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("AmpCheck: metronome session error: \(error)")
            return
        }

        engine.attach(player)
        let mixer = engine.mainMixerNode
        engine.connect(player, to: mixer, format: mixer.outputFormat(forBus: 0))

        do {
            engine.prepare()
            try engine.start()
        } catch {
            print("AmpCheck: metronome engine error: \(error)")
            return
        }

        isPlaying = true
        beatCount = 0
        beatInBar = 0
        player.play()
        scheduleNextBeat()
    }

    func stop() {
        guard isPlaying else { return }
        isPlaying = false
        player.stop()
        engine.stop()
        engine.detach(player)
        try? AVAudioSession.sharedInstance().setActive(
            false, options: .notifyOthersOnDeactivation
        )
    }

    private func scheduleNextBeat() {
        guard isPlaying else { return }
        let beatSeconds = 60.0 / max(30, tempo)
        let outputFormat = engine.mainMixerNode.outputFormat(forBus: 0)
        let sampleRate = outputFormat.sampleRate > 0 ? outputFormat.sampleRate : 44100

        let accent = beatInBar == 0
        let buffer = metronomeBuffer(
            sampleRate: sampleRate,
            totalSeconds: beatSeconds,
            frequency: accent ? 1400 : 900,
            amplitude: accent ? 0.85 : 0.5
        )

        player.scheduleBuffer(buffer, at: nil, options: []) { [weak self] in
            DispatchQueue.main.async { self?.beatCompleted() }
        }
    }

    private func beatCompleted() {
        guard isPlaying else { return }
        beatCount += 1
        beatInBar = (beatInBar + 1) % beatsPerBar
        scheduleNextBeat()
    }

    /// One beat = one buffer of exactly `beatSeconds`, click at the head with a
    /// fast exponential decay. Changing tempo takes effect on the next beat.
    private func metronomeBuffer(sampleRate: Double, totalSeconds: Double, frequency: Double, amplitude: Double) -> AVAudioPCMBuffer {
        let frames = max(1, AVAudioFrameCount(sampleRate * totalSeconds))
        let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: outputChannelCount
        )!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let data = buffer.floatChannelData![0]
        let clickFrames = Int(Double(frames) * clickSeconds / max(0.001, totalSeconds))
        for i in 0..<Int(frames) {
            if i < clickFrames {
                let t = Double(i) / sampleRate
                let envelope = exp(-t * 45)
                data[i] = Float(amplitude * envelope * sin(2 * Double.pi * frequency * t))
            } else {
                data[i] = 0
            }
        }
        return buffer
    }

    private var outputChannelCount: AVAudioChannelCount {
        let fmt = engine.mainMixerNode.outputFormat(forBus: 0)
        return fmt.channelCount > 0 ? fmt.channelCount : 2
    }

    deinit {
        stop()
    }
}

// MARK: - 🎼 Experimental Chord Detective (chroma + template matching)
//
// Honest scope: this is a real DSP-based chord guesser, NOT a trained ML
// model. It works best on clean single chords played one at a time with
// clear pauses. Polyphonic strumming and full songs are hard and the
// confidence will be low — that is reported honestly, never faked.

final class ChordDetector: ObservableObject {
    @Published private(set) var isListening = false
    @Published private(set) var detectedChords: [DetectedChord] = []
    @Published private(set) var liveChroma: [Double] = Array(repeating: 0, count: 12)
    @Published private(set) var liveGuess: String = "—"
    @Published private(set) var liveConfidence: Double = 0

    private let engine = AVAudioEngine()
    private var fftSetups: [Int: FFTSetup] = [:]
    private var windowCache: [Int: [Float]] = [:]
    private var running = false

    private var noiseFloor: Float = 0.001
    private var quietSeconds: Double = 0
    private var segmentChroma: [Double] = Array(repeating: 0, count: 12)
    private var segmentFrames = 0
    private var lastClassificationTime: CFAbsoluteTime = 0

    private let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    // Chord templates: (suffix, interval pattern relative to root)
    private let templates: [(String, [Int])] = [
        ("", [0, 4, 7]),            // major
        ("m", [0, 3, 7]),           // minor
        ("5", [0, 7]),              // power
        ("7", [0, 4, 7, 10]),      // dominant 7
        ("maj7", [0, 4, 7, 11]),   // major 7
        ("m7", [0, 3, 7, 10]),     // minor 7
        ("sus2", [0, 2, 7]),        // suspended 2
        ("sus4", [0, 5, 7]),        // suspended 4
        ("dim", [0, 3, 6]),         // diminished
        ("aug", [0, 4, 8])          // augmented
    ]

    func start() {
        guard !running else { return }
        detectedChords = []
        segmentChroma = Array(repeating: 0, count: 12)
        segmentFrames = 0
        quietSeconds = 0
        running = true

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            print("ChordDetector: session error \(error)")
            running = false
            return
        }

        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        guard format.sampleRate > 0 else { running = false; return }

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            self?.process(buffer: buffer, sampleRate: format.sampleRate)
        }
        do {
            engine.prepare()
            try engine.start()
            isListening = true
        } catch {
            print("ChordDetector: engine error \(error)")
            running = false
        }
    }

    func stop() {
        guard running else { return }
        running = false
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isListening = false
        // Classify whatever is left in the current segment.
        classifySegment()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func process(buffer: AVAudioPCMBuffer, sampleRate: Double) {
        guard running else { return }
        let n = Int(buffer.frameLength)
        guard n > 0, let channel = buffer.floatChannelData?[0] else { return }

        var rms: Float = 0
        vDSP_rmsqv(channel, 1, &rms, vDSP_Length(n))
        if rms.isNaN { rms = 0 }

        let interval = Double(n) / sampleRate
        let gate = max(0.006, noiseFloor * 3)
        let audible = rms > gate

        if !audible {
            noiseFloor = noiseFloor * 0.95 + rms * 0.05
            quietSeconds += interval
            if segmentFrames > 8 && quietSeconds > 0.25 {
                classifySegment()
            }
            return
        }
        quietSeconds = 0

        // Chroma from FFT
        let magnitudes = runFFT(samples: channel, count: n, setupSize: n)
        var chroma = Array(repeating: 0.0, count: 12)
        let binHz = sampleRate / Double(n)
        for bin in 1..<(magnitudes.count) {
            let freq = Double(bin) * binHz
            guard freq >= 60 && freq < 2000 else { continue }
            let midi = 12 * log2(freq / 440.0) + 69
            let pc = ((Int(round(midi)) % 12) + 12) % 12
            chroma[pc] += Double(magnitudes[bin] * magnitudes[bin])
        }

        // Accumulate into the current segment
        for i in 0..<12 { segmentChroma[i] += chroma[i] }
        segmentFrames += 1

        // Live guess every ~0.4s
        let now = CFAbsoluteTimeGetCurrent()
        if now - lastClassificationTime > 0.4 {
            lastClassificationTime = now
            let guess = classify(chroma: chroma)
            DispatchQueue.main.async {
                self.liveChroma = self.normalize(chroma)
                self.liveGuess = guess.name
                self.liveConfidence = guess.confidence
            }
        }
    }

    private func classifySegment() {
        guard segmentFrames >= 8 else {
            segmentChroma = Array(repeating: 0, count: 12)
            segmentFrames = 0
            return
        }
        let result = classify(chroma: segmentChroma)
        if result.confidence >= 0.45 {
            let chord = DetectedChord(name: result.name, confidence: result.confidence)
            DispatchQueue.main.async {
                self.detectedChords.append(chord)
            }
        }
        segmentChroma = Array(repeating: 0, count: 12)
        segmentFrames = 0
    }

    private func normalize(_ v: [Double]) -> [Double] {
        let norm = sqrt(v.reduce(0) { $0 + $1 * $1 })
        guard norm > 0 else { return v }
        return v.map { $0 / norm }
    }

    private func classify(chroma: [Double]) -> (name: String, confidence: Double) {
        let n = normalize(chroma)
        var bestName = "—"
        var bestSim = 0.0
        for root in 0..<12 {
            for (suffix, intervals) in templates {
                var template = Array(repeating: 0.0, count: 12)
                for iv in intervals {
                    template[(root + iv) % 12] = 1.0
                }
                let tNorm = normalize(template)
                let denom = (sqrt(n.reduce(0){$0+$1*$1}) * sqrt(tNorm.reduce(0){$0+$1*$1}) + 1e-9)
                let cosSim = zip(n, tNorm).reduce(0.0) { $0 + $1.0 * $1.1 } / denom
                if cosSim > bestSim {
                    bestSim = cosSim
                    bestName = noteNames[root] + suffix
                }
            }
        }
        if bestSim < 0.45 { bestName = "—" }
        return (bestName, bestSim)
    }

    // FFT helpers (reuse same approach, sized to buffer)
    private func window(for size: Int) -> [Float] {
        if let cached = windowCache[size] { return cached }
        var w = [Float](repeating: 0, count: size)
        let denom = Float(size - 1)
        for i in 0..<size { w[i] = 0.5 - 0.5 * cos(2 * Float.pi * Float(i) / denom) }
        windowCache[size] = w
        return w
    }

    private func fftSetup(for size: Int) -> FFTSetup? {
        if let cached = fftSetups[size] { return cached }
        let log2n = vDSP_Length(Int(log2(Double(size))))
        guard log2n > 0, let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return nil }
        fftSetups[size] = setup
        return setup
    }

    private func runFFT(samples: UnsafeMutablePointer<Float>, count: Int, setupSize: Int) -> [Float] {
        // Use a fixed 2048-pt FFT by zero-padding/truncating for stable chroma.
        let size = 2048
        guard let setup = fftSetup(for: size) else { return [] }
        var real = [Float](repeating: 0, count: size)
        var imag = [Float](repeating: 0, count: size)
        let w = window(for: size)
        for i in 0..<min(count, size) {
            real[i] = samples[i] * w[i]
        }
        var magnitudes = [Float](repeating: 0, count: size / 2)
        real.withUnsafeMutableBufferPointer { rbp in
            imag.withUnsafeMutableBufferPointer { ibp in
                var split = DSPSplitComplex(realp: rbp.baseAddress!, imagp: ibp.baseAddress!)
                let log2n = vDSP_Length(Int(log2(Double(size))))
                vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                var scale: Float = 0.5
                vDSP_vsmul(split.realp, 1, &scale, split.realp, 1, vDSP_Length(size / 2))
                vDSP_vsmul(split.imagp, 1, &scale, split.imagp, 1, vDSP_Length(size / 2))
                vDSP_zvabs(&split, 1, &magnitudes, 1, vDSP_Length(size / 2))
            }
        }
        return magnitudes
    }

    deinit {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        fftSetups.forEach { vDSP_destroy_fftsetup($0.value) }
    }
}
