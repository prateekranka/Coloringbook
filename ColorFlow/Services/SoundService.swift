import AVFoundation

/// Synthesizes soft ambient sounds for the coloring experience.
/// All audio is generated programmatically — no bundled audio files required.
final class SoundService {
    static let shared = SoundService()

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let format: AVAudioFormat

    private static let enabledKey = "ambientSoundEnabled"

    /// Whether ambient sounds are active. Persisted across launches.
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: SoundService.enabledKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: SoundService.enabledKey)
            if newValue { startEngine() } else { engine.pause() }
        }
    }

    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.6
        if isEnabled { startEngine() }
    }

    private func startEngine() {
        guard !engine.isRunning else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default,
                                                             options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
        } catch {
            // Non-critical — silently skip if audio session can't start
        }
    }

    // MARK: - Sound events

    /// Soft "pop" played when a region is filled.
    func playFillPop() {
        guard isEnabled else { return }
        play(buffer: makeTone(frequency: 523.25, duration: 0.12, amplitude: 0.25,
                              envelope: .exponentialDecay))
    }

    /// Very subtle scratch burst played when a brush stroke begins.
    func playBrushStart() {
        guard isEnabled else { return }
        play(buffer: makeNoise(duration: 0.06, amplitude: 0.08))
    }

    /// Gentle chime played when a save succeeds.
    func playSaveChime() {
        guard isEnabled else { return }
        play(buffer: makeTone(frequency: 784.0, duration: 0.18, amplitude: 0.18,
                              envelope: .exponentialDecay))
    }

    // MARK: - Buffer generation

    private enum Envelope { case exponentialDecay, linear }

    private func play(buffer: AVAudioPCMBuffer) {
        startEngine()
        playerNode.scheduleBuffer(buffer, completionHandler: nil)
        if !playerNode.isPlaying { playerNode.play() }
    }

    private func makeTone(frequency: Double, duration: Double,
                          amplitude: Float, envelope: Envelope) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        let frames = AVAudioFrameCount(sampleRate * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let data = buffer.floatChannelData![0]
        for i in 0..<Int(frames) {
            let t = Double(i) / sampleRate
            let env: Float
            switch envelope {
            case .exponentialDecay:
                env = Float(exp(-t / (duration * 0.3)))
            case .linear:
                env = Float(1.0 - t / duration)
            }
            data[i] = amplitude * env * Float(sin(2 * .pi * frequency * t))
        }
        return buffer
    }

    private func makeNoise(duration: Double, amplitude: Float) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        let frames = AVAudioFrameCount(sampleRate * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let data = buffer.floatChannelData![0]
        for i in 0..<Int(frames) {
            let t = Double(i) / sampleRate
            let env = Float(1.0 - t / duration)
            data[i] = amplitude * env * Float.random(in: -1...1)
        }
        return buffer
    }
}
