//
//  OptionalImage.swift
//  EmojiArtSwiftUI
//
//  Created by Minho Choi on 2021/01/12.
//

import SwiftUI

struct OptionalImage: View {
    var uiImage: UIImage?
    
    var body: some View {
        Group {
            if uiImage != nil {
                Image(uiImage: uiImage!)
            }
        }
    }
}
