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
    private var isAudioSessionActive = false

    init(mediaBaseURL: URL? = nil) {
        if let url = mediaBaseURL {
            self.mediaBaseURL = url
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            let kakitoriMedia = appSupport?.appendingPathComponent("Kakitori").appendingPathComponent("Media")
            self.mediaBaseURL = kakitoriMedia ?? FileManager.default.temporaryDirectory
        }
    }

    var isAvailable: Bool {
        AVSpeechSynthesisVoice(language: "ja-JP") != nil
    }

    @discardableResult
    func playDeckAudio(filename: String, deckID: UUID) -> Bool {
        activateAudioSessionIfNeeded()
        let url = Self.mediaFileURL(filename: filename, deckID: deckID, mediaBaseURL: mediaBaseURL)
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            currentPlayer = player
            player.play()
            return true
        } catch {
            print("AudioService: failed to load deck audio at \(url.path): \(error)")
            return false
        }
    }

    func speakTarget(_ target: String) {
        activateAudioSessionIfNeeded()
        let utterance = AVSpeechUtterance(string: target)
        utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
        synthesizer.speak(utterance)
    }

    private func activateAudioSessionIfNeeded() {
        guard !isAudioSessionActive else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback)
            try session.setActive(true)
            isAudioSessionActive = true
        } catch {
            print("AudioService: failed to activate audio session: \(error)")
        }
    }
}
