# Natural♮ | Mobile Chromatic Tuner
Inspired by the guitar tuning apps I use daily, this project was created to experiment with audio signal processing through the lens of musical pitch tuning. What began as a simple idea—detecting pitch from a phone’s microphone input—quickly turned into a deep dive into the quite exciting complexities of frequency analysis. The result is a versatile and simplistic chromatic tuner, designed to recognize pitches across a wide range of instruments tuned on the Western enharmonic system. I've included the app's views and helper classes (written in Swift for iOS) in this repo. An overview of the app's core processes can also be found below. Hope you enjoy!

> **Note:** If downloading the app files, make sure to add the appropriate key to `Info.plist` to request the user's permission to access the microphone.


<img src="https://github.com/EvanC8/chromatic-Tuner/blob/main/Demos/demo2.PNG?raw=true" width="200"> <img src="https://github.com/EvanC8/chromatic-Tuner/blob/main/Demos/demo1.PNG?raw=true" width="200"> <img src="https://github.com/EvanC8/chromatic-Tuner/blob/main/Demos/demo3.PNG?raw=true" width="200">
<br>

<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li>
      <a href="#how-it-works">How it works</a>
      <ul>
        <li><a href="#User-Interface">User Interface</a></li>
        <li><a href="#Microphone-Input-Processing">Microphone Input Processing</a></li>
        <li><a href="#Musical-Application">Musical Application</a></li>
      </ul>
    </li>
    <li><a href="#next-steps">Next Steps</a></li>
    <li><a href="#license">License</a></li>
    <li><a href="#contact">Contact</a></li>
  </ol>
</details>

# How it works

### User Interface
The minimalist UI features a rotating wheel that represents the 12 semitones of the Western musical system. This circular design is intuitive, as the semitones naturally wrap around with each octave. A pointer above the wheel indicates the pitch detected from the microphone in real time. The goal during tuning is to align the played note as closely as possible with the target note, which appears at the center of the wheel. This target is automatically selected based on the nearest semitone to the detected pitch. Additionally, the app makes use of two timers under the hood. One timer is used to trigger a UI response if no pitch is sent to the UI within a set timespan. If no pitch is sent, it means that the input handler rendered the audio input as background noise or too quiet, meaning that the app can pause and wait for the next pitch callback. The other timer is used when the user achieves a pitch within a reasonably tuned range. When this happens, the UI starts a timer to ensure that the tune is being sustained for a short period, confirming that the user actually reached tune and the achieved tune wasn't just the result of one audio sample. The user interface is showcased in `ContentView.swift`.

### Microphone Input Processing
Microphone input is formatted as a time-dependent waveform signal not directly related to frequency, meaning that no pitch can be directly read from a single audio sample. Thus, mic samples must be processed. However, before performing any extensive computations, the original signal is inspected to determine whether further processing is even necessary. The `Root Mean Square`, a method for calculating a signal's average loudness, is used to determine if the signal passes a set threshold. This allows the app to skip over any quiet and likely background noise signals picked up by the mic, preventing unintentional and inaccurate frequencies, as well as avoiding unnecessary computations. If the signal makes it past this check, a technique known as a `Hann Window` is applied to smooth out any rough edges before further processing.

A `Fast Fourier Transform` (FFT) is an algorithm for efficiently splitting a raw audio sample into a frequency domaain spectrum, representing the signal as varying magnitudes of frequency bins across a wide range. From here, the bin with the largest magnitude (the most dominant approximate frequency) is identified. However, since the frequency bins are discrete and therefore do not represent the exact frequency, `Parabolic Interpolation` is applied to the peak bin and its neighboring bins to more accurately estimate the true frequency. This approach is also beneficial because frequency bins with lower magnitudes than the peak are ignored. Thus, background noise can be mixed into the signal as long as the dominant frequency remains the pitch being tested.

Once a frequency is estimated, it is checked to ensure it falls within a reasonable instrumental range. This filter ensures that the estimated frequency is plausible and not a result of miscalculation or further inaccuracies. However, even after all of the signal processing that has occurred thus far, some samples may contain background noise that overpowers the user's intended pitch. This can cause the UI's wheel to jitter, leading to an unpleasant experience. To mitigate this, the previous three estimated frequencies are recorded and saved. When a new frequency is determined, the median of the last three is returned. Although this introduces slight latency in updating the displayed pitch, it prevents large and sudden frequency spikes from disturbing the app's functionality.

The estimated frequency is now ready for interpretation in the musical context of pitch tuning. The app records approximately three estimated frequencies per second. All signal processing described here is implemented in `InputHandler.swift`.

### Musical Application
12 semitones - ```C, C#, D, D#, E, F, F#, G, G#, A, A#, B```

Using the formula below, a given frequency can be mapped to a pitch within the range of the 12 semitones. Using a reference note (A4 – 440Hz – assigned to the note number 69), a relative note number is assigned to the frequency. By rounding the result, we get the note number corresponding to the closest pitch among the 12 semitones. Then, taking the remainder of dividing the target note number by the 12 semitone count yields the index of the closest semitone.

$$ \text{Target Note Number} = round[69 + 12 * log_{2}(\frac{\text{frequency}}{440})] $$

$$ \text{Target Note Index} = \text{Target Note Number}\mod{12} $$

Taking the inverse of the last formula, the frequency corresponding to a target note can be solved for, given its note number:

$$ \text{Ideal Frequency} = 440 * 2^{\frac{\text{Note Number} - 69}{12}} $$

Now, for any given input frequency, its target note can be identified along with its corresponding ideal frequency. The last thing needed is to calculate the distance—or error—between the input frequency and the ideal frequency. A standardized way to express this distance in music is using the unit of cents, which can be calculated as follows. As the name implies, there are 100 cents separating every semitone:

$$ \text{Cents} = round[1200 * log_{2}(\frac{\text{freqency}}{\text{ideal frequency}})] $$

Now, the input frequency can be mapped to an angle along the semitone wheel, and the calculated cents can be used to determine whether the frequency is reasonably in tune with the calculated target note.


# Next Steps
* Improve signal processing methods to denoise mic input and measure frequency more accurately

# License
Destributed under the MIT License. See `LICENSE.txt` for more information.

# Contact
Evan Cedeno - escedeno8@gmail.com

Project Link: [Chromatic-Tuner](https://github.com/EvanC8/Chromatic-Tuner)

