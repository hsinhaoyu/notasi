# 0065 Examples name their own published sources; examples/LICENSE names only the books

Status: accepted (2026-11-27)

Context: ADR 0063 made `examples/LICENSE` the one list of the examples whose notes come from a published source, each named by its file with its source. Writing the file showed that a list of file names in a licence goes stale as examples are added, moved or renamed, and that nothing reliable checks it: only some examples give their source with `:source`, others in a comment or a caption. The `contrib/` files already carry their own credit (ADR 0063, and 07, "Licences").

Decision:

- `examples/LICENSE` names the published books the user's examples transcribe, without listing the files, and says that each example from a published source names its source in the file itself (with `:source`, in a comment or in a caption). It still says that in those examples the user licenses only their own work (the encoding, the comments), and that each source keeps its rights.
- No test checks the sources: which examples come from a published source isn't something a test can know.
- Everything else in ADR 0063 stands: MIT for the code, CC BY 4.0 for the manual and the examples, the `contrib/` rule.

Consequences: Adding, moving or renaming an example doesn't touch `examples/LICENSE`, unless it transcribes a book not yet named there. Each example carries its own credit, as a contributed file does. A source given only in a comment or a caption is up to the author to keep; nothing checks it. The list of books is kept by hand.

Supersedes: 0063 (only its list of examples in `examples/LICENSE`)
