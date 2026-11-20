"""Original Quiet Conservatory music and ecological effects; no external assets.

Uses only the Python standard library. Compositions are circular so note tails
cross the loop point, and synthesis is deliberately soft rather than arcade-loud.
"""
from pathlib import Path
from array import array
import math
import random
import wave
import zlib

RATE = 22050
DURATION = 64.0
OUT = Path(__file__).resolve().parents[1] / 'assets' / 'audio'
TAU = math.tau
TABLE_SIZE = 16384
SIN = [math.sin(TAU * i / TABLE_SIZE) for i in range(TABLE_SIZE)]

def sine(phase):
    return SIN[int(phase) & (TABLE_SIZE - 1)]

def midi(note):
    return 440.0 * 2 ** ((note - 69) / 12)

class Canvas:
    def __init__(self, seconds):
        self.frames = int(round(seconds * RATE))
        self.left = array('f', [0.0]) * self.frames
        self.right = array('f', [0.0]) * self.frames

    def tone(self, start, duration, note, amplitude=.1, pan=0.0, kind='pluck', seed=1):
        count = int(duration * RATE)
        start_frame = int(start * RATE)
        frequency = midi(note)
        increment = frequency * TABLE_SIZE / RATE
        phase = 0.0
        phase_b = 0.0
        phase_c = 0.0
        rng = random.Random(seed)
        noise = 0.0
        left_gain = math.sqrt((1 - pan) * .5)
        right_gain = math.sqrt((1 + pan) * .5)
        for j in range(count):
            t = j / RATE
            remain = max(0.0, 1 - t / duration)
            if kind == 'pad':
                attack = min(1.0, t / .85)
                release = min(1.0, (duration - t) / 1.2)
                envelope = attack * attack * (3 - 2 * attack) * release * release * (3 - 2 * release)
                sample = (sine(phase) + .37 * sine(phase_b) + .13 * sine(phase * 2)) * .66
                phase_b += increment * 1.0023
            elif kind == 'flute':
                attack = min(1.0, t / .10)
                release = min(1.0, (duration - t) / .28)
                envelope = attack * release * (.82 + .18 * remain)
                noise += ((rng.random() * 2 - 1) - noise) * .045
                sample = .72 * sine(phase) + .14 * sine(phase * 2) + .055 * sine(phase * 3) + noise * .11
                increment = frequency * TABLE_SIZE / RATE * (1 + .0017 * math.sin(t * TAU * 4.8))
            elif kind == 'bell':
                envelope = min(1.0, t / .008) * math.exp(-3.4 * t / max(.3, duration)) * min(1, (duration - t) / .04)
                sample = .75 * sine(phase) + .17 * sine(phase_b) + .06 * sine(phase_c)
                phase_b += increment * 2.003
                phase_c += increment * 4.07
            else:
                envelope = min(1.0, t / .006) * math.exp(-5.3 * t / max(.25, duration)) * min(1, (duration - t) / .035)
                sample = .76 * sine(phase) + .16 * sine(phase_b) + .06 * sine(phase_c)
                phase_b += increment * 2.0
                phase_c += increment * 4.08
            value = sample * envelope * amplitude
            at = (start_frame + j) % self.frames
            self.left[at] += value * left_gain
            self.right[at] += value * right_gain
            phase += increment

    def brush(self, start, duration, amplitude=.1, pan=0.0, seed=1, cutoff=.15, low_note=None):
        rng = random.Random(seed)
        noise = 0.0
        left_gain = math.sqrt((1 - pan) * .5)
        right_gain = math.sqrt((1 + pan) * .5)
        start_frame = int(start * RATE)
        for j in range(int(duration * RATE)):
            t = j / RATE
            envelope = min(1, t / .006) * max(0, 1 - t / duration) ** 2
            noise += ((rng.random() * 2 - 1) - noise) * cutoff
            value = noise * amplitude * envelope
            if low_note is not None:
                value += math.sin(TAU * (low_note * t - low_note * .24 * t * t / duration)) * amplitude * .30 * envelope
            at = (start_frame + j) % self.frames
            self.left[at] += value * left_gain
            self.right[at] += value * right_gain

    def write(self, filename, peak=.32):
        highest = max(max(abs(v) for v in self.left), max(abs(v) for v in self.right), .00001)
        gain = min(2.0, peak / highest)
        pcm = array('h')
        square = 0.0
        for l, r in zip(self.left, self.right):
            l = max(-.98, min(.98, l * gain))
            r = max(-.98, min(.98, r * gain))
            square += (l * l + r * r) * .5
            pcm.extend((round(l * 32767), round(r * 32767)))
        with wave.open(str(OUT / filename), 'wb') as target:
            target.setnchannels(2)
            target.setsampwidth(2)
            target.setframerate(RATE)
            target.writeframes(pcm.tobytes())
        rms = math.sqrt(square / self.frames)
        print(f'{filename}: {self.frames / RATE:.2f}s stereo, peak={highest * gain:.3f}, rms={rms:.3f}', flush=True)

CHORDS = [
    [50, 57, 62, 65], [46, 53, 58, 62], [41, 53, 57, 60], [48, 55, 60, 64],
    [43, 50, 58, 62], [46, 53, 58, 65], [48, 55, 62, 64], [50, 57, 62, 65],
]
GARDEN_MELODY = [[74,77,76,81], [77,74,72,70], [72,77,81,79], [76,74,72,67], [70,74,77,79], [77,74,70,72], [76,79,74,72], [74,77,76,74]]
WILD_MELODY = [[62,65,69,72], [70,65,62,65], [69,72,77,76], [72,67,64,62], [67,70,74,72], [70,74,77,74], [76,74,72,67], [65,69,74,62]]

def music(context):
    canvas = Canvas(DURATION)
    for chord_index, chord in enumerate(CHORDS):
        start = chord_index * 8
        for voice, note in enumerate(chord):
            canvas.tone(start, 9.4, note, .075 if context != 'battle' else .060, [-.50,.38,-.15,.55][voice], 'pad', 100+voice)
        if context == 'garden':
            for i, note in enumerate(GARDEN_MELODY[chord_index]):
                canvas.tone(start + .75 + i * 1.75, 2.0, note, .115 if i != 3 else .075, [-.35,.28,-.12,.35][i], 'pluck', chord_index*17+i)
            canvas.tone(start + 5.25, 2.6, chord[2] + 24, .028, .65 if chord_index % 2 else -.65, 'bell')
        elif context == 'wild':
            for i, note in enumerate(WILD_MELODY[chord_index]):
                canvas.tone(start + .45 + i * 1.8, 1.65, note+12, .085, .16 if i % 2 else -.18, 'flute', chord_index*23+i)
                if i % 2 == 0: canvas.tone(start + 1 + i * 1.8, 1.3, chord[(i+1)%4]+12, .044, -.38, 'pluck')
        else:
            for beat in range(16):
                offset = beat * .5
                note = chord[0] if beat % 4 < 2 else chord[1]-12
                canvas.tone(start+offset, .5, note, .065, -.12 if beat % 2 else .12, 'pluck')
                if beat % 2 == 0: canvas.brush(start+offset, .18, .027, -.22 if beat % 4 else .22, chord_index*61+beat, .065, 82)
                elif beat % 4 == 3: canvas.brush(start+offset+.125, .09, .020, .35 if beat % 3 else -.35, chord_index*79+beat, .25)
            for i, note in enumerate(WILD_MELODY[chord_index][1:]):
                canvas.tone(start+1.5+i*2, 1.9, note+12, .053, [-.30,.25,.0][i], 'flute', 21+i)
    canvas.write(f'music_{context}.wav', .24)

def ambience():
    canvas = Canvas(DURATION)
    rng = random.Random(20517)
    a, b = 0.0, 0.0
    for j in range(canvas.frames):
        t = j / RATE
        a += ((rng.random()*2-1)-a)*.008
        b += ((rng.random()*2-1)-b)*.012
        fade = min(1, t/.5, (DURATION-t)/.5)
        air = (.15+.045*math.sin(TAU*t/19)) * fade
        canvas.left[j] = a*air
        canvas.right[j] = b*air*.9
    for i in range(24):
        when = 1.2 + i * 2.6
        canvas.tone(when, .42, [89,93,96,88,91][i%5], .012, math.sin(i*2.3)*.8, 'bell', i)
        canvas.brush(when+.4,.3,.025,math.sin(i*1.7)*.8,200+i,.04)
    canvas.write('ambience_forest.wav', .10)

def effect(name, seconds, notes=(), noise=() , peak=.30):
    canvas = Canvas(seconds)
    for start, duration, note, amp, pan, kind in notes: canvas.tone(start,duration,note,amp,pan,kind,zlib.crc32(name.encode()) & 65535)
    for args in noise: canvas.brush(*args)
    canvas.write(f'fx_{name}.wav', peak)

def effects():
    effect('ui', .14, [(0,.11,79,.13,-.08,'pluck'),(.025,.11,86,.035,.08,'bell')], [(0,.035,.035,0,31,.12)], .17)
    effect('back', .25, [(0,.18,74,.1,-.2,'pluck'),(.055,.18,69,.06,.2,'pluck')], peak=.20)
    effect('step', .15, noise=[(0,.11,.18,-.12,481,.045,92)], peak=.16)
    effect('grass', .21, noise=[(0,.17,.16,.1,982,.16,75)], peak=.16)
    effect('encounter', .95, [(0,.55,74,.14,-.35,'bell'),(.12,.55,81,.12,.2,'bell'),(.25,.6,77,.12,.0,'flute')], [(0,.5,.06,.0,94,.03)], .31)
    effect('observe', .58, [(0,.35,77,.1,-.25,'bell'),(.14,.4,81,.09,.25,'bell')], peak=.24)
    effect('collect_success', 1.35, [(i*.13,.7,n,.13,(-.3+i*.2),'bell') for i,n in enumerate([74,77,81,86])], [(0,.5,.06,.0,13,.06)], .35)
    effect('collect_fail', .67, [(0,.35,77,.1,-.2,'pluck'),(.13,.35,76,.09,.2,'pluck'),(.25,.4,74,.065,0,'flute')], peak=.26)
    effect('seed', .68, [(0,.4,62,.11,-.15,'pluck'),(.13,.48,74,.08,.15,'bell')], [(0,.18,.07,0,61,.045)], .26)
    effect('breed', 1.35, [(i*.12,.65,n,.1,(-.45+i*.15),'bell') for i,n in enumerate([62,69,65,74,77,81])], [(0,.7,.05,.0,555,.02)], .32)
    effect('graft', .58, [(0,.3,62,.13,-.2,'pluck'),(.18,.35,69,.1,.2,'pluck')], [(0,.06,.06,0,29,.08)], .25)
    effect('mutate', 1.1, [(0,.75,69,.09,-.4,'flute'),(.10,.75,70,.025,.4,'flute'),(.35,.65,77,.09,0,'bell')], [(0,.8,.06,0,77,.035)], .28)
    effect('bloom', 1.8, [(i*.055,1.45,n,.10,(-.5+i*.2),'bell') for i,n in enumerate([62,69,74,77,81,86])], [(0,1.4,.06,0,325,.02)], .38)
    effect('battle_start', 1.05, [(0,.55,50,.11,-.2,'pluck'),(.2,.55,57,.1,.2,'pluck'),(.42,.55,62,.1,0,'flute')], [(0,.18,.08,0,920,.055,90)], .30)
    effect('battle_win', 2.0, [(i*.16,1.0,n,.12,(-.4+i*.16),'bell') for i,n in enumerate([62,65,69,74,77,86])], peak=.38)
    effect('battle_lose', 1.6, [(i*.20,.85,n,.085,(-.25+i*.2),'flute') for i,n in enumerate([69,65,62,50])], peak=.27)

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    for context in ['garden','wild','battle']: music(context)
    ambience()
    effects()
    (OUT/'README.md').write_text('''# Original game audio\n\nAll music, ambience and effects were composed and synthesized specifically for The Quiet Conservatory by `tools/generate_audio.py`. No recordings, third-party music or external samples are used.\n\nMusic and forest ambience are 64-second, 22050 Hz, stereo 16-bit PCM WAV loops. Musical note tails wrap around each loop point. Soundscape applies quiet mix levels and crossfades. Effects are short, pooled and rate limited.\n\nRun `python3 tools/generate_audio.py` to regenerate the assets with Python\'s standard library.\n''')

if __name__ == '__main__': main()
