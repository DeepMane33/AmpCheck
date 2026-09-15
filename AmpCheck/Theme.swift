import SwiftUI

// MARK: - 🎸 AmpCheck Theme 🎸
// Y2K + Pastel + Glassmorphism + Neumorphism

extension Color {
    // Pastel Y2K Colors
    static let ampPink = Color(red: 1.0, green: 0.75, blue: 0.85)
    static let ampPurple = Color(red: 0.85, green: 0.75, blue: 1.0)
    static let ampBlue = Color(red: 0.75, green: 0.85, blue: 1.0)
    static let ampMint = Color(red: 0.75, green: 1.0, blue: 0.85)
    static let ampLavender = Color(red: 0.9, green: 0.85, blue: 1.0)
    static let ampPeach = Color(red: 1.0, green: 0.85, blue: 0.75)
    static let ampSky = Color(red: 0.8, green: 0.9, blue: 1.0)
    static let ampLilac = Color(red: 0.85, green: 0.8, blue: 0.95)
    
    // Glass Colors
    static let glassWhite = Color.white.opacity(0.15)
    static let glassBorder = Color.white.opacity(0.3)
    static let glassShadow = Color.black.opacity(0.1)
    
    // Neumorphic Colors
    static let neuLight = Color.white.opacity(0.8)
    static let neuDark = Color.black.opacity(0.15)
    
    // Text Colors
    static let textPrimary = Color(red: 0.2, green: 0.15, blue: 0.3)
    static let textSecondary = Color(red: 0.5, green: 0.45, blue: 0.6)
    static let textAccent = Color(red: 0.7, green: 0.4, blue: 0.8)
    
    // Background Gradient
    static let bgGradientStart = Color(red: 0.95, green: 0.9, blue: 1.0)
    static let bgGradientEnd = Color(red: 0.9, green: 0.95, blue: 1.0)
}

// MARK: - 🪟 Glassmorphism Modifier

struct GlassModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    var opacity: Double = 0.7
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)
                        .opacity(opacity)
                    
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.white.opacity(0.1))
                    
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                }
            )
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

extension View {
    func glassStyle(cornerRadius: CGFloat = 20, opacity: Double = 0.7) -> some View {
        modifier(GlassModifier(cornerRadius: cornerRadius, opacity: opacity))
    }
}

// MARK: - 🫧 Neumorphism Modifier

struct NeumorphicModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    var isActive: Bool = false
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color(red: 0.95, green: 0.92, blue: 0.98))
                    
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .shadow(
                            color: isActive ? Color.purple.opacity(0.3) : Color.white.opacity(0.8),
                            radius: isActive ? 8 : 10,
                            x: isActive ? -4 : -5,
                            y: isActive ? 4 : -5
                        )
                        .shadow(
                            color: isActive ? Color.purple.opacity(0.2) : Color.black.opacity(0.15),
                            radius: isActive ? 8 : 10,
                            x: isActive ? 4 : 5,
                            y: isActive ? -4 : 5
                        )
                }
            )
    }
}

extension View {
    func neuStyle(cornerRadius: CGFloat = 20, isActive: Bool = false) -> some View {
        modifier(NeumorphicModifier(cornerRadius: cornerRadius, isActive: isActive))
    }
}

// MARK: - 🎵 Y2K Button Style

struct Y2KButtonStyle: ButtonStyle {
    var color: Color = .ampPurple
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.3), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .cornerRadius(16)
            .shadow(color: color.opacity(0.4), radius: 8, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - 🌈 Gradient Background

struct GradientBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.98, green: 0.95, blue: 1.0),
                Color(red: 0.95, green: 0.92, blue: 1.0),
                Color(red: 0.92, green: 0.95, blue: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

// MARK: - ✨ Floating Particles (Y2K Vibes)

struct FloatingEmoji: View {
    let emoji: String
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let duration: Double
    
    @State private var offsetY: CGFloat = 0
    @State private var opacity: Double = 0.6
    
    var body: some View {
        Text(emoji)
            .font(.system(size: size))
            .position(x: x, y: y + offsetY)
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: duration)
                    .repeatForever(autoreverses: true)
                ) {
                    offsetY = -20
                    opacity = 0.3
                }
            }
    }
}

// MARK: - 🎸 Chord Shape View

struct ChordShape: View {
    let chordName: String
    let isActive: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Text(chordName)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(isActive ? .ampPurple : .textPrimary)
            
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.98, green: 0.96, blue: 1.0))
                    .frame(width: 80, height: 100)
                
                VStack(spacing: 4) {
                    ForEach(0..<4) { _ in
                        Rectangle()
                            .fill(Color.textPrimary.opacity(0.3))
                            .frame(width: 70, height: 1)
                    }
                }
            }
        }
        .neuStyle(cornerRadius: 16, isActive: isActive)
        .padding(8)
    }
}

// MARK: - 📊 Compatibility Ring

struct CompatibilityRing: View {
    let percentage: Double
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(
                    Color.gray.opacity(0.2),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .frame(width: size, height: size)
            
            // Progress ring
            Circle()
                .trim(from: 0, to: percentage / 100)
                .stroke(
                    LinearGradient(
                        colors: ringColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.0), value: percentage)
            
            // Percentage text
            VStack(spacing: 4) {
                Text("\(Int(percentage))%")
                    .font(.system(size: size * 0.25, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                
                Text("match")
                    .font(.system(size: size * 0.1, weight: .medium, design: .rounded))
                    .foregroundColor(.textSecondary)
            }
        }
    }
    
    private var ringColors: [Color] {
        if percentage >= 80 {
            return [.ampMint, .ampBlue]
        } else if percentage >= 60 {
            return [.ampPeach, .ampPink]
        } else if percentage >= 40 {
            return [.ampPink, .ampPurple]
        } else {
            return [.ampPurple, .ampLilac]
        }
    }
}

// MARK: - 🎛️ Knob Visual

struct KnobVisual: View {
    let label: String
    let value: Double
    let maxValue: Double
    let isAdjustable: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.textSecondary)
            
            ZStack {
                // Knob background
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.95, green: 0.92, blue: 0.98),
                                Color(red: 0.88, green: 0.85, blue: 0.95)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                    .shadow(
                        color: Color.white.opacity(0.8),
                        radius: 5,
                        x: -2,
                        y: -2
                    )
                    .shadow(
                        color: Color.black.opacity(0.15),
                        radius: 5,
                        x: 2,
                        y: 2
                    )
                
                // Knob indicator
                Circle()
                    .fill(
                        isAdjustable ?
                        LinearGradient(
                            colors: [.ampPurple, .ampPink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 12, height: 12)
                    .offset(y: -15)
                    .rotationEffect(.degrees(value / maxValue * 270 - 135))
            }
            
            Text("\(Int(value))/\(Int(maxValue))")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(isAdjustable ? .textAccent : .textSecondary)
        }
    }
}

// MARK: - 🎯 Priority Badge

struct PriorityBadge: View {
    let text: String
    let priority: Priority
    
    enum Priority {
        case high, medium, low
        
        var color: Color {
            switch self {
            case .high: return .ampPink
            case .medium: return .ampPeach
            case .low: return .ampMint
            }
        }
        
        var emoji: String {
            switch self {
            case .high: return "🔴"
            case .medium: return "🟡"
            case .low: return "🟢"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Text(priority.emoji)
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(priority.color)
        )
    }
}

// MARK: - 🌟 Y2K Decorative Elements

struct Y2KDecorations: View {
    var body: some View {
        ZStack {
            FloatingEmoji(emoji: "🎸", x: 50, y: 100, size: 30, duration: 3.0)
            FloatingEmoji(emoji: "🎵", x: 300, y: 150, size: 24, duration: 2.5)
            FloatingEmoji(emoji: "✨", x: 200, y: 80, size: 20, duration: 2.0)
            FloatingEmoji(emoji: "💜", x: 350, y: 250, size: 18, duration: 3.5)
            FloatingEmoji(emoji: "🎶", x: 80, y: 300, size: 22, duration: 2.8)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 📱 Tab Item Style

struct TabItemStyle: View {
    let icon: String
    let label: String
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(isSelected ? .ampPurple : .textSecondary)
            
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(isSelected ? .ampPurple : .textSecondary)
        }
    }
}

// MARK: - 🔍 Search Bar Style

struct SearchBarStyle: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.textSecondary)
            
            TextField("Search any song... 🎵", text: $text)
                .font(.system(size: 16, design: .rounded))
                .foregroundColor(.textPrimary)
                .focused($isFocused)
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.textSecondary)
                }
            }
        }
        .padding()
        .glassStyle(cornerRadius: 16)
    }
}

// MARK: - 🎸 Song Card

struct SongCard: View {
    let title: String
    let artist: String
    let compatibility: Double
    let genre: String
    
    var body: some View {
        HStack(spacing: 16) {
            // Album art placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [.ampPurple, .ampPink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                
                Text("🎸")
                    .font(.system(size: 28))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                
                Text(artist)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.textSecondary)
                
                HStack(spacing: 6) {
                    Text(genre)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.ampPurple)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.ampPurple.opacity(0.1))
                        )
                    
                    if compatibility > 0 {
                        Text("\(Int(compatibility))% match")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(compatibility >= 70 ? .ampMint : .ampPink)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(compatibility >= 70 ? Color.ampMint.opacity(0.1) : Color.ampPink.opacity(0.1))
                            )
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.textSecondary)
                .font(.system(size: 14))
        }
        .padding()
        .glassStyle(cornerRadius: 16)
    }
}

// MARK: - 🎛️ Setting Row

struct SettingRow: View {
    let label: String
    let value: Double
    let maxValue: Double
    let isAdjustable: Bool
    let recommendation: String?
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.textPrimary)
                
                if let rec = recommendation {
                    Text(rec)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.textSecondary)
                }
            }
            
            Spacer()
            
            // Value bar
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 120, height: 8)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: isAdjustable ? [.ampPurple, .ampPink] : [.gray.opacity(0.3), .gray.opacity(0.2)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 120 * (value / maxValue), height: 8)
            }
            
            Text("\(Int(value))")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(isAdjustable ? .ampPurple : .textSecondary)
                .frame(width: 30)
        }
        .padding()
        .neuStyle(cornerRadius: 12)
    }
}

// MARK: - 📊 Frequency Visualizer

struct FrequencyVisualizer: View {
    let bass: Double
    let mid: Double
    let treble: Double
    let label: String
    
    var body: some View {
        VStack(spacing: 12) {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.textSecondary)
            
            HStack(spacing: 16) {
                // Bass
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.ampPink.opacity(0.3))
                        .frame(width: 40, height: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.ampPink)
                                .frame(width: 40, height: 80 * (bass / 10))
                                .frame(maxHeight: .infinity, alignment: .bottom)
                        )
                    Text("BASS")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(.ampPink)
                }
                
                // Mid
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.ampPurple.opacity(0.3))
                        .frame(width: 40, height: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.ampPurple)
                                .frame(width: 40, height: 80 * (mid / 10))
                                .frame(maxHeight: .infinity, alignment: .bottom)
                        )
                    Text("MID")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(.ampPurple)
                }
                
                // Treble
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.ampBlue.opacity(0.3))
                        .frame(width: 40, height: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.ampBlue)
                                .frame(width: 40, height: 80 * (treble / 10))
                                .frame(maxHeight: .infinity, alignment: .bottom)
                        )
                    Text("TREBLE")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(.ampBlue)
                }
            }
        }
        .padding()
        .glassStyle(cornerRadius: 16)
    }
}

// MARK: - 🎯 Quick Action Button

struct QuickActionButton: View {
    let emoji: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(emoji)
                    .font(.system(size: 32))
                
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                
                Text(subtitle)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .glassStyle(cornerRadius: 20)
        }
    }
}

// MARK: - 🔮 Section Header

struct SectionHeader: View {
    let emoji: String
    let title: String
    let subtitle: String?
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(emoji)
                .font(.system(size: 28))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                
                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.textSecondary)
                }
            }
        }
    }
}

// MARK: - 🎸 Amp Card

struct AmpCard: View {
    let name: String
    let brand: String
    let watts: Int
    let isSelected: Bool
    
    var body: some View {
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
                Text(name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                
                Text("\(brand) • \(watts)W")
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
}

// MARK: - 📝 Question Card (for self-assessment)

struct QuestionCard: View {
    let question: String
    let options: [String]
    @Binding var selectedOption: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(question)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.textPrimary)
            
            ForEach(options, id: \.self) { option in
                Button(action: { selectedOption = option }) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(selectedOption == option ? Color.ampPurple : Color.clear)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle()
                                    .stroke(Color.ampPurple, lineWidth: 2)
                            )
                        
                        Text(option)
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(.textPrimary)
                        
                        Spacer()
                    }
                    .padding()
                    .neuStyle(cornerRadius: 12, isActive: selectedOption == option)
                }
            }
        }
        .padding()
        .glassStyle(cornerRadius: 20)
    }
}

// MARK: - 🎸 Preview Provider

struct Theme_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Glass card
                VStack {
                    Text("Glassmorphism Card")
                        .font(.headline)
                }
                .padding()
                .glassStyle()
                
                // Neumorphic card
                VStack {
                    Text("Neumorphic Card")
                        .font(.headline)
                }
                .padding()
                .neuStyle()
                
                // Compatibility ring
                CompatibilityRing(percentage: 72, size: 120)
                
                // Frequency visualizer
                FrequencyVisualizer(bass: 7, mid: 4, treble: 6, label: "Current Tone")
                
                // Button
                Button("Tap Me 🎸") { }
                    .buttonStyle(Y2KButtonStyle())
                    .padding()
            }
            .padding()
        }
        .background(GradientBackground())
    }
}
