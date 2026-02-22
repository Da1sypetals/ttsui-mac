//
//  CloneSpeaker.swift
//  ttsui-mac
//
//  Speaker model for Clone mode voice configurations
//

import Foundation

struct CloneSpeaker: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    let audioFileName: String
    var textReference: String?

    var audioURL: URL {
        FileService.shared.cloneSpeakersAudioDirectory.appendingPathComponent(audioFileName)
    }
}
