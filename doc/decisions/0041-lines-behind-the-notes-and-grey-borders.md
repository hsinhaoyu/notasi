# 0041 The lines behind the notes are chosen by the score; notes have grey borders

Status: accepted (2026-11-23)

Context: ADR 0020 made the background white with only the pulse lines, and gave notes a thin white border so neighbouring notes of the same colour stay apart. Rows of a group have no lines between them, so a note's key is read only from its lane label, and there is no way to change what is drawn. A white border also disappears against the white background, so a note's edge on an empty neighbour is not drawn at all, and strokes (light grey) read faintly.

Decision: The option `:background grid/vertical/horizontal/empty`, on a score or a group, chooses the lines behind the notes: pulse lines and a thin line between every two rows (`grid`, the default), pulse lines only (`vertical`, the look of ADR 0020), row lines only (`horizontal`), or neither (`empty`). Lines between groups and the heavier cycle lines (ADR 0037) are always drawn. Row lines are drawn between the rows of every kind of group. Notes have a thin grey border, the same on every edge, instead of a white one; stroke cells are a lighter grey that stays grey and matches no palette colour. A note with `:fill none` has no rectangle and no border. A cut note's continuation is still shown only by having no text.

Consequences: Every drawing gains row lines and grey borders, so every figure changes; the greys and widths are judged by eye. A score can go back to ADR 0020's look with `:background vertical`, except for the borders, which have no option.

Supersedes: 0020 (the background and the note border; notes still fill their cells exactly)
