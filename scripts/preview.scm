;;; scripts/preview.scm -- `make preview': draw every score of every
;;; example to build/preview/, NAME.png for a file with only the default
;;; score and NAME_SCORE.png for each score otherwise (ADR 0040), matching the
;;; golden files (05, "Version pinning"; 04, "Golden tests").
;;;
;;; Run from the repo root: guile -L . scripts/preview.scm

(use-modules (ice-9 ftw)
             (notasi piece)
             (notasi reader)
             (notasi typst))

(define (draw nts out score)
  (render-piece nts out #:score score)
  (format #t "wrote ~a~%" out))

(for-each
 (lambda (file)
   (let* ((name (basename file ".nts"))
          (nts (string-append "examples/" file))
          (scores (piece-scores (read-piece-file nts))))
     (if (not (score-location (car scores)))
         (draw nts (string-append "build/preview/" name ".png") #f)
         (for-each (lambda (score)
                     (draw nts
                           (string-append "build/preview/" name "_"
                                          (symbol->string (score-name score))
                                          ".png")
                           (score-name score)))
                   scores))))
 (scandir "examples" (lambda (f) (string-suffix? ".nts" f))))
