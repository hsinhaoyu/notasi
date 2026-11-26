;;; Smoke test: all modules load, and the test harness works.

(use-modules (srfi srfi-64)
             (notasi piece)
             (notasi expand)
             (notasi reader)
             (notasi layout)
             (notasi json)
             (notasi style)
             (notasi command)
             (notasi save)
             (notasi typst))

(test-begin "smoke")
(test-assert "modules load" #t)
(define runner (test-runner-current))
(test-end "smoke")

(exit (zero? (+ (test-runner-fail-count runner)
                (test-runner-xpass-count runner))))
