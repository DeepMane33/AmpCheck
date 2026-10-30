import SwiftUI
import UniformTypeIdentifiers

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
    private let storageKey = "ampcheck.state.v2"

    private struct StoredState: Codable {
        var ampName: String?
        var progress: UserProgress?
        var assessment: AmpAssessment?
        var hapticEnabled: Bool?
        var visualMode: Bool?
        var toneReport: ToneReport?
        var customAmps: [GuitarAmp]?
        var customSongs: [Song]?
    }

    @Published var selectedAmp: GuitarAmp? { didSet { save() } }
    @Published var userProgress: UserProgress { didSet { save() } }
    @Published var assessment: AmpAssessment { didSet { save() } }
    @Published var selectedTab: Tab
    @Published var hapticEnabled: Bool { didSet { save() } }
    @Published var visualMode: Bool { didSet { save() } }

    /// The last real measured tone report from the Sound Test, so the amp's
    /// capability profile is always visible on the My Amp tab.
    @Published var toneReport: ToneReport? { didSet { save() } }

    /// The last real measured tone report from the Sound Test, so the amp's
    /// capability profile is always visible on the My Amp tab.
    @Published var customAmps: [GuitarAmp] { didSet { save() } }
    @Published var customSongs: [Song] { didSet { save() } }

    var availableAmps: [GuitarAmp] { GuitarAmp.sampleAmps + customAmps }
    var availableSongs: [Song] { Song.sampleSongs + customSongs }
    
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
        self.customAmps = []
        self.customSongs = []

        // Restore previously saved state (amp, progress, streaks, settings).
        if let data = UserDefaults.standard.data(forKey: storageKey) {
            let stored = try? JSONDecoder().decode(StoredState.self, from: data)
            if let name = stored?.ampName,
               let amp = availableAmps.first(where: { $0.name == name }) {
                self.selectedAmp = amp
            }
            if let progress = stored?.progress {
                self.userProgress = progress
            }
            if let assessment = stored?.assessment {
                self.assessment = assessment
            }
            if let haptic = stored?.hapticEnabled {
                self.hapticEnabled = haptic
            }
            if let visual = stored?.visualMode {
                self.visualMode = visual
            }
            if let report = stored?.toneReport {
                self.toneReport = report
            }
            if let amps = stored?.customAmps {
                self.customAmps = amps
            }
            if let songs = stored?.customSongs {
                self.customSongs = songs
            }
        }
    }

    private func save() {
        let stored = StoredState(
            ampName: selectedAmp?.name,
            progress: userProgress,
            assessment: assessment,
            hapticEnabled: hapticEnabled,
            visualMode: visualMode,
            toneReport: toneReport,
            customAmps: customAmps,
            customSongs: customSongs
        )
        guard let data = try? JSONEncoder().encode(stored) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
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
        
        let adjustedGain = min(ideal.gain, amp.maxGain)
        let adjustedBass = amp.hasBassControl ? ideal.bass : 5
        var adjustedMid = amp.hasMidControl ? ideal.mid : 5
        let adjustedTreble = amp.hasTrebleControl ? ideal.treble : 5
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
    @FocusState private var isSearchFocused: Bool
    @State private var showingAddSong = false
    @State private var showingSongAnalyzer = false
    
    let genres = ["All", "Metal", "Rock", "Punk", "Blues", "Ballad", "Britpop", "Grunge", "Classic Rock"]
    
    var filteredSongs: [Song] {
        var songs = appState.availableSongs
        
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

                            Button(action: { showingAddSong = true }) {
                                VStack(spacing: 4) {
                                    Text("➕")
                                        .font(.system(size: 24))
                                    Text("Add Song")
                                        .font(.system(size: 10, weight: .medium, design: .rounded))
                                        .foregroundColor(.ampPurple)
                                }
                                .padding()
                                .glassStyle(cornerRadius: 12)
                            }
                            .buttonStyle(PlainButtonStyle())
                            Button(action: { showingSongAnalyzer = true }) {
                                VStack(spacing: 4) {
                                    Text("🎵")
                                        .font(.system(size: 24))
                                    Text("Analyze Song")
                                        .font(.system(size: 10, weight: .medium, design: .rounded))
                                        .foregroundColor(.ampPurple)
                                }
                                .padding()
                                .glassStyle(cornerRadius: 12)
                            }
                            .buttonStyle(PlainButtonStyle())
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
            .sheet(isPresented: $showingAddSong) {
                CustomSongView()
            }
            .sheet(isPresented: $showingSongAnalyzer) {
                SongAnalyzerView()
            }
        }
    }
}

// MARK: - 🎛️ Amp Setup View

struct AmpSetupView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedAmpIndex: Int? = nil
    @State private var showingAssessment = false
    @State private var showingCustomAmp = false
    
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

                    // Measured tone profile (from a real Sound Test run)
                    if let report = appState.toneReport {
                        VStack(spacing: 16) {
                            HStack {
                                Text("🎙️ Measured Tone Profile")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.textPrimary)
                                Spacer()
                                Text("⭐ \(report.qualityLabel)")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundColor(.ampMint)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(Color.ampMint.opacity(0.15)))
                            }

                            Text("“\(report.toneCharacter)”")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.ampPurple)

                            HStack(spacing: 14) {
                                FrequencyVisualizer(
                                    bass: report.bass,
                                    mid: report.mid,
                                    treble: report.treble,
                                    label: "Measured"
                                )
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                ShareRow(name: "BASS", share: report.bassShare, color: .ampPink)
                                ShareRow(name: "MID", share: report.midShare, color: .ampPurple)
                                ShareRow(name: "TREBLE", share: report.trebleShare, color: .ampBlue)
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.3)))

                            Text(String(format: "Based on %.1f s across %d chord strikes · tone center ≈ %d Hz", report.seconds, report.strikes, Int(report.centroidHz)))
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(.textSecondary)

                            Text(String(format: "Sustain ≈ %.1f s · dynamics %.1fx", report.sustainSeconds, report.dynamics))
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(.textSecondary)

                            Text(report.consistencyLabel)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor((report.consistency ?? 1) >= 0.6 ? .ampMint : .ampPeach)
                                .multilineTextAlignment(.center)

                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(report.genreFit, id: \.self) { fit in
                                    HStack(spacing: 8) {
                                        Text("🎸")
                                        Text(fit)
                                            .font(.system(size: 12, design: .rounded))
                                            .foregroundColor(.textSecondary)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Text("Measure again after changing knobs to compare — same guitar, same volume, only the knob changes.")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(.textSecondary)
                                .multilineTextAlignment(.center)

                            Button(action: {
                                appState.selectedTab = .soundTest
                            }) {
                                Text("Run a new measurement")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(
                                        LinearGradient(colors: [.ampPurple, .ampPink], startPoint: .leading, endPoint: .trailing)
                                    ))
                            }
                        }
                        .padding()
                        .glassStyle(cornerRadius: 20)
                        .padding(.horizontal)
                    }
                    VStack(spacing: 12) {
                        Text("Available Amps")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        
                        ForEach(appState.availableAmps) { amp in
                            Button(action: {
                                withAnimation(.spring(response: 0.3)) {
                                    appState.selectedAmp = amp
                                    selectedAmpIndex = appState.availableAmps.firstIndex(where: { $0.id == amp.id })
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
                    
                    // Build your own amp (for amps not in the list)
                    Button(action: { showingCustomAmp = true }) {
                        HStack {
                            Text("🛠️")
                            Text("Build Your Own Amp")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.ampPurple)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.textSecondary)
                        }
                        .padding()
                        .glassStyle(cornerRadius: 16)
                    }
                    .buttonStyle(PlainButtonStyle())
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
            .sheet(isPresented: $showingCustomAmp) {
                CustomAmpView()
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

                        // Amp capability verdict (controls + features + measured tone)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("🎛️ Amp Capability Check")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.textPrimary)

                            let missingControls = [
                                (!amp.hasBassControl && song.idealSettings.bass != 5) ? "Bass" : nil,
                                (!amp.hasMidControl && song.idealSettings.mid != 5) ? "Mid" : nil,
                                (!amp.hasTrebleControl && song.idealSettings.treble != 5) ? "Treble" : nil,
                                (!amp.hasPresenceControl && song.idealSettings.presence > 6) ? "Presence" : nil
                            ].compactMap { $0 }

                            if missingControls.isEmpty {
                                Text("✅ Your amp has every control this song's tone needs. Dial the settings below and you're set.")
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundColor(.ampMint)
                            } else {
                                Text("⚠️ Missing on your amp: \(missingControls.joined(separator: ", ")). The app has compensated in the settings below (e.g. use your guitar's tone knob).")
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundColor(.ampPeach)
                            }

                            if let report = appState.toneReport {
                                let similarity = 100 - abs(report.bass - song.idealSettings.bass) * 5
                                    - abs(report.mid - song.idealSettings.mid) * 5
                                    - abs(report.treble - song.idealSettings.treble) * 5
                                Text(String(format: "Your measured tone vs. this song: %.0f%% match. %s",
                                           max(0, min(100, similarity)),
                                           similarity >= 70 ? "Close — small knob tweaks should get you there." : "Farther apart — expect to adjust gain/EQ significantly."))
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundColor(.textSecondary)
                            } else {
                                Text("Run a Sound Test to compare your measured tone against this song's ideal.")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundColor(.textSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.ampBlue.opacity(0.1)))
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
                                VStack(spacing: 8) {
                                    Text(chord.name)
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                        .foregroundColor(.textPrimary)

                                    FretDiagramView(chord: chord)
                                        .frame(width: 110, height: 130)
                                }
                                .neuStyle(cornerRadius: 16)
                                .padding(6)
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

// MARK: - 🔊 Sound Test View (real mic analysis, long-session)

struct SoundTestView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var analyzer = AudioAnalyzer()
    @State private var hapticModeEnabled = false
    @State private var showingDetector = false

    private var hasResult: Bool {
        analyzer.phase == .done && analyzer.result != nil
    }

    private var notEnough: Bool {
        analyzer.phase == .tooQuiet && analyzer.result == nil
    }

    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header
                    SectionHeader(
                        emoji: "🔊",
                        title: "Sound Test",
                        subtitle: "Deep spectrum analysis of your amp"
                    )
                    .padding(.horizontal)
                    Button(action: { showingDetector = true }) {
                        HStack {
                            Text("🎼")
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Chord Detective (experimental)")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(.textPrimary)
                                Text("Play chords one at a time — the app guesses each chord. Best on clean single chords.")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundColor(.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.textSecondary)
                        }
                        .padding()
                        .glassStyle(cornerRadius: 16)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal)

                    // How it works
                    VStack(spacing: 16) {
                        Text("How It Works")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 16) {
                            StepCard(number: "1", emoji: "🎛️", text: "Set your amp once, keep knobs untouched")
                            StepCard(number: "2", emoji: "🎸", text: "Keep playing chords — short pauses between them")
                            StepCard(number: "3", emoji: "📱", text: "Each chord strike gets scored separately")
                        }

                        Text("More audio = better stats. 3s is the minimum, 12s+ is excellent. Nothing is ever invented.")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .glassStyle(cornerRadius: 20)
                    .padding(.horizontal)

                    // Test button
                    Button(action: {
                        withAnimation {
                            switch analyzer.phase {
                            case .idle, .denied, .failed, .done:
                                analyzer.start()
                            case .requesting, .listening, .tooQuiet:
                                if canFinish { analyzer.stop() }
                            }
                        }
                    }) {
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(
                                        isTestActive ?
                                        LinearGradient(colors: [.ampPink, .ampPurple], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                        LinearGradient(colors: [.ampPurple, .ampPink], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                    .frame(width: 100, height: 100)
                                    .shadow(color: isTestActive ? .ampPink.opacity(0.5) : .ampPurple.opacity(0.3), radius: 15)

                                if isTestActive {
                                    Circle()
                                        .stroke(Color.ampPink, lineWidth: 3)
                                        .frame(width: 120, height: 120)
                                        .opacity(0.5)
                                        .scaleEffect(analyzer.phase == .listening ? 1.2 : 1.0)
                                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: analyzer.phase == .listening)
                                }

                                Image(systemName: isTestActive ? "stop.fill" : "mic.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white)
                            }

                            Text(buttonLabel)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.textPrimary)

                            Text(statusMessage)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(statusColor)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isTestActive && !canFinish)
                    .padding()

                    // Problem states
                    if analyzer.phase == .denied {
                        warningCard(
                            icon: "🎙️",
                            title: "Microphone access needed",
                            body: "AmpCheck can only analyze sound it can hear. Enable microphone access in Settings."
                        ) {
                            Button(action: {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                Text("Open Settings")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(Color.ampPurple))
                            }
                        }
                    }

                    if analyzer.phase == .failed {
                        warningCard(
                            icon: "⚠️",
                            title: "Couldn't start the microphone",
                            body: "The audio engine failed to start. Try again, or check that no other app is using the mic."
                        )
                    }

                    if notEnough {
                        warningCard(
                            icon: "🤫",
                            title: String(format: "Only %.1f s of real audio was measured", analyzer.audibleSeconds),
                            body: "The mic hears your room, but not enough of your playing. Keep strumming chords near the phone until the counter below passes 3 s — then finish. No results are guessed."
                        )
                    }

                    // Live deep-analysis card
                    if isTestActive {
                        VStack(spacing: 16) {
                            HStack {
                                Text("📊 Live Analysis")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(.textPrimary)
                                Spacer()
                                HStack(spacing: 8) {
                                    Text(qualityBadge)
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundColor(.ampMint)
                                    Text("\(Int(analyzer.liveLevel * 100))% lvl")
                                        .font(.system(size: 12, design: .rounded))
                                        .foregroundColor(.textSecondary)
                                }
                            }

                            // Session stats
                            HStack(spacing: 12) {
                                LiveStatChip(icon: "⏱️", value: String(format: "%.1f s", analyzer.audibleSeconds), label: "measured")
                                LiveStatChip(icon: "🎸", value: "\(analyzer.strikeCount)", label: "strikes")
                                if analyzer.liveCentroidHz > 0 {
                                    LiveStatChip(icon: "🎯", value: "\(Int(analyzer.liveCentroidHz)) Hz", label: "tone center")
                                }
                            }

                            Text("🎸 Keep playing chords — each new strike sharpens the reading. Press Finish when you've played enough (≥5 s).")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 6)

                            // Accuracy meter: how solid the reading is so far
                            VStack(spacing: 6) {
                                HStack {
                                    Text("Reading accuracy")
                                        .font(.system(size: 12, design: .rounded))
                                        .foregroundColor(.textSecondary)
                                    Spacer()
                                    Text("5s min · 8s good · 15s+ excellent")
                                        .font(.system(size: 11, design: .rounded))
                                        .foregroundColor(.textSecondary)
                                }
                                ProgressBar(value: min(1.0, analyzer.audibleSeconds / 15.0))
                            }

                            // Last measured chord strike
                            if let strike = analyzer.lastStrike {
                                HStack(spacing: 10) {
                                    Image(systemName: "music.note")
                                        .foregroundColor(.ampPurple)
                                    Text("Strike #\(analyzer.strikeCount):")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundColor(.textPrimary)
                                    Text(String(format: "B %.1f · M %.1f · T %.1f", strike.bass, strike.mid, strike.treble))
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color.ampPurple.opacity(0.08)))
                            }

                            if analyzer.strikeCount >= 2 {
                                Text("Repeatability check active — if each strike scores similarly, the reading is trustworthy.")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundColor(.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding()
                        .glassStyle(cornerRadius: 20)
                        .padding(.horizontal)
                    }

                    // Results
                    if hasResult, let report = analyzer.result {
                        VStack(spacing: 16) {
                            Text("📊 Measured Report")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.textPrimary)

                            Text("“\(report.toneCharacter)”")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(.ampPurple)
                                .multilineTextAlignment(.center)

                            FrequencyVisualizer(
                                bass: report.bass,
                                mid: report.mid,
                                treble: report.treble,
                                label: "Your Amp Output (measured)"
                            )

                            // Measured energy shares (the raw truth)
                            VStack(alignment: .leading, spacing: 8) {
                                ShareRow(name: "BASS (40–250 Hz)", share: report.bassShare, color: .ampPink)
                                ShareRow(name: "MID (250–2 kHz)", share: report.midShare, color: .ampPurple)
                                ShareRow(name: "TREBLE (2–8 kHz)", share: report.trebleShare, color: .ampBlue)
                            }
                            .padding()
                            .glassStyle(cornerRadius: 12)

                            // Stats grid
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                StatTile(title: "Quality", value: report.qualityLabel, color: .ampMint)
                                StatTile(title: "Audio analyzed", value: String(format: "%.1f s", report.seconds), color: .ampBlue)
                                StatTile(title: "Chord strikes", value: "\(report.strikes)", color: .ampPurple)
                                StatTile(title: "Tone center", value: "\(Int(report.centroidHz)) Hz", color: .ampPeach)
                                StatTile(title: "Sustain", value: String(format: "%.1f s", report.sustainSeconds), color: .ampPink)
                                StatTile(title: "Dynamics", value: String(format: "%.1fx", report.dynamics), color: .ampMint)
                            }

                            Text(report.consistencyLabel)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor((report.consistency ?? 1) >= 0.6 ? .ampMint : .ampPeach)
                                .multilineTextAlignment(.center)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("What this says about your amp:")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(.textPrimary)

                                Text(interpretation(report))
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundColor(.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.ampMint.opacity(0.1)))

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Looks best suited for:")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(.textPrimary)

                                ForEach(report.genreFit, id: \.self) { fit in
                                    HStack(spacing: 8) {
                                        Text("🎸")
                                        Text(fit)
                                            .font(.system(size: 12, design: .rounded))
                                            .foregroundColor(.textSecondary)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.ampPurple.opacity(0.1)))

                            if report.level < 0.35 {
                                Text("⚠️ Level was low (\(Int(report.level * 100))%). For a more reliable result, play louder and closer to the phone, then measure again.")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundColor(.ampPeach)
                                    .multilineTextAlignment(.center)
                            }

                            Text("Saved to My Amp ✓ — you can compare later tests by changing only the knobs.")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(.textSecondary)
                                .multilineTextAlignment(.center)

                            Button(action: { analyzer.start() }) {
                                Text("Measure Again 🔁")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(
                                        Capsule().fill(
                                            LinearGradient(colors: [.ampPurple, .ampPink], startPoint: .leading, endPoint: .trailing)
                                        )
                                    )
                            }
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

                                Text("Real vibrations driven by the live mic signal")
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
                                Text("While the test listens, your phone vibrates with the actual tone it measures:")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(.textSecondary)

                                HStack(spacing: 16) {
                                    HapticExample(emoji: "📳", label: "Strong", meaning: "Measured bass energy")
                                    HapticExample(emoji: "〰️", label: "Medium", meaning: "Measured mids")
                                    HapticExample(emoji: "✨", label: "Light tick", meaning: "Measured treble")
                                }

                                Text("For hearing-impaired players: play a chord and feel the difference as you turn the bass or treble knobs.")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundColor(.textSecondary)
                                    .multilineTextAlignment(.center)

                                if isTestActive {
                                    Text("Haptics are LIVE — keep playing!")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundColor(.ampPurple)
                                }
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
        .onChange(of: hapticModeEnabled) { newValue in
            analyzer.hapticsEnabled = newValue
        }
        .onChange(of: analyzer.phase) { newPhase in
            if newPhase == .done, let report = analyzer.result {
                appState.toneReport = report
            }
        }
        .sheet(isPresented: $showingDetector) {
            ChordDetectiveView()
        }
        .onDisappear {
            analyzer.stop()
        }
    }

    private var isTestActive: Bool {
        switch analyzer.phase {
        case .requesting, .listening, .tooQuiet: return true
        default: return false
        }
    }

    private var canFinish: Bool {
        analyzer.audibleSeconds >= 5.0
    }

    private var buttonLabel: String {
        if !isTestActive { return "Start Analysis 🎸" }
        if !canFinish {
            return String(format: "Keep playing… %.0f s / 5 s", analyzer.audibleSeconds)
        }
        return "Finish & See Results ⏹"
    }

    private var qualityBadge: String {
        switch analyzer.audibleSeconds {
        case 12...: return "⭐ Excellent"
        case 6..<12: return "✅ Good"
        case 3..<6: return "🟡 Basic"
        default: return "⏳ Warming up"
        }
    }

    private var statusMessage: String {
        switch analyzer.phase {
        case .idle: return "Tap to begin — then keep playing chords near the phone"
        case .requesting: return "Asking for microphone access…"
        case .listening: return "Keep playing! Press Finish when you've played enough"
        case .tooQuiet: return "Too quiet — strum louder, closer to the mic"
        case .denied: return "Microphone was blocked"
        case .failed: return "Audio engine error"
        case .done: return "Done! Full report below"
        }
    }

    private var statusColor: Color {
        switch analyzer.phase {
        case .tooQuiet, .denied, .failed: return .ampPink
        case .listening, .requesting: return .ampPurple
        case .done: return .ampMint
        default: return .textSecondary
        }
    }

    private func interpretation(_ report: ToneReport) -> String {
        var lines: [String] = []

        switch report.toneCharacter {
        case "Bass-heavy & warm":
            lines.append("Most of the energy sits below 250 Hz. Great for thick rhythm tones; leads may sound muffled — try raising treble/presence.")
        case "Bright & clear":
            lines.append("Strong 2–8 kHz content. Clean and attack-forward; may get sharp on high-gain — try easing treble down.")
        case "Mid-forward & punchy":
            lines.append("Energy concentrated in the 250–2 kHz band where guitars 'cut' through a band mix.")
        case "Scooped (V-shaped)":
            lines.append("Classic metal voicing: heavy lows, recessed mids, bright attack.")
        default:
            lines.append("Energy is spread evenly across bass, mid and treble — an even, workable platform for any genre.")
        }

        if report.centroidHz > 0 {
            if report.centroidHz < 350 {
                lines.append(String(format: "Tone center ≈ %d Hz — a dark, warm reading.", Int(report.centroidHz)))
            } else if report.centroidHz > 900 {
                lines.append(String(format: "Tone center ≈ %d Hz — a bright, wiry reading.", Int(report.centroidHz)))
            } else {
                lines.append(String(format: "Tone center ≈ %d Hz — a natural midrange balance.", Int(report.centroidHz)))
            }
        }

        if report.level > 0 && report.level < 0.45 {
            lines.append("Reading taken at a modest volume, so quiet details may be under-represented.")
        }

        if report.sustainSeconds > 0 {
            if report.sustainSeconds >= 1.5 {
                lines.append(String(format: "Chords ring out for ≈ %.1f s — good sustain from the amp/speaker.", report.sustainSeconds))
            } else {
                lines.append(String(format: "Quick decay (≈ %.1f s) — tight, controlled response; raise volume or check speaker.", report.sustainSeconds))
            }
        }

        if report.dynamics >= 2.0 {
            lines.append(String(format: "Punchy dynamics (%.1fx peak/avg) — the amp responds to your touch.", report.dynamics))
        } else if report.dynamics < 1.3 {
            lines.append(String(format: "Compressed feel (%.1fx peak/avg) — high gain/saturation; good for metal, less touch-sensitive.", report.dynamics))
        }

        return lines.joined(separator: "\n")
    }

    @ViewBuilder
    private func warningCard<Content: View>(icon: String, title: String, body: String, @ViewBuilder content: () -> Content = { EmptyView() }) -> some View {
        VStack(spacing: 10) {
            Text(icon).font(.system(size: 28))
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.textPrimary)
            Text(body)
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
            content()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .glassStyle(cornerRadius: 20)
        .padding(.horizontal)
    }
}

// MARK: - 📊 Live Stat Chip

struct LiveStatChip: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(icon).font(.system(size: 16))
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.textPrimary)
            Text(label)
                .font(.system(size: 9, design: .rounded))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.35)))
    }
}

// MARK: - 📊 Energy Share Row

struct ShareRow: View {
    let name: String
    let share: Double // 0-1
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.textPrimary)
                Spacer()
                Text("\(Int(share * 100))% of energy")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.textSecondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.15))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * max(0.02, min(1.0, share * 2.2)))
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - 📊 Stat Tile

struct StatTile: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.35)))
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
                    
                    // Accuracy & limits (honest)
                    VStack(spacing: 12) {
                        HStack {
                            Text("🎯")
                            Text("Accuracy & Limits")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.textPrimary)
                            Spacer()
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tone measurement: ~±1–2 on the 0–10 scale under consistent conditions. Phone mics and rooms vary; use it for RELATIVE comparisons (knob A vs knob B), not absolute amp identity.")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(.textSecondary)
                            Text("Chord detection: experimental. ~60–75% on clean single chords played one at a time; much lower on strummed songs. Confidence is shown for every guess.")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(.textSecondary)
                            Text("Compatibility scores are based on the controls/features you declare for your amp — fill them in honestly (or use Build Your Own Amp) for meaningful results.")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .glassStyle(cornerRadius: 20)
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
    @State private var tempo: Double = 120
    @State private var showChords = true
    @State private var showStrumming = true
    @State private var autoAdvance = true
    @State private var recordedThisSession = false
    @StateObject private var metronome = MetronomeEngine()
    
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
                            if metronome.isPlaying {
                                metronome.stop()
                            } else {
                                metronome.tempo = tempo
                                metronome.start()
                                // Progress counts only when an actual session starts.
                                if !recordedThisSession {
                                    appState.userProgress.recordPracticeSession(songTitle: song.title)
                                    recordedThisSession = true
                                }
                            }
                        }) {
                            Image(systemName: metronome.isPlaying ? "pause.fill" : "play.fill")
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
                                .scaleEffect(metronome.isPlaying && metronome.beatInBar == 0 ? 1.08 : 1.0)
                                .animation(.easeInOut(duration: 0.12), value: metronome.beatInBar)
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
                            .onChange(of: tempo) { newValue in
                                metronome.tempo = newValue
                            }
                    }
                    .padding()
                    .glassStyle(cornerRadius: 16)
                    .padding(.horizontal)

                    // Metronome beat indicator + auto-advance
                    VStack(spacing: 12) {
                        HStack(spacing: 10) {
                            ForEach(0..<4, id: \.self) { beat in
                                Circle()
                                    .fill(beat == metronome.beatInBar && metronome.isPlaying ? Color.ampPink : Color.ampPink.opacity(0.2))
                                    .frame(width: 14, height: 14)
                            }
                            Spacer()
                            Text("🔺 Auto-advance chords every 4 beats")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(.textSecondary)
                            Toggle("", isOn: $autoAdvance)
                                .labelsHidden()
                                .tint(.ampPurple)
                                .scaleEffect(0.8, anchor: .trailing)
                        }
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
                    Button("Done") {
                        metronome.stop()
                        dismiss()
                    }
                        .foregroundColor(.ampPurple)
                }
            }
            .onChange(of: metronome.beatCount) { beats in
                // Advance the chord card every 4 beats (one bar) while looping.
                guard metronome.isPlaying, autoAdvance,
                      beats > 0, beats % 4 == 0,
                      !song.chords.isEmpty else { return }
                withAnimation {
                    currentChordIndex = (currentChordIndex + 1) % song.chords.count
                }
            }
            .onDisappear {
                metronome.stop()
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



// MARK: - 🛠️ Custom Amp Builder

struct CustomAmpView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var brand = ""
    @State private var watts = 20
    @State private var maxGain = 5.0
    @State private var hasBass = true
    @State private var hasMid = true
    @State private var hasTreble = true
    @State private var hasPresence = false
    @State private var canDoClean = true
    @State private var canDoCrunch = true
    @State private var canDoHighGain = false
    @State private var canDoMetal = false
    @State private var hasEffects = false
    @State private var hasReverb = false
    @State private var hasDelay = false

    var body: some View {
        NavigationView {
            Form {
                Section("Identity") {
                    TextField("Amp name", text: $name)
                    TextField("Brand", text: $brand)
                    Stepper("Watts: \(watts)", value: $watts, in: 1...200)
                }
                Section("Controls your amp has") {
                    Toggle("Bass", isOn: $hasBass)
                    Toggle("Mid", isOn: $hasMid)
                    Toggle("Treble", isOn: $hasTreble)
                    Toggle("Presence", isOn: $hasPresence)
                }
                Section("Capabilities") {
                    Toggle("Clean", isOn: $canDoClean)
                    Toggle("Crunch", isOn: $canDoCrunch)
                    Toggle("High Gain", isOn: $canDoHighGain)
                    Toggle("Metal", isOn: $canDoMetal)
                    Toggle("Effects", isOn: $hasEffects)
                    Toggle("Reverb", isOn: $hasReverb)
                    Toggle("Delay", isOn: $hasDelay)
                }
                Section("Max gain") {
                    Slider(value: $maxGain, in: 1...10, step: 0.5)
                    Text(String(format: "%.1f / 10", maxGain))
                }
            }
            .navigationTitle("Build Your Amp")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let amp = GuitarAmp(
            name: name.trimmingCharacters(in: .whitespaces),
            brand: brand.trimmingCharacters(in: .whitespaces).isEmpty ? "Custom" : brand.trimmingCharacters(in: .whitespaces),
            watts: watts,
            features: AmpFeatures(canDoClean: canDoClean, canDoCrunch: canDoCrunch, canDoHighGain: canDoHighGain, canDoMetal: canDoMetal, hasEffects: hasEffects, hasReverb: hasReverb, hasDelay: hasDelay),
            maxGain: maxGain,
            hasBassControl: hasBass,
            hasMidControl: hasMid,
            hasTrebleControl: hasTreble,
            hasPresenceControl: hasPresence,
            description: "Custom amp added by you."
        )
        appState.customAmps.append(amp)
        appState.selectedAmp = amp
        dismiss()
    }
}

// MARK: - 🎵 Custom Song Builder

struct CustomSongView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var title = ""
    @State private var artist = ""
    @State private var genre = "Rock"
    @State private var difficulty: Song.Difficulty = .medium
    @State private var chordsText = ""
    @State private var description = ""
    @State private var gain = 5.0
    @State private var bass = 5.0
    @State private var mid = 5.0
    @State private var treble = 5.0
    @State private var presence = 5.0
    @State private var volume = 5.0

    private let genres = ["Rock", "Metal", "Blues", "Punk", "Ballad", "Classic Rock", "Other"]

    var body: some View {
        NavigationView {
            Form {
                Section("Song info") {
                    TextField("Title", text: $title)
                    TextField("Artist", text: $artist)
                    Picker("Genre", selection: $genre) {
                        ForEach(genres, id: \.self) { Text($0) }
                    }
                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(Song.Difficulty.allCases, id: \.self) { d in
                            Text(d.rawValue).tag(d)
                        }
                    }
                }
                Section("Chords (comma separated, e.g. E5, G5, A5)") {
                    TextField("Chords", text: $chordsText)
                    Text("Chord diagrams won't be shown for custom chords; names are used for practice mode.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Section("Ideal amp settings") {
                    SliderRow(label: "Gain", value: $gain)
                    SliderRow(label: "Bass", value: $bass)
                    SliderRow(label: "Mid", value: $mid)
                    SliderRow(label: "Treble", value: $treble)
                    SliderRow(label: "Presence", value: $presence)
                    SliderRow(label: "Volume", value: $volume)
                }
                Section("Notes") {
                    TextField("Description / tips", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Song")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let chordNames = chordsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let chords = chordNames.map { Chord(name: $0) }

        let song = Song(
            title: title.trimmingCharacters(in: .whitespaces),
            artist: artist.trimmingCharacters(in: .whitespaces).isEmpty ? "Unknown" : artist.trimmingCharacters(in: .whitespaces),
            genre: genre,
            difficulty: difficulty,
            chords: chords,
            idealSettings: AmpSettings(gain: gain, bass: bass, mid: mid, treble: treble, presence: presence, volume: volume),
            description: description,
            isCustom: true
        )
        appState.customSongs.append(song)
        dismiss()
    }
}

struct SliderRow: View {
    let label: String
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text(String(format: "%.1f", value))
                    .foregroundColor(.ampPurple)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            Slider(value: $value, in: 0...10, step: 0.5)
                .tint(.ampPurple)
        }
    }
}

// MARK: - 🎼 Chord Detective (experimental)

struct ChordDetectiveView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @StateObject private var detector = ChordDetector()

    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    SectionHeader(
                        emoji: "🎼",
                        title: "Chord Detective",
                        subtitle: "Experimental · real DSP, not ML"
                    )
                    .padding(.horizontal)

                    // Honesty banner
                    Text("This listens to your guitar and guesses each chord using chroma (pitch-class) template matching. It works best on CLEAN single chords played ONE AT A TIME with pauses. Strummed songs and polyphony are hard — expect low confidence. Nothing is faked; confidence is shown for every guess.")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding()
                        .glassStyle(cornerRadius: 16)
                        .padding(.horizontal)

                    Button(action: {
                        if detector.isListening { detector.stop() } else { detector.start() }
                    }) {
                        VStack(spacing: 10) {
                            Image(systemName: detector.isListening ? "stop.fill" : "mic.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                            Text(detector.isListening ? "Stop" : "Start Listening")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .frame(width: 120, height: 120)
                        .background(
                            Circle().fill(
                                LinearGradient(colors: [.ampPurple, .ampPink], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

                    if detector.isListening {
                        VStack(spacing: 8) {
                            Text("Live guess:")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(.textSecondary)
                            Text(detector.liveGuess)
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundColor(.ampPurple)
                            Text(String(format: "Confidence: %.0f%%", detector.liveConfidence * 100))
                                .font(.system(size: 13, design: .rounded))
                                .foregroundColor(detector.liveConfidence >= 0.6 ? .ampMint : .ampPeach)

                            // Chroma bars
                            HStack(spacing: 4) {
                                ForEach(0..<12, id: \.self) { i in
                                    let val = detector.liveChroma.isEmpty ? 0 : detector.liveChroma[i]
                                    VStack {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.ampPurple)
                                            .frame(width: 18, height: CGFloat(max(2, val * 60)))
                                        Text(["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"][i])
                                            .font(.system(size: 8, design: .monospaced))
                                            .foregroundColor(.textSecondary)
                                    }
                                }
                            }
                            .padding(.top, 8)
                        }
                        .padding()
                        .glassStyle(cornerRadius: 20)
                        .padding(.horizontal)
                    }

                    if !detector.detectedChords.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Detected sequence")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.textPrimary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(detector.detectedChords) { c in
                                        VStack(spacing: 4) {
                                            Text(c.name)
                                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                                .foregroundColor(.ampPurple)
                                            Text(String(format: "%.0f%%", c.confidence * 100))
                                                .font(.system(size: 10, design: .rounded))
                                                .foregroundColor(c.confidence >= 0.6 ? .ampMint : .ampPeach)
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .glassStyle(cornerRadius: 12)
                                    }
                                }
                            }

                            Button(action: saveAsSong) {
                                Text("Save detected sequence as a Song 🎵")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Capsule().fill(LinearGradient(colors: [.ampPurple, .ampPink], startPoint: .leading, endPoint: .trailing)))
                            }
                            .disabled(detector.detectedChords.isEmpty)
                        }
                        .padding()
                        .glassStyle(cornerRadius: 20)
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 80)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        detector.stop()
                        dismiss()
                    }
                    .foregroundColor(.ampPurple)
                }
            }
            .onDisappear { detector.stop() }
        }
    }

    private func saveAsSong() {
        let chords = detector.detectedChords.map { Chord(name: $0.name) }
        let song = Song(
            title: "Detected \(Date().formatted(date: .abbreviated, time: .shortened))",
            artist: "You",
            genre: "Custom",
            difficulty: .medium,
            chords: chords,
            idealSettings: .neutral,
            description: "Chords detected by the experimental Chord Detective. Verify before relying on it.",
            isCustom: true
        )
        appState.customSongs.append(song)
        dismiss()
    }
}

// MARK: - 🎵 Song Analyzer View

struct SongAnalyzerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @StateObject private var analyzer = SongAnalyzer()
    @State private var showingFilePicker = false
    @State private var selectedFileName: String = ""

    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    SectionHeader(
                        emoji: "🎵",
                        title: "Song Analyzer",
                        subtitle: "Upload a track — get chords, tone, playability"
                    )
                    .padding(.horizontal)

                    Text("Pick an audio or video file (mp3, m4a, wav, mp4, mov). For videos the audio track is extracted first. The app separates harmonic (guitar/vocals) from percussive (drums), estimates BPM, recognizes a chord sequence, measures tone, and judges playability. Analysis runs on-device; first 90 s are analyzed. Results are an estimate — verify by ear.")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding()
                        .glassStyle(cornerRadius: 16)
                        .padding(.horizontal)

                    Button(action: { showingFilePicker = true }) {
                        HStack {
                            Image(systemName: "doc.badge.plus")
                            Text(selectedFileName.isEmpty ? "Choose Audio File" : selectedFileName)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(LinearGradient(colors: [.ampPurple, .ampPink], startPoint: .leading, endPoint: .trailing)))
                    }
                    .disabled(analyzer.isAnalyzing)
                    .buttonStyle(PlainButtonStyle())

                    if analyzer.isAnalyzing {
                        VStack(spacing: 10) {
                            ProgressView(value: analyzer.progress)
                                .tint(.ampPurple)
                            Text(analyzer.status)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(.textSecondary)
                        }
                        .padding()
                        .glassStyle(cornerRadius: 16)
                        .padding(.horizontal)
                    }

                    if let r = analyzer.result {
                        resultCard(r)
                    }

                    Spacer(minLength: 80)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.ampPurple)
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.audio, .movie, .video, .mpeg4Movie, .quickTimeMovie, .avi],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    selectedFileName = url.lastPathComponent
                    analyzer.analyze(url: url)
                case .failure(let error):
                    print("File import error: \(error)")
                }
            }
        }
    }

    @ViewBuilder
    private func resultCard(_ r: SongAnalysis) -> some View {
        VStack(spacing: 16) {
            Text("📊 Analysis: \(r.title)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                StatTile(title: "Duration", value: String(format: "%.0f s", r.duration), color: .ampBlue)
                StatTile(title: "BPM", value: String(format: "%.0f", r.bpm), color: .ampPurple)
                StatTile(title: "Difficulty", value: r.playabilityDifficulty, color: .ampPink)
            }

            // Detected chords
            VStack(alignment: .leading, spacing: 8) {
                Text("🎼 Detected chord sequence")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.textPrimary)
                if r.detectedChords.isEmpty {
                    Text("No confident chords detected. Try a cleaner mix or a guitar-only track.")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.textSecondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(r.detectedChords.enumerated()), id: \.offset) { _, c in
                                Text(c)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.ampPurple)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .glassStyle(cornerRadius: 10)
                            }
                        }
                    }
                    Text("Unique chords: \(r.detectedChords.count) · \(r.chordNamesTimeline.count) segments")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .glassStyle(cornerRadius: 16)

            // Tone
            VStack(alignment: .leading, spacing: 8) {
                Text("🎛️ Estimated guitar tone (from the track)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.textPrimary)
                FrequencyVisualizer(bass: r.toneBass, mid: r.toneMid, treble: r.toneTreble, label: "Measured from mix")
                HStack {
                    Text(String(format: "Gain ≈ %.1f/10", r.estimatedGain))
                    Spacer()
                    Text(String(format: "Sustain ≈ %.1f s", r.sustain))
                    Spacer()
                    Text(String(format: "Dynamics %.1fx", r.dynamics))
                }
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(.textSecondary)
            }
            .padding()
            .glassStyle(cornerRadius: 16)

            // Mix analysis
            VStack(alignment: .leading, spacing: 8) {
                Text("🎚️ Mix analysis")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.textPrimary)
                HStack {
                    Text(String(format: "Harmonic (guitar/vocals): %.0f%%", r.harmonicRatio * 100))
                    Spacer()
                    Text(String(format: "Percussive (drums): %.0f%%", r.percussiveRatio * 100))
                }
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.textSecondary)
                Text("Instruments likely present:")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.textPrimary)
                    .padding(.top, 4)
                ForEach(r.instruments, id: \.self) { inst in
                    HStack(spacing: 6) {
                        Text("•")
                        Text(inst)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.textSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .glassStyle(cornerRadius: 16)

            // Playability
            VStack(alignment: .leading, spacing: 8) {
                Text("🎸 Playability on guitar")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.textPrimary)
                Text("Difficulty: \(r.playabilityDifficulty)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(r.playabilityDifficulty == "Easy" ? .ampMint : r.playabilityDifficulty == "Hard" ? .ampPink : .ampPeach)
                Text("What you'll need:")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.textPrimary)
                    .padding(.top, 4)
                ForEach(r.neededEquipment, id: \.self) { item in
                    HStack(spacing: 6) {
                        Text("•")
                        Text(item)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.textSecondary)
                    }
                }
                Text("Notes:")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.textPrimary)
                    .padding(.top, 4)
                ForEach(r.playabilityNotes, id: \.self) { n in
                    Text("– \(n)")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .glassStyle(cornerRadius: 16)

            Button(action: { saveAsSong(r) }) {
                Text("Save as a Song 🎵")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(LinearGradient(colors: [.ampPurple, .ampPink], startPoint: .leading, endPoint: .trailing)))
            }
            .disabled(r.detectedChords.isEmpty)
        }
        .padding()
        .glassStyle(cornerRadius: 20)
        .padding(.horizontal)
    }

    private func saveAsSong(_ r: SongAnalysis) {
        let chords = r.detectedChords.map { Chord(name: $0) }
        let song = Song(
            title: r.title,
            artist: "Analyzed track",
            genre: "Custom",
            difficulty: r.playabilityDifficulty == "Easy" ? .easy : r.playabilityDifficulty == "Hard" ? .hard : .medium,
            chords: chords,
            idealSettings: AmpSettings(gain: r.estimatedGain, bass: r.toneBass, mid: r.toneMid, treble: r.toneTreble, presence: 5, volume: 5),
            description: "Auto-analyzed from audio. Chords: \(r.detectedChords.joined(separator: ", ")). \(r.playabilityNotes.joined(separator: " "))",
            isCustom: true
        )
        appState.customSongs.append(song)
        dismiss()
    }
}
