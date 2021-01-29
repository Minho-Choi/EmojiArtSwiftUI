//
//  EmojiArtSwiftUIApp.swift
//  EmojiArtSwiftUI
//
//  Created by Minho Choi on 2021/01/12.
//

import SwiftUI

@main
struct EmojiArtSwiftUIApp: App {
//    let store = EmojiArtDocumentStore(named: "Emoji Art")
    let store = EmojiArtDocumentStore(directory: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!)
    var body: some Scene {
        WindowGroup {
            EmojiArtDocumentChooser().environmentObject(store)
        }
    }
}
