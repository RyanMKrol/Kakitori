import AVFoundation
import Foundation

@MainActor protocol AudioPlaying: AnyObject {
    var isAvailable: Bool { get }
    @discardableResult func playDeckAudio(filename: String, deckID: UUID) -> Bool
    func speakTarget(_ target: String)
}

extension AudioPlaying {
    func play(target: String, audioFilename: String?, deckID: UUID) {
        if let filename = audioFilename, !filename.isEmpty {
            if !playDeckAudio(filename: filename, deckID: deckID) {
                speakTarget(target)
            }
        } else {
            speakTarget(target)
        }
    }

    static func mediaFileURL(filename: String, deckID: UUID, mediaBaseURL: URL) -> URL {
        mediaBaseURL.appendingPathComponent(deckID.uuidString).appendingPathComponent(filename)
    }
}

@MainActor final class AudioService: AudioPlaying {
    private var currentPlayer: AVAudioPlayer?
    private let synthesizer = AVSpeechSynthesizer()
    private let mediaBaseURL: URL
    private var didConfigureCategory = false

    init(mediaBaseURL: URL? = nil) {
        if let url = mediaBaseURL {
            self.mediaBaseURL = url
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            let kakitoriMedia = appSupport?.appendingPathComponent("Kakitori").appendingPathComponent("Media")
            self.mediaBaseURL = kakitoriMedia ?? FileManager.default.temporaryDirectory
        }
        // Configure the session up front (session start), so the audio server / RemoteIO unit has a
        // chance to warm up before the first card auto-plays — a cold-start config-then-play in one
        // tick is what produced "IPCAUClient can't connect to server" and clipped/empty first buffers.
        configureSession()
    }

    var isAvailable: Bool {
        AVSpeechSynthesisVoice(language: "ja-JP") != nil
    }

    @discardableResult
    func playDeckAudio(filename: String, deckID: UUID) -> Bool {
        let url = Self.mediaFileURL(filename: filename, deckID: deckID, mediaBaseURL: mediaBaseURL)

        // A genuinely missing/zero-byte file can't play — fall through to TTS rather than throw.
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = (attributes?[.size] as? Int) ?? 0
        guard fileSize > 0 else {
            print("AudioService: deck audio missing or empty at \(url.path)")
            return false
        }

        activateSession()
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            // Stop the outgoing player BEFORE replacing it, so a fast second play (autoplay racing
            // the manual play button, or the next card) doesn't deallocate a still-playing player
            // mid-sound — that was clipping the tail of clips.
            currentPlayer?.stop()
            currentPlayer = player
            player.prepareToPlay() // pre-roll the audio unit so the first frames aren't dropped (start-clip).
            player.play()
            return true
        } catch {
            print("AudioService: failed to load deck audio at \(url.path): \(error)")
            return false
        }
    }

    func speakTarget(_ target: String) {
        activateSession()
        let utterance = AVSpeechUtterance(string: target)
        utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
        synthesizer.speak(utterance)
    }

    /// Set the category/mode once. `.spokenAudio` is right for speech recordings + TTS.
    private func configureSession() {
        guard !didConfigureCategory else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            didConfigureCategory = true
        } catch {
            print("AudioService: failed to set audio session category: \(error)")
        }
    }

    /// Ensure the session is active right before playing. Called every time (cheap) so playback also
    /// recovers after an interruption (a phone call, another app) deactivated the session.
    private func activateSession() {
        configureSession()
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("AudioService: failed to activate audio session: \(error)")
        }
    }
}
