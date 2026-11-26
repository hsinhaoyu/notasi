# 0056 Notes are coloured by pitch (`by-pitch`); parts in one group are told apart by marks, when asked

Status: accepted (2026-11-26)

Context: ADR 0017 colours each pitched note by its scale degree, with the scheme `by-degree`, and says parts in one group are not told apart. The glossary (ADR 0051) calls a member of a scale a pitch, not a degree. A group can hold several parts on one instrument (ADR 0011), as the kotekan does: on `notes` and compact rows the parts merge into one composite line, and the interlocking, the point of drawing them together, can't be seen. A colour per part would lose the pitch colour; a colour family per part, with a shade per pitch, has shades too alike to read.

Decision: Colour is decided by a colour scheme in layout, from an instrument and a note to the note's fill, text and text colour, as ADR 0017 says. The scheme is renamed `by-pitch`: it colours each pitched note by its pitch, the same in every octave and on every instrument. `by-degree` becomes an unknown value, with no migration. Parts are not told apart by colour. When a group asks, with `:part-marker` (a group option, not a score's), a part's notes get a small symbol (`dot`, `ring`, `cross`) centred in the cell, a border of a colour the writer gives, or both, each with its size and colour; a part with no entry is drawn as now. A note label and a symbol in one note are both drawn. A unison drawn once is drawn with the first part's marks only.

Consequences: Nothing changes for existing scores until a group asks for marks. The JSON gets each voice's symbol and border (contract version 4, 05), and the template draws them. In norot, each figure's opening unison looks like polos alone; the manual says so. The default symbol size and border width are chosen by eye when built.

Supersedes: 0017
