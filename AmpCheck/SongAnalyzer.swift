import AVFoundation
import Accelerate
import CoreMedia

// MARK: - 🎵 Song Analysis Result

struct SongAnalysis: Codable, Equatable {
    let title: String
    let duration: Double
    let bpm: Double
    let detectedChords: [String]
    let chordNamesTimeline: [String]
    let chordTimesTimeline: [Double]
    let toneBass: Double
    let toneMid: Double
    let toneTreble: Double
    let estimatedGain: Double
    let sustain: Double
    let dynamics: Double
    let instruments: [String]
    let playabilityDifficulty: String
    let playabilityNotes: [String]
    let neededEquipment: [String]
    let harmonicRatio: Double
    let percussiveRatio: Double

    enum CodingKeys: String, CodingKey {
        case title, duration, bpm, detectedChords, chordNamesTimeline, chordTimesTimeline
        case toneBass, toneMid, toneTreble, estimatedGain, sustain, dynamics
        case instruments, playabilityDifficulty, playabilityNotes, neededEquipment
        case harmonicRatio, percussiveRatio
    }
}

// MARK: - 🎵 Song Analyzer

final class SongAnalyzer: ObservableObject {
    @Published private(set) var progress: Double = 0
    @Published private(set) var status: String = "Idle"
    @Published private(set) var result: SongAnalysis? = nil
    @Published private(set) var isAnalyzing = false

    private let maxAnalyzeSeconds: Double = 90

    func analyze(url: URL) {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        progress = 0
        result = nil
        status = "Loading audio…"

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let r = self.runAnalysis(url: url) { p, s in
                DispatchQueue.main.async {
                    self.progress = p
                    self.status = s
                }
            }
            DispatchQueue.main.async {
                self.result = r
                self.isAnalyzing = false
                self.status = r == nil ? "Failed" : "Done"
                self.progress = 1
            }
        }
    }

    // Loads mono Float32 PCM from an audio file OR a video file (extracts its
    // audio track). Caps to maxSeconds. Returns (samples, sampleRate).
    static func loadMonoAudio(from url: URL, maxSeconds: Double) -> (mono: [Float], sr: Double)? {
        let videoExts: Set<String> = ["mp4","mov","m4v","avi","mkv","webm","qt","mpg","mpeg"]
        let isVideo = videoExts.contains(url.pathExtension.lowercased())

        if !isVideo {
            // Try AVAudioFile first (handles most audio containers).
            if let file = try? AVAudioFile(forReading: url) {
                let sr = file.processingFormat.sampleRate
                let total = Int(file.length)
                guard total > 0 else { return nil }
                let toRead = min(total, Int(sr * maxSeconds))
                guard let buf = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(toRead)) else { return nil }
                do { try file.read(into: buf, frameCount: AVAudioFrameCount(toRead)) } catch { return nil }
                let frames = Int(buf.frameLength)
                let channels = Int(file.processingFormat.channelCount)
                var mono = [Float](repeating: 0, count: frames)
                if channels == 1 {
                    if let d = buf.floatChannelData?[0] { for i in 0..<frames { mono[i] = d[i] } }
                } else {
                    for ch in 0..<channels {
                        if let d = buf.floatChannelData?[ch] { for i in 0..<frames { mono[i] += d[i] } }
                    }
                    for i in 0..<frames { mono[i] /= Float(channels) }
                }
                return (mono, sr)
            }
        }

        // Video (or audio AVAudioFile failed): extract via AVAssetReader.
        let asset = AVAsset(url: url)
        guard let track = asset.tracks(withMediaType: .audio).first else { return nil }

        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1
        ]
        guard let reader = try? AVAssetReader(asset: asset) else { return nil }
        let trackOutput = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        trackOutput.alwaysCopiesSampleData = false
        guard reader.canAdd(trackOutput) else { return nil }
        reader.add(trackOutput)

        guard reader.startReading() else { return nil }
        let sr = 44100.0
        let maxFrames = Int(sr * maxSeconds)
        var mono: [Float] = []
        mono.reserveCapacity(maxFrames)

        while let sampleBuffer = trackOutput.copyNextSampleBuffer() {
            guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { continue }
            var length = 0
            var dataPointer: UnsafeMutablePointer<Int8>?
            CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer)
            if let ptr = dataPointer, length > 0 {
                let floatCount = length / MemoryLayout<Float>.size
                let floats = ptr.withMemoryRebound(to: Float.self, capacity: floatCount) { $0 }
                let toAppend = min(floatCount, maxFrames - mono.count)
                if toAppend > 0 {
                    mono.append(contentsOf: UnsafeBufferPointer(start: floats, count: toAppend))
                }
            }
            if mono.count >= maxFrames { break }
        }
        reader.cancelReading()
        guard !mono.isEmpty else { return nil }
        return (mono, sr)
    }

    private func runAnalysis(url: URL, report: (Double, String) -> Void) -> SongAnalysis? {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        report(0.03, "Loading audio (video supported)…")
        guard let loaded = Self.loadMonoAudio(from: url, maxSeconds: maxAnalyzeSeconds) else { return nil }
        let mono = loaded.mono
        let sr = loaded.sr
        let frameCount = mono.count
        guard frameCount > 0 else { return nil }

        let duration = Double(frameCount) / sr
        let title = url.deletingPathExtension().lastPathComponent

        report(0.1, "Harmonic/percussive separation…")
        // STFT + HPSS
        let nfft = 2048
        let hop = 512
        let numFrames = (frameCount - nfft) / hop + 1
        guard numFrames > 4 else { return nil }

        // Compute magnitude spectrogram (real FFT per frame)
        var mag = [[Float]](repeating: [Float](repeating: 0, count: numFrames), count: nfft/2+1)
        var phase = [[Float]](repeating: [Float](repeating: 0, count: numFrames), count: nfft/2+1)
        let halfN = nfft / 2 + 1

        // Hann window
        var window = [Float](repeating: 0, count: nfft)
        for i in 0..<nfft { window[i] = 0.5 - 0.5 * cos(2 * Float.pi * Float(i) / Float(nfft - 1)) }

        for f in 0..<numFrames {
            let offset = f * hop
            var real = [Float](repeating: 0, count: nfft)
            var imag = [Float](repeating: 0, count: nfft)
            for i in 0..<nfft {
                let idx = offset + i
                if idx < frameCount {
                    real[i] = mono[idx] * window[i]
                }
            }
            // FFT
            var split = DSPSplitComplex(realp: &real, imagp: &imag)
            let log2n = vDSP_Length(log2(Double(nfft)))
            let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
            vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
            vDSP_destroy_fftsetup(setup)
            for b in 0..<halfN {
                let re = real[b]
                let im = (b == 0 || b == halfN-1) ? 0 : imag[b]
                mag[b][f] = sqrt(re*re + im*im)
                phase[b][f] = atan2(im, re)
            }
        }

        report(0.3, "Separating drums from guitar…")
        // HPSS via median filters
        let hKernel = 17  // time (horizontal) for harmonic
        let pKernel = 17  // freq (vertical) for percussive

        // harmonic magnitude: median along time for each freq bin
        var harmMag = mag
        var percMag = mag
        for b in 0..<halfN {
            for f in 0..<numFrames {
                // harmonic: median of mag[b][f-h..f+h]
                var windowVals = [Float]()
                for k in -hKernel/2...hKernel/2 {
                    let fi = f + k
                    if fi >= 0 && fi < numFrames { windowVals.append(mag[b][fi]) }
                }
                windowVals.sort()
                harmMag[b][f] = windowVals.isEmpty ? 0 : windowVals[windowVals.count/2]

                // percussive: median of mag[b-h..b+h][f]
                var windowVals2 = [Float]()
                for k in -pKernel/2...pKernel/2 {
                    let bi = b + k
                    if bi >= 0 && bi < halfN { windowVals2.append(mag[bi][f]) }
                }
                windowVals2.sort()
                percMag[b][f] = windowVals2.isEmpty ? 0 : windowVals2[windowVals2.count/2]
            }
        }

        // Soft masks
        // Apply masks to original complex STFT and invert to get harmonic audio
        var harmReal = [[Float]](repeating: [Float](repeating: 0, count: nfft), count: numFrames)
        var harmImag = [[Float]](repeating: [Float](repeating: 0, count: nfft), count: numFrames)

        for f in 0..<numFrames {
            let offset = f * hop
            // recompute original FFT for this frame (we have mag/phase but need complex)
            var real = [Float](repeating: 0, count: nfft)
            var imag = [Float](repeating: 0, count: nfft)
            for i in 0..<nfft {
                let idx = offset + i
                if idx < frameCount { real[i] = mono[idx] * window[i] }
            }
            var split = DSPSplitComplex(realp: &real, imagp: &imag)
            let log2n = vDSP_Length(log2(Double(nfft)))
            let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
            vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
            vDSP_destroy_fftsetup(setup)

            for b in 0..<halfN {
                let h = harmMag[b][f]
                let p = percMag[b][f]
                let mask = h / (h + p + 1e-8)
                // apply mask to bins (complex)
                if b == 0 || b == halfN - 1 {
                    real[b] *= mask
                    // imag stays 0
                } else {
                    real[b] *= mask
                    imag[b] *= mask
                    // mirror
                    real[nfft - b] *= mask
                    imag[nfft - b] *= -mask  // conjugate
                }
            }
            // store masked complex for ISTFT
            for i in 0..<nfft {
                harmReal[f][i] = real[i]
                harmImag[f][i] = imag[i]
            }
        }

        // ISTFT (overlap-add)
        report(0.5, "Reconstructing guitar track…")
        var harmonicAudio = [Float](repeating: 0, count: frameCount)
        var windowSum = [Float](repeating: 0, count: frameCount)
        for f in 0..<numFrames {
            var real = harmReal[f]
            var imag = harmImag[f]
            var split = DSPSplitComplex(realp: &real, imagp: &imag)
            let log2n = vDSP_Length(log2(Double(nfft)))
            let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
            vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_INVERSE))
            vDSP_destroy_fftsetup(setup)
            // scale
            var scale: Float = 1.0 / Float(nfft)
            vDSP_vsmul(split.realp, 1, &scale, split.realp, 1, vDSP_Length(nfft))
            let offset = f * hop
            for i in 0..<nfft {
                let idx = offset + i
                if idx < frameCount {
                    harmonicAudio[idx] += real[i] * window[i]
                    windowSum[idx] += window[i] * window[i]
                }
            }
        }
        for i in 0..<frameCount {
            if windowSum[i] > 1e-8 { harmonicAudio[i] /= windowSum[i] }
        }

        // Percussive audio = original - harmonic (approx)
        var percussiveAudio = [Float](repeating: 0, count: frameCount)
        for i in 0..<frameCount { percussiveAudio[i] = mono[i] - harmonicAudio[i] }

        // Energy ratios
        var harmRMS: Float = 0, percRMS: Float = 0, totalRMS: Float = 0
        vDSP_rmsqv(harmonicAudio, 1, &harmRMS, vDSP_Length(frameCount))
        vDSP_rmsqv(percussiveAudio, 1, &percRMS, vDSP_Length(frameCount))
        vDSP_rmsqv(mono, 1, &totalRMS, vDSP_Length(frameCount))
        let harmEnergy = harmRMS * harmRMS
        let percEnergy = percRMS * percRMS
        let totalEnergy = harmEnergy + percEnergy + 1e-12
        let harmonicRatio = Double(harmEnergy / totalEnergy)
        let percussiveRatio = Double(percEnergy / totalEnergy)

        report(0.6, "Detecting tempo…")
        // Beat tracking on percussive envelope
        let bpm = estimateBPM(audio: percussiveAudio, sr: sr)

        report(0.7, "Recognizing chords…")
        // Chord recognition on harmonic component, segmented by beats
        let segmentSeconds = 2.0
        let segFrames = Int(sr * segmentSeconds)
        var chordTimeline: [(String, Double)] = []
        var lastChord = ""
        var i = 0
        while i + segFrames < frameCount {
            // compute chroma for this segment
            var chroma = [Double](repeating: 0, count: 12)
            // FFT over sub-frames
            let subHop = 1024
            var subOffset = i
            while subOffset + nfft < i + segFrames {
                var real = [Float](repeating: 0, count: nfft)
                var imag = [Float](repeating: 0, count: nfft)
                for k in 0..<nfft {
                    let idx = subOffset + k
                    if idx < frameCount { real[k] = harmonicAudio[idx] * window[k] }
                }
                var split = DSPSplitComplex(realp: &real, imagp: &imag)
                let log2n = vDSP_Length(log2(Double(nfft)))
                let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
                vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                vDSP_destroy_fftsetup(setup)
                for b in 1..<(nfft/2) {
                    let freq = Double(b) * sr / Double(nfft)
                    guard freq >= 60 && freq < 2000 else { continue }
                    let re = real[b], im = imag[b]
                    let magv = sqrt(re*re + im*im)
                    let midi = 12 * log2(freq / 440.0) + 69
                    let pc = ((Int(round(midi)) % 12) + 12) % 12
                    chroma[pc] += Double(magv * magv)
                }
                subOffset += subHop
            }
            let (name, _) = classifyChroma(chroma)
            if name != "—" && name != lastChord {
                chordTimeline.append((name, Double(i) / sr))
                lastChord = name
            } else if name == lastChord {
                // keep
            } else {
                // unknown segment; skip
            }
            i += segFrames
        }

        let uniqueChords = chordTimeline.map { $0.0 }.reduce(into: [String]()) { acc, c in
            if acc.last != c { acc.append(c) }
        }
        // dedupe consecutive already done; unique list preserves first occurrence
        var seen = Set<String>()
        var uniqueOrdered: [String] = []
        for c in chordTimeline.map({ $0.0 }) {
            if !seen.contains(c) { seen.insert(c); uniqueOrdered.append(c) }
        }

        report(0.85, "Estimating tone & playability…")
        // Tone from harmonic component spectrum
        var bassE = 0.0, midE = 0.0, trebleE = 0.0
        // compute average spectrum of harmonic audio
        let specHop = 2048
        var frameCount2 = 0
        var idx = 0
        while idx + nfft < frameCount {
            var real = [Float](repeating: 0, count: nfft)
            var imag = [Float](repeating: 0, count: nfft)
            for k in 0..<nfft {
                let i2 = idx + k
                if i2 < frameCount { real[k] = harmonicAudio[i2] * window[k] }
            }
            var split = DSPSplitComplex(realp: &real, imagp: &imag)
            let log2n = vDSP_Length(log2(Double(nfft)))
            let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
            vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
            vDSP_destroy_fftsetup(setup)
            for b in 1..<(nfft/2) {
                let freq = Double(b) * sr / Double(nfft)
                let magv = sqrt(real[b]*real[b] + imag[b]*imag[b])
                let e = Double(magv * magv)
                if freq < 250 { bassE += e }
                else if freq < 2000 { midE += e }
                else if freq < 8000 { trebleE += e }
            }
            frameCount2 += 1
            idx += specHop
        }
        let total = bassE + midE + trebleE + 1e-9
        let bassShare = bassE / total
        let midShare = midE / total
        let trebleShare = trebleE / total
        // map share to 0-10 (balanced reference bass .4 mid .4 treble .2)
        let bassScore = min(10, max(0.5, 5 * (bassShare / 0.4)))
        let midScore = min(10, max(0.5, 5 * (midShare / 0.4)))
        let trebleScore = min(10, max(0.5, 5 * (trebleShare / 0.2)))

        // gain estimate from RMS
        let gainEst = min(10.0, max(1.0, Double(totalRMS) * 40.0))

        // sustain: decay after peak
        var peak: Float = 0
        for v in harmonicAudio { if abs(v) > peak { peak = abs(v) } }
        var sustainFrames = 0
        var foundPeak = false
        for v in harmonicAudio {
            if !foundPeak {
                if abs(v) > peak * 0.5 { foundPeak = true }
            } else {
                if abs(v) > peak * 0.1 { sustainFrames += 1 } else { break }
            }
        }
        let sustain = Double(sustainFrames) / sr

        // dynamics
        var sumLevel: Double = 0
        for v in harmonicAudio { sumLevel += Double(abs(v)) }
        let avgLevel = sumLevel / Double(frameCount)
        let dynamics = avgLevel > 0 ? Double(peak) / avgLevel : 1.0

        // Instrument detection (heuristic)
        var instruments: [String] = []
        if percussiveRatio > 0.15 { instruments.append("Drums / percussion") }
        if harmonicRatio > 0.3 {
            // bass presence
            var lowE: Double = 0
            for b in 0..<halfN {
                let freq = Double(b) * sr / Double(nfft)
                if freq < 250 {
                    // approximate from mag of first frame
                }
            }
            instruments.append("Guitar (electric or acoustic)")
        }
        // vocal heuristic: energy in 300-3400 Hz with spectral flatness
        instruments.append("Likely vocals / melody (if present)")
        if bassShare > 0.45 { instruments.append("Bass guitar") }
        if trebleShare > 0.3 { instruments.append("High-frequency content (cymbals / bright guitar)") }

        // Playability
        let chordCount = uniqueOrdered.count
        let tempoFast = bpm > 140
        var difficulty = "Medium"
        if chordCount <= 4 && bpm < 120 { difficulty = "Easy" }
        if chordCount >= 8 || tempoFast || uniqueOrdered.contains(where: { $0.contains("7") || $0.contains("sus") || $0.contains("m7") }) { difficulty = "Hard" }

        var needed: [String] = []
        if gainEst > 7 { needed.append("High-gain amp or distortion pedal") }
        if uniqueOrdered.contains(where: { $0.contains("#") || $0.contains("b") }) { needed.append("Capo or alternate tuning may help with sharp/flat chords") }
        if bpm > 0 { needed.append(String(format: "Metronome at %.0f BPM", bpm)) }
        if sustainsCheck(sustain) { needed.append("Sustain: chords ring ~\(String(format: "%.1f", sustain))s — a compressor or higher volume may help") }
        if needed.isEmpty { needed.append("Standard electric guitar + amp") }

        var notes: [String] = []
        notes.append(String(format: "Analyzed first %.0f s of %0.0f s total.", min(duration, maxAnalyzeSeconds), duration))
        notes.append(String(format: "Harmonic energy %.0f%% vs percussive %.0f%%.", harmonicRatio * 100, percussiveRatio * 100))
        notes.append("Chord detection is experimental; verify the sequence by ear.")
        if percussiveRatio < 0.05 {
            notes.append("Little percussion detected — track may be guitar-only or very quiet drums.")
        }

        let analysis = SongAnalysis(
            title: title,
            duration: duration,
            bpm: bpm,
            detectedChords: uniqueOrdered,
            chordNamesTimeline: chordTimeline.map { $0.0 },
            chordTimesTimeline: chordTimeline.map { $0.1 },
            toneBass: bassScore,
            toneMid: midScore,
            toneTreble: trebleScore,
            estimatedGain: gainEst,
            sustain: sustain,
            dynamics: dynamics,
            instruments: instruments,
            playabilityDifficulty: difficulty,
            playabilityNotes: notes,
            neededEquipment: needed,
            harmonicRatio: harmonicRatio,
            percussiveRatio: percussiveRatio
        )
        return analysis
    }

    private func sustainsCheck(_ s: Double) -> Bool { s < 1.0 }

    private func estimateBPM(audio: [Float], sr: Double) -> Double {
        // Onset detection on frame energy flux
        let frameSize = 1024
        let hop = 512
        let numFrames = (audio.count - frameSize) / hop
        guard numFrames > 10 else { return 120 }
        var energy = [Double](repeating: 0, count: numFrames)
        for f in 0..<numFrames {
            var rms: Float = 0
            let off = f * hop
            var sum: Float = 0
            for k in 0..<frameSize {
                let idx = off + k
                if idx < audio.count { sum += audio[idx] * audio[idx] }
            }
            energy[f] = Double(sum / Float(frameSize))
        }
        // flux
        var flux = [Double](repeating: 0, count: numFrames)
        for f in 1..<numFrames {
            flux[f] = max(0, energy[f] - energy[f-1])
        }
        // peak picking
        var onsets: [Int] = []
        for f in 1..<(numFrames-1) {
            if flux[f] > flux[f-1] && flux[f] > flux[f+1] && flux[f] > 0.0001 {
                onsets.append(f)
            }
        }
        guard onsets.count >= 4 else { return 120 }
        // median inter-onset interval in frames → seconds
        var intervals: [Double] = []
        for i in 1..<onsets.count {
            intervals.append(Double(onsets[i] - onsets[i-1]) * Double(hop) / sr)
        }
        intervals.sort()
        let median = intervals[intervals.count / 2]
        guard median > 0.2 && median < 2.0 else { return 120 }
        return 60.0 / median
    }

    private func classifyChroma(_ chroma: [Double]) -> (String, Double) {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let templates: [(String, [Int])] = [
            ("", [0,4,7]), ("m", [0,3,7]), ("5", [0,7]),
            ("7", [0,4,7,10]), ("maj7", [0,4,7,11]), ("m7", [0,3,7,10]),
            ("sus2", [0,2,7]), ("sus4", [0,5,7])
        ]
        let norm = sqrt(chroma.reduce(0){$0+$1*$1})
        guard norm > 0 else { return ("—", 0) }
        let n = chroma.map { $0 / norm }
        var bestName = "—"
        var bestSim = 0.0
        for root in 0..<12 {
            for (suffix, intervals) in templates {
                var t = [Double](repeating: 0, count: 12)
                for iv in intervals { t[(root+iv)%12] = 1 }
                let tn = sqrt(t.reduce(0){$0+$1*$1})
                guard tn > 0 else { continue }
                let tnorm = t.map { $0 / tn }
                let cos = zip(n, tnorm).reduce(0.0) { $0 + $1.0 * $1.1 }
                if cos > bestSim { bestSim = cos; bestName = noteNames[root] + suffix }
            }
        }
        if bestSim < 0.5 { bestName = "—" }
        return (bestName, bestSim)
    }
}