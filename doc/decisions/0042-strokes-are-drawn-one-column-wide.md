# 0042 Strokes are drawn one column wide

Status: accepted (2026-11-23)

Context: A stroke on an unpitched instrument is drawn as wide as its written duration, like a pitched note. In a score whose step is a quarter pulse (Jaya Semara's kotekan), the gong's `P:1` and every kempli `K` are four columns wide, and the kempli row is one unbroken grey bar. For gongs, kempli and drums the written duration mostly places the next stroke; what the reader needs is where each stroke falls, and gongs are never damped anyway.

Decision: In the drawing, every stroke on an instrument with a stroke set (gong, kempli, kendang) is one column wide, the score's step, starting where it starts. Only the drawing changes: the music keeps its durations, so `-:3 P:1` still puts the kempur on pulse 4 and a player still has them. Pitched notes stay as wide as they sound. The name a stroke shows is still chosen by its written duration (`du` or `du'`), and `:holds dash` writes no dashes after a stroke: only pitched notes are held. One column was chosen over "the shortest note in the piece or score" because it is always the smallest cell, so a stroke reads as a point, and it is easy to predict.

Consequences: Every figure with gongs, kempli or kendang changes, and so do their golden files. There is no option to draw strokes at their durations; it is in the backlog until someone needs it.
