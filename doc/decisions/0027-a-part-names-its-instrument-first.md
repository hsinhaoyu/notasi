# 0027 A part names its instrument first

Status: superseded by 0038

Context: v1 parts are `(part NAME INSTRUMENT TOKEN ...)`. Most parts are the only part on their instrument, so the name repeats the instrument (`(part ugal ugal ...)`). Guessing whether the first symbol is a name or a note would turn a typo in the first note into a name.

Decision: A part is `(part INSTRUMENT :name NAME TOKEN ...)`. Without `:name`, the part is named after its instrument. Two parts on one instrument without names are an error. Part names are unique in the piece, generated parts (ADR 0030) included.

Consequences: Single parts are shorter to write, and the instrument is never ambiguous. Scores refer to parts by name. Every v1 part is rewritten.
