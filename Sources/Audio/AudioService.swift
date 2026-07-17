import AVFoundation
import Foundation

@MainActor protocol AudioPlaying: AnyObject {
    var isAvailable: Bool { get }
    func playDeckAudio(filename: String, deckID: UUID)
    func speakTarget(_ target: String)
}

extension AudioPlaying {
    func play(target: String, audioFilename: String?, deckID: UUID) {
        if let filename = audioFilename, !filename.isEmpty {
            playDeckAudio(filename: filename, deckID: deckID)
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

    func playDeckAudio(filename: String, deckID: UUID) {
        let url = Self.mediaFileURL(filename: filename, deckID: deckID, mediaBaseURL: mediaBaseURL)
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
        currentPlayer = player
        player.play()
    }

    func speakTarget(_ target: String) {
        let utterance = AVSpeechUtterance(string: target)
        utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
        synthesizer.speak(utterance)
    }
}
