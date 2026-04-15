import AVFoundation
import Combine

/// Plays looping ambient background audio during coloring sessions.
/// Audio files (ambient_rain.mp3, ambient_lofi.mp3, etc.) should be added to
/// the app bundle under Resources/Sounds/. If a file is absent the service
/// silently skips playback so the rest of the app is unaffected.
final class AmbientSoundService: ObservableObject {

    // MARK: - Singleton

    static let shared = AmbientSoundService()

    // MARK: - Sound catalogue

    enum Sound: String, CaseIterable, Identifiable {
        case none     = "None"
        case rain     = "Rain"
        case lofi     = "Lo-Fi"
        case nature   = "Nature"
        case ocean    = "Ocean"

        var id: String { rawValue }

        var bundleFilename: String? {
            switch self {
            case .none:   return nil
            case .rain:   return "ambient_rain"
            case .lofi:   return "ambient_lofi"
            case .nature: return "ambient_nature"
            case .ocean:  return "ambient_ocean"
            }
        }

        var icon: String {
            switch self {
            case .none:   return "speaker.slash"
            case .rain:   return "cloud.rain"
            case .lofi:   return "music.note"
            case .nature: return "leaf"
            case .ocean:  return "water.waves"
            }
        }
    }

    // MARK: - Published state

    @Published private(set) var currentSound: Sound = .none
    @Published var volume: Float = 0.6 {
        didSet { player?.volume = volume }
    }

    // MARK: - Private

    private var player: AVAudioPlayer?

    private init() {}

    // MARK: - Playback control

    func play(_ sound: Sound) {
        guard sound != currentSound else { return }
        stop()

        guard let filename = sound.bundleFilename,
              let url = Bundle.main.url(forResource: filename, withExtension: "mp3") else {
            // File not found — silently remain silent; still update published state
            // so UI can reflect the selection.
            currentSound = (sound == .none) ? .none : .none
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.numberOfLoops = -1   // loop indefinitely
            player?.volume = volume
            player?.prepareToPlay()
            player?.play()
            currentSound = sound
        } catch {
            print("[AmbientSoundService] Playback error for '\(filename)': \(error.localizedDescription)")
            currentSound = .none
        }
    }

    func stop() {
        player?.stop()
        player = nil
        currentSound = .none
    }
}
