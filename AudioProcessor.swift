//
//  AudioProcessor.swift
//  Tuner
//
//  Created by Evan Cedeno on 5/9/25.
//

import Foundation

// Handles interpretation of detected mic frequencies for musical and UI contexts
class AudioProcessor {
    // Chromatic Notes
    private let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    
    // Track current and past filtered frequencies
    private var currentFreq = -1.0
    private var previousFreqs = [Double]()
    
    //MARK: Public get methods
    
    // Return list of note names
    public func getNoteNames() -> [String] {
        return noteNames
    }
    
    // Get chromatic note closest to current frequency
    public func getClosestNoteName(_ freq: Double) -> String {
        return noteNames[closestNoteNumber(freq) % 12]
    }
    
    // Get current frequency's offset from closest chromatic note (in cents)
    public func getClosestNoteOffset(_ freq: Double) -> Int {
        let closestNoteNumber = closestNoteNumber(freq)
        let idealFrequency = noteFrequency(closestNoteNumber)
        
        return offsetCents(observedFreq: freq, idealFreq: idealFrequency)
    }
    
    // Get new current filtered frequency - Median frequency over past 3 samples
    public func getFilteredFrequency(_ freq: Double) -> Double {
        if previousFreqs.isEmpty {
            previousFreqs.append(contentsOf: [freq, freq, freq])
        }
        
        previousFreqs.remove(at: 0)
        previousFreqs.append(freq)
        
        currentFreq = previousFreqs.sorted()[1]
        return currentFreq
    }
    
    // Get wheel rotation for current frequency
    func getWheelAngle(freq: Double) -> Double {
        let note = getClosestNoteName(freq) // "A", "A#", etc.
        
        guard let noteIndex = noteNames.firstIndex(of: note) else { return 0 }
        
        let cents = getClosestNoteOffset(freq)
        let totalCents = noteIndex * 100 + cents
        let angle = -1.0 * Double(totalCents) * 0.3
        
        return angle // In degrees
    }
    
    //MARK: Private helper methods
    
    // Calculate chromatic note closest to current frequency
    private func closestNoteNumber(_ freq: Double) -> Int {
        return Int(round(69 + 12 * log2(freq / 440)))
    }
    
    // Calculate frequency of chromatic note
    private func noteFrequency(_ noteNumber: Int) -> Double {
        return 440 * pow(2.0, Double(noteNumber - 69) / 12.0)
    }
    
    // Calculate octave of chromatic note
    private func noteOctave(_ noteNumber: Int) -> Int {
        return (noteNumber / 12) - 1
    }
    
    // Calculate offset between two frequencies (in cents)
    private func offsetCents(observedFreq: Double, idealFreq: Double) -> Int {
        return Int(1200 * log2(observedFreq / idealFreq))
    }

}
