import math
import struct
import random
import wave
import os

SAMPLE_RATE = 22050
DURATION = 10  # seconds
NUM_SAMPLES = SAMPLE_RATE * DURATION
OUTPUT_DIR = "assets/audio"

def write_wav(filename, samples):
    filepath = os.path.join(OUTPUT_DIR, filename)
    print(f"Generating: {filepath}...")
    with wave.open(filepath, 'wb') as wav_file:
        wav_file.setnchannels(1)  # mono
        wav_file.setsampwidth(2)  # 16-bit (2 bytes)
        wav_file.setframerate(SAMPLE_RATE)
        
        # Pack to 16-bit little-endian integers
        for sample in samples:
            val = int(max(-32768, min(32767, sample * 32767)))
            wav_file.writeframesraw(struct.pack('<h', val))
    print(f"Successfully generated {filename}!")

# 1. White Noise Generator (Cozy Breeze)
def generate_white_noise():
    # Simple lowpass filter to make it sound like a soft breeze
    samples = []
    b0 = 0.0
    for _ in range(NUM_SAMPLES):
        white = random.uniform(-0.15, 0.15)
        # Soft low-pass filtering
        b0 = 0.85 * b0 + 0.15 * white
        samples.append(b0)
    return samples

# 2. Rain Generator (Gentle Rain)
def generate_rain():
    samples = []
    b0 = 0.0
    random.seed(12345)
    for _ in range(NUM_SAMPLES):
        white = random.uniform(-0.12, 0.12)
        # Brownish filter for background rain hum
        b0 = 0.94 * b0 + 0.06 * white
        
        # Add crackling raindrops with decay
        crackle = 0.0
        if random.random() < 0.003:  # Randomly spawn a raindrop
            crackle = random.uniform(0.08, 0.22)
            
        samples.append(b0 * 0.75 + crackle)
    
    # Smooth moving average to reduce high-frequency harshness
    smoothed = []
    for i in range(len(samples)):
        val = samples[i]
        if i > 0:
            val = 0.65 * val + 0.35 * samples[i-1]
        smoothed.append(val)
    return smoothed

# 3. Ocean Waves Generator
def generate_ocean():
    samples = []
    b0 = 0.0
    random.seed(54321)
    for i in range(NUM_SAMPLES):
        white = random.uniform(-0.18, 0.18)
        # Deep brown noise filter
        b0 = 0.982 * b0 + 0.018 * white
        
        # Slow swell amplitude modulation: 5 second rolling waves
        t = i / SAMPLE_RATE
        swell = 0.52 + 0.48 * math.sin(2 * math.pi * t / 5.0)
        samples.append(b0 * swell)
    return samples

# 4. Lullaby / Music Box Generator
PENTATONIC = [261.63, 293.66, 329.63, 392.00, 440.00, 523.25, 587.33, 659.25, 783.99, 880.00, 1046.50]
CHORDS = [
    [261.63, 329.63, 392.00, 523.25],  # C Major (C4, E4, G4, C5)
    [349.23, 440.00, 523.25, 698.46],  # F Major (F4, A4, C5, F5)
    [220.00, 329.63, 440.00, 523.25],  # A Minor (A3, E4, A4, C5)
    [293.66, 392.00, 440.00, 587.33]   # G Major / Dsus (D4, G4, A4, D5)
]

def generate_lullaby():
    samples = [0.0] * NUM_SAMPLES
    
    # 4 chords, each 2.5 seconds (total 10 seconds)
    chord_duration = 2.5
    samples_per_chord = int(chord_duration * SAMPLE_RATE)
    
    for c_idx in range(4):
        start_sample = c_idx * samples_per_chord
        chord = CHORDS[c_idx]
        
        # Soft sine backing pad
        for i in range(samples_per_chord):
            idx = start_sample + i
            if idx >= NUM_SAMPLES:
                break
            t = i / SAMPLE_RATE
            env = math.sin(math.pi * (i / samples_per_chord))  # half sine window
            
            val = 0.0
            for freq in chord:
                val += 0.04 * math.sin(2 * math.pi * freq * t)
            samples[idx] += val * env

    # Twinkling high bell arpeggios
    note_interval = 0.5
    samples_per_note = int(note_interval * SAMPLE_RATE)
    random.seed(999)
    
    for step in range(int(DURATION / note_interval)):
        note_start = step * samples_per_note
        freq = random.choice(PENTATONIC[5:])  # Twinkly octaves 5-6
        
        note_dur = 0.4
        note_samples = int(note_dur * SAMPLE_RATE)
        
        for i in range(note_samples):
            idx = note_start + i
            if idx >= NUM_SAMPLES:
                break
            t = i / SAMPLE_RATE
            env = math.exp(-7.0 * t)  # Rapid pluck decay
            
            # Bright sine wave with higher harmonics
            val = 0.05 * math.sin(2 * math.pi * freq * t) + 0.018 * math.sin(2 * math.pi * 2 * freq * t)
            samples[idx] += val * env
            
    # Normalize to prevent any clipping
    max_val = max(abs(s) for s in samples)
    if max_val > 1.0:
        samples = [s / max_val * 0.85 for s in samples]
    else:
        samples = [s * 0.85 for s in samples]
        
    return samples

def main():
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)
        
    write_wav("white_noise.wav", generate_white_noise())
    write_wav("rain.wav", generate_rain())
    write_wav("ocean.wav", generate_ocean())
    write_wav("lullaby.wav", generate_lullaby())
    print("All bedtime audio files generated successfully!")

if __name__ == "__main__":
    main()
