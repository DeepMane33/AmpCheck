import SwiftUI

// MARK: - 🎸 AmpCheck App

@main
struct AmpCheckApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}

// MARK: - 📱 App State

class AppState: ObservableObject {
    @Published var selectedAmp: GuitarAmp?
    @Published var userProgress: UserProgress
    @Published var assessment: AmpAssessment
    @Published var selectedTab: Tab
    @Published var hapticEnabled: Bool
    @Published var visualMode: Bool
    
    enum Tab: Int, CaseIterable {
        case home = 0
        case amp = 1
        case soundTest = 2
        case progress = 3
        case settings = 4
        
        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .amp: return "speaker.wave.3.fill"
            case .soundTest: return "waveform"
            case .progress: return "chart.line.uptrend.xyaxis"
            case .settings: return "gearshape.fill"
            }
        }
        
        var label: String {
            switch self {
            case .home: return "Songs"
            case .amp: return "My Amp"
            case .soundTest: return "Sound Test"
            case .progress: return "Progress"
            case .settings: return "Settings"
            }
        }
    }
    
    init() {
        self.selectedAmp = nil
        self.userProgress = UserProgress.empty
        self.assessment = AmpAssessment.perfect
        self.selectedTab = .home
        self.hapticEnabled = true
        self.visualMode = true
    }
    
    func calculateCompatibility(for song: Song, amp: GuitarAmp) -> CompatibilityResult {
        var bassMatch = 10.0
        var midMatch = 10.0
        var trebleMatch = 10.0
        var gainMatch = 10.0
        var limitations: [String] = []
        var recommendations: [String] = []
        
        // Check gain capability
        if song.idealSettings.gain > amp.maxGain {
            gainMatch = amp.maxGain / song.idealSettings.gain * 10
            limitations.append("Your amp can't reach the ideal gain level")
            recommendations.append("Try boosting your guitar's volume knob")
        }
        
        // Check bass control
        if !amp.hasBassControl && song.idealSettings.bass != 5 {
            bassMatch = 7
            limitations.append("No bass control on your amp")
            recommendations.append("Use your guitar's tone knob to adjust bass")
        }
        
        // Check mid control
        if !amp.hasMidControl && song.idealSettings.mid != 5 {
            midMatch = 7
            limitations.append("No mid control on your amp")
            recommendations.append("Mids are less critical for most songs")
        }
        
        // Check treble control
        if !amp.hasTrebleControl && song.idealSettings.treble != 5 {
            trebleMatch = 7
            limitations.append("No treble control on your amp")
            recommendations.append("Use your guitar's tone knob to adjust treble")
        }
        
        // Check presence control
        if !amp.hasPresenceControl && song.idealSettings.presence > 6 {
            limitations.append("No presence control on your amp")
        }
        
        // Check feature limitations
        if song.genre == "Metal" && !amp.features.canDoMetal {
            gainMatch = min(gainMatch, 5)
            limitations.append("Your amp isn't designed for heavy metal")
            recommendations.append("Consider a higher-gain amp for metal")
        }
        
        if song.genre == "Metal" && !amp.features.canDoHighGain {
            gainMatch = min(gainMatch, 4)
            limitations.append("Limited high-gain capability")
        }
        
        // Calculate overall score
        let overallScore = (gainMatch + bassMatch + midMatch + trebleMatch) / 4
        
        // Add condition adjustment based on assessment
        let conditionPenalty = (100 - assessment.conditionScore) / 10
        let adjustedScore = max(0, overallScore - conditionPenalty)
        
        return CompatibilityResult(
            overallScore: adjustedScore,
            bassMatch: bassMatch,
            midMatch: midMatch,
            trebleMatch: trebleMatch,
            gainMatch: gainMatch,
            limitations: limitations,
            recommendations: recommendations
        )
    }
    
    func getBestSongs(for amp: GuitarAmp) -> [Song] {
        Song.sampleSongs.filter { song in
            let result = calculateCompatibility(for: song, amp: amp)
            return result.overallScore >= 70
        }
    }
    
    func getAdjustedSettings(for song: Song, amp: GuitarAmp) -> AmpSettings {
        let ideal = song.idealSettings
        
        var adjustedGain = min(ideal.gain, amp.maxGain)
        var adjustedBass = amp.hasBassControl ? ideal.bass : 5
        var adjustedMid = amp.hasMidControl ? ideal.mid : 5
        var adjustedTreble = amp.hasTrebleControl ? ideal.treble : 5
        var adjustedPresence = amp.hasPresenceControl ? ideal.presence : 5
        
        // If gain is too high for amp, compensate with other settings
        if ideal.gain > amp.maxGain {
            // Boost mids to add perceived gain
            if amp.hasMidControl {
                adjustedMid = min(10, adjustedMid + 1)
            }
            // Boost presence for more bite
            if amp.hasPresenceControl {
                adjustedPresence = min(10, adjustedPresence + 1)
            }
        }
        
        return AmpSettings(
            gain: adjustedGain,
            bass: adjustedBass,
            mid: adjustedMid,
            treble: adjustedTreble,
            presence: adjustedPresence,
            volume: ideal.volume
        )
    }
}

// MARK: - 📱 Main Content View

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack {
            // Background gradient
            GradientBackground()
            
            // Floating Y2K decorations
            Y2KDecorations()
            
            // Tab content
            VStack(spacing: 0) {
                // Content
                TabView(selection: $appState.selectedTab) {
                    HomeView()
                        .tag(AppState.Tab.home)
                    
                    AmpSetupView()
                        .tag(AppState.Tab.amp)
                    
                    SoundTestView()
                        .tag(AppState.Tab.soundTest)
                    
                    UserProgressView()
                        .tag(AppState.Tab.progress)
                    
                    SettingsView()
                        .tag(AppState.Tab.settings)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Custom tab bar
                CustomTabBar()
            }
        }
    }
}

// MARK: - 🎸 Custom Tab Bar

struct CustomTabBar: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppState.Tab.allCases, id: \.rawValue) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        appState.selectedTab = tab
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 18))
                            .foregroundColor(appState.selectedTab == tab ? .ampPurple : .textSecondary)
                        
                        Text(tab.label)
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundColor(appState.selectedTab == tab ? .ampPurple : .textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        appState.selectedTab == tab ?
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.ampPurple.opacity(0.1))
                        : nil
                    )
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .glassStyle(cornerRadius: 24, opacity: 0.9)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

// MARK: - 🏠 Home View

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var selectedGenre: String? = nil
    @State private var isSearchFocused = false
    
    let genres = ["All", "Metal", "Rock", "Punk", "Blues", "Ballad", "Britpop", "Grunge", "Classic Rock"]
    
    var filteredSongs: [Song] {
        var songs = Song.sampleSongs
        
        if let genre = selectedGenre, genre != "All" {
            songs = songs.filter { $0.genre == genre }
        }
        
        if !searchText.isEmpty {
            songs = songs.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.artist.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return songs
    }
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("🎸")
                                    .font(.system(size: 36))
                                
                                Text("AmpCheck")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(.textPrimary)
                                
                                Text("Find your perfect tone")
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundColor(.textSecondary)
                            }
                            
                            Spacer()
                            
                            // Current amp indicator
                            if let amp = appState.selectedAmp {
                                VStack(spacing: 4) {
                                    Text("🎛️")
                                        .font(.system(size: 24))
                                    Text(amp.name)
                                        .font(.system(size: 10, weight: .medium, design: .rounded))
                                        .foregroundColor(.textSecondary)
                                }
                                .padding()
                                .glassStyle(cornerRadius: 12)
                            } else {
                                NavigationLink(destination: AmpSetupView()) {
                                    VStack(spacing: 4) {
                                        Text("➕")
                                            .font(.system(size: 24))
                                        Text("Add Amp")
                                            .font(.system(size: 10, weight: .medium, design: .rounded))
                                            .foregroundColor(.ampPurple)
                                    }
                                    .padding()
                                    .glassStyle(cornerRadius: 12)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Search bar
                    SearchBarStyle(text: $searchText, isFocused: $isSearchFocused)
                        .padding(.horizontal)
                    
                    // Genre filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(genres, id: \.self) { genre in
                                Button(action: {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedGenre = genre
                                    }
                                }) {
                                    Text(genre)
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundColor(selectedGenre == genre ? .white : .textPrimary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule()
                                                .fill(selectedGenre == genre ?
                                                    LinearGradient(colors: [.ampPurple, .ampPink], startPoint: .leading, endPoint: .trailing) :
                                                    LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing)
                                                )
                                                .overlay(
                                                    Capsule()
                                                        .stroke(selectedGenre == genre ? Color.clear : Color.ampPurple.opacity(0.3), lineWidth: 1)
                                                )
                                        )
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Quick actions
                    if appState.selectedAmp == nil {
                        VStack(spacing: 16) {
                            SectionHeader(emoji: "🚀", title: "Get Started", subtitle: "Set up your amp first")
                            
                            QuickActionButton(
                                emoji: "🎛️",
                                title: "Add Your Amp",
                                subtitle: "Tell us about your gear to get personalized settings",
                                color: .ampPurple
                            ) {
                                appState.selectedTab = .amp
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Songs list
                    VStack(spacing: 16) {
                        SectionHeader(
                            emoji: "🎵",
                            title: "Songs",
                            subtitle: "\(filteredSongs.count) songs available"
                        )
                        
                        ForEach(filteredSongs) { song in
                            NavigationLink(destination: SongDetailView(song: song)) {
                                SongCard(
                                    title: song.title,
                                    artist: song.artist,
                                    compatibility: appState.selectedAmp != nil ?
                                        appState.calculateCompatibility(for: song, amp: appState.selectedAmp!).overallScore : 0,
                                    genre: song.genre
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                    
                    // Bottom spacing
                    Spacer(minLength: 100)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - 🎛️ Amp Setup View

struct AmpSetupView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedAmpIndex: Int? = nil
    @State private var showingAssessment = false
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header
                    SectionHeader(
                        emoji: "🎛️",
                        title: "My Amp",
                        subtitle: "Select your amplifier"
                    )
                    .padding(.horizontal)
                    
                    // Current amp display
                    if let amp = appState.selectedAmp {
                        VStack(spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(amp.name)
                                        .font(.system(size: 24, weight: .bold, design: .rounded))
                                        .foregroundColor(.textPrimary)
                                    
                                    Text("\(amp.brand) • \(amp.watts)W")
                                        .font(.system(size: 14, design: .rounded))
                                        .foregroundColor(.textSecondary)
                                }
                                
                                Spacer()
                                
                                Button(action: { showingAssessment = true }) {
                                    Text("Check Condition")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundColor(.ampPurple)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .glassStyle(cornerRadius: 12)
                                }
                            }
                            
                            // Features
                            HStack(spacing: 12) {
                                FeatureBadge(emoji: "✨", text: "Clean", available: amp.features.canDoClean)
                                FeatureBadge(emoji: "🔥", text: "Crunch", available: amp.features.canDoCrunch)
                                FeatureBadge(emoji: "⚡", text: "High Gain", available: amp.features.canDoHighGain)
                                FeatureBadge(emoji: "🤘", text: "Metal", available: amp.features.canDoMetal)
                            }
                            
                            // Controls
                            HStack(spacing: 12) {
                                ControlBadge(text: "Bass", available: amp.hasBassControl)
                                ControlBadge(text: "Mid", available: amp.hasMidControl)
                                ControlBadge(text: "Treble", available: amp.hasTrebleControl)
                                ControlBadge(text: "Presence", available: amp.hasPresenceControl)
                            }
                        }
                        .padding()
                        .glassStyle(cornerRadius: 20)
                        .padding(.horizontal)
                    }
                    
                    // Amp list
                    VStack(spacing: 12) {
                        Text("Available Amps")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        
                        ForEach(GuitarAmp.sampleAmps) { amp in
                            Button(action: {
                                withAnimation(.spring(response: 0.3)) {
                                    appState.selectedAmp = amp
                                    selectedAmpIndex = GuitarAmp.sampleAmps.firstIndex(where: { $0.id == amp.id })
                                }
                            }) {
                                AmpCard(
                                    name: amp.name,
                                    brand: amp.brand,
                                    watts: amp.watts,
                                    isSelected: appState.selectedAmp?.id == amp.id
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                    
                    // Condition assessment summary
                    if appState.selectedAmp != nil {
                        VStack(spacing: 16) {
                            SectionHeader(
                                emoji: "📊",
                                title: "Amp Condition",
                                subtitle: "Based on your self-assessment"
                            )
                            
                            VStack(spacing: 12) {
                                HStack {
                                    Text("Condition Score")
                                        .font(.system(size: 14, design: .rounded))
                                        .foregroundColor(.textPrimary)
                                    Spacer()
                                    Text("\(Int(appState.assessment.conditionScore))%")
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                        .foregroundColor(appState.assessment.conditionScore >= 80 ? .ampMint : .ampPink)
                                }
                                
                                ProgressBar(value: appState.assessment.conditionScore / 100)
                            }
                            .padding()
                            .glassStyle(cornerRadius: 16)
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 100)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAssessment) {
                AssessmentView()
            }
        }
    }
}

// MARK: - 🔍 Feature Badge

struct FeatureBadge: View {
    let emoji: String
    let text: String
    let available: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Text(emoji)
                .font(.system(size: 20))
            Text(text)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundColor(available ? .textPrimary : .textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(available ? Color.ampMint.opacity(0.2) : Color.gray.opacity(0.1))
        )
    }
}

// MARK: - 🎛️ Control Badge

struct ControlBadge: View {
    let text: String
    let available: Bool
    
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundColor(available ? .white : .textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(available ? Color.ampPurple : Color.gray.opacity(0.2))
            )
    }
}

// MARK: - 📊 Progress Bar

struct ProgressBar: View {
    let value: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.15))
                    .frame(height: 8)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: value >= 0.7 ? [.ampMint, .ampBlue] : [.ampPink, .ampPurple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * value, height: 8)
            }
        }
        .frame(height: 8)
    }
}

// MARK: - 📋 Assessment View

struct AssessmentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var buzzesOrCrackles = false
    @State private var bassSoundsWeak = false
    @State private var isOlderThan5Years = false
    @State private var hasBeenDropped = false
    @State private var knobsFeelScratchy = false
    @State private var hasDistortionChannel = true
    @State private var worksConsistently = true
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header
                    SectionHeader(
                        emoji: "🔍",
                        title: "Amp Check",
                        subtitle: "Answer these questions about your amp"
                    )
                    .padding(.horizontal)
                    
                    // Questions
                    VStack(spacing: 16) {
                        AssessmentQuestion(
                            question: "Does your amp buzz or crackle?",
                            isOn: $buzzesOrCrackles
                        )
                        
                        AssessmentQuestion(
                            question: "Does the bass sound weak or distorted?",
                            isOn: $bassSoundsWeak
                        )
                        
                        AssessmentQuestion(
                            question: "Is the amp more than 5 years old?",
                            isOn: $isOlderThan5Years
                        )
                        
                        AssessmentQuestion(
                            question: "Has it been dropped or damaged?",
                            isOn: $hasBeenDropped
                        )
                        
                        AssessmentQuestion(
                            question: "Do the knobs feel scratchy when turning?",
                            isOn: $knobsFeelScratchy
                        )
                        
                        AssessmentQuestion(
                            question: "Does it have a distortion channel?",
                            isOn: $hasDistortionChannel,
                            isNegative: true
                        )
                        
                        AssessmentQuestion(
                            question: "Does it work consistently?",
                            isOn: $worksConsistently
                        )
                    }
                    .padding(.horizontal)
                    
                    // Score preview
                    VStack(spacing: 12) {
                        Text("Condition Score")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(.textSecondary)
                        
                        Text("\(Int(calculateScore()))%")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(calculateScore() >= 80 ? .ampMint : calculateScore() >= 60 ? .ampPeach : .ampPink)
                        
                        ProgressBar(value: calculateScore() / 100)
                            .padding(.horizontal)
                        
                        Text(scoreMessage)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .glassStyle(cornerRadius: 20)
                    .padding(.horizontal)
                    
                    // Save button
                    Button(action: {
                        appState.assessment = AmpAssessment(
                            buzzesOrCrackles: buzzesOrCrackles,
                            bassSoundsWeak: bassSoundsWeak,
                            isOlderThan5Years: isOlderThan5Years,
                            hasBeenDropped: hasBeenDropped,
                            knobsFeelScratchy: knobsFeelScratchy,
                            hasDistortionChannel: hasDistortionChannel,
                            worksConsistently: worksConsistently
                        )
                        dismiss()
                    }) {
                        Text("Save Assessment ✨")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [.ampPurple, .ampPink],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 100)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.ampPurple)
                }
            }
        }
    }
    
    private func calculateScore() -> Double {
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
    
    private var scoreMessage: String {
        let score = calculateScore()
        if score >= 80 {
            return "Your amp is in great shape! 🎉"
        } else if score >= 60 {
            return "Your amp has some wear but should work fine."
        } else if score >= 40 {
            return "Your amp has significant limitations. Focus on what it CAN do."
        } else {
            return "Your amp needs attention. Consider getting it serviced or upgrading."
        }
    }
}

// MARK: - ✅ Assessment Question

struct AssessmentQuestion: View {
    let question: String
    @Binding var isOn: Bool
    var isNegative: Bool = false
    
    var body: some View {
        HStack(spacing: 16) {
            Text(question)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.textPrimary)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.ampPurple)
        }
        .padding()
        .glassStyle(cornerRadius: 16)
    }
}

// MARK: - 🎵 Song Detail View

struct SongDetailView: View {
    @EnvironmentObject var appState: AppState
    let song: Song
    
    @State private var showingPracticeMode = false
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                // Song header
                VStack(spacing: 12) {
                    // Album art
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [.ampPurple, .ampPink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                        
                        Text("🎸")
                            .font(.system(size: 56))
                    }
                    
                    Text(song.title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.textPrimary)
                        .multilineTextAlignment(.center)
                    
                    Text(song.artist)
                        .font(.system(size: 16, design: .rounded))
                        .foregroundColor(.textSecondary)
                    
                    HStack(spacing: 12) {
                        Text(song.genre)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.ampPurple)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.ampPurple.opacity(0.1)))
                        
                        Text(song.difficulty.emoji + " " + song.difficulty.rawValue)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.ampPeach.opacity(0.2)))
                    }
                }
                .padding()
                .glassStyle(cornerRadius: 24)
                .padding(.horizontal)
                
                // Compatibility section
                if let amp = appState.selectedAmp {
                    let result = appState.calculateCompatibility(for: song, amp: amp)
                    
                    VStack(spacing: 16) {
                        HStack {
                            Text("🎯")
                                .font(.system(size: 24))
                            Text("Compatibility")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.textPrimary)
                            Spacer()
                            Text(amp.name)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(.textSecondary)
                        }
                        
                        CompatibilityRing(percentage: result.overallScore, size: 140)
                            .frame(maxWidth: .infinity)
                        
                        // Frequency comparison
                        HStack(spacing: 20) {
                            FrequencyVisualizer(
                                bass: song.idealSettings.bass,
                                mid: song.idealSettings.mid,
                                treble: song.idealSettings.treble,
                                label: "Ideal"
                            )
                            
                            FrequencyVisualizer(
                                bass: min(song.idealSettings.bass, amp.hasBassControl ? song.idealSettings.bass : 5),
                                mid: min(song.idealSettings.mid, amp.hasMidControl ? song.idealSettings.mid : 5),
                                treble: min(song.idealSettings.treble, amp.hasTrebleControl ? song.idealSettings.treble : 5),
                                label: "Your Amp"
                            )
                        }
                        
                        if !result.limitations.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("⚠️ Limitations")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(.textPrimary)
                                
                                ForEach(result.limitations, id: \.self) { limitation in
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(Color.ampPink)
                                            .frame(width: 6, height: 6)
                                        Text(limitation)
                                            .font(.system(size: 12, design: .rounded))
                                            .foregroundColor(.textSecondary)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.ampPink.opacity(0.1)))
                        }
                        
                        if !result.recommendations.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("💡 Tips")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(.textPrimary)
                                
                                ForEach(result.recommendations, id: \.self) { rec in
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(Color.ampMint)
                                            .frame(width: 6, height: 6)
                                        Text(rec)
                                            .font(.system(size: 12, design: .rounded))
                                            .foregroundColor(.textSecondary)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.ampMint.opacity(0.1)))
                        }
                    }
                    .padding()
                    .glassStyle(cornerRadius: 20)
                    .padding(.horizontal)
                } else {
                    // No amp selected
                    VStack(spacing: 12) {
                        Text("🎛️")
                            .font(.system(size: 32))
                        Text("Add your amp to see compatibility")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(.textSecondary)
                        
                        NavigationLink(destination: AmpSetupView()) {
                            Text("Add Amp")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [.ampPurple, .ampPink],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                        }
                    }
                    .padding()
                    .glassStyle(cornerRadius: 20)
                    .padding(.horizontal)
                }
                
                // Chords section
                VStack(spacing: 16) {
                    SectionHeader(
                        emoji: "🎵",
                        title: "Chords",
                        subtitle: "Tap to see finger positions"
                    )
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(song.chords) { chord in
                                ChordShape(chordName: chord.name, isActive: false)
                            }
                        }
                    }
                    
                    Text(song.description)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .glassStyle(cornerRadius: 20)
                .padding(.horizontal)
                
                // Settings section
                VStack(spacing: 16) {
                    SectionHeader(
                        emoji: "🎛️",
                        title: "Amp Settings",
                        subtitle: appState.selectedAmp != nil ? "Adjusted for your \(appState.selectedAmp!.name)" : "Ideal settings for this song"
                    )
                    
                    let settings = appState.selectedAmp != nil ?
                        appState.getAdjustedSettings(for: song, amp: appState.selectedAmp!) :
                        song.idealSettings
                    
                    SettingRow(label: "GAIN", value: settings.gain, maxValue: 10, isAdjustable: true, recommendation: nil)
                    SettingRow(label: "BASS", value: settings.bass, maxValue: 10, isAdjustable: appState.selectedAmp?.hasBassControl ?? true, recommendation: appState.selectedAmp?.hasBassControl == false ? "Use guitar tone knob" : nil)
                    SettingRow(label: "MID", value: settings.mid, maxValue: 10, isAdjustable: appState.selectedAmp?.hasMidControl ?? true, recommendation: appState.selectedAmp?.hasMidControl == false ? "Less critical for this song" : nil)
                    SettingRow(label: "TREBLE", value: settings.treble, maxValue: 10, isAdjustable: appState.selectedAmp?.hasTrebleControl ?? true, recommendation: appState.selectedAmp?.hasTrebleControl == false ? "Use guitar tone knob" : nil)
                    SettingRow(label: "PRESENCE", value: settings.presence, maxValue: 10, isAdjustable: appState.selectedAmp?.hasPresenceControl ?? true, recommendation: appState.selectedAmp?.hasPresenceControl == false ? "Not available on your amp" : nil)
                }
                .padding()
                .glassStyle(cornerRadius: 20)
                .padding(.horizontal)
                
                // Practice button
                Button(action: { showingPracticeMode = true }) {
                    HStack {
                        Text("🎸")
                            .font(.system(size: 24))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Start Practice Mode")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("Learn this song step by step")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [.ampPurple, .ampPink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal)
                
                // Important message
                VStack(spacing: 12) {
                    Text("🎓")
                        .font(.system(size: 28))
                    
                    Text("Play First, Tone Later")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.textPrimary)
                    
                    Text("You can play ANY song on ANY amp. The notes are the same — only the tone is different. Focus on getting the chords and rhythm right first. Tone comes with practice!")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .glassStyle(cornerRadius: 20)
                .padding(.horizontal)
                
                Spacer(minLength: 100)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingPracticeMode) {
            PracticeModeView(song: song)
        }
    }
}

// MARK: - 🔊 Sound Test View

struct SoundTestView: View {
    @EnvironmentObject var appState: AppState
    @State private var isRecording = false
    @State private var recordedBass: Double = 5
    @State private var recordedMid: Double = 5
    @State private var recordedTreble: Double = 5
    @State private var hapticModeEnabled = false
    @State private var showingResults = false
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header
                    SectionHeader(
                        emoji: "🔊",
                        title: "Sound Test",
                        subtitle: "Let your phone listen to your amp"
                    )
                    .padding(.horizontal)
                    
                    // How it works
                    VStack(spacing: 16) {
                        Text("How It Works")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        HStack(spacing: 16) {
                            StepCard(number: "1", emoji: "🎛️", text: "Set your amp to neutral settings")
                            StepCard(number: "2", emoji: "🎸", text: "Play a chord on your guitar")
                            StepCard(number: "3", emoji: "📱", text: "App listens and analyzes")
                        }
                    }
                    .padding()
                    .glassStyle(cornerRadius: 20)
                    .padding(.horizontal)
                    
                    // Test button
                    Button(action: {
                        withAnimation {
                            isRecording.toggle()
                            if isRecording {
                                // Simulate recording
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    isRecording = false
                                    recordedBass = Double.random(in: 3...8)
                                    recordedMid = Double.random(in: 3...7)
                                    recordedTreble = Double.random(in: 4...8)
                                    showingResults = true
                                }
                            }
                        }
                    }) {
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(
                                        isRecording ?
                                        LinearGradient(colors: [.ampPink, .ampPurple], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                        LinearGradient(colors: [.ampPurple, .ampPink], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                    .frame(width: 100, height: 100)
                                    .shadow(color: isRecording ? .ampPink.opacity(0.5) : .ampPurple.opacity(0.3), radius: 15)
                                
                                if isRecording {
                                    Circle()
                                        .stroke(Color.ampPink, lineWidth: 3)
                                        .frame(width: 120, height: 120)
                                        .opacity(0.5)
                                        .scaleEffect(isRecording ? 1.2 : 1.0)
                                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isRecording)
                                }
                                
                                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white)
                            }
                            
                            Text(isRecording ? "Listening... 🔴" : "Start Test 🎸")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.textPrimary)
                            
                            Text(isRecording ? "Play a chord on your guitar" : "Tap to begin")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(.textSecondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding()
                    
                    // Results
                    if showingResults {
                        VStack(spacing: 16) {
                            Text("📊 Analysis Results")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.textPrimary)
                            
                            FrequencyVisualizer(
                                bass: recordedBass,
                                mid: recordedMid,
                                treble: recordedTreble,
                                label: "Your Amp Output"
                            )
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("What This Means:")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(.textPrimary)
                                
                                Text(analyzeResults())
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundColor(.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.ampMint.opacity(0.1)))
                        }
                        .padding()
                        .glassStyle(cornerRadius: 20)
                        .padding(.horizontal)
                    }
                    
                    // Haptic mode
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("📳 Haptic Mode")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.textPrimary)
                                
                                Text("Feel your tone through vibrations")
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundColor(.textSecondary)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $hapticModeEnabled)
                                .labelsHidden()
                                .tint(.ampPurple)
                        }
                        
                        if hapticModeEnabled {
                            VStack(spacing: 12) {
                                Text("How it works:")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(.textSecondary)
                                
                                HStack(spacing: 16) {
                                    HapticExample(emoji: "📳", label: "Strong", meaning: "Bass is high")
                                    HapticExample(emoji: "〰️", label: "Medium", meaning: "Mids are balanced")
                                    HapticExample(emoji: "✨", label: "Light/Fast", meaning: "Treble is high")
                                }
                                
                                Text("Play your guitar and feel how the vibrations change based on your tone!")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundColor(.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                            .glassStyle(cornerRadius: 12)
                        }
                    }
                    .padding()
                    .glassStyle(cornerRadius: 20)
                    .padding(.horizontal)
                    
                    Spacer(minLength: 100)
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    private func analyzeResults() -> String {
        var analysis: [String] = []
        
        if recordedBass > 7 {
            analysis.append("Your bass response is strong. Good for rock and metal.")
        } else if recordedBass < 4 {
            analysis.append("Your bass is weak. Check your speaker or boost bass knob.")
        } else {
            analysis.append("Your bass is balanced. Good for most genres.")
        }
        
        if recordedMid > 7 {
            analysis.append("Your mids are prominent. Good for blues and classic rock.")
        } else if recordedMid < 4 {
            analysis.append("Your mids are scooped. Common for metal tones.")
        } else {
            analysis.append("Your mids are balanced. Versatile for many styles.")
        }
        
        if recordedTreble > 7 {
            analysis.append("Your treble is bright. Good for clean and funk tones.")
        } else if recordedTreble < 4 {
            analysis.append("Your treble is dark. May sound muddy for some songs.")
        } else {
            analysis.append("Your treble is warm. Good for most playing styles.")
        }
        
        return analysis.joined(separator: "\n")
    }
}

// MARK: - 📝 Step Card

struct StepCard: View {
    let number: String
    let emoji: String
    let text: String
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.ampPurple, .ampPink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                
                Text(number)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            Text(emoji)
                .font(.system(size: 24))
            
            Text(text)
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 📳 Haptic Example

struct HapticExample: View {
    let emoji: String
    let label: String
    let meaning: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(emoji)
                .font(.system(size: 20))
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(.textPrimary)
            Text(meaning)
                .font(.system(size: 8, design: .rounded))
                .foregroundColor(.textSecondary)
        }
    }
}

// MARK: - 📈 User Progress View

struct UserProgressView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header
                    SectionHeader(
                        emoji: "📈",
                        title: "Your Progress",
                        subtitle: "Keep playing, you're doing great!"
                    )
                    .padding(.horizontal)
                    
                    // Skill level
                    VStack(spacing: 16) {
                        Text(appState.userProgress.skillLevel.emoji)
                            .font(.system(size: 48))
                        
                        Text(appState.userProgress.skillLevel.rawValue)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.textPrimary)
                        
                        ProgressBar(value: appState.userProgress.progressToNextLevel)
                            .padding(.horizontal)
                        
                        Text("\(appState.userProgress.songsLearned) songs learned")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.textSecondary)
                    }
                    .padding()
                    .glassStyle(cornerRadius: 20)
                    .padding(.horizontal)
                    
                    // Stats grid
                    HStack(spacing: 16) {
                        StatCard(emoji: "🎵", value: "\(appState.userProgress.songsPlayed)", label: "Played")
                        StatCard(emoji: "📚", value: "\(appState.userProgress.songsLearned)", label: "Learned")
                    }
                    .padding(.horizontal)
                    
                    HStack(spacing: 16) {
                        StatCard(emoji: "🔥", value: "\(appState.userProgress.currentStreak)", label: "Streak")
                        StatCard(emoji: "⭐", value: "\(appState.userProgress.longestStreak)", label: "Best")
                    }
                    .padding(.horizontal)
                    
                    // Play first, tone later reminder
                    VStack(spacing: 12) {
                        Text("🎓")
                            .font(.system(size: 28))
                        
                        Text("Remember")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.textPrimary)
                        
                        Text("Tone is the LAST thing to worry about. First learn the notes and rhythm. Then worry about how it sounds. You're making progress!")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .glassStyle(cornerRadius: 20)
                    .padding(.horizontal)
                    
                    Spacer(minLength: 100)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - 📊 Stat Card

struct StatCard: View {
    let emoji: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(emoji)
                .font(.system(size: 24))
            
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.textPrimary)
            
            Text(label)
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .glassStyle(cornerRadius: 16)
    }
}

// MARK: - ⚙️ Settings View

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header
                    SectionHeader(
                        emoji: "⚙️",
                        title: "Settings",
                        subtitle: "Customize your experience"
                    )
                    .padding(.horizontal)
                    
                    // Preferences
                    VStack(spacing: 12) {
                        SettingsToggle(
                            emoji: "📳",
                            title: "Haptic Feedback",
                            subtitle: "Feel tones through vibrations",
                            isOn: $appState.hapticEnabled
                        )
                        
                        SettingsToggle(
                            emoji: "👁️",
                            title: "Visual Mode",
                            subtitle: "Show frequency visualizations",
                            isOn: $appState.visualMode
                        )
                    }
                    .padding(.horizontal)
                    
                    // About
                    VStack(spacing: 16) {
                        HStack {
                            Text("ℹ️")
                                .font(.system(size: 20))
                            Text("About AmpCheck")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.textPrimary)
                            Spacer()
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("AmpCheck helps beginners find their perfect tone and teaches the most important lesson: play first, tone later.")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundColor(.textSecondary)
                            
                            Text("Built for the Swift Student Challenge 2027 🎸")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.ampPurple)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .glassStyle(cornerRadius: 20)
                    .padding(.horizontal)
                    
                    // Credits
                    VStack(spacing: 8) {
                        Text("🎸")
                            .font(.system(size: 32))
                        
                        Text("Made with ❤️ for guitarists everywhere")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.textSecondary)
                        
                        Text("Version 1.0")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundColor(.textSecondary)
                    }
                    .padding()
                    
                    Spacer(minLength: 100)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - ⚙️ Settings Toggle

struct SettingsToggle: View {
    let emoji: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Text(emoji)
                .font(.system(size: 24))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.textPrimary)
                
                Text(subtitle)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.textSecondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.ampPurple)
        }
        .padding()
        .glassStyle(cornerRadius: 16)
    }
}

// MARK: - 🎸 Practice Mode View

struct PracticeModeView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    let song: Song
    
    @State private var currentChordIndex = 0
    @State private var isPlaying = false
    @State private var tempo: Double = 120
    @State private var showChords = true
    @State private var showStrumming = true
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("🎸")
                            .font(.system(size: 36))
                        
                        Text("Practice Mode")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.textPrimary)
                        
                        Text(song.title)
                            .font(.system(size: 16, design: .rounded))
                            .foregroundColor(.textSecondary)
                    }
                    .padding()
                    .glassStyle(cornerRadius: 20)
                    .padding(.horizontal)
                    
                    // Current chord display
                    VStack(spacing: 16) {
                        Text("Current Chord")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.textSecondary)
                        
                        if currentChordIndex < song.chords.count {
                            let chord = song.chords[currentChordIndex]
                            
                            VStack(spacing: 12) {
                                Text(chord.name)
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                    .foregroundColor(.ampPurple)
                                
                                Text(chord.displayFrets)
                                    .font(.system(size: 20, design: .monospaced))
                                    .foregroundColor(.textPrimary)
                                
                                if chord.isPowerChord {
                                    Text("Power Chord")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundColor(.ampPink)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Capsule().fill(Color.ampPink.opacity(0.1)))
                                }
                            }
                        }
                    }
                    .padding()
                    .glassStyle(cornerRadius: 20)
                    .padding(.horizontal)
                    
                    // Chord navigation
                    HStack(spacing: 20) {
                        Button(action: {
                            withAnimation {
                                currentChordIndex = max(0, currentChordIndex - 1)
                            }
                        }) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 24))
                                .foregroundColor(currentChordIndex > 0 ? .ampPurple : .gray)
                                .frame(width: 60, height: 60)
                                .glassStyle(cornerRadius: 30)
                        }
                        .disabled(currentChordIndex == 0)
                        
                        Button(action: {
                            isPlaying.toggle()
                        }) {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white)
                                .frame(width: 80, height: 80)
                                .background(
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [.ampPurple, .ampPink],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                )
                        }
                        
                        Button(action: {
                            withAnimation {
                                currentChordIndex = min(song.chords.count - 1, currentChordIndex + 1)
                            }
                        }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 24))
                                .foregroundColor(currentChordIndex < song.chords.count - 1 ? .ampPurple : .gray)
                                .frame(width: 60, height: 60)
                                .glassStyle(cornerRadius: 30)
                        }
                        .disabled(currentChordIndex == song.chords.count - 1)
                    }
                    
                    // Tempo control
                    VStack(spacing: 12) {
                        HStack {
                            Text("⏱️ Tempo")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.textPrimary)
                            Spacer()
                            Text("\(Int(tempo)) BPM")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.ampPurple)
                        }
                        
                        Slider(value: $tempo, in: 60...180, step: 5)
                            .tint(.ampPurple)
                    }
                    .padding()
                    .glassStyle(cornerRadius: 16)
                    .padding(.horizontal)
                    
                    // All chords overview
                    VStack(spacing: 12) {
                        Text("All Chords")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Array(song.chords.enumerated()), id: \.element.id) { index, chord in
                                    Button(action: {
                                        withAnimation {
                                            currentChordIndex = index
                                        }
                                    }) {
                                        VStack(spacing: 8) {
                                            Text(chord.name)
                                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                                .foregroundColor(index == currentChordIndex ? .white : .textPrimary)
                                            
                                            Text(chord.displayFrets)
                                                .font(.system(size: 12, design: .monospaced))
                                                .foregroundColor(index == currentChordIndex ? .white.opacity(0.8) : .textSecondary)
                                        }
                                        .frame(width: 80, height: 80)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(index == currentChordIndex ?
                                                    LinearGradient(colors: [.ampPurple, .ampPink], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                                    LinearGradient(colors: [Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(index == currentChordIndex ? Color.clear : Color.ampPurple.opacity(0.3), lineWidth: 1)
                                                )
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .glassStyle(cornerRadius: 20)
                    .padding(.horizontal)
                    
                    // Practice tips
                    VStack(spacing: 12) {
                        Text("🎓 Practice Tips")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        TipRow(emoji: "1️⃣", text: "Start slow, build speed gradually")
                        TipRow(emoji: "2️⃣", text: "Focus on clean chord changes")
                        TipRow(emoji: "3️⃣", text: "Don't worry about tone yet — just play!")
                    }
                    .padding()
                    .glassStyle(cornerRadius: 16)
                    .padding(.horizontal)
                    
                    Spacer(minLength: 100)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.ampPurple)
                }
            }
        }
    }
}

// MARK: - 💡 Tip Row

struct TipRow: View {
    let emoji: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text(emoji)
                .font(.system(size: 16))
            Text(text)
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(.textSecondary)
            Spacer()
        }
    }
}

// MARK: - 🔌 Amp Card with Selection

struct AmpCardSelectable: View {
    let amp: GuitarAmp
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            isSelected ?
                            LinearGradient(colors: [.ampPurple, .ampPink], startPoint: .topLeading, endPoint: .bottomTrailing) :
                            LinearGradient(colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 50, height: 50)
                    
                    Text("🎛️")
                        .font(.system(size: 24))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(amp.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.textPrimary)
                    
                    Text("\(amp.brand) • \(amp.watts)W")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.textSecondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.ampPurple)
                        .font(.system(size: 22))
                }
            }
            .padding()
            .glassStyle(cornerRadius: 16, opacity: isSelected ? 0.9 : 0.5)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
