\version "2.24.0"

% Gambangan, reyong kotekan, on a staff: the passage of
% gambangan-readme.nts, a small cropped illustration for the README.
% Source: Colin McPhee, Balinese Ceremonial Music (1940), "Gambangan".
% Drawn by `make lilypond' (ADR 0064) into
% examples/gallery/images/gambangan-readme-piano.png, with:
%   lilypond -dcrop -dno-print-pages --png -dresolution=200 gambangan-readme-piano.ly
% which writes gambangan-readme-piano.cropped.png.

sangsih = {
  b'8[ cis''16 b']   r16 cis''[ b'8]   cis''16[ b'8 cis''16]   b'16[ cis''8 cis''16~]
  cis''16[ cis'' cis'' ais']   r16 cis''[ ais'8]   cis''16[ ais'8 cis''16]   ais'8[ cis''16 ais']
}

polos = {
  r16 fis'[ ais'8]   fis'16[ ais'8 fis'16]   ais'8[ fis'16 ais']   r16 ais'[ fis' ais'~]
  ais'16[ eis' fis'8]   eis'16[ fis'8 eis'16]   fis'8[ eis'16 fis']   r16 eis'[ fis'8]
}

\paper {
  indent = 0
  tagline = ##f
}

\score {
  \new Staff \with { \omit TimeSignature } {
    \key fis \major
    \time 4/4
    << { \voiceOne \sangsih } \new Voice { \voiceTwo \polos } >>
    \bar "|"
  }
  \layout { }
}
