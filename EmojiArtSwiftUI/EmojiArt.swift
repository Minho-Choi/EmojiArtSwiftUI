//
//  EmojiArt.swift
//  EmojiArtSwiftUI
//
//  Created by Minho Choi on 2021/01/12.
//

import Foundation

struct EmojiArt: Codable {
    var backgroundURL: URL?
    var emojis = [Emoji]()
    
    struct Emoji: Identifiable, Codable, Hashable {
        let id: Int
        let text: String
        var x: Int
        var y: Int
        var size: Int
        var isSelected = false
        var isReadyToRemove = false
        
        fileprivate init(text: String, x: Int, y: Int, size: Int, id: Int) {
            self.text = text
            self.x = x
            self.y = y
            self.size = size
            self.id = id
        }
    }
    
    var json: Data? {
        return try? JSONEncoder().encode(self)
    }
    
    init?(json: Data?) {    // fallable initializer
        if json != nil, let newEmojiArt = try? JSONDecoder().decode(EmojiArt.self, from: json!) {
            self = newEmojiArt  // allowed for value types
        } else {
            return nil
        }
    }
    
    init() {}
    
    private var uniqueEmojiId = 0
    
    mutating func addEmoji(_ text: String, x: Int, y: Int, size: Int) {
        uniqueEmojiId += 1
        emojis.append(Emoji(text: text, x: x, y: y, size: size, id: uniqueEmojiId))
    }
    
    mutating func toggleEmoji(_ emoji: Emoji) {
        if let index = emojis.firstIndex(matching: emoji) {
            emojis[index].isSelected.toggle()
        }
    }
    
    mutating func readyToDeleteEmoji(_ emoji: Emoji) {
        if let index = emojis.firstIndex(matching: emoji) {
            emojis[index].isReadyToRemove = true
        }
    }
    
    mutating func deleteEmoji(_ emoji: Emoji) {
        if let index = emojis.firstIndex(matching: emoji) {
            emojis.remove(at: index)
        }
    }
    
    mutating func deselectAllEmojis() {
        for index in 0..<emojis.count {
            emojis[index].isSelected = false
            emojis[index].isReadyToRemove = false
        }
    }
}
