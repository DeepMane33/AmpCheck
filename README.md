# 🎸 AmpCheck

A guitar amp settings app that helps beginners find their perfect tone — and teaches the most important lesson: play first, tone later.

## How to Run
1. Open `AmpCheck.xcodeproj` in Xcode
2. Press ⌘R to run on the iPhone simulator (or a device with a signing team)
3. The Sound Test uses your device microphone — grant access when prompted

## Features
- Search 10 built-in songs + **add your own songs** with custom chords and ideal settings
- Select from **16 real amplifiers** (Fender, Marshall, Vox, Mesa, Peavey, Orange, Roland, Line 6, Yamaha, Boss, Blackstar, Positive Grid) or **build your own amp** by toggling which controls it has (bass/mid/treble/presence) and which capabilities (clean/crunch/high-gain/metal/effects/reverb/delay)
- Get compatibility scores + an **Amp Capability Check** per song (missing controls, measured-tone vs. song-ideal match)
- **Real microphone sound test** — long-duration FFT spectral analysis (vDSP/Accelerate), multi-strike repeatability, sustain & dynamics, quality tiers (5 s min / 8 s good / 15 s+ excellent). Silence → no result, never invented
- **Real haptic mode** — vibrations driven by measured bass/treble energy (for hearing-impaired players)
- **Real metronome** in practice mode with tempo + auto-advancing chords
- **Real fretboard diagrams** from chord data
- **Song Analyzer** — upload an audio or video file (mp3, m4a, wav, mp4, mov); videos have their audio track extracted first. The app separates harmonic (guitar/vocals) from percussive (drums), estimates BPM, recognizes a chord sequence, measures tone, detects likely instruments, and judges playability (difficulty + what you'll need)
- Progress, streaks, custom amps/songs, measured profiles persist between launches
- Honest accuracy & limits documented in Settings

## Sound Test (how it really works)
1. Tap **Start Analysis** — the app asks for microphone access
2. Play chords near the phone. The mic stays open while you play; longer = better stats (5 s minimum, 15 s+ excellent). Each chord strike is scored separately.
3. Results show measured energy shares, tone center, sustain, dynamics, and what the amp is suited for
4. If the mic hears nothing, you get "Too quiet — nothing detected", never a fake answer

## Files
- `AudioEngine.swift` — Real microphone FFT analyzer (AVFoundation + Accelerate/vDSP), metronome, experimental chord detector
- `Theme.swift` — All styling (glassmorphism, neumorphism, pastel colors) + fretboard diagrams
- `Models.swift` — Data models, 16 real amps, 10 songs, detected chords
- `AmpCheckApp.swift` — All views and app logic

## Research notes
- A phone mic cannot identify an amp model. What it CAN measure honestly is the relative spectral balance (bass/mid/treble energy shares), loudness, sustain, and dynamics of what it hears. Use it for RELATIVE comparisons (knob A vs knob B), not absolute identity.
- Many amps lack controls (Vox AC30 has no mid knob; Fender Twin has no high-gain channel; JC-120 has no distortion). Declare your amp's real controls via "Build Your Own Amp" so compatibility math and settings advice are meaningful.
- Chord transcription from polyphonic audio is an open research problem. This app's Chord Detective is a lightweight, clearly-labeled experimental DSP approach (chroma + cosine template matching), not a trained model. Confidence is shown for every guess.

## For Swift Student Challenge 2027
This app addresses:
- Beginners quitting due to gear limitations
- Hearing-impaired guitarists who can't hear their tone
- Players with limited dexterity who can't adjust many knobs
- Honest, measurement-based feedback instead of made-up numbers