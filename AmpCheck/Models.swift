import Foundation

// MARK: - 🎵 Data Models

// Song Model
struct Song: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let artist: String
    let genre: String
    let difficulty: Difficulty
    let chords: [Chord]
    let idealSettings: AmpSettings
    let description: String
    
    enum Difficulty: String, Codable, CaseIterable {
        case easy = "Easy"
        case medium = "Medium"
        case hard = "Hard"
        
        var emoji: String {
            switch self {
            case .easy: return "🟢"
            case .medium: return "🟡"
            case .hard: return "🔴"
            }
        }
        
        var color: String {
            switch self {
            case .easy: return "ampMint"
            case .medium: return "ampPeach"
            case .hard: return "ampPink"
            }
        }
    }
    
    init(title: String, artist: String, genre: String, difficulty: Difficulty, chords: [Chord], idealSettings: AmpSettings, description: String) {
        self.id = UUID()
        self.title = title
        self.artist = artist
        self.genre = genre
        self.difficulty = difficulty
        self.chords = chords
        self.idealSettings = idealSettings
        self.description = description
    }
}

// Chord Model
struct Chord: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let frets: [Int] // -1 for muted, 0 for open, 1-24 for fret positions
    let fingers: [Int] // 0 for no finger, 1-4 for finger numbers
    let isPowerChord: Bool
    
    init(name: String, frets: [Int], fingers: [Int] = [], isPowerChord: Bool = false) {
        self.id = UUID()
        self.name = name
        self.frets = frets
        self.fingers = fingers
        self.isPowerChord = isPowerChord
    }
    
    var displayFrets: String {
        frets.map { $0 == -1 ? "X" : ($0 == 0 ? "0" : "\($0)") }.joined(separator: " ")
    }
}

// Amp Settings Model
struct AmpSettings: Codable, Hashable {
    let gain: Double      // 0-10
    let bass: Double      // 0-10
    let mid: Double       // 0-10
    let treble: Double    // 0-10
    let presence: Double  // 0-10
    let volume: Double    // 0-10
    
    static let neutral = AmpSettings(gain: 5, bass: 5, mid: 5, treble: 5, presence: 5, volume: 5)
    static let metal = AmpSettings(gain: 9, bass: 6, mid: 3, treble: 7, presence: 6, volume: 5)
    static let blues = AmpSettings(gain: 5, bass: 6, mid: 7, treble: 6, presence: 5, volume: 5)
    static let clean = AmpSettings(gain: 2, bass: 5, mid: 5, treble: 5, presence: 5, volume: 5)
}

// Amp Model
struct GuitarAmp: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let brand: String
    let watts: Int
    let features: AmpFeatures
    let maxGain: Double
    let hasBassControl: Bool
    let hasMidControl: Bool
    let hasTrebleControl: Bool
    let hasPresenceControl: Bool
    let description: String
    
    init(name: String, brand: String, watts: Int, features: AmpFeatures, maxGain: Double, hasBassControl: Bool = true, hasMidControl: Bool = true, hasTrebleControl: Bool = true, hasPresenceControl: Bool = false, description: String = "") {
        self.id = UUID()
        self.name = name
        self.brand = brand
        self.watts = watts
        self.features = features
        self.maxGain = maxGain
        self.hasBassControl = hasBassControl
        self.hasMidControl = hasMidControl
        self.hasTrebleControl = hasTrebleControl
        self.hasPresenceControl = hasPresenceControl
        self.description = description
    }
}

// Amp Features
struct AmpFeatures: Codable, Hashable {
    let canDoClean: Bool
    let canDoCrunch: Bool
    let canDoHighGain: Bool
    let canDoMetal: Bool
    let hasEffects: Bool
    let hasReverb: Bool
    let hasDelay: Bool
    
    var metalScore: Double {
        var score = 0.0
        if canDoHighGain { score += 3 }
        if canDoMetal { score += 4 }
        if hasEffects { score += 1 }
        if hasReverb { score += 1 }
        if hasDelay { score += 1 }
        return score
    }
}

// Compatibility Result
struct CompatibilityResult: Codable {
    let overallScore: Double
    let bassMatch: Double
    let midMatch: Double
    let trebleMatch: Double
    let gainMatch: Double
    let limitations: [String]
    let recommendations: [String]
}

// Self Assessment Answers
struct AmpAssessment: Codable {
    var buzzesOrCrackles: Bool
    var bassSoundsWeak: Bool
    var isOlderThan5Years: Bool
    var hasBeenDropped: Bool
    var knobsFeelScratchy: Bool
    var hasDistortionChannel: Bool
    var worksConsistently: Bool
    
    static let perfect = AmpAssessment(
        buzzesOrCrackles: false,
        bassSoundsWeak: false,
        isOlderThan5Years: false,
        hasBeenDropped: false,
        knobsFeelScratchy: false,
        hasDistortionChannel: true,
        worksConsistently: true
    )
    
    var conditionScore: Double {
        var score = 100.0
        if buzzesOrCrackles { score -= 15 }
        if bassSoundsWeak { score -= 20 }
        if isOlderThan5Years { score -= 10 }
        if hasBeenDropped { score -= 15 }
        if knobsFeelScratchy { score -= 10 }
        if !hasDistortionChannel { score -= 25 }
        if !worksConsistently { score -= 20 }
        return max(0, score)
    }
}

// Progress Data
struct UserProgress: Codable {
    var songsPlayed: Int
    var songsLearned: Int
    var daysPlayed: Int
    var currentStreak: Int
    var longestStreak: Int
    var skillLevel: SkillLevel
    var playedSongs: [String]
    var favorites: [String]
    
    enum SkillLevel: String, Codable, CaseIterable {
        case beginner = "Beginner"
        case intermediate = "Intermediate"
        case advanced = "Advanced"
        case pro = "Pro"
        
        var emoji: String {
            switch self {
            case .beginner: return "🌱"
            case .intermediate: return "🎸"
            case .advanced: return "🔥"
            case .pro: return "⭐"
            }
        }
        
        var nextLevelSongs: Int {
            switch self {
            case .beginner: return 10
            case .intermediate: return 25
            case .advanced: return 50
            case .pro: return Int.max
            }
        }
    }
    
    static let empty = UserProgress(
        songsPlayed: 0,
        songsLearned: 0,
        daysPlayed: 0,
        currentStreak: 0,
        longestStreak: 0,
        skillLevel: .beginner,
        playedSongs: [],
        favorites: []
    )
    
    mutating func playSong(_ songTitle: String) {
        songsPlayed += 1
        if !playedSongs.contains(songTitle) {
            playedSongs.append(songTitle)
            songsLearned += 1
        }
        updateSkillLevel()
    }
    
    mutating func incrementStreak() {
        currentStreak += 1
        if currentStreak > longestStreak {
            longestStreak = currentStreak
        }
        daysPlayed += 1
    }
    
    mutating func updateSkillLevel() {
        switch songsLearned {
        case 0..<10:
            skillLevel = .beginner
        case 10..<25:
            skillLevel = .intermediate
        case 25..<50:
            skillLevel = .advanced
        default:
            skillLevel = .pro
        }
    }
    
    var progressToNextLevel: Double {
        let current = Double(songsLearned)
        let target = Double(skillLevel.nextLevelSongs)
        return min(current / target, 1.0)
    }
}

// Practice Mode State
struct PracticeModeState: Codable {
    var currentChordIndex: Int
    var isPlaying: Bool
    var tempo: Double // BPM
    var showChords: Bool
    var showStrumming: Bool
    var loopEnabled: Bool
    
    static let initial = PracticeModeState(
        currentChordIndex: 0,
        isPlaying: false,
        tempo: 120,
        showChords: true,
        showStrumming: true,
        loopEnabled: true
    )
}

// Haptic Feedback Pattern
struct HapticPattern: Codable {
    let bass: Double
    let mid: Double
    let treble: Double
    let intensity: Double
    
    var description: String {
        var parts: [String] = []
        if bass > 7 { parts.append("Heavy bass") }
        else if bass > 4 { parts.append("Moderate bass") }
        else { parts.append("Light bass") }
        
        if mid > 7 { parts.append("strong mids") }
        else if mid > 4 { parts.append("balanced mids") }
        else { parts.append("scooped mids") }
        
        if treble > 7 { parts.append("bright treble") }
        else if treble > 4 { parts.append("warm treble") }
        else { parts.append("dark treble") }
        
        return parts.joined(separator: ", ")
    }
}

// MARK: - 📊 Sample Data

extension Song {
    static let sampleSongs: [Song] = [
        Song(
            title: "Enter Sandman",
            artist: "Metallica",
            genre: "Metal",
            difficulty: .medium,
            chords: [
                Chord(name: "E5", frets: [-1, 0, 2, 2, -1, -1], isPowerChord: true),
                Chord(name: "G5", frets: [-1, -1, 0, 2, 3, -1], isPowerChord: true),
                Chord(name: "A5", frets: [-1, 0, 2, 2, -1, -1], isPowerChord: true)
            ],
            idealSettings: .metal,
            description: "Classic metal riff with heavy distortion. Focus on power chords and palm muting."
        ),
        Song(
            title: "Back in Black",
            artist: "AC/DC",
            genre: "Rock",
            difficulty: .easy,
            chords: [
                Chord(name: "E5", frets: [-1, 0, 2, 2, -1, -1], isPowerChord: true),
                Chord(name: "D5", frets: [-1, -1, 0, 2, 3, -1], isPowerChord: true),
                Chord(name: "A5", frets: [-1, 0, 2, 2, -1, -1], isPowerChord: true)
            ],
            idealSettings: .blues,
            description: "Iconic rock riff. Simple power chords with a crunchy tone."
        ),
        Song(
            title: "Smells Like Teen Spirit",
            artist: "Nirvana",
            genre: "Grunge",
            difficulty: .easy,
            chords: [
                Chord(name: "F5", frets: [-1, -1, 3, 5, 5, -1], isPowerChord: true),
                Chord(name: "Bb5", frets: [-1, 1, 3, 3, -1, -1], isPowerChord: true),
                Chord(name: "Ab5", frets: [-1, -1, 1, 3, 3, -1], isPowerChord: true),
                Chord(name: "Db5", frets: [-1, -1, 4, 6, 6, -1], isPowerChord: true)
            ],
            idealSettings: AmpSettings(gain: 7, bass: 6, mid: 5, treble: 6, presence: 5, volume: 5),
            description: "Grunge anthem with distorted power chords. Great for beginners."
        ),
        Song(
            title: "Wonderwall",
            artist: "Oasis",
            genre: "Britpop",
            difficulty: .easy,
            chords: [
                Chord(name: "Em7", frets: [0, 2, 2, 0, 3, 0]),
                Chord(name: "G", frets: [3, 2, 0, 0, 0, 3]),
                Chord(name: "Dsus4", frets: [-1, -1, 0, 2, 3, 3]),
                Chord(name: "A7sus4", frets: [-1, 0, 2, 0, 3, 0])
            ],
            idealSettings: .clean,
            description: "Classic acoustic-style strumming. Clean or slightly driven tone works great."
        ),
        Song(
            title: "Stairway to Heaven",
            artist: "Led Zeppelin",
            genre: "Classic Rock",
            difficulty: .hard,
            chords: [
                Chord(name: "Am", frets: [-1, 0, 2, 2, 1, 0]),
                Chord(name: "E/G#", frets: [4, 2, 2, 1, 0, 0]),
                Chord(name: "C/G", frets: [3, 3, 2, 0, 1, 0]),
                Chord(name: "D/F#", frets: [2, 0, 0, 2, 3, 2]),
                Chord(name: "Fmaj7", frets: [-1, -1, 3, 2, 1, 0])
            ],
            idealSettings: AmpSettings(gain: 4, bass: 5, mid: 6, treble: 6, presence: 5, volume: 5),
            description: "Epic fingerpicking intro building to a powerful solo. Advanced but rewarding."
        ),
        Song(
            title: "Basket Case",
            artist: "Green Day",
            genre: "Punk",
            difficulty: .easy,
            chords: [
                Chord(name: "Eb5", frets: [-1, -1, 1, 3, 3, -1], isPowerChord: true),
                Chord(name: "Bb5", frets: [-1, 1, 3, 3, -1, -1], isPowerChord: true),
                Chord(name: "F5", frets: [1, -1, 3, 3, 1, -1], isPowerChord: true),
                Chord(name: "Ab5", frets: [-1, -1, 1, 3, 3, -1], isPowerChord: true)
            ],
            idealSettings: AmpSettings(gain: 7, bass: 5, mid: 5, treble: 6, presence: 5, volume: 5),
            description: "Punk rock classic with fast power chords. High energy and fun!"
        ),
        Song(
            title: "Sweet Child O' Mine",
            artist: "Guns N' Roses",
            genre: "Rock",
            difficulty: .hard,
            chords: [
                Chord(name: "D", frets: [-1, -1, 0, 2, 3, 2]),
                Chord(name: "C", frets: [-1, 3, 2, 0, 1, 0]),
                Chord(name: "G", frets: [3, 2, 0, 0, 0, 3]),
                Chord(name: "A", frets: [-1, 0, 2, 2, 2, 0])
            ],
            idealSettings: AmpSettings(gain: 6, bass: 5, mid: 6, treble: 7, presence: 6, volume: 5),
            description: "Iconic intro riff with melodic lead lines. Requires good finger coordination."
        ),
        Song(
            title: "Hells Bells",
            artist: "AC/DC",
            genre: "Rock",
            difficulty: .medium,
            chords: [
                Chord(name: "A5", frets: [-1, 0, 2, 2, -1, -1], isPowerChord: true),
                Chord(name: "C5", frets: [-1, 3, 5, 5, -1, -1], isPowerChord: true),
                Chord(name: "D5", frets: [-1, -1, 0, 2, 3, -1], isPowerChord: true),
                Chord(name: "G5", frets: [-1, -1, 0, 2, 3, -1], isPowerChord: true)
            ],
            idealSettings: AmpSettings(gain: 7, bass: 6, mid: 5, treble: 6, presence: 5, volume: 5),
            description: "Dark, powerful riff with a driving rhythm. Classic hard rock."
        ),
        Song(
            title: "Nothing Else Matters",
            artist: "Metallica",
            genre: "Ballad",
            difficulty: .medium,
            chords: [
                Chord(name: "Em", frets: [0, 2, 2, 0, 0, 0]),
                Chord(name: "D", frets: [-1, -1, 0, 2, 3, 2]),
                Chord(name: "C", frets: [-1, 3, 2, 0, 1, 0]),
                Chord(name: "G", frets: [3, 2, 0, 0, 0, 3])
            ],
            idealSettings: AmpSettings(gain: 3, bass: 5, mid: 5, treble: 6, presence: 5, volume: 5),
            description: "Beautiful ballad with fingerpicking. Clean tone with some reverb works best."
        ),
        Song(
            title: "Thunderstruck",
            artist: "AC/DC",
            genre: "Rock",
            difficulty: .hard,
            chords: [
                Chord(name: "B5", frets: [-1, 2, 4, 4, -1, -1], isPowerChord: true),
                Chord(name: "A5", frets: [-1, 0, 2, 2, -1, -1], isPowerChord: true),
                Chord(name: "D5", frets: [-1, -1, 0, 2, 3, -1], isPowerChord: true),
                Chord(name: "E5", frets: [-1, 0, 2, 2, -1, -1], isPowerChord: true)
            ],
            idealSettings: AmpSettings(gain: 8, bass: 6, mid: 5, treble: 7, presence: 6, volume: 5),
            description: "Fast, energetic riff with rapid single-note picking. High stamina required."
        )
    ]
}

extension GuitarAmp {
    static let sampleAmps: [GuitarAmp] = [
        GuitarAmp(
            name: "Practice Amp 10W",
            brand: "Generic",
            watts: 10,
            features: AmpFeatures(canDoClean: true, canDoCrunch: false, canDoHighGain: false, canDoMetal: false, hasEffects: false, hasReverb: false, hasDelay: false),
            maxGain: 3,
            hasBassControl: false,
            hasMidControl: false,
            hasTrebleControl: true,
            description: "Basic practice amp. Clean tones only."
        ),
        GuitarAmp(
            name: "MG10",
            brand: "Marshall",
            watts: 10,
            features: AmpFeatures(canDoClean: true, canDoCrunch: true, canDoHighGain: false, canDoMetal: false, hasEffects: false, hasReverb: false, hasDelay: false),
            maxGain: 5,
            hasBassControl: true,
            hasMidControl: false,
            hasTrebleControl: true,
            description: "Popular beginner amp. Good for blues and light rock."
        ),
        GuitarAmp(
            name: "Katana 50",
            brand: "Boss",
            watts: 50,
            features: AmpFeatures(canDoClean: true, canDoCrunch: true, canDoHighGain: true, canDoMetal: true, hasEffects: true, hasReverb: true, hasDelay: true),
            maxGain: 10,
            description: "Versatile modeling amp. Can handle any genre."
        ),
        GuitarAmp(
            name: "Blues Jr",
            brand: "Fender",
            watts: 15,
            features: AmpFeatures(canDoClean: true, canDoCrunch: true, canDoHighGain: false, canDoMetal: false, hasEffects: false, hasReverb: true, hasDelay: false),
            maxGain: 6,
            hasPresenceControl: true,
            description: "Classic tube amp. Perfect for blues and classic rock."
        ),
        GuitarAmp(
            name: "ID:Core 40",
            brand: "Blackstar",
            watts: 40,
            features: AmpFeatures(canDoClean: true, canDoCrunch: true, canDoHighGain: true, canDoMetal: true, hasEffects: true, hasReverb: true, hasDelay: true),
            maxGain: 9,
            description: "Digital modeling amp with great versatility."
        ),
        GuitarAmp(
            name: "Spark",
            brand: "Positive Grid",
            watts: 40,
            features: AmpFeatures(canDoClean: true, canDoCrunch: true, canDoHighGain: true, canDoMetal: true, hasEffects: true, hasReverb: true, hasDelay: true),
            maxGain: 10,
            description: "Smart amp with AI features. Excellent for beginners."
        ),
        GuitarAmp(
            name: "Code 50",
            brand: "Marshall",
            watts: 50,
            features: AmpFeatures(canDoClean: true, canDoCrunch: true, canDoHighGain: true, canDoMetal: true, hasEffects: true, hasReverb: true, hasDelay: true),
            maxGain: 9,
            hasPresenceControl: true,
            description: "Digital modeling amp with Bluetooth. Great all-rounder."
        ),
        GuitarAmp(
            name: "Orange Micro Dark",
            brand: "Orange",
            watts: 20,
            features: AmpFeatures(canDoClean: true, canDoCrunch: true, canDoHighGain: true, canDoMetal: false, hasEffects: false, hasReverb: false, hasDelay: false),
            maxGain: 8,
            description: "Tiny but powerful tube hybrid. Great crunch tones."
        )
    ]
}
