# 0020 A plain white grid; notes fill their cells

Status: superseded by 0041

Context: The template (05) followed the prototype: alternate pulses shaded grey, and each note drawn as a block inset 1.5pt from its cells, with a cut note's block flush to the left (ADR 0019) as the only sign that it continues. Reviewing the drawings, the shading and margins made the score look busy. Removing the margins alone made neighbouring notes of the same colour merge: two strokes of the same pot, or a kempli on every step, looked like one held note.

Decision: The background is always white; only the pulse lines remain. Notes fill their cells exactly, with no margin, and have a thin white border (0.5pt) so that each note stays a separate block and a held note stays one block. A cut note's continuation is shown only by having no text, not by its edge.

Consequences: Figures are cleaner, and a step is a coloured square edge to edge. Pulses are told apart by the pulse lines and header alone. A held note and a run of repeated notes still look different, thanks to the white borders. This replaces ADR 0019's "a note cut across systems starts flush with the system's left edge"; the rest of 0019 stands. The prototype's look differs further from what notasi draws.

Supersedes: 0019 (only how a cut note is shown)
