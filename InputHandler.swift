//
//  InputHandler.swift
//  Tuner
//
//  Created by Evan Cedeno on 3/21/25.
//

import Foundation
import AVFoundation
import Accelerate

// Handles microphone input capturing and processing
// Utilizes Fast Fourier Transform
class InputHandler {
    
    // Core handler for mic input
    private var audioEngine = AVAudioEngine()
    
    // Variables for FFT efficiency and resolution
    private let fftSize = 16384
    private let paddedSize = 32768
    
    // FFT audio sampling rate
    private var sampleRate: Double = 44100.0
    
    // Callback method
    var onFrequencyUpdate: ((Double) -> Void)?
    
    // Threshold to ignore noise and silence
    private let magnitudeThreshold: Float = 0.005
    private let rmsThreshold: Float = 0.01
    
    // Track last returned frequency
    private var lastValidFrequency: Double?

    // Frequency range to process (Hz)
    private let minFrequency: Double = 30.0
    private let maxFrequency: Double = 1500.0
    
    // Request mic access from user
    func requestMicPermission(completion: @escaping (Bool) -> Void) {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    // Start mic input monitering
    func startListening() {
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        sampleRate = format.sampleRate
        let bufferSize = AVAudioFrameCount(fftSize)

        // Create tap to capture audio
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: format) { buffer, time in
            // Send audio for processing
            self.processAudio(buffer: buffer)
        }

        do {
            try audioEngine.start()
            print("Listening for frequencies...")
        } catch {
            print("Error starting audio engine: \(error.localizedDescription)")
        }
    }
    
    // Process mic input sample -> Return estimated frequency
    private func processAudio(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }

        // 1. Root Mean Square check - Skip quiet audio
        var rms: Float = 0
        vDSP_rmsqv(channelData, 1, &rms, vDSP_Length(fftSize))
        if rms < rmsThreshold {
            return
        }

        // 2. Apply Hann window - Reduce spectral leakage
        var window = [Float](repeating: 0.0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        
        // 3. Apply FFT - Convert audio signal to frequency spectrum
        var realParts = [Float](repeating: 0.0, count: paddedSize)
        var imagParts = [Float](repeating: 0.0, count: paddedSize)
        vDSP_vmul(channelData, 1, window, 1, &realParts, 1, vDSP_Length(fftSize))

        var splitComplex = DSPSplitComplex(realp: &realParts, imagp: &imagParts)
        let log2n = vDSP_Length(log2(Float(paddedSize)))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return }

        vDSP_fft_zip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

        var magnitudes = [Float](repeating: 0.0, count: paddedSize / 2)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(paddedSize / 2))

        vDSP_destroy_fftsetup(fftSetup)

        // 4. Find peak frequency bin
        var maxIndex: vDSP_Length = 0
        var maxValue: Float = 0
        vDSP_maxvi(&magnitudes, 1, &maxValue, &maxIndex, vDSP_Length(magnitudes.count))

        if maxValue < magnitudeThreshold {
            return
        }

        // 5. Parabolic interpolation around peak - Estimate actual input frequency
        let peakIndex = Int(maxIndex)
        guard peakIndex > 0 && peakIndex < magnitudes.count - 1 else { return }

        let magPrev = magnitudes[peakIndex - 1]
        let magPeak = magnitudes[peakIndex]
        let magNext = magnitudes[peakIndex + 1]

        let numerator = magPrev - magNext
        let denominator = magPrev - 2 * magPeak + magNext
        let delta = denominator == 0 ? 0 : 0.5 * (numerator / denominator)

        let interpolatedIndex = Double(peakIndex) + Double(delta)

        // 5. Convert to frequency
        let frequency = interpolatedIndex * (sampleRate / Double(paddedSize))
        let roundedFrequency = round(frequency * 100) / 100

        // 6. Ensure frequency is in set range
        if roundedFrequency < minFrequency || roundedFrequency > maxFrequency {
            return
        }
        
        // 7. Return frequency (Rounded to 2 decimals)
        lastValidFrequency = roundedFrequency

        DispatchQueue.main.async {
            self.onFrequencyUpdate?(roundedFrequency)
        }
    }
    
    // Stop mic input monitering
    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        print("Stopped listening.")
    }
}
