# Reference: Gold, *Music in Bali* (2005)

Status: reference (2026-11-21). Guidance for the notation design.

Lisa Gold, *Music in Bali: Experiencing Music, Expressing Culture*.
Global Music Series. New York: Oxford University Press, 2005.

We use this textbook as the main guide for musical facts in the design.
This note summarises, in our own words, what it says that bears on the
notation, with page numbers, and what follows for the design. The book
itself is not in the repository.

## What the book says

### Pitch names and cipher notation (pp. 34–36, 39)

- Pitch names are the five syllables nding, ndong, ndeng, ndung, ndang,
  shortened to i o e u a. This matches `templates/selisir.nts`.
- Gold writes examples in cipher notation borrowed from Java: the five
  degrees are written 1 2 3 5 6 (nding = 1, ndang = 6). A dot above or
  below a number means a higher or lower octave.
- A dot between numbers is a beat on which nothing new is struck. It
  usually means the previous note keeps sounding, not that it is
  damped (p. 36; again p. 57).
- Cipher is read starting from the gong, which is the last note of the
  cycle (p. 56).
- Balinese musicians rarely use notation, and never in performance;
  music is taught by rote (p. 36).

### Instruments and ranges (pp. 39–48)

- Gongs: the gong (often a pair, the lower wadon and the higher lanang),
  the kempur, the small klentong (also called kemong), and the kempli, a
  horizontal gong that keeps the beat. The kajar is another timekeeper,
  higher in pitch (pp. 40–41).
- The gong is never damped (p. 41). Keyed instruments are damped by
  hand after each stroke (p. 43).
- Low instruments (jegogan, jublag/calung, panyacah) have five keys,
  one octave, each pair an octave above the previous (pp. 44–45).
- Gangsa pemade and kantilan have ten keys, two octaves (p. 46).
- Ugal: the glossary says fifteen keys (p. 39) but the text says a
  two-octave range like the gangsa (p. 46). Our template has 10 keys.
- Reyong: twelve kettles, four players (p. 46).
- Figure 2.7 (p. 40) gives every range on one chart. In our octave
  numbering: jegogan i1-a1, jublag i2-a2, panyacah i3-a3, ugal o1-i3,
  pemade o2-i4, kantilan o3-i5, trompong a1-u3, reyong e2-u4. The chart
  puts the pemade only an octave above the jublag, although the text
  says it is an octave above the panyacah (pp. 45-46); we follow the
  chart. Our template's reyong (e1-u3) is an octave below the chart.

### Density and roles (pp. 55–59)

- The lower an instrument, the slower its part.
- The jublag plays the pokok (basic melody); the jegogan plays every
  2, 4 or 8 pokok tones; the panyacah fills in passing tones (p. 56).
- In the book's main example the jublag plays on every other kempli
  beat (p. 56).
- Gangsa kotekan (polos and sangsih) usually runs 4 or 8 times as fast
  as the pokok (p. 59).
- Melodic stress falls on the last note of a group, not the first,
  often marked by the gong or the jegogan (p. 57).

### Colotomic meter (pp. 42–43, 108–114)

- Gold follows Tenzer in calling the gong cycles "colotomic meters".
  There is no single Balinese term; each meter has its own name (p. 42).
- The largest gong marks the most important stress, which is both the
  end of one cycle and the start of the next (p. 42).
- Beats are counted 1 to N with the gong on N (pp. 43, 110). Meters are
  recited starting from the final gong (p. 110).
- A meter is named after the genre or melody it is most associated
  with, and the name travels with the pattern (pp. 108–109).
- Composers sometimes adjust a meter to fit an irregular melody
  (p. 109).
- Figure 5.11 (p. 110) gives these meters, with the kempli or kajar on
  every beat:

| Meter | Beats | Gongs |
|---|---|---|
| batel | 2 | klentong on 1, kempur on 2, kelenang on the offbeats (kajar keeps the pulse) |
| omang | 4 | kempur at the end, klentong halfway, kelenang (kajar) |
| bapang | 8 | kempur on 2 and 6, klentong on 4, gong on 8 |
| gabor longgor | 16 | klentong on 8, kempur on 16, kelenang |
| gegaboran | 16 | kempur on 4 and 12, klentong on 8, gong on 16 |
| gilak | 8 | gong lanang on 4, kempur on 5 and 7, gong wadon on 8 |

- Several meters are doubled-length (longgor) forms of others; gilak is
  the exception (p. 111). Bapang is played at 8, 16 (Jaya Semara's
  pangecet, pp. 57–58, 140) and 32 beats ("Jagra Parwata", p. 142:
  kempur, klentong, kempur, gong).
- The 16-beat bapang and gegaboran have the same gong strokes; they
  differ in drumming, mood and genre, so the gongs alone don't name the
  meter. notasi's template keeps them as two colotomies (ADR 0053).
- Cycles in other music reach 512 beats (p. 110).
- Gong symbols used in the book: G gong, P kempur, T klentong,
  n kelenang, and the syllable "tuk" for the kempli or kajar (p. 110).

### Form (pp. 126–137)

- Classical pieces have three sections: kawitan, pangawak (longest gong
  cycle, slow), pangecet (shorter cycle, fast) (p. 127).
- A pangecet cycle can have an irregular number of beats, or alternate
  between two gong cycles (p. 127).
- Gineman are metrically free preludes with no fixed pulse (p. 127).
- Long cycles are written in lines of 8 beats, with the jegogan at the
  end of each line; the "Sinom Ladrang" pangecet is 72 beats, 9 lines
  (pp. 133–135).
- In the pangecet of "Sinom Ladrang" the tempo rises and the pulse
  doubles (p. 133).
- Kebyar pieces string together cycles with different colotomic meters,
  with transitions between them (p. 136).

## What follows for the design

| Finding | Consequence |
|---|---|
| Gong ends the cycle, numbered 1..N | Positions count 1..N with the gong on N; a piece that opens on the gong starts with a pickup (colotomy note) |
| Meters are named and reused | Colotomies are named definitions in templates |
| Densities vary by piece and section | Pace belongs to the part, not the instrument (duration note) |
| Gilak has two gongs | The gong stroke set needs gong wadon and gong lanang |
| Batel and omang use the kajar and the kelenang offbeats | A colotomy names its timekeeper; colotomic parts need sub-pulse durations |
| Long cycles are written in 8-beat lines | Positions may need a line level: cycle, line, pulse |
| Cipher dot = nothing new, note sustained | Supports "nothing new" for open question 2 in `01-notation.md`; our `·` (rest, damped) contradicts the book's dot |
| Cipher digits are scale degrees | Our numbers are keys; the manual must warn readers transcribing from cipher |
| Gongs are never damped | A rest in a gong part cannot mean "damped" |

## Known limits of the current model

The book describes music the design does not cover yet. Record these,
don't solve them now:

- metrically free passages with no pulse (gineman)
- the pulse doubling inside a piece (pangecet of "Sinom Ladrang")
- a piece changing colotomic meter between sections
- irregular cycles and meters adjusted to a melody
