;;; check.el --- Lint notasi-mode for make check-emacs  -*- lexical-binding: t; -*-

;;; Commentary:

;; Run by `make check-emacs' from the repository root:
;;
;;   emacs -Q --batch -l editors/emacs/check.el -f notasi-check-checkdoc FILE
;;   emacs -Q --batch -l editors/emacs/check.el -f notasi-check-package-lint FILE
;;
;; `notasi-check-checkdoc' exits 1 if checkdoc reports anything.
;; `notasi-check-package-lint' installs package-lint from MELPA into
;; build/emacs-packages/ the first time, then runs it; nothing is added
;; to the user's own Emacs configuration.

;;; Code:

(require 'package)

;; Linting needs no native compilation, which also writes to the user's
;; eln-cache and fails where the compiler toolchain is missing.
(defvar native-comp-enable-subr-trampolines)
(defvar native-comp-jit-compilation)
(setq native-comp-enable-subr-trampolines nil
      native-comp-jit-compilation nil)

;; Bound below before checkdoc is loaded; declared so that compiling
;; this file (as package-vc does) gives no warning.
(defvar checkdoc-create-error-function)
(defvar package-lint-main-file)
(declare-function package-lint-batch-and-exit "package-lint")

(defun notasi-check-checkdoc ()
  "Run checkdoc on the files on the command line; exit 1 on any warning."
  (require 'checkdoc)
  (let ((problems 0))
    (dolist (file command-line-args-left)
      (let ((checkdoc-create-error-function
             (lambda (text start _end &optional _unfixable)
               (setq problems (1+ problems))
               (message "%s:%d: %s" file
                        (save-restriction (widen) (line-number-at-pos start))
                        text)
               nil)))
        (with-current-buffer (find-file-noselect file)
          (checkdoc-current-buffer t))))
    (setq command-line-args-left nil)
    (kill-emacs (if (zerop problems) 0 1))))

(defun notasi-check-package-lint ()
  "Run package-lint on the files on the command line, installing it if needed."
  (setq package-user-dir (expand-file-name "build/emacs-packages")
        package-archives '(("melpa" . "https://melpa.org/packages/")))
  (package-initialize)
  (unless (package-installed-p 'package-lint)
    (package-refresh-contents)
    (package-install 'package-lint))
  (require 'package-lint)
  ;; notasi-mode is not on MELPA, so its own name is not checked there.
  (setq package-lint-main-file (car command-line-args-left))
  (package-lint-batch-and-exit))

;;; check.el ends here
