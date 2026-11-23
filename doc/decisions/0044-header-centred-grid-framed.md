# 0044 Header numbers are centred over their pulse, and the grid is framed

Status: accepted (2026-11-23)

Context: The template draws a cycle number left-aligned in its column and a pulse number centred in its first column, so the two don't line up, and with sub-pulse steps a pulse's number sits over its first quarter, with a grey `·` in the other columns. Nothing separates the lane labels from the first column of notes: the line at a system's first column is always `none` (04, iteration 2), which also hides the heavier cycle line where a system starts on a new cycle.

Decision: Each pulse number is centred over all of its pulse's columns (`steps_per_pulse` from its entry), and each cycle number over the first pulse of its cycle, so the two line up. The grey `·` is dropped; the lines show the steps. Every pulse a system shows is whole, since positions are whole pulses. A vertical line frames the grid at its left edge, between the lane labels and the first column, in every system, drawn like the lines between groups (`0.8pt`, `luma(120)`) and running beside the groups only. The template draws it; the figure's `lines[0]` stays `none`, since a fixed frame needs no counting (ADR 0005).

Consequences: Every drawing changes slightly; the golden files don't. A system that starts on a cycle shows its start by the frame and its cycle number.
