# 0070 The README and the manual are for users, not only musicians

Status: accepted (2026-11-28)

Context: ADR 0014 wrote the user manual "for musicians", and ADR 0062 defined the README's readers as "musicians who write and draw gamelan scores with notasi". notasi's readers are wider than that: teachers and researchers who write about gamelan, students, and anyone else who wants its scores, whether or not they play. What sets them apart from `CONTRIBUTING.md`'s readers is that they don't work on notasi's code.

Decision: The README and the user manual are for users: anyone who writes and draws gamelan scores with notasi without working on its code. They aren't described as being for musicians. Developers read `CONTRIBUTING.md` and the design documents. `doc/manual/STYLE.md`'s reader is such a user, who knows gamelan's words but may never have programmed. Error messages and the manual still speak in musical terms (03), since that is the vocabulary of the music, not of the reader's trade.

Consequences: The README and manual address a player, a student, a teacher and a researcher alike. Nothing else in ADRs 0014 and 0062 changes.

Supersedes: 0014 (only its reader), 0062 (only its description of the README's readers)
