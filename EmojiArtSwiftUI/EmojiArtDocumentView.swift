//
//  EmojiArtDocumentView.swift
//  EmojiArtSwiftUI
//
//  Created by Minho Choi on 2021/01/12.
//

import SwiftUI

struct EmojiArtDocumentView: View {
    @ObservedObject var document: EmojiArtDocument
    @State var chosenPalette: String = ""
    var body: some View {
        VStack {
            HStack {
                PaletteChooser(document: document, chosenPalette: $chosenPalette)
                ScrollView(.horizontal) {
                    HStack {
                        // \. : keypath syntax
                        ForEach(chosenPalette.map { String($0) }, id: \.self) { emoji in
                            Text(emoji)
                                .font(Font.system(size: defaultEmojiSize))
                                .onDrag { return NSItemProvider(object: emoji as NSString) }
                        }
                    }
                }
                .onAppear { self.chosenPalette = document.defaultPalette }
            }
            // using overlay or background - sizing problem(match size with foreground view)
            // compare with ZStack(which shrinks view to original image size)
            GeometryReader { geometry in
                ZStack {
                    Color.white.overlay(
                        OptionalImage(uiImage: self.document.backgroundImage)
                            .scaleEffect(zoomScale)
                            .offset(self.panOffset)
                    )
                    // if single tap Gesture is behind the doubletap gesture, reaction slows down
                    // gesture recognizer is waiting for doubletap time, maybe
                    // reversed order disables double tap gesture(don't know why)
                    .gesture(self.doubleTapToZoom(in: geometry.size))
                    .gesture(tapToDeselect())
                    
                    if isLoading {
                        Image(systemName: "hourglass").imageScale(.large).spinning()
                    } else {
                        ForEach(self.document.emojis) { emoji in
                            Group {
                                Text(emoji.text)
                                    .font(animatableWithSize: magnification(for: emoji))
                                Rectangle()
                                    .stroke(emoji.isSelected ? Color.blue : Color.clear)
                                    .frame(width: magnification(for: emoji), height:magnification(for: emoji), alignment: .center)
                            }.position(self.position(for: emoji, in: geometry.size))
                            .colorMultiply(emoji.isReadyToRemove ? .red : .white)
                            .gesture(tapEmojiGesture(emoji: emoji))
                            .gesture(readyToRemoveGesture(emoji: emoji))
                        }
                    }
                }
                .clipped()
                // order matters!!
                // if panning is added after the zooming gestures, moving animation does not work
                .gesture(document.isSelectionExists ? nil : panGesture())
                .gesture(document.isSelectionExists ? panEachGesture(emojis: document.selectedEmojis()) : nil)
                .gesture(document.isSelectionExists ? nil : zoomGesture())
                .gesture(document.isSelectionExists ? zoomEachGesture(emojis: document.selectedEmojis()) : nil)
                .edgesIgnoringSafeArea([.horizontal, .bottom])
                .onReceive(self.document.$backgroundImage) { image in
                    self.zoomToFit(image, in: geometry.size)
                }
                .onDrop(of: ["public.image", "public.text"], isTargeted: nil) { providers, location in
                    var location = geometry.convert(location, from: .global)
                    location = CGPoint(x: location.x - geometry.size.width/2, y: location.y - geometry.size.height/2)
                    location = CGPoint(x: location.x - self.panOffset.width, y: location.y - self.panOffset.height)
                    location = CGPoint(x: location.x / self.zoomScale, y: location.y / self.zoomScale)
                    return self.drop(providers: providers, at: location)
                }
            }
        }
    }
    private let defaultEmojiSize: CGFloat = 40
    
    var isLoading: Bool {
        document.backgroundURL != nil && document.backgroundImage == nil
    }
    
    // MARK: - Deselect All
    
    private func tapToDeselect() -> some Gesture {
        TapGesture(count: 1)
            .onEnded {
                document.deselectAllEmojis()
            }
    }
    
    // MARK: - Remove Emoji
    
    func readyToRemoveGesture(emoji: EmojiArt.Emoji) -> some Gesture {
        return LongPressGesture().onEnded { _ in
            withAnimation(Animation.linear.repeatForever(autoreverses: true)) {
                document.readyToDeleteEmoji(emoji)
            }
        }
    }
    
    func tapEmojiGesture(emoji: EmojiArt.Emoji) -> some Gesture {
        return TapGesture(count: 1)
            .onEnded { _ in
                if emoji.isReadyToRemove {
                    document.deleteEmoji(emoji)
                } else {
                    document.selectEmoji(emoji)
                }
        }
    }
    
    
    
    // MARK: - Zoom & Pinch Gesture
    
    @State private var steadyStateZoomScale: CGFloat = 1.0
    @GestureState private var gestureZoomScale: CGFloat = 1.0
    @GestureState private var gestureEachZoomScale: CGFloat = 1.0
    
    private var zoomScale: CGFloat {
        steadyStateZoomScale * gestureZoomScale
    }
    
    private func zoomGesture() -> some Gesture {
        MagnificationGesture()
            .updating($gestureZoomScale) { latestGestureScale, gestureZoomScale, transaction in
                gestureZoomScale = latestGestureScale
            }
            .onEnded { finalGestureScale in
                steadyStateZoomScale *= finalGestureScale
            }
    }
    
    private func zoomEachGesture(emojis: [EmojiArt.Emoji]) -> some Gesture {
        MagnificationGesture()
            .updating($gestureEachZoomScale) { latestGestureScale, gestureEachZoomScale, transaction in
                gestureEachZoomScale = latestGestureScale
            }
            .onEnded { finalGestureScale in
                for emoji in emojis {
                    document.scaleEmoji(emoji, by: finalGestureScale)
                }
            }
    }
    
    private func doubleTapToZoom(in size: CGSize) -> some Gesture {
        TapGesture(count: 2)
            .onEnded {
                withAnimation(.linear) {
                    zoomToFit(self.document.backgroundImage, in: size)
                }
            }
    }
    
    private func zoomToFit(_ image: UIImage?, in size: CGSize) {
        if let image = image, image.size.width > 0, image.size.height > 0 {
            let hZoom = size.width / image.size.width
            let vZoom = size.height / image.size.height
            self.steadyStatePanOffset = .zero
            self.steadyStateZoomScale = min(hZoom, vZoom)
        }
    }
    
    private func magnification(for emoji: EmojiArt.Emoji) -> CGFloat {
        var scale = emoji.fontSize * zoomScale
        if emoji.isSelected {
            scale *= gestureEachZoomScale
        }
        return scale
    }
    
    // MARK: - Pan & Drag Gesture
    
    @State private var steadyStatePanOffset: CGSize = .zero
    @GestureState private var gesturePanOffset: CGSize = .zero
    @GestureState private var gestureEachPanOffset: CGSize = .zero
    
    private var panOffset: CGSize {
        (steadyStatePanOffset + gesturePanOffset) * zoomScale
    }
    
    private func panGesture() -> some Gesture {
        DragGesture()
            .updating($gesturePanOffset) { latestDragGestureValue, gesturePanOffset, transaction in
                gesturePanOffset = latestDragGestureValue.translation / self.zoomScale
            }
            .onEnded { finalDragGestureValue in
                self.steadyStatePanOffset = self.steadyStatePanOffset + (finalDragGestureValue.translation / self.zoomScale)
            }
    }
    
    private func panEachGesture(emojis: [EmojiArt.Emoji]) -> some Gesture {
        DragGesture()
            .updating($gestureEachPanOffset) { latestDragGestureValue, gestureEachPanOffset, transaction in
                gestureEachPanOffset = latestDragGestureValue.translation / self.zoomScale
            }
            .onEnded { finalDragGestureValue in
                for emoji in emojis {
                    document.moveEmoji(emoji, by: finalDragGestureValue.translation / zoomScale)
                }
            }
    }
    
    private func position(for emoji: EmojiArt.Emoji, in size: CGSize) -> CGPoint {
        var location = emoji.location
        location = CGPoint(x: location.x * zoomScale, y: location.y * zoomScale)
        location = CGPoint(x: location.x + size.width/2, y: location.y + size.height/2)
        location = CGPoint(x: location.x + panOffset.width, y: location.y + panOffset.height)
        if emoji.isSelected {
            location = CGPoint(x: location.x + gestureEachPanOffset.width * zoomScale, y: location.y + gestureEachPanOffset.height * zoomScale)
        }
        return location
    }
    
    // MARK: - Drop

    
    private func drop(providers: [NSItemProvider], at location: CGPoint) -> Bool {
        var found = providers.loadFirstObject(ofType: URL.self) { url in
            print("dropped \(url)")
            self.document.backgroundURL = url
        }
        if !found {
            found = providers.loadObjects(ofType: String.self) { string in
                self.document.addEmoji(string, at: location, size: self.defaultEmojiSize)
            }
        }
        return found
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            EmojiArtDocumentView(document: EmojiArtDocument())
        }
    }
}
