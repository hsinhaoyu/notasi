# 0063 The code is MIT; the manual and examples are CC BY 4.0

Status: accepted (2026-11-27)

Context: notasi had no licence, so no one could legally use, copy or change it. It holds two kinds of work: code, and content (the user manual, the examples and their drawings). Software licences fit code; Creative Commons licences fit content, and Creative Commons advises against them for software. Some examples transcribe published books, which aren't the user's to license, and `examples/contrib/` is meant for other people's files (ADR 0052).

Decision:

- The code, everything not listed below, is under the MIT licence, in `LICENSE` at the top of the repository, so GitHub shows "MIT license" on the repository page.
- The user manual, `doc/manual/`, is under CC BY 4.0, in `doc/manual/LICENSE`.
- `examples/`, with its drawings, is under CC BY 4.0, in `examples/LICENSE`. That file names the examples whose notes come from a published source, with their sources, says the user licenses only their own work in them (the encoding as a notasi file, the comments), and that each source keeps its rights. The examples themselves may name their source with `:source` or in a comment; `examples/LICENSE` is the one list.
- `examples/contrib/` is under CC BY 4.0 too, covered by `examples/LICENSE`, and credited to each file's contributor. Inbound equals outbound: `examples/LICENSE` and `CONTRIBUTING.md` say "By adding a file to `examples/contrib/`, you license it under CC BY 4.0 and confirm you have the right to: it's your own transcription or composition, or its source allows it." Opening the PR is the agreement; there is no CLA and no signed commits.
- A contributed file credits its contributor in the file itself, with `:contributor`, `:transcriber` and `:source`. A file without them is asked about before it is merged: a review rule, not a test, since `contrib/` is not read by the tests (ADR 0052).
- The README ends with a "Licence" section, the user's (ADR 0062), saying this and linking to the three files.
- The licence files reach `main` with the folders they cover.

Consequences: Anyone may use and change the code, and share and adapt the manual and examples with credit. The rights of the published sources are left with them, so the published transcriptions are shared only as far as their sources allow; the user asks their authors where that matters. A contribution needs nothing beyond a PR. Credit for `contrib/` files depends on review, not on a test.
