import AVFoundation
import SwiftUI

enum AmbientSound: String, CaseIterable, Identifiable {
    case rain = "Rain"
    case lofi = "Lo-fi"
    case nature = "Nature"

    var id: String { rawValue }
    var filename: String {
        switch self {
        case .rain: return "rain"
        case .lofi: return "lofi"
        case .nature: return "nature"
        }
    }
    var systemIcon: String {
        switch self {
        case .rain: return "cloud.rain"
        case .lofi: return "music.note"
        case .nature: return "leaf"
        }
    }
}

class AudioService: ObservableObject {
    static let shared = AudioService()
    @Published var currentSound: AmbientSound?

    private var player: AVAudioPlayer?

    private init() {
        configureAudioSession()
    }

    private func configureAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func play(_ sound: AmbientSound) {
        guard let url = Bundle.main.url(forResource: sound.filename, withExtension: "mp3") else { return }
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.numberOfLoops = -1   // infinite loop
            player?.volume = 0.5
            player?.play()
            currentSound = sound
        } catch {
            print("AudioService: failed to play \(sound.rawValue): \(error)")
        }
    }

    func stop() {
        player?.stop()
        player = nil
        currentSound = nil
    }

    func toggle(_ sound: AmbientSound) {
        if currentSound == sound { stop() } else { play(sound) }
    }
}
