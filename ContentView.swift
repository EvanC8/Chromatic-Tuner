//
//  ContentView.swift
//  Tuner
//
//  Created by Evan Cedeno on 3/21/25.
//

import SwiftUI
import CoreHaptics

struct ContentView: View {
    
    // Helper classes
    let inputHandler = InputHandler()
    let audioProcess = AudioProcessor()
    
    @State var sampling = true
    
    // For UI responses to input
    @State var noteName = "—"
    @State var noteCents = 101
    @State var wheelAngle = Double.zero
    
    // For tracking tune state
    @State var tuneAchieved = false
    @State var tuneSustained = false
    @State var tuneSustainedAnimation = false
    @State var silenceTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    @State var sustainTimer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()
    
    var body: some View {
        //MARK: Main page
        ZStack {
            // Background color
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 0) {
                //MARK: Header
                HStack(spacing: 4) {
                    Spacer()
                    Text("Natural")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.orange)
                    Text("♮")
                        .font(.system(size: 60, weight: .medium))
                        .foregroundStyle(.orange)
                        .offset(y: 3)
                    Spacer()
                }
                .frame(height: 50)
                Spacer()
                // MARK: Wheel
                HStack {
                    WheelPointer()
                        .fill(tuneAchieved ? Color.orange : Color.gray.opacity(0.25))
                        .scaleEffect(tuneSustainedAnimation ? 1.2 : 1)
                        .frame(width: 18, height: 15)
                }
                ZStack {
                    ChromaticWheel(noteNames: audioProcess.getNoteNames(), radius: (UIScreen.main.bounds.width*0.8)/2, wheelRotation: $wheelAngle, noteName: $noteName)
                        .rotationEffect(Angle.degrees(wheelAngle))
                    VStack(spacing: 10) {
                        Text(noteName)
                            .foregroundStyle(audioProcess.getNoteNames().contains(noteName) ? .black : .gray.opacity(0.25))
                            .font(.system(size: 75, weight: .bold))
                    }
                }
                .aspectRatio(1.0, contentMode: .fit)
                Spacer()
            }
            .padding()
            .onAppear {
                setupInputHandler()
            }
            .onReceive(silenceTimer) { _ in
                silenceTimer.upstream.connect().cancel()
                withAnimation {
                    noteName = "—"
                    tuneAchieved = false
                }
                noteCents = 101
            }
            .onReceive(sustainTimer) { _ in
                sustainTimer.upstream.connect().cancel()
                tuneSustained = true
            }
        }
    }
    
    private func setupInputHandler() {
        inputHandler.requestMicPermission { granted in
            // Check for mic user permission
            if granted {
                // Callback function
                inputHandler.onFrequencyUpdate = { frequency in
                    if sampling {
                        handleInputRecieve(frequency)
                    }
                }
                
                // Start input listener
                inputHandler.startListening()
            } else {
                print("Microphone access is required to detect frequencies.")
            }
        }
    }
    
    private func handleInputRecieve(_ frequency: Double) {
        print("Estimated Frequency: \(frequency) Hz")
        
        // Start timer to measure for silence (no frequency updates)
        silenceTimer.upstream.connect().cancel()
        silenceTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
        
        // Get filtered frequency
        let filteredFreq = audioProcess.getFilteredFrequency(frequency)
        print("Filtered Frequency: \(filteredFreq) Hz")
        
        // Get ideal note
        withAnimation {
            noteName = audioProcess.getClosestNoteName(filteredFreq)
        }
        
        // Get offset from ideal note in cents (-50 to 50)
        noteCents = audioProcess.getClosestNoteOffset(filteredFreq)
        
        // Check if tune is achieved (within 10 cents of ideal note)
        if noteCents <= 10 && noteCents >= -10 {
            // If just achieved tune, start timer to check for sustained tune
            if !tuneAchieved {
                tuneAchieved = true
                sustainTimer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()
            }
        }
        else {
            // Tune not achieved
            tuneAchieved = false
            tuneSustained = false
            sustainTimer.upstream.connect().cancel()
        }
        
        // Update wheel angle
        withAnimation(.smooth) {
            wheelAngle = audioProcess.getWheelAngle(freq: filteredFreq)
        }
    }
    
}

#Preview {
    ContentView()
}

struct ChromaticWheel: View {
    var noteNames: [String]
    var radius: CGFloat
    
    @Binding var wheelRotation: Double
    
    @Binding var noteName: String
    
    var body: some View {
        let tickCount = noteNames.count * 3
        
        ZStack {
            // Outer ring ticks
            let currentTickIndex = topTickIndex(tickCount: tickCount, rotationAngle: wheelRotation)
            ForEach(0..<tickCount, id: \.self) { i in
                let angle = Angle.degrees(Double(i) / Double(tickCount) * 360)
                let isNoteTick = i % 3 == 0
                let isCurrentTickIndex = currentTickIndex == i && noteNames.contains(noteName)
                
                RoundedRectangle(cornerRadius: 1)
                    .fill(isCurrentTickIndex ? .orange : Color.gray.opacity(isNoteTick ? 0.4 : 0.3))
                    .frame(width: 2, height: isNoteTick ? 7 : 5)
                    .scaleEffect(isCurrentTickIndex ? 1.5 : 1)
                    .offset(x: 0, y: -radius)
                    .rotationEffect(angle)
            }
            
            // Inner note names
            ForEach(Array(noteNames.enumerated()), id: \.offset) { index, text in
                let angle = Angle.degrees(Double(index) / Double(noteNames.count) * 360)
                let insetRadius = radius * 0.85
                
                let currentNote = noteName == text
                
                Text(text)
                    .font(.system(size: currentNote ? 25 : 20, weight: currentNote ? .bold : .medium, design: .monospaced))
                    .foregroundColor(.orange)
                    .offset(x: 0, y: -insetRadius)
                    .rotationEffect(angle)
            }
        }
        .frame(width: radius * 2 + 40, height: radius * 2 + 40)
    }
    
    func topTickIndex(tickCount: Int, rotationAngle: Double) -> Int {
        let tickSpacing = 360.0 / Double(tickCount)
        let rawIndex = Int(round(-rotationAngle / tickSpacing))
        let i = (rawIndex % tickCount + tickCount) % tickCount
        return i
    }
}

struct WheelPointer: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
