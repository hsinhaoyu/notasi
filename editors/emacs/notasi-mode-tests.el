;;; notasi-mode-tests.el --- Tests for notasi-mode  -*- lexical-binding: t; -*-

;;; Commentary:

;; ERT tests for notasi-mode, written from doc/design/08-emacs.md
;; ("The package", "Writing" and "Testing") before the package itself,
;; for the milestone feat/emacs-package: the package's headers, its
;; autoloads, the `notasi' customisation group, the major mode,
;; indentation and highlighting.
;;
;; The tests under "The preview: drawing" were written the same way,
;; from 08 ("The preview", "How a drawing is made", "Finding notasi",
;; "Testing" and "Slices", item 1), for the slice
;; feat/emacs-preview-draw.  They run the fake notasi beside this file,
;; `fake-notasi', so they need neither Guile nor Typst; one real test
;; draws with scripts/notasi when both are installed.
;;
;; The tests under "The preview: live" were written from 08 ("The
;; preview", "The score shown" and "Slices", item 2) for the slice
;; feat/emacs-preview-live: redrawing on a pause and on saving, the
;; settings, the score shown, `notasi-choose-score' and kept pictures.
;;
;; The tests under "The preview: mistakes" were written from 08
;; ("Mistakes", "Testing" and "Slices", item 3) for the slice
;; feat/emacs-preview-errors: Flymake, the red header, mistakes in
;; templates and the other problems.
;;
;; Run from the repository root with:
;;
;;   emacs -Q --batch -L editors/emacs -l ert \
;;     -l editors/emacs/notasi-mode-tests.el -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'package)
(require 'seq)
(require 'notasi-mode)

(defconst notasi-mode-tests--dir
  (file-name-directory (or load-file-name buffer-file-name))
  "The directory holding the package and these tests.")

(defconst notasi-mode-tests--package-file
  (expand-file-name "notasi-mode.el" notasi-mode-tests--dir)
  "The package's main file.")

(defconst notasi-mode-tests--music-faces
  '(notasi-note notasi-hold notasi-rest notasi-bar notasi-pattern)
  "The faces the mode gives to the music.")

(defconst notasi-mode-tests--indented-forms
  '(piece scale strokes instrument colotomy part pattern score group rep)
  "The forms whose body is indented by 2, like `defun'.")

;;;; Helpers

(defun notasi-mode-tests--emacs ()
  "Return the file name of the running Emacs, to start a fresh one."
  (expand-file-name invocation-name invocation-directory))

(defun notasi-mode-tests--run-emacs (&rest args)
  "Run a fresh `emacs -Q --batch' with ARGS.
Return a cons of its exit status and its output."
  (with-temp-buffer
    (let ((status (apply #'call-process (notasi-mode-tests--emacs)
                         nil t nil "-Q" "--batch" args)))
      (cons status (buffer-string)))))

(defun notasi-mode-tests--face-at (text place)
  "Return the face at PLACE in TEXT, highlighted by `notasi-mode'.
PLACE is a piece of TEXT with a caret (^) just before the character
to look at, e.g. \"(@ ^polos-3\".  The first occurrence of PLACE
without its caret is used."
  (let* ((caret (string-search "^" place))
         (needle (concat (substring place 0 caret)
                         (substring place (1+ caret)))))
    (with-temp-buffer
      (insert text)
      (notasi-mode)
      (font-lock-ensure)
      (goto-char (point-min))
      (unless (search-forward needle nil t)
        (error "%S not found in the text" needle))
      (get-text-property (+ (match-beginning 0) caret) 'face))))

(defun notasi-mode-tests--has-face-p (face faces)
  "Return non-nil if FACE is FACES or is among them.
FACES is the value of a `face' property: nil, a face or a list."
  (if (listp faces) (memq face faces) (eq face faces)))

(defun notasi-mode-tests--music-face-p (faces)
  "Return non-nil if FACES holds any of the music faces."
  (seq-some (lambda (face) (notasi-mode-tests--has-face-p face faces))
            notasi-mode-tests--music-faces))

(defun notasi-mode-tests--indent (mode text)
  "Return TEXT indented with `indent-region' in a buffer in MODE."
  (with-temp-buffer
    (insert text)
    (funcall mode)
    (indent-region (point-min) (point-max))
    (buffer-string)))

;;;; The package

(ert-deftest notasi-mode-test-lexical-binding ()
  "The package's first line turns on `lexical-binding'."
  (with-temp-buffer
    (insert-file-contents notasi-mode-tests--package-file)
    (goto-char (point-min))
    (should (string-match-p "-\\*-.*lexical-binding: *t"
                            (buffer-substring (point) (line-end-position))))))

(ert-deftest notasi-mode-test-package-name ()
  "The package is called notasi-mode."
  (with-temp-buffer
    (insert-file-contents notasi-mode-tests--package-file)
    (should (eq (package-desc-name (package-buffer-info)) 'notasi-mode))))

(ert-deftest notasi-mode-test-package-version ()
  "The package's version is notasi's, 0.4.0."
  (with-temp-buffer
    (insert-file-contents notasi-mode-tests--package-file)
    (should (equal (package-desc-version (package-buffer-info)) '(0 4 0)))))

(ert-deftest notasi-mode-test-version-constant-matches-header ()
  "`notasi-mode-version', which the version check compares with, is the
Version: header's."
  (with-temp-buffer
    (insert-file-contents notasi-mode-tests--package-file)
    (should (equal (version-to-list notasi-mode-version)
                   (package-desc-version (package-buffer-info))))))

(ert-deftest notasi-mode-test-package-requires-emacs-29-1 ()
  "The package requires Emacs 29.1."
  (with-temp-buffer
    (insert-file-contents notasi-mode-tests--package-file)
    (should (member '(emacs (29 1))
                    (package-desc-reqs (package-buffer-info))))))

(ert-deftest notasi-mode-test-byte-compiles-without-warnings ()
  "The package byte-compiles with warnings treated as errors."
  (let ((out (make-temp-file "notasi-mode-elc" t)))
    (unwind-protect
        (let ((result
               (notasi-mode-tests--run-emacs
                "-L" notasi-mode-tests--dir
                "--eval" "(setq byte-compile-error-on-warn t)"
                "--eval" (format "(setq byte-compile-dest-file-function
                                        (lambda (file)
                                          (expand-file-name
                                           (concat (file-name-nondirectory file) \"c\")
                                           %S)))"
                                 out)
                "-f" "batch-byte-compile" notasi-mode-tests--package-file)))
          (should (equal result (cons 0 (cdr result))))
          (should (file-exists-p (expand-file-name "notasi-mode.elc" out))))
      (delete-directory out t))))

;;;; Autoloads

(defun notasi-mode-tests--with-loaddefs (function)
  "Generate the package's autoloads in a temporary file; call FUNCTION.
FUNCTION is called with the file name of the generated loaddefs.  The
package is copied into the same temporary directory first, as it is
when installed, so the autoloads name it by a file name that the
directory on `load-path' resolves."
  (let* ((out (make-temp-file "notasi-mode-autoloads" t))
         (file (expand-file-name "notasi-mode-autoloads.el" out)))
    (unwind-protect
        (progn
          (copy-file notasi-mode-tests--package-file (file-name-as-directory out))
          (loaddefs-generate out file)
          (funcall function file))
      (delete-directory out t))))

(ert-deftest notasi-mode-test-autoloads-define-the-mode ()
  "The generated autoloads define an autoload for `notasi-mode'."
  (notasi-mode-tests--with-loaddefs
   (lambda (file)
     (with-temp-buffer
       (insert-file-contents file)
       (should (search-forward "(autoload 'notasi-mode " nil t))))))

(ert-deftest notasi-mode-test-autoloads-alone-give-the-mode ()
  "In a fresh Emacs, loading only the autoloads autoloads `notasi-mode'.
Nothing is required: the mode is an autoload until it is used."
  (notasi-mode-tests--with-loaddefs
   (lambda (file)
     (let ((result (notasi-mode-tests--run-emacs
                    "-L" (file-name-directory file) "-l" file
                    "--eval"
                    "(princ (format \"%S %S\"
                                    (autoloadp (symbol-function 'notasi-mode))
                                    (featurep 'notasi-mode)))")))
       (should (equal result '(0 . "t nil")))))))

(ert-deftest notasi-mode-test-autoloads-map-nts-files ()
  "In a fresh Emacs, loading only the autoloads maps .nts to `notasi-mode'."
  (notasi-mode-tests--with-loaddefs
   (lambda (file)
     (let ((result (notasi-mode-tests--run-emacs
                    "-L" (file-name-directory file) "-l" file
                    "--eval"
                    "(princ (assoc-default \"piece.nts\" auto-mode-alist
                                           #'string-match))")))
       (should (equal result '(0 . "notasi-mode")))))))

(ert-deftest notasi-mode-test-autoloads-visiting-turns-on-the-mode ()
  "In a fresh Emacs with only the autoloads, visiting a .nts file
turns on `notasi-mode'."
  (notasi-mode-tests--with-loaddefs
   (lambda (file)
     (let* ((dir (make-temp-file "notasi-mode-visit" t))
            (nts (expand-file-name "gilak.nts" dir)))
       (unwind-protect
           (progn
             (with-temp-file nts
               (insert "(piece \"Gilak\" :colotomy gilak :pickup 1)\n"))
             (let ((result
                    (notasi-mode-tests--run-emacs
                     "-L" (file-name-directory file) "-l" file
                     "--eval"
                     (format "(princ (buffer-local-value
                                       'major-mode (find-file-noselect %S)))"
                             nts))))
               (should (equal result '(0 . "notasi-mode")))))
         (delete-directory dir t))))))

(ert-deftest notasi-mode-test-auto-mode-for-nts ()
  "A buffer for a file named NAME.nts gets `notasi-mode'."
  (with-temp-buffer
    (setq buffer-file-name
          (expand-file-name "jaya-semara.nts" temporary-file-directory))
    (unwind-protect
        (progn
          (set-auto-mode)
          (should (eq major-mode 'notasi-mode)))
      (setq buffer-file-name nil))))

;;;; The customisation group

(ert-deftest notasi-mode-test-custom-group ()
  "There is a `notasi' customisation group, with a docstring."
  (should (get 'notasi 'group-documentation)))

(ert-deftest notasi-mode-test-faces-are-defined ()
  "The five music faces are faces."
  (dolist (face notasi-mode-tests--music-faces)
    (should (facep face))))

(ert-deftest notasi-mode-test-faces-in-custom-group ()
  "The five music faces are in the `notasi' group, so users can change them."
  (dolist (face notasi-mode-tests--music-faces)
    (should (assq face (get 'notasi 'custom-group)))))

;;;; The mode

(ert-deftest notasi-mode-test-derived-from-lisp-data-mode ()
  "`notasi-mode' is derived from `lisp-data-mode'."
  (with-temp-buffer
    (notasi-mode)
    (should (eq major-mode 'notasi-mode))
    (should (derived-mode-p 'lisp-data-mode))))

(ert-deftest notasi-mode-test-comment-start ()
  "Comments start with a semicolon."
  (with-temp-buffer
    (notasi-mode)
    (should (equal (string-trim comment-start) ";"))))

(ert-deftest notasi-mode-test-mode-has-docstring ()
  "The mode has a docstring, so `C-h m' describes it."
  (should (documentation 'notasi-mode)))

;;;; Indentation

(ert-deftest notasi-mode-test-indent-score ()
  "A score's body is indented by 2."
  (should (equal (notasi-mode-tests--indent
                  #'notasi-mode
                  "(score full :fill none\n(group \"Ugal\" ugal))")
                 "(score full :fill none\n  (group \"Ugal\" ugal))")))

(ert-deftest notasi-mode-test-indent-pattern ()
  "A pattern's body is indented by 2."
  (should (equal (notasi-mode-tests--indent
                  #'notasi-mode
                  "(pattern pokok-ugal :instrument ugal\n_ i2 _ a1 _ e2 _ o2)")
                 "(pattern pokok-ugal :instrument ugal\n  _ i2 _ a1 _ e2 _ o2)")))

(ert-deftest notasi-mode-test-indent-part ()
  "A part's body is indented by 2."
  (should (equal (notasi-mode-tests--indent
                  #'notasi-mode
                  "(part :instrument ugal a1 || o2 i2 e2 o2\n| a1 o2 i2 a1 ||)")
                 "(part :instrument ugal a1 || o2 i2 e2 o2\n  | a1 o2 i2 a1 ||)")))

(ert-deftest notasi-mode-test-indent-piece ()
  "A piece's body is indented by 2."
  (should (equal (notasi-mode-tests--indent
                  #'notasi-mode
                  "(piece \"Gilak\"\n:colotomy gilak :pickup 1)")
                 "(piece \"Gilak\"\n  :colotomy gilak :pickup 1)")))

(ert-deftest notasi-mode-test-indent-colotomy ()
  "A colotomy's body is indented by 2."
  (should (equal (notasi-mode-tests--indent
                  #'notasi-mode
                  "(colotomy gilak 8\n(part :instrument gong -:3 GL:1 P - P G))")
                 "(colotomy gilak 8\n  (part :instrument gong -:3 GL:1 P - P G))")))

(ert-deftest notasi-mode-test-indent-group ()
  "A group's body is indented by 2."
  (should (equal (notasi-mode-tests--indent
                  #'notasi-mode
                  "(group \"Ugal\" :short \"U.\"\nugal)")
                 "(group \"Ugal\" :short \"U.\"\n  ugal)")))

(ert-deftest notasi-mode-test-indent-rep ()
  "A rep's body is indented by 2, also inside a part."
  (should (equal (notasi-mode-tests--indent
                  #'notasi-mode
                  "(part :instrument panyacah o3 ||\n(rep 2 a3 i3 u3 a3\no3 e3 i3 o3) ||)")
                 "(part :instrument panyacah o3 ||\n  (rep 2 a3 i3 u3 a3\n    o3 e3 i3 o3) ||)")))

(ert-deftest notasi-mode-test-indent-nested-group ()
  "A group inside a score is at 2, its continuation at 4."
  (should (equal (notasi-mode-tests--indent
                  #'notasi-mode
                  "(score full :fill none\n(group \"Ugal\" :short \"U.\"\nugal)\n(group \"Gong\" gong))")
                 "(score full :fill none\n  (group \"Ugal\" :short \"U.\"\n    ugal)\n  (group \"Gong\" gong))")))

(ert-deftest notasi-mode-test-indent-scale ()
  "A scale's degrees are indented by 2, as in templates/selisir.nts."
  (should (equal (notasi-mode-tests--indent
                  #'notasi-mode
                  "(scale selisir\n(ding :alias i :display \"i\")\n(dong :alias o :display \"o\"))")
                 "(scale selisir\n  (ding :alias i :display \"i\")\n  (dong :alias o :display \"o\"))")))

(ert-deftest notasi-mode-test-indent-strokes ()
  "A stroke set's strokes are indented by 2."
  (should (equal (notasi-mode-tests--indent
                  #'notasi-mode "(strokes gong-strokes\nG GL P T)")
                 "(strokes gong-strokes\n  G GL P T)")))

(ert-deftest notasi-mode-test-indent-instrument ()
  "An instrument's keys are indented by 2."
  (should (equal (notasi-mode-tests--indent
                  #'notasi-mode "(instrument ugal selisir\no1 e1 u1 a1 i2)")
                 "(instrument ugal selisir\n  o1 e1 u1 a1 i2)")))

(ert-deftest notasi-mode-test-indent-option-lines ()
  "A line of options in a form's body is indented by 4, the body by 2."
  (should (equal (notasi-mode-tests--indent
                  #'notasi-mode
                  "(pattern panyacah-fill :instrument panyacah :short \"fill\"\n:long \"Panyacah\"\na3 i3 u3)")
                 "(pattern panyacah-fill :instrument panyacah :short \"fill\"\n    :long \"Panyacah\"\n  a3 i3 u3)"))
  (should (equal (notasi-mode-tests--indent
                  #'notasi-mode
                  "(score full :fill none\n:caption \"A\" :breaks ((1 3))\n(group \"Ugal\"\n:short \"U.\"\nugal))")
                 "(score full :fill none\n    :caption \"A\" :breaks ((1 3))\n  (group \"Ugal\"\n      :short \"U.\"\n    ugal))")))

(ert-deftest notasi-mode-test-indent-other-forms-as-lisp ()
  "Other forms (`use', pattern calls, chords) follow Lisp's usual rule,
as in `lisp-data-mode'."
  (dolist (text '("(use\ngong-kebyar)"
                  "(@ polos-1 :step 1\n:short \"2\")"
                  "(o2\ne2)"))
    ;; Lisp reads `@' as a prefix, so the baseline uses a plain name of
    ;; the same length in its place.
    (should (equal (notasi-mode-tests--indent #'notasi-mode text)
                   (string-replace
                    "(x " "(@ "
                    (notasi-mode-tests--indent
                     #'lisp-data-mode (string-replace "(@ " "(x " text)))))))

(ert-deftest notasi-mode-test-indent-does-not-set-symbol-properties ()
  "The indentation is not put on the symbols, which Emacs Lisp shares."
  (with-temp-buffer (notasi-mode))
  (dolist (name notasi-mode-tests--indented-forms)
    (should-not (get name 'lisp-indent-function))
    (should-not (get name 'common-lisp-indent-function))))

(ert-deftest notasi-mode-test-indent-does-not-leak-into-emacs-lisp ()
  "After `notasi-mode' has been used, Emacs Lisp indents the form names
like any unknown function of the same length."
  (with-temp-buffer (notasi-mode))
  (dolist (name notasi-mode-tests--indented-forms)
    (let* ((name (symbol-name name))
           (other (make-string (length name) ?x)))
      (should (equal (notasi-mode-tests--indent
                      #'emacs-lisp-mode (format "(%s a\nb)" name))
                     (string-replace
                      other name
                      (notasi-mode-tests--indent
                       #'emacs-lisp-mode (format "(%s a\nb)" other))))))))

;;;; Highlighting: Lisp

(defconst notasi-mode-tests--piece
  ";; Gilak: an eight-pulse cycle.
(piece \"Gilak\" :colotomy gilak :pickup 1)
(use gong-kebyar)
(scale selisir
  (ding :alias i :display \"i\"))
(strokes gong-strokes  G GL P T)
(instrument ugal  selisir  o1 e1 u1 a1 i2 o2 e2 u2 a2 i3)
(colotomy gilak 8
  (part :instrument gong  -:3 GL:1 P - P G))
(pattern polos-1 :instrument pemade :short \"1\" :long \"Norot polos on 1\"
  o3:1/4 i3 i3 - | i3 - i3 -)
(part :instrument pemade :name polos
  (rep 2  @polos-1 (@ polos-3 :step 1)))
(score full :breaks ((1 1) (2 1))
  (group \"Ugal\" :short \"U.\" ugal))
"
  "A small piece using every form.")

(ert-deftest notasi-mode-test-form-names-are-keywords ()
  "The form names are in `font-lock-keyword-face'."
  (dolist (place '("(^piece" "(^use" "(^scale" "(^strokes" "(^instrument"
                   "(^colotomy" "(^pattern" "(^part :instrument pemade"
                   "(^part :instrument gong" "(^score" "(^group" "(^rep"
                   "(^@ polos-3"))
    (should (notasi-mode-tests--has-face-p
             'font-lock-keyword-face
             (notasi-mode-tests--face-at notasi-mode-tests--piece place)))))

(ert-deftest notasi-mode-test-option-keys-are-builtins ()
  "Option keys such as :instrument are in `font-lock-builtin-face'."
  (dolist (place '("^:colotomy gilak :pickup" "^:pickup" "^:instrument gong"
                   "^:short \"1\"" "^:step" "^:breaks" "^:name"))
    (should (notasi-mode-tests--has-face-p
             'font-lock-builtin-face
             (notasi-mode-tests--face-at notasi-mode-tests--piece place)))))

(ert-deftest notasi-mode-test-strings ()
  "Strings are in `font-lock-string-face'."
  (dolist (place '("^\"Gilak\"" "^\"Norot polos on 1\"" "^\"U.\""))
    (should (notasi-mode-tests--has-face-p
             'font-lock-string-face
             (notasi-mode-tests--face-at notasi-mode-tests--piece place)))))

(ert-deftest notasi-mode-test-comments ()
  "Comments are in a comment face."
  (let ((faces (notasi-mode-tests--face-at notasi-mode-tests--piece
                                           ";; ^Gilak: an")))
    (should (or (notasi-mode-tests--has-face-p 'font-lock-comment-face faces)
                (notasi-mode-tests--has-face-p
                 'font-lock-comment-delimiter-face faces)))))

(ert-deftest notasi-mode-test-comment-after-music ()
  "A comment after the music is a comment, not music."
  (let ((faces (notasi-mode-tests--face-at
                "(part :instrument ugal  a1 o2   ; a1 is low\n  i2)"
                "; ^a1 is low")))
    (should (notasi-mode-tests--has-face-p 'font-lock-comment-face faces))
    (should-not (notasi-mode-tests--music-face-p faces))))

;;;; Highlighting: the music

(defun notasi-mode-tests--should-have-face (face text places)
  "Check that each of PLACES in TEXT has FACE."
  (dolist (place places)
    (should (equal (list place
                         (and (notasi-mode-tests--has-face-p
                               face (notasi-mode-tests--face-at text place))
                              t))
                   (list place t)))))

(defun notasi-mode-tests--should-not-have-music-face (text places)
  "Check that none of PLACES in TEXT has a music face."
  (dolist (place places)
    (should-not (notasi-mode-tests--music-face-p
                 (notasi-mode-tests--face-at text place)))))

(ert-deftest notasi-mode-test-notes ()
  "Notes, by name or number, with or without a duration, are notes."
  (notasi-mode-tests--should-have-face
   'notasi-note
   "(part :instrument ugal  a1 5 o3:1/4 GL:1 e2:2 5:1/4 ding)"
   '(" ^a1" " ^5 " " ^o3:1/4" " ^GL:1" " ^e2:2" " ^5:1/4" " ^ding")))

(ert-deftest notasi-mode-test-holds ()
  "Holds, with or without a duration, are holds."
  (notasi-mode-tests--should-have-face
   'notasi-hold
   "(part :instrument ugal  a1 _ o2 _:2 i2)"
   '(" ^_ o2" " ^_:2")))

(ert-deftest notasi-mode-test-rests ()
  "Rests, with or without a duration, are rests."
  (notasi-mode-tests--should-have-face
   'notasi-rest
   "(part :instrument ugal  a1 - o2 -:3 i2)"
   '(" ^- o2" " ^-:3")))

(ert-deftest notasi-mode-test-bars ()
  "Single and double bar lines are bars."
  (notasi-mode-tests--should-have-face
   'notasi-bar
   "(part :instrument ugal  a1 || o2 i2 | e2 o2 ||)"
   '(" ^|| o2" " ^| e2" " ^||)")))

(ert-deftest notasi-mode-test-pattern-calls ()
  "Pattern calls, @NAME and the name in (@ NAME ...), are patterns."
  (notasi-mode-tests--should-have-face
   'notasi-pattern
   "(part :instrument pemade  @polos-1 (@ polos-3 :step 1) @polos-2)"
   '(" ^@polos-1" "(@ ^polos-3" " ^@polos-2")))

(ert-deftest notasi-mode-test-music-in-pattern ()
  "The tokens after a pattern's options are music."
  (let ((text "(pattern polos-1 :instrument pemade :short \"1\"
  o3:1/4 i3 _ - | i3 -:2 ||)"))
    (notasi-mode-tests--should-have-face
     'notasi-note text '("^o3:1/4" " ^i3 _"))
    (notasi-mode-tests--should-have-face 'notasi-hold text '(" ^_ -"))
    (notasi-mode-tests--should-have-face 'notasi-rest text '(" ^- |" " ^-:2"))
    (notasi-mode-tests--should-have-face 'notasi-bar text '(" ^| i3" " ^||"))))

(ert-deftest notasi-mode-test-music-after-options-on-several-lines ()
  "The music starts after the options, even when they take several lines."
  (let ((text "(pattern panyacah-fill :instrument panyacah :short \"fill\"
    :long \"Panyacah: 6 1 5 6 2 3 1 2\"
  a3 i3 u3 a3 o3 e3 i3 o3)"))
    (notasi-mode-tests--should-have-face 'notasi-note text '("^a3 i3" " ^o3)"))
    (notasi-mode-tests--should-not-have-music-face
     text '("^:long" "^\"Panyacah" "^panyacah-fill" ":instrument ^panyacah"))))

(ert-deftest notasi-mode-test-music-in-rep ()
  "The tokens inside a rep are music."
  (let ((text "(part :instrument panyacah  o3 || (rep 2  a3 _ - | @polos-1) ||)"))
    (notasi-mode-tests--should-have-face 'notasi-note text '("2  ^a3"))
    (notasi-mode-tests--should-have-face 'notasi-hold text '(" ^_ -"))
    (notasi-mode-tests--should-have-face 'notasi-rest text '(" ^- |"))
    (notasi-mode-tests--should-have-face 'notasi-bar text '(" ^| @"))
    (notasi-mode-tests--should-have-face 'notasi-pattern text '(" ^@polos-1"))))

(ert-deftest notasi-mode-test-music-in-chord ()
  "The members of a chord are notes."
  (notasi-mode-tests--should-have-face
   'notasi-note
   "(part :instrument ugal  a1 (3 5) (o2 e2) i2)"
   '("(^3 5)" "(3 ^5)" "(^o2 e2)" "(o2 ^e2)")))

(ert-deftest notasi-mode-test-music-in-colotomy ()
  "The music of the part inside a colotomy is music."
  (let ((text "(colotomy bapang 16
  (part :instrument gong  -:3 P:1 -:3 T:1 -:3 P:1 -:3 G:1))"))
    (notasi-mode-tests--should-have-face 'notasi-rest text '("  ^-:3 P:1"))
    (notasi-mode-tests--should-have-face 'notasi-note text '(" ^P:1" " ^G:1"))))

(ert-deftest notasi-mode-test-music-in-pattern-call-options-not-notes ()
  "In (@ NAME :key value), the option's value is not music."
  (notasi-mode-tests--should-not-have-music-face
   "(part :instrument pemade  (@ polos-1 :step -1 :short \"6\") i3)"
   '(":step ^-1" ":short ^\"6\"")))

;;;; Highlighting: names outside the music

(ert-deftest notasi-mode-test-option-values-not-music ()
  "An option's value, such as :instrument ugal, is not music."
  (notasi-mode-tests--should-not-have-music-face
   "(part :instrument ugal :name melody  a1 o2)"
   '(":instrument ^ugal" ":name ^melody")))

(ert-deftest notasi-mode-test-pattern-name-not-music ()
  "A pattern's name is not music."
  (notasi-mode-tests--should-not-have-music-face
   "(pattern pokok-ugal :instrument ugal :short \"pokok\"\n  _ i2 _ a1 _ e2 _ o2)"
   '("(pattern ^pokok-ugal" ":instrument ^ugal" ":short ^\"pokok\"")))

(ert-deftest notasi-mode-test-score-not-music ()
  "A score's name, its options and its groups are not music."
  (notasi-mode-tests--should-not-have-music-face
   "(score full :breaks ((1 1) (2 1)) :fill none
  (group \"Ugal\" :short \"U.\" ugal)
  (group \"Gong\" gong))"
   '("(score ^full" "((^1 1)" ":fill ^none" "^\"Ugal\"" ":short ^\"U.\""
     "\"U.\" ^ugal" "\"Gong\" ^gong")))

(ert-deftest notasi-mode-test-instrument-keys-not-music ()
  "The notes listed in an instrument form are not music."
  (notasi-mode-tests--should-not-have-music-face
   "(instrument ugal selisir o1 e1 u1)"
   '("(instrument ^ugal" "^selisir" " ^o1" " ^e1" " ^u1")))

(ert-deftest notasi-mode-test-strokes-not-music ()
  "The strokes listed in a strokes form are not music."
  (notasi-mode-tests--should-not-have-music-face
   "(strokes gong-strokes  G GL P T)"
   '("^gong-strokes" " ^G " " ^GL" " ^P" " ^T")))

(ert-deftest notasi-mode-test-piece-options-not-music ()
  "A piece's title and option values, such as :pickup 1, are not music."
  (notasi-mode-tests--should-not-have-music-face
   "(piece \"Gilak\" :colotomy gilak :pickup 1)"
   '("^\"Gilak\"" ":colotomy ^gilak" ":pickup ^1")))

(ert-deftest notasi-mode-test-use-and-scale-not-music ()
  "A template's name and a scale's degrees are not music."
  (notasi-mode-tests--should-not-have-music-face
   "(use gong-kebyar)\n(scale selisir\n  (ding :alias i :display \"i\"))"
   '("^gong-kebyar" "(scale ^selisir" "(^ding" ":alias ^i")))

(ert-deftest notasi-mode-test-colotomy-name-and-length-not-music ()
  "A colotomy's name and length are not music."
  (notasi-mode-tests--should-not-have-music-face
   "(colotomy gilak 8\n  (part :instrument gong  -:3 GL:1 P - P G))"
   '("(colotomy ^gilak" "gilak ^8" ":instrument ^gong")))

;;;; The preview: drawing (slice feat/emacs-preview-draw)

;; Written from 08 before the code.  Choices where 08 leaves room:
;;
;; - The fake notasi (`fake-notasi') logs each run (its working folder
;;   and arguments) to $FAKE_NOTASI_LOG, copies the text it was given to
;;   $FAKE_NOTASI_INPUT, waits $FAKE_NOTASI_SLEEP seconds when asked,
;;   and prints $FAKE_NOTASI_VERSION for --version.  The tests set these
;;   through `process-environment', so the mode must start its
;;   processes while the test's binding is in effect (it does, if the
;;   commands start them before returning).
;; - The picture is found as an image `display' property (a text
;;   property or an overlay) in the preview buffer, and its SVG text is
;;   read from its :data, or else from its :file.
;; - The header line is read from `header-line-format' by a small
;;   reader of mode line constructs (strings, symbols, lists, :eval,
;;   :propertize, conditionals), since `format-mode-line' gives "" in
;;   batch Emacs.  "drawing…" may also be written "drawing...".
;; - "The preview says" (the version message) means the preview's
;;   header line or its text, checked once the first drawing is done.
;; - `--version' runs once for each program: every version test uses
;;   its own copy of the fake, so the tests don't share what the mode
;;   remembers about a program.
;; - Finding notasi in a folder above the .nts file (step 4) is tested
;;   in a fresh Emacs that loads a copy of the package from a temporary
;;   folder, so step 3 (scripts/notasi in the package's own clone)
;;   finds nothing; nothing about how the mode remembers its own file
;;   is assumed.  `notasi-find-program' uses the current buffer's file.
;; - `notasi-write-score' takes the file to write as an argument, so it
;;   can be called from Lisp; interactively it asks for it.
;; - A buffer in `notasi-mode' that visits no file draws nothing.
;; - The real test draws a copy of examples/gallery/jaya-semara.nts in a
;;   temporary folder (its template is found by notasi), so nothing is
;;   written in examples/gallery/.
;; - Windows: batch Emacs has one frame, 80 columns by 25 lines, where
;;   windows can be split and buffers displayed, so opening, showing
;;   and hiding the preview are tested; that it goes to the right or
;;   below, and that the picture refits when the window is resized
;;   (redisplay doesn't run in batch), are checked by hand.

(require 'cl-lib)

(defvar notasi-program)

(defconst notasi-mode-tests--fake
  (expand-file-name "fake-notasi" notasi-mode-tests--dir)
  "The fake notasi the tests draw with.")

(defconst notasi-mode-tests--repo
  (file-name-as-directory
   (expand-file-name "../.." notasi-mode-tests--dir))
  "The notasi repository, the clone the package is loaded from.")

(defconst notasi-mode-tests--gilak
  "(piece \"Gilak: pangawit\" :colotomy gilak :pickup 1)

(use gong-kebyar)

(score full :fill none
  (group \"Ugal\" ugal))

(score second
  (group \"Ugal\" ugal))
"
  "A piece with two scores; the first is `full'.")

(defconst notasi-mode-tests--no-score
  "(piece \"Gilak: pangawit\" :colotomy gilak :pickup 1)

(use gong-kebyar)
"
  "A piece with no `score' forms.")

;;;;; Helpers for drawing

(defun notasi-mode-tests--wait (&optional process timeout)
  "Wait for PROCESS to finish, or, without it, for every process.
Give up after TIMEOUT seconds (10 by default) with an error.  Then let
the sentinels run."
  (let ((end (+ (float-time) (or timeout 10)))
        (busy (lambda ()
                (if process
                    (process-live-p process)
                  (seq-some #'process-live-p (process-list))))))
    (while (and (funcall busy) (< (float-time) end))
      (accept-process-output nil 0.05))
    (when (funcall busy)
      (error "A drawing still runs after %s seconds" (or timeout 10)))
    (dotimes (_ 5) (accept-process-output nil 0.02))))

(defun notasi-mode-tests--runs (log)
  "Return the runs of the fake notasi recorded in LOG.
Each is a list (FOLDER ARG...), oldest first."
  (when (file-exists-p log)
    (with-temp-buffer
      (insert-file-contents log)
      (mapcar (lambda (line) (split-string line "\t"))
              (split-string (buffer-string) "\n" t)))))

(defun notasi-mode-tests--render-runs (log)
  "Return the runs of `notasi render' recorded in LOG."
  (seq-filter (lambda (run) (equal (cadr run) "render"))
              (notasi-mode-tests--runs log)))

(defun notasi-mode-tests--version-runs (log)
  "Return the runs of `notasi --version' recorded in LOG."
  (seq-filter (lambda (run) (member "--version" (cdr run)))
              (notasi-mode-tests--runs log)))

(defun notasi-mode-tests--option (run option)
  "Return the value after OPTION in RUN's arguments, or nil."
  (cadr (member option (cdr run))))

(defun notasi-mode-tests--piece-arg (run)
  "Return the PIECE.nts argument of the render RUN."
  (let ((args (cddr run)) found)
    (while args
      (if (member (car args) '("-o" "--output" "--score"))
          (setq args (cddr args))
        (setq found (car args) args nil)))
    found))

(defun notasi-mode-tests--out (run)
  "Return the absolute OUT of the render RUN."
  (expand-file-name (or (notasi-mode-tests--option run "-o")
                        (notasi-mode-tests--option run "--output"))
                    (car run)))

(defun notasi-mode-tests--preview (file)
  "Return the preview buffer of FILE, or nil."
  (get-buffer (format "*notasi: %s*" (file-name-nondirectory file))))

(defun notasi-mode-tests--format (format)
  "Return the text of the mode line construct FORMAT, in plain text.
`format-mode-line' gives \"\" in batch Emacs, so the usual constructs
are read here: strings (with %% for %), symbols, lists, (:eval FORM),
(:propertize ELT ...), (SYMBOL THEN ELSE) and (WIDTH ELT)."
  (pcase format
    ('nil "")
    ((pred stringp)
     (string-replace "%%" "%" (substring-no-properties format)))
    ((pred symbolp)
     (if (boundp format) (notasi-mode-tests--format (symbol-value format)) ""))
    (`(:eval ,form) (notasi-mode-tests--format (eval form t)))
    (`(:propertize ,elt . ,_) (notasi-mode-tests--format elt))
    (`(,(and (pred integerp)) ,elt) (notasi-mode-tests--format elt))
    (`(,(and (pred symbolp) (pred (not keywordp)) sym) ,then . ,else)
     (if (and (boundp sym) (symbol-value sym))
         (notasi-mode-tests--format then)
       (mapconcat #'notasi-mode-tests--format else "")))
    ((pred consp) (mapconcat #'notasi-mode-tests--format format ""))
    (_ "")))

(defun notasi-mode-tests--header (preview)
  "Return the header line of the buffer PREVIEW, as plain text."
  (with-current-buffer preview
    (notasi-mode-tests--format header-line-format)))

(defun notasi-mode-tests--says (preview)
  "Return what the buffer PREVIEW says: its header line and its text."
  (concat (notasi-mode-tests--header preview) "\n"
          (with-current-buffer preview
            (buffer-substring-no-properties (point-min) (point-max)))))

(defun notasi-mode-tests--image-in (display)
  "Return the image spec in the `display' property DISPLAY, or nil."
  (cond ((eq (car-safe display) 'image) display)
        ((and (consp display) (consp (car display)))
         (seq-find (lambda (d) (eq (car-safe d) 'image)) display))))

(defun notasi-mode-tests--image (preview)
  "Return the image spec the buffer PREVIEW shows, or nil."
  (with-current-buffer preview
    (or (seq-some (lambda (o)
                    (notasi-mode-tests--image-in (overlay-get o 'display)))
                  (overlays-in (point-min) (point-max)))
        (let ((pos (point-min)) found)
          (while (and (not found) (< pos (point-max)))
            (setq found (notasi-mode-tests--image-in
                         (get-text-property pos 'display))
                  pos (1+ pos)))
          found))))

(defun notasi-mode-tests--image-text (image)
  "Return the SVG text of the image spec IMAGE."
  (or (plist-get (cdr image) :data)
      (let ((file (plist-get (cdr image) :file)))
        (and file (file-exists-p file)
             (with-temp-buffer
               (insert-file-contents file)
               (buffer-string))))))

(defun notasi-mode-tests--shown (file)
  "Return the SVG text of the picture FILE's preview shows, or nil."
  (let* ((preview (notasi-mode-tests--preview file))
         (image (and preview (notasi-mode-tests--image preview))))
    (and image (notasi-mode-tests--image-text image))))

(defun notasi-mode-tests--hidden-files (dir)
  "Return the hidden `.notasi-preview-*' files in DIR."
  (directory-files dir nil "\\`\\.notasi-preview-"))

(defun notasi-mode-tests--drawing-p (text)
  "Return non-nil if TEXT says a drawing is being made."
  (string-match-p "drawing\\(…\\|\\.\\.\\.\\)" text))

(defun notasi-mode-tests--copy-fake ()
  "Copy the fake notasi to a new folder of its own, as `notasi'.
Return the copy's file name."
  (let ((copy (expand-file-name
               "notasi" (make-temp-file "notasi-mode-fake" t))))
    (copy-file notasi-mode-tests--fake copy)
    (set-file-modes copy #o755)
    copy))

(defun notasi-mode-tests--wait-for-first-drawing (log)
  "Wait until a drawing has been started (LOG records it), then for it."
  (unless (fboundp 'notasi-preview-redraw)
    (error "notasi-mode can't draw yet: no `notasi-preview-redraw'"))
  (let ((end (+ (float-time) 10)))
    (while (and (null (notasi-mode-tests--render-runs log))
                (< (float-time) end))
      (accept-process-output nil 0.05)))
  (notasi-mode-tests--wait))

(cl-defun notasi-mode-tests--with-piece
    (function &key (text notasi-mode-tests--gilak) (name "gilak.nts")
              (program notasi-mode-tests--fake) env select)
  "Open a .nts file holding TEXT and call FUNCTION.
The file, NAME, is in a temporary folder of its own; the mode draws
with PROGRAM (`notasi-program'), with ENV (strings \"VAR=VALUE\") added
to the environment.  With SELECT, the file is opened with `find-file'
in a frame with one window; otherwise with `find-file-noselect'.  The
first drawing, made on opening, is waited for.

FUNCTION is called in the file's buffer, with a plist: :buffer, :dir
\(the file's folder), :file, :log (the fake's log) and :input (the text it was last given).
Afterwards the buffer is killed and the folders removed."
  (let* ((dir (make-temp-file "notasi-mode-piece" t))
         (aux (make-temp-file "notasi-mode-aux" t))
         (file (expand-file-name name dir))
         (log (expand-file-name "fake.log" aux))
         (input (expand-file-name "input.nts" aux))
         (process-environment
          (append (list (concat "FAKE_NOTASI_LOG=" log)
                        (concat "FAKE_NOTASI_INPUT=" input))
                  env process-environment))
         (notasi-program program)
         buffer)
    (with-temp-file file (insert text))
    (unwind-protect
        (progn
          (delete-other-windows)
          (setq buffer (if select (find-file file) (find-file-noselect file)))
          (notasi-mode-tests--wait-for-first-drawing log)
          (with-current-buffer buffer
            (funcall function (list :buffer buffer :dir dir :file file
                                    :log log :input input))))
      (when (buffer-live-p buffer)
        (with-current-buffer buffer (set-buffer-modified-p nil))
        (kill-buffer buffer))
      (ignore-errors (notasi-mode-tests--wait))
      (delete-other-windows)
      (delete-directory dir t)
      (delete-directory aux t))))

(defun notasi-mode-tests--run-emacs-for (form &rest args)
  "Run FORM in a fresh `emacs -Q --batch' with ARGS before it.
FORM's value is printed and read back; return it."
  (let* ((result (apply #'notasi-mode-tests--run-emacs
                        (append args
                                (list "--eval"
                                      (format "(progn (princ \"\\nRESULT:\") (prin1 %S))"
                                              form)))))
         (out (cdr result))
         (at (string-search "\nRESULT:" out)))
    (unless (and (eq (car result) 0) at)
      (error "Emacs failed: %s"
             (string-join (seq-take (split-string out "\n" t) 3) "; ")))
    (car (read-from-string out (+ at (length "\nRESULT:"))))))

(defun notasi-mode-tests--same-file-p (a b)
  "Return non-nil if A and B name the same file."
  (and a b (equal (file-truename a) (file-truename b))))

;;;;; Finding notasi

(ert-deftest notasi-mode-test-find-program-setting-wins ()
  "`notasi-program', when set, is the notasi run, before the PATH's."
  (let* ((bin (make-temp-file "notasi-mode-bin" t))
         (on-path (expand-file-name "notasi" bin)))
    (unwind-protect
        (progn
          (copy-file notasi-mode-tests--fake on-path)
          (set-file-modes on-path #o755)
          (let ((notasi-program notasi-mode-tests--fake)
                (exec-path (list bin)))
            (with-temp-buffer
              (should (equal (notasi-find-program)
                             notasi-mode-tests--fake)))))
      (delete-directory bin t))))

(ert-deftest notasi-mode-test-find-program-on-path ()
  "Without `notasi-program', `notasi' on the PATH is the notasi run."
  (let* ((bin (make-temp-file "notasi-mode-bin" t))
         (on-path (expand-file-name "notasi" bin)))
    (unwind-protect
        (progn
          (copy-file notasi-mode-tests--fake on-path)
          (set-file-modes on-path #o755)
          (let ((notasi-program nil)
                (exec-path (list bin)))
            (with-temp-buffer
              (should (notasi-mode-tests--same-file-p
                       (notasi-find-program) on-path)))))
      (delete-directory bin t))))

(ert-deftest notasi-mode-test-find-program-package-clone ()
  "With nothing set and no notasi on the PATH, scripts/notasi in the
clone the package was loaded from is run, before one above the file."
  (let* ((empty (make-temp-file "notasi-mode-empty" t))
         (proj (make-temp-file "notasi-mode-proj" t))
         (scripts (expand-file-name "scripts" proj))
         (nts (expand-file-name "songs/gilak.nts" proj)))
    (unwind-protect
        (progn
          (make-directory scripts)
          (make-directory (file-name-directory nts))
          (copy-file notasi-mode-tests--fake (expand-file-name "notasi" scripts))
          (set-file-modes (expand-file-name "notasi" scripts) #o755)
          (with-temp-file nts (insert notasi-mode-tests--no-score))
          (let ((notasi-program nil)
                (exec-path (list empty)))
            (with-temp-buffer
              (setq buffer-file-name nts
                    default-directory (file-name-directory nts))
              (unwind-protect
                  (should (notasi-mode-tests--same-file-p
                           (notasi-find-program)
                           (expand-file-name "scripts/notasi"
                                             notasi-mode-tests--repo)))
                (setq buffer-file-name nil)))))
      (delete-directory empty t)
      (delete-directory proj t))))

(ert-deftest notasi-mode-test-find-program-above-the-file ()
  "When the package's own folder holds no clone, scripts/notasi in a
folder above the .nts file is run.  Tested in a fresh Emacs loading a
copy of the package from a folder outside any clone."
  (let* ((tmp (make-temp-file "notasi-mode-above" t))
         (lisp (expand-file-name "pkg/lisp" tmp))
         (empty (expand-file-name "empty" tmp))
         (proj (expand-file-name "proj" tmp))
         (program (expand-file-name "scripts/notasi" proj))
         (near (expand-file-name "songs/gilak.nts" proj))
         (far (expand-file-name "a/b/c/gilak.nts" proj)))
    (unwind-protect
        (progn
          (make-directory lisp t)
          (make-directory empty t)
          (make-directory (file-name-directory program) t)
          (make-directory (file-name-directory near) t)
          (make-directory (file-name-directory far) t)
          (copy-file notasi-mode-tests--package-file
                     (file-name-as-directory lisp))
          (copy-file notasi-mode-tests--fake program)
          (set-file-modes program #o755)
          (dolist (nts (list near far))
            (with-temp-file nts (insert notasi-mode-tests--no-score)))
          (let ((found
                 (notasi-mode-tests--run-emacs-for
                  `(progn
                     (setq exec-path (list ,empty))
                     (require 'notasi-mode)
                     (mapcar (lambda (nts)
                               (with-temp-buffer
                                 (setq buffer-file-name nts
                                       default-directory
                                       (file-name-directory nts))
                                 (prog1 (notasi-find-program)
                                   (setq buffer-file-name nil))))
                             (list ,near ,far)))
                  "-L" lisp)))
            (should (= (length found) 2))
            (dolist (f found)
              (should (notasi-mode-tests--same-file-p f program)))))
      (delete-directory tmp t))))

(ert-deftest notasi-mode-test-find-program-none ()
  "When no notasi is found anywhere, `notasi-find-program' returns nil."
  (let* ((tmp (make-temp-file "notasi-mode-none" t))
         (lisp (expand-file-name "pkg/lisp" tmp))
         (empty (expand-file-name "empty" tmp))
         (nts (expand-file-name "songs/gilak.nts" tmp)))
    (unwind-protect
        (progn
          (make-directory lisp t)
          (make-directory empty t)
          (make-directory (file-name-directory nts) t)
          (copy-file notasi-mode-tests--package-file
                     (file-name-as-directory lisp))
          (with-temp-file nts (insert notasi-mode-tests--no-score))
          (should
           (equal (notasi-mode-tests--run-emacs-for
                   `(progn
                      (setq exec-path (list ,empty))
                      (require 'notasi-mode)
                      (with-temp-buffer
                        (setq buffer-file-name ,nts
                              default-directory ,(file-name-directory nts))
                        (prog1 (list (notasi-find-program))
                          (setq buffer-file-name nil))))
                   "-L" lisp)
                  '(nil))))
      (delete-directory tmp t))))

;;;;; How a drawing is made

(ert-deftest notasi-mode-test-redraw-returns-the-process ()
  "`notasi-preview-redraw' returns the drawing's process."
  (notasi-mode-tests--with-piece
   (lambda (_)
     (let ((p (notasi-preview-redraw)))
       (should (processp p))
       (notasi-mode-tests--wait p)
       (should (eq (process-status p) 'exit))
       (should (= (process-exit-status p) 0))))))

(ert-deftest notasi-mode-test-draws-unsaved-text-from-hidden-file ()
  "A drawing runs notasi in the file's folder on the hidden file
.notasi-preview-FILE, which holds the buffer's text, unsaved."
  (notasi-mode-tests--with-piece
   (lambda (ctx)
     (with-current-buffer (plist-get ctx :buffer)
       (goto-char (point-max))
       (insert ";; written, not saved\n")
       (notasi-mode-tests--wait (notasi-preview-redraw))
       (let ((run (car (last (notasi-mode-tests--render-runs
                              (plist-get ctx :log))))))
         (should run)
         (should (file-equal-p (car run) (plist-get ctx :dir)))
         (let ((piece (notasi-mode-tests--piece-arg run)))
           (should (equal (file-name-nondirectory piece)
                          ".notasi-preview-gilak.nts"))
           (should (file-equal-p
                    (file-name-directory (expand-file-name piece (car run)))
                    (plist-get ctx :dir)))))
       (should (equal (with-temp-buffer
                        (insert-file-contents (plist-get ctx :input))
                        (buffer-string))
                      (buffer-string)))
       ;; The file itself is not saved.
       (should (buffer-modified-p))
       (should (equal (with-temp-buffer
                        (insert-file-contents (plist-get ctx :file))
                        (buffer-string))
                      notasi-mode-tests--gilak))))))

(ert-deftest notasi-mode-test-hidden-file-removed ()
  "The hidden file is gone once a drawing is done."
  (notasi-mode-tests--with-piece
   (lambda (ctx)
     (with-current-buffer (plist-get ctx :buffer)
       (notasi-mode-tests--wait (notasi-preview-redraw))
       (should-not (notasi-mode-tests--hidden-files (plist-get ctx :dir)))))))

(ert-deftest notasi-mode-test-output-in-temporary-folder ()
  "The picture is DIR/NAME.svg for the first score's NAME, in a folder
made for the buffer, not beside the file."
  (skip-unless (image-type-available-p 'svg))
  (notasi-mode-tests--with-piece
   (lambda (ctx)
     (let* ((run (car (last (notasi-mode-tests--render-runs
                             (plist-get ctx :log)))))
            (out (notasi-mode-tests--out run)))
       (should (equal (file-name-nondirectory out) "full.svg"))
       (should-not (file-in-directory-p out (plist-get ctx :dir)))
       (should (file-exists-p out))))))

(ert-deftest notasi-mode-test-output-piece-svg-without-score ()
  "Without a `score' form, the picture is DIR/piece.svg."
  (skip-unless (image-type-available-p 'svg))
  (notasi-mode-tests--with-piece
   (lambda (ctx)
     (let ((run (car (last (notasi-mode-tests--render-runs
                            (plist-get ctx :log))))))
       (should (equal (file-name-nondirectory (notasi-mode-tests--out run))
                      "piece.svg"))))
   :text notasi-mode-tests--no-score))

(ert-deftest notasi-mode-test-draws-first-score-without-score-option ()
  "The first score is drawn, so `--score' is never passed."
  (notasi-mode-tests--with-piece
   (lambda (ctx)
     (with-current-buffer (plist-get ctx :buffer)
       (notasi-mode-tests--wait (notasi-preview-redraw)))
     (let ((runs (notasi-mode-tests--render-runs (plist-get ctx :log))))
       (should runs)
       (dolist (run runs)
         (should-not (member "--score" run)))))))

(ert-deftest notasi-mode-test-new-drawing-stops-running-one ()
  "A drawing still running when a new one starts is stopped, and the
picture and header line are the new drawing's."
  (notasi-mode-tests--with-piece
   (lambda (ctx)
     (with-current-buffer (plist-get ctx :buffer)
       (let ((slow (let ((process-environment
                          (cons "FAKE_NOTASI_SLEEP=5" process-environment)))
                     (notasi-preview-redraw))))
         (should (process-live-p slow))
         (let ((fast (notasi-preview-redraw)))
           (should-not (eq slow fast))
           (notasi-mode-tests--wait fast)
           (should-not (process-live-p slow))
           ;; The stopped drawing's sentinel changes nothing.
           (dotimes (_ 10) (accept-process-output nil 0.02))
           (let ((header (notasi-mode-tests--header
                          (notasi-mode-tests--preview
                           (plist-get ctx :file)))))
             (should (string-search "Gilak: pangawit — full" header))
             (should-not (notasi-mode-tests--drawing-p header)))
           (should (notasi-mode-tests--shown (plist-get ctx :file)))))))))

(ert-deftest notasi-mode-test-picture-reloaded-fresh ()
  "Each drawing's picture is shown, not an earlier one."
  (notasi-mode-tests--with-piece
   (lambda (ctx)
     (with-current-buffer (plist-get ctx :buffer)
       (should (string-search
                (format "%d lines" (count-lines (point-min) (point-max)))
                (notasi-mode-tests--shown (plist-get ctx :file))))
       (goto-char (point-max))
       (insert ";; one\n;; two\n;; three\n")
       (notasi-mode-tests--wait (notasi-preview-redraw))
       (should (string-search
                (format "%d lines" (count-lines (point-min) (point-max)))
                (notasi-mode-tests--shown (plist-get ctx :file))))))))

;;;;; The preview buffer and its header line

(ert-deftest notasi-mode-test-preview-buffer ()
  "The preview is a read-only buffer, *notasi: FILE*, showing the picture."
  (notasi-mode-tests--with-piece
   (lambda (ctx)
     (let ((preview (notasi-mode-tests--preview (plist-get ctx :file))))
       (should (buffer-live-p preview))
       (should (equal (buffer-name preview) "*notasi: gilak.nts*"))
       (should (buffer-local-value 'buffer-read-only preview))
       (should (string-search "fake-notasi"
                              (notasi-mode-tests--shown
                               (plist-get ctx :file))))))))

(ert-deftest notasi-mode-test-header-title-and-score ()
  "The header line is TITLE — NAME, NAME the first score's."
  (notasi-mode-tests--with-piece
   (lambda (ctx)
     (let ((header (notasi-mode-tests--header
                    (notasi-mode-tests--preview (plist-get ctx :file)))))
       (should (string-search "Gilak: pangawit — full" header))
       (should-not (notasi-mode-tests--drawing-p header))))))

(ert-deftest notasi-mode-test-header-title-alone-without-score ()
  "Without `score' forms, the header line is the title alone."
  (notasi-mode-tests--with-piece
   (lambda (ctx)
     (let ((header (notasi-mode-tests--header
                    (notasi-mode-tests--preview (plist-get ctx :file)))))
       (should (string-search "Gilak: pangawit" header))
       (should-not (string-search "—" header))))
   :text notasi-mode-tests--no-score))

(ert-deftest notasi-mode-test-header-says-drawing ()
  "The header line says \"drawing…\" while a drawing is made, and not after."
  (notasi-mode-tests--with-piece
   (lambda (ctx)
     (let ((preview (notasi-mode-tests--preview (plist-get ctx :file))))
       (with-current-buffer (plist-get ctx :buffer)
         (let ((p (let ((process-environment
                         (cons "FAKE_NOTASI_SLEEP=1" process-environment)))
                    (notasi-preview-redraw))))
           (should (process-live-p p))
           (should (notasi-mode-tests--drawing-p
                    (notasi-mode-tests--header preview)))
           (notasi-mode-tests--wait p)
           (should-not (notasi-mode-tests--drawing-p
                        (notasi-mode-tests--header preview)))))))))

;;;;; A failed drawing

(ert-deftest notasi-mode-test-failure-keeps-picture-and-shows-message ()
  "A failed drawing keeps the last picture, and the header line shows
notasi's message with the real file's name for the hidden file's."
  (notasi-mode-tests--with-piece
   (lambda (ctx)
     (let* ((file (plist-get ctx :file))
            (preview (notasi-mode-tests--preview file))
            (before (notasi-mode-tests--shown file)))
       (should before)
       (with-current-buffer (plist-get ctx :buffer)
         (goto-char (point-max))
         (insert ";; MISTAKE\n")
         (let ((p (notasi-preview-redraw)))
           (notasi-mode-tests--wait p)
           (should (= (process-exit-status p) 1))))
       (should (equal (notasi-mode-tests--shown file) before))
       (let ((header (notasi-mode-tests--header preview)))
         (should (string-search "gilak.nts:3: a mistake" header))
         (should-not (string-search ".notasi-preview" header))
         (should-not (notasi-mode-tests--drawing-p header)))
       (should-not (notasi-mode-tests--hidden-files (plist-get ctx :dir)))))))

(ert-deftest notasi-mode-test-good-drawing-after-failure ()
  "After a failed drawing, a good one shows its picture and the title."
  (notasi-mode-tests--with-piece
   (lambda (ctx)
     (let ((preview (notasi-mode-tests--preview (plist-get ctx :file))))
       (with-current-buffer (plist-get ctx :buffer)
         (goto-char (point-max))
         (insert ";; MISTAKE\n")
         (notasi-mode-tests--wait (notasi-preview-redraw))
         (delete-region (line-beginning-position 0) (point-max))
         (notasi-mode-tests--wait (notasi-preview-redraw)))
       (let ((header (notasi-mode-tests--header preview)))
         (should (string-search "Gilak: pangawit — full" header))
         (should-not (string-search "mistake" header)))))))

;;;;; notasi --version

(defconst notasi-mode-tests--older-message
  "This notasi (0.3.0) is older than notasi-mode (0.4.0)"
  "What the preview says when notasi 0.3.0 is found.")

(ert-deftest notasi-mode-test-older-notasi-said-and-still-draws ()
  "An older notasi is said in the preview, and the score is still drawn."
  (let ((program (notasi-mode-tests--copy-fake)))
    (unwind-protect
        (notasi-mode-tests--with-piece
         (lambda (ctx)
           (let ((preview (notasi-mode-tests--preview (plist-get ctx :file))))
             (should (string-search notasi-mode-tests--older-message
                                    (notasi-mode-tests--says preview)))
             (should (notasi-mode-tests--shown (plist-get ctx :file)))))
         :program program :env '("FAKE_NOTASI_VERSION=0.3.0"))
      (delete-directory (file-name-directory program) t))))

(ert-deftest notasi-mode-test-same-version-not-said ()
  "notasi 0.4.0-dev is not older than the package: nothing is said."
  (let ((program (notasi-mode-tests--copy-fake)))
    (unwind-protect
        (notasi-mode-tests--with-piece
         (lambda (ctx)
           (should (notasi-mode-tests--version-runs (plist-get ctx :log)))
           (should-not
            (string-search "older"
                           (notasi-mode-tests--says
                            (notasi-mode-tests--preview
                             (plist-get ctx :file))))))
         :program program)
      (delete-directory (file-name-directory program) t))))

(ert-deftest notasi-mode-test-versions-compared-as-numbers ()
  "notasi 0.10.0 is newer than 0.4.0: versions are compared as numbers."
  (let ((program (notasi-mode-tests--copy-fake)))
    (unwind-protect
        (notasi-mode-tests--with-piece
         (lambda (ctx)
           (should (notasi-mode-tests--version-runs (plist-get ctx :log)))
           (should-not
            (string-search "older"
                           (notasi-mode-tests--says
                            (notasi-mode-tests--preview
                             (plist-get ctx :file))))))
         :program program :env '("FAKE_NOTASI_VERSION=0.10.0"))
      (delete-directory (file-name-directory program) t))))

(ert-deftest notasi-mode-test-version-run-once-per-program ()
  "`notasi --version' is run once for a program, however often it draws."
  (let ((program (notasi-mode-tests--copy-fake)))
    (unwind-protect
        (notasi-mode-tests--with-piece
         (lambda (ctx)
           (with-current-buffer (plist-get ctx :buffer)
             (notasi-mode-tests--wait (notasi-preview-redraw))
             (notasi-mode-tests--wait (notasi-preview-redraw)))
           (should (= (length (notasi-mode-tests--render-runs
                               (plist-get ctx :log)))
                      3))
           (should (= (length (notasi-mode-tests--version-runs
                               (plist-get ctx :log)))
                      1)))
         :program program)
      (delete-directory (file-name-directory program) t))))

;;;;; Opening a file, and the preview window

(ert-deftest notasi-mode-test-opening-file-opens-preview-and-draws ()
  "Opening a .nts file turns on the mode, opens the preview beside the
text, and draws; the text's window stays selected."
  (notasi-mode-tests--with-piece
   (lambda (ctx)
     (let* ((buffer (plist-get ctx :buffer))
            (preview (notasi-mode-tests--preview (plist-get ctx :file))))
       (should (eq (buffer-local-value 'major-mode buffer) 'notasi-mode))
       (should (buffer-live-p preview))
       (should (get-buffer-window preview))
       (should (eq (window-buffer (selected-window)) buffer))
       (should (string-search "fake-notasi"
                              (notasi-mode-tests--shown
                               (plist-get ctx :file))))))
   :select t))

(ert-deftest notasi-mode-test-opening-file-noselect-draws ()
  "Visiting a .nts file without showing it still draws its preview."
  (notasi-mode-tests--with-piece
   (lambda (ctx)
     (should (eq (buffer-local-value 'major-mode (plist-get ctx :buffer))
                 'notasi-mode))
     (should (notasi-mode-tests--render-runs (plist-get ctx :log)))
     (should (notasi-mode-tests--shown (plist-get ctx :file))))))

(ert-deftest notasi-mode-test-picture-fits-window-width ()
  "The picture is no wider than the preview window."
  (notasi-mode-tests--with-piece
   (lambda (ctx)
     (let* ((preview (notasi-mode-tests--preview (plist-get ctx :file)))
            (window (get-buffer-window preview))
            (image (notasi-mode-tests--image preview)))
       (should window)
       (should image)
       (let ((width (or (plist-get (cdr image) :max-width)
                        (plist-get (cdr image) :width))))
         (should (numberp width))
         (should (<= width (window-body-width window t))))))
   :select t))

(ert-deftest notasi-mode-test-toggle-hides-and-shows-preview ()
  "`notasi-preview-toggle' hides the preview window, then shows it."
  (notasi-mode-tests--with-piece
   (lambda (ctx)
     (let* ((buffer (plist-get ctx :buffer))
            (preview (notasi-mode-tests--preview (plist-get ctx :file))))
       (should (get-buffer-window preview))
       (with-selected-window (get-buffer-window buffer)
         (notasi-preview-toggle))
       (should-not (get-buffer-window preview))
       (should (get-buffer-window buffer))
       (with-selected-window (get-buffer-window buffer)
         (notasi-preview-toggle))
       (should (get-buffer-window preview))
       (should (get-buffer-window buffer))))
   :select t))

(ert-deftest notasi-mode-test-toggle-shows-hidden-preview ()
  "When the preview window isn't shown, `notasi-preview-toggle' shows it."
  (notasi-mode-tests--with-piece
   (lambda (ctx)
     (let* ((buffer (plist-get ctx :buffer))
            (preview (notasi-mode-tests--preview (plist-get ctx :file))))
       (delete-other-windows (get-buffer-window buffer))
       (should-not (get-buffer-window preview))
       (with-selected-window (get-buffer-window buffer)
         (notasi-preview-toggle))
       (should (get-buffer-window preview))))
   :select t))

;;;;; Writing the score to a file

(ert-deftest notasi-mode-test-write-score ()
  "`notasi-write-score' writes the current score to the file named."
  (let* ((outdir (make-temp-file "notasi-mode-write" t))
         (target (expand-file-name "gilak-full.pdf" outdir)))
    (unwind-protect
        (notasi-mode-tests--with-piece
         (lambda (ctx)
           (with-current-buffer (plist-get ctx :buffer)
             (let ((p (notasi-write-score target)))
               (notasi-mode-tests--wait (and (processp p) p))))
           (should (file-exists-p target))
           (let ((run (car (last (notasi-mode-tests--render-runs
                                  (plist-get ctx :log))))))
             (should (equal (notasi-mode-tests--out run) target)))
           (should-not (notasi-mode-tests--hidden-files (plist-get ctx :dir)))))
      (delete-directory outdir t))))

;;;;; Keys, commands and settings

(ert-deftest notasi-mode-test-preview-keys ()
  "C-c C-c redraws, C-c C-p shows or hides the preview, C-c C-o writes."
  (should (eq (lookup-key notasi-mode-map (kbd "C-c C-c"))
              'notasi-preview-redraw))
  (should (eq (lookup-key notasi-mode-map (kbd "C-c C-p"))
              'notasi-preview-toggle))
  (should (eq (lookup-key notasi-mode-map (kbd "C-c C-o"))
              'notasi-write-score)))

(ert-deftest notasi-mode-test-preview-commands ()
  "The three commands are commands with docstrings."
  (dolist (command '(notasi-preview-redraw notasi-preview-toggle
                     notasi-write-score))
    (should (commandp command))
    (should (documentation command))))

(ert-deftest notasi-mode-test-find-program-documented ()
  "`notasi-find-program' is a function with a docstring."
  (should (functionp 'notasi-find-program))
  (should (documentation 'notasi-find-program)))

(ert-deftest notasi-mode-test-preview-settings ()
  "`notasi-program' and `notasi-preview-side' are settings in the
`notasi' group, with docstrings; `notasi-program' is unset at first."
  (dolist (setting '(notasi-program notasi-preview-side))
    (should (custom-variable-p setting))
    (should (assq setting (get 'notasi 'custom-group)))
    (should (documentation-property setting 'variable-documentation)))
  (should (null (eval (car (get 'notasi-program 'standard-value)) t))))

;;;;; Cleaning up

(ert-deftest notasi-mode-test-kill-buffer-cleans-up ()
  "Killing the .nts buffer kills its preview and removes the temporary
folder; no hidden file is left."
  (let (outdir preview dir)
    (notasi-mode-tests--with-piece
     (lambda (ctx)
       (let ((run (car (last (notasi-mode-tests--render-runs
                              (plist-get ctx :log))))))
         (setq outdir (file-name-directory (notasi-mode-tests--out run))
               preview (notasi-mode-tests--preview (plist-get ctx :file))
               dir (plist-get ctx :dir))
         (should (file-directory-p outdir))
         (should (buffer-live-p preview))
         (with-current-buffer (plist-get ctx :buffer)
           (set-buffer-modified-p nil))
         (kill-buffer (plist-get ctx :buffer))
         (should-not (buffer-live-p preview))
         (should-not (file-exists-p outdir))
         (should-not (notasi-mode-tests--hidden-files dir)))))))

(ert-deftest notasi-mode-test-kill-buffer-closes-preview-window ()
  "Killing the .nts buffer closes its preview's window, so no split is
left showing another buffer."
  (notasi-mode-tests--with-piece
   (lambda (ctx)
     (let* ((buffer (plist-get ctx :buffer))
            (preview (notasi-mode-tests--preview (plist-get ctx :file))))
       (should (get-buffer-window preview))
       (should (= (length (window-list)) 2))
       (with-current-buffer buffer (set-buffer-modified-p nil))
       (kill-buffer buffer)
       (should-not (buffer-live-p preview))
       (should (= (length (window-list)) 1))))
   :select t))

(ert-deftest notasi-mode-test-kill-buffer-keeps-only-window ()
  "When the preview is the frame's only window, killing the .nts buffer
kills the preview but leaves the window."
  (notasi-mode-tests--with-piece
   (lambda (ctx)
     (let* ((buffer (plist-get ctx :buffer))
            (preview (notasi-mode-tests--preview (plist-get ctx :file))))
       (select-window (get-buffer-window preview))
       (delete-other-windows)
       (with-current-buffer buffer (set-buffer-modified-p nil))
       (kill-buffer buffer)
       (should-not (buffer-live-p preview))
       (should (= (length (window-list)) 1))
       (should (window-live-p (selected-window)))))
   :select t))

(ert-deftest notasi-mode-test-kill-buffer-while-drawing ()
  "Killing the .nts buffer during a drawing stops it and cleans up."
  (notasi-mode-tests--with-piece
   (lambda (ctx)
     (let* ((run (car (last (notasi-mode-tests--render-runs
                             (plist-get ctx :log)))))
            (outdir (file-name-directory (notasi-mode-tests--out run)))
            (p (with-current-buffer (plist-get ctx :buffer)
                 (let ((process-environment
                        (cons "FAKE_NOTASI_SLEEP=5" process-environment)))
                   (notasi-preview-redraw)))))
       (should (process-live-p p))
       (with-current-buffer (plist-get ctx :buffer)
         (set-buffer-modified-p nil))
       (kill-buffer (plist-get ctx :buffer))
       (dotimes (_ 10) (accept-process-output nil 0.02))
       (should-not (process-live-p p))
       (should-not (notasi-mode-tests--preview (plist-get ctx :file)))
       (should-not (file-exists-p outdir))
       (should-not (notasi-mode-tests--hidden-files (plist-get ctx :dir)))))))

(ert-deftest notasi-mode-test-no-file-no-drawing ()
  "A `notasi-mode' buffer that visits no file draws nothing."
  (let ((notasi-program notasi-mode-tests--fake)
        (before (process-list)))
    (with-temp-buffer
      (insert notasi-mode-tests--gilak)
      (notasi-mode)
      (dotimes (_ 5) (accept-process-output nil 0.02))
      (should (equal (process-list) before))
      (should-not (seq-find (lambda (b)
                              (string-prefix-p "*notasi: " (buffer-name b)))
                            (buffer-list))))))

;;;;; A real drawing

(ert-deftest notasi-mode-test-real-drawing ()
  "scripts/notasi draws jaya-semara.nts (a copy, in a temporary folder).
Skipped when Guile or Typst is missing."
  (skip-unless (and (executable-find "guile") (executable-find "typst")))
  (unless (fboundp 'notasi-preview-redraw)
    (error "notasi-mode can't draw yet: no `notasi-preview-redraw'"))
  (let* ((dir (make-temp-file "notasi-mode-real" t))
         (file (expand-file-name "jaya-semara.nts" dir))
         (notasi-program (expand-file-name "scripts/notasi"
                                           notasi-mode-tests--repo))
         buffer)
    (unwind-protect
        (progn
          (copy-file (expand-file-name "examples/gallery/jaya-semara.nts"
                                       notasi-mode-tests--repo)
                     file)
          ;; Opening the file draws it.
          (setq buffer (find-file-noselect file))
          (let ((end (+ (float-time) 120)))
            (while (and (not (notasi-mode-tests--shown file))
                        (< (float-time) end))
              (accept-process-output nil 0.1)))
          (notasi-mode-tests--wait nil 120)
          (let ((preview (notasi-mode-tests--preview file)))
            (should (buffer-live-p preview))
            (should (string-search "Jaya Semara: pangecet — full"
                                   (notasi-mode-tests--header preview)))
            (should (string-match-p "<svg"
                                    (or (notasi-mode-tests--shown file) ""))))
          (should-not (notasi-mode-tests--hidden-files dir)))
      (when (buffer-live-p buffer)
        (with-current-buffer buffer (set-buffer-modified-p nil))
        (kill-buffer buffer))
      (ignore-errors (notasi-mode-tests--wait nil 120))
      (delete-directory dir t))))

;;;; The preview: live (slice feat/emacs-preview-live)

;; Written from 08 ("The preview", "The score shown" and "Slices", item
;; 2 and its decided list) before the code.  Choices where 08 leaves
;; room:
;;
;; - The user's actions are simulated with `ert-simulate-command', so
;;   `pre-command-hook' and `post-command-hook' run around each, as in
;;   the command loop: moving the cursor is `goto-char', typing is a
;;   command that inserts (so `after-change-functions' run too), saving
;;   is `save-buffer', choosing is `notasi-choose-score'.  The buffer is
;;   shown in the selected window (`find-file').
;; - The pause runs on a timer (`run-at-time'), restarted by each change;
;;   it fires while the tests wait in `accept-process-output'.  The tests
;;   bind `notasi-preview-delay' to 0.1 s (0.3 or 0.5 s where the tests
;;   look before it runs out), and each setting with `let', in effect
;;   while the mode decides.
;; - Moving the cursor into a score that has no kept picture draws it,
;;   at once or after the pause: the tests wait up to 2 s.  Switching
;;   back to a kept picture shows it within 0.05 s.
;; - "No drawing" is checked by waiting 0.5 s (five pauses) and finding
;;   no new run in the fake's log.
;; - `(notasi-choose-score nil)' goes back to following the cursor; the
;;   tests then move the cursor (inside the same score) before expecting
;;   the cursor's score, so whether choosing nil switches at once is
;;   left open.
;; - A chosen score that disappears goes back to following the cursor by
;;   the drawing that follows the change (after the pause); that drawing
;;   is of the cursor's score, never of the vanished one.
;; - Interactively, `notasi-choose-score' reads with `completing-read';
;;   "follow the cursor" is a candidate matching that phrase, whatever
;;   its case.
;; - `notasi-preview-delay''s customisation type accepts 0.5 and 2; the
;;   two others are `boolean'.
;; - With `notasi-preview-on-open' off, opening a file starts no drawing
;;   and makes no preview buffer; what happens later is not tested.
;; - With `notasi-auto-preview' off the file still draws on opening (that
;;   is `notasi-preview-on-open'); the tests turn it off once the file
;;   is open.

(require 'ert-x)
(require 'wid-edit)

(defvar notasi-preview-delay)
(defvar notasi-auto-preview)
(defvar notasi-preview-on-open)

(defconst notasi-mode-tests--three
  "(piece \"Gilak: pangawit\" :colotomy gilak :pickup 1)

(use gong-kebyar)

(score full :fill none
  (group \"Ugal\" ugal))

(pattern pokok :instrument ugal
  _ i2 _ a1)

(score kotekan
  (group \"Ugal\" ugal))

(part :instrument ugal
  @pokok)

(score third
  (group \"Ugal\" ugal))
"
  "A piece with three scores, `full' (the first), `kotekan' and `third'.")

;;;;; Helpers for the live preview

(defun notasi-mode-tests--call (function)
  "Call FUNCTION: a command, for `notasi-mode-tests--command'."
  (interactive (list #'ignore))
  (funcall function))

(defun notasi-mode-tests--command (function)
  "Call FUNCTION as a command, with the command loop's hooks around it."
  (ert-simulate-command (list #'notasi-mode-tests--call function)))

(defun notasi-mode-tests--place (where &optional offset)
  "Return the position at the end of the first WHERE, plus OFFSET.
WHERE is a string, or a position."
  (+ (if (stringp where)
         (save-excursion
           (goto-char (point-min))
           (search-forward where))
       where)
     (or offset 0)))

(defun notasi-mode-tests--move (where &optional offset)
  "Move the cursor, as the user would, to WHERE plus OFFSET.
See `notasi-mode-tests--place'."
  (ert-simulate-command
   (list #'goto-char (notasi-mode-tests--place where offset))))

(defun notasi-mode-tests--type (text &optional where)
  "Type TEXT, as the user would, at WHERE (see `notasi-mode-tests--move').
Without WHERE, at the cursor."
  (when where (notasi-mode-tests--move where))
  (notasi-mode-tests--command (lambda () (insert text))))

(defun notasi-mode-tests--pause (seconds)
  "Let timers, processes and sentinels run for SECONDS."
  (let ((end (+ (float-time) seconds)))
    (while (< (float-time) end)
      (accept-process-output nil 0.02))))

(defun notasi-mode-tests--wait-until (predicate &optional timeout)
  "Wait until PREDICATE returns non-nil, at most TIMEOUT seconds (2).
Return its value, or nil."
  (let ((end (+ (float-time) (or timeout 2)))
        value)
    (while (and (not (setq value (funcall predicate)))
                (< (float-time) end))
      (accept-process-output nil 0.02))
    value))

(defun notasi-mode-tests--count (log)
  "Return how many render runs LOG records."
  (length (notasi-mode-tests--render-runs log)))

(defun notasi-mode-tests--runs-after (log count)
  "Return the render runs in LOG after the first COUNT."
  (nthcdr count (notasi-mode-tests--render-runs log)))

(defun notasi-mode-tests--score-of (run)
  "Return the `--score' of the render RUN, or nil."
  (notasi-mode-tests--option run "--score"))

(defun notasi-mode-tests--next-drawing (log count &optional timeout)
  "Wait for a render run in LOG after the first COUNT, then for it to end.
Give up waiting for it after TIMEOUT seconds (2).  Return the new runs."
  (when (notasi-mode-tests--wait-until
         (lambda () (notasi-mode-tests--runs-after log count))
         timeout)
    (notasi-mode-tests--wait))
  (notasi-mode-tests--runs-after log count))

(defun notasi-mode-tests--must-draw (log)
  "Wait for a new drawing recorded in LOG, and for it to end.
Fail at once if none starts within 2 seconds."
  (should (notasi-mode-tests--next-drawing
           log (notasi-mode-tests--count log))))

(defun notasi-mode-tests--live-header (ctx)
  "Return the header line of the preview of the piece in CTX."
  (notasi-mode-tests--header
   (notasi-mode-tests--preview (plist-get ctx :file))))

(cl-defun notasi-mode-tests--with-live-piece
    (function &key (delay 0.1) env)
  "Open the three-score piece in the selected window and call FUNCTION.
As `notasi-mode-tests--with-piece', with `notasi-preview-delay' DELAY
and ENV added to the environment."
  (let ((notasi-preview-delay delay))
    (notasi-mode-tests--with-piece
     function :text notasi-mode-tests--three :select t :env env)))

;;;;; Writing the score shown to a file

(defun notasi-mode-tests--write-run (ctx file)
  "Write the score with `notasi-write-score' to FILE; return its render run.
CTX is the plist of `notasi-mode-tests--with-piece'."
  (let ((before (notasi-mode-tests--count (plist-get ctx :log))))
    (notasi-write-score file)
    (should (file-exists-p file))
    (let ((runs (notasi-mode-tests--runs-after (plist-get ctx :log) before)))
      (should (= (length runs) 1))
      (car runs))))

(ert-deftest notasi-mode-test-write-score-at-cursor ()
  "`notasi-write-score' writes the score the cursor is in, not the first."
  (let ((outdir (make-temp-file "notasi-mode-write" t)))
    (unwind-protect
        (notasi-mode-tests--with-live-piece
         (lambda (ctx)
           (notasi-mode-tests--move "(score kotekan")
           (notasi-mode-tests--must-draw (plist-get ctx :log))
           (let ((run (notasi-mode-tests--write-run
                       ctx (expand-file-name "kotekan.pdf" outdir))))
             (should (equal (notasi-mode-tests--score-of run) "kotekan")))))
      (delete-directory outdir t))))

(ert-deftest notasi-mode-test-write-score-chosen ()
  "`notasi-write-score' writes the score chosen with `notasi-choose-score'."
  (let ((outdir (make-temp-file "notasi-mode-write" t)))
    (unwind-protect
        (notasi-mode-tests--with-live-piece
         (lambda (ctx)
           (notasi-choose-score "third")
           (notasi-mode-tests--wait)
           (notasi-mode-tests--move "(score kotekan")
           (let ((run (notasi-mode-tests--write-run
                       ctx (expand-file-name "third.svg" outdir))))
             (should (equal (notasi-mode-tests--score-of run) "third")))))
      (delete-directory outdir t))))

(ert-deftest notasi-mode-test-write-score-first-no-option ()
  "`notasi-write-score' writes the first score without `--score'."
  (let ((outdir (make-temp-file "notasi-mode-write" t)))
    (unwind-protect
        (notasi-mode-tests--with-live-piece
         (lambda (ctx)
           (let ((run (notasi-mode-tests--write-run
                       ctx (expand-file-name "full.png" outdir))))
             (should-not (member "--score" run)))))
      (delete-directory outdir t))))

(ert-deftest notasi-mode-test-write-score-mistake ()
  "`notasi-write-score' shows notasi's message when the drawing fails."
  (let ((outdir (make-temp-file "notasi-mode-write" t)))
    (unwind-protect
        (notasi-mode-tests--with-piece
         (lambda (_ctx)
           (let ((since (notasi-mode-tests--messages-end)))
             (notasi-write-score (expand-file-name "out.pdf" outdir))
             (should (= 1 (notasi-mode-tests--echoed
                           since "gilak.nts:3: a mistake"))))
           (should-not (file-exists-p (expand-file-name "out.pdf" outdir))))
         :text (concat notasi-mode-tests--gilak ";; MISTAKE\n"))
      (delete-directory outdir t))))

;;;;; Settings and keys

(ert-deftest notasi-mode-test-live-settings ()
  "`notasi-preview-on-open', `notasi-auto-preview' and
`notasi-preview-delay' are settings in the `notasi' group, with
docstrings."
  (dolist (setting '(notasi-preview-on-open notasi-auto-preview
                     notasi-preview-delay))
    (should (custom-variable-p setting))
    (should (assq setting (get 'notasi 'custom-group)))
    (should (documentation-property setting 'variable-documentation))))

(ert-deftest notasi-mode-test-live-settings-on-by-default ()
  "`notasi-preview-on-open' and `notasi-auto-preview' are on or off,
and on by default."
  (dolist (setting '(notasi-preview-on-open notasi-auto-preview))
    (should (custom-variable-p setting))
    (should (eq (get setting 'custom-type) 'boolean))
    (should (eq (eval (car (get setting 'standard-value)) t) t))))

(ert-deftest notasi-mode-test-preview-delay-setting ()
  "`notasi-preview-delay' is a number of seconds, 1 by default."
  (should (custom-variable-p 'notasi-preview-delay))
  (let ((default (eval (car (get 'notasi-preview-delay 'standard-value)) t))
        (widget (widget-convert (get 'notasi-preview-delay 'custom-type))))
    (should (numberp default))
    (should (= default 1))
    (should (widget-apply widget :match 0.5))
    (should (widget-apply widget :match 2))))

(ert-deftest notasi-mode-test-choose-score-key ()
  "C-c C-s is `notasi-choose-score', a command with a docstring."
  (should (eq (lookup-key notasi-mode-map (kbd "C-c C-s"))
              'notasi-choose-score))
  (should (commandp 'notasi-choose-score))
  (should (documentation 'notasi-choose-score)))

;;;;; Redrawing on a pause and on saving

(ert-deftest notasi-mode-test-typing-redraws-after-pause ()
  "Typing redraws once the pause has run out, not before, without saving."
  (notasi-mode-tests--with-live-piece
   (lambda (ctx)
     (let* ((log (plist-get ctx :log))
            (before (notasi-mode-tests--count log)))
       (notasi-mode-tests--type ";; typed\n" (point-max))
       (notasi-mode-tests--pause 0.25)
       (should-not (notasi-mode-tests--runs-after log before))
       (let ((runs (notasi-mode-tests--next-drawing log before)))
         (should (= (length runs) 1))
         (should-not (notasi-mode-tests--score-of (car runs))))
       (should (buffer-modified-p))
       (should (string-search
                (format "%d lines" (count-lines (point-min) (point-max)))
                (notasi-mode-tests--shown (plist-get ctx :file))))))
   :delay 0.5))

(ert-deftest notasi-mode-test-quick-changes-draw-once ()
  "Changes closer together than the pause give one drawing, of the
text after the last change."
  (notasi-mode-tests--with-live-piece
   (lambda (ctx)
     (let* ((log (plist-get ctx :log))
            (before (notasi-mode-tests--count log)))
       (notasi-mode-tests--move (point-max))
       (dotimes (i 4)
         (notasi-mode-tests--type (format ";; change %d\n" i))
         (notasi-mode-tests--pause 0.1))
       (should-not (notasi-mode-tests--runs-after log before))
       (notasi-mode-tests--next-drawing log before)
       (notasi-mode-tests--pause 0.5)
       (should (= (length (notasi-mode-tests--runs-after log before)) 1))
       (should (equal (with-temp-buffer
                        (insert-file-contents (plist-get ctx :input))
                        (buffer-string))
                      (buffer-string)))))
   :delay 0.3))

(ert-deftest notasi-mode-test-moving-cursor-does-not-redraw ()
  "Moving the cursor, without leaving the score shown for another
score, never redraws."
  (notasi-mode-tests--with-live-piece
   (lambda (ctx)
     (let* ((log (plist-get ctx :log))
            (before (notasi-mode-tests--count log)))
       (notasi-mode-tests--move "(score full")
       (notasi-mode-tests--move "(pattern pokok")
       (notasi-mode-tests--move "\n\n(part" -6)
       (notasi-mode-tests--move (point-max))
       (notasi-mode-tests--move (point-min))
       (notasi-mode-tests--pause 0.5)
       (should-not (notasi-mode-tests--runs-after log before))))))

(ert-deftest notasi-mode-test-saving-redraws ()
  "Saving redraws, even when the text has not changed."
  (notasi-mode-tests--with-live-piece
   (lambda (ctx)
     (let* ((log (plist-get ctx :log))
            (before (notasi-mode-tests--count log)))
       (set-buffer-modified-p t)
       (ert-simulate-command '(save-buffer))
       (should-not (buffer-modified-p))
       (should (= (length (notasi-mode-tests--next-drawing log before)) 1))))))

(ert-deftest notasi-mode-test-auto-preview-off ()
  "With `notasi-auto-preview' off, neither a pause nor saving redraws;
`notasi-preview-redraw' still does."
  (notasi-mode-tests--with-live-piece
   (lambda (ctx)
     (let* ((log (plist-get ctx :log))
            (before (notasi-mode-tests--count log))
            (notasi-auto-preview nil))
       (notasi-mode-tests--type ";; typed\n" (point-max))
       (notasi-mode-tests--pause 0.5)
       (should-not (notasi-mode-tests--runs-after log before))
       (ert-simulate-command '(save-buffer))
       (notasi-mode-tests--pause 0.5)
       (should-not (notasi-mode-tests--runs-after log before))
       (notasi-mode-tests--wait (notasi-preview-redraw))
       (should (= (length (notasi-mode-tests--runs-after log before)) 1))))))

(ert-deftest notasi-mode-test-preview-on-open-off ()
  "With `notasi-preview-on-open' off, opening a file draws nothing and
shows no preview."
  (let* ((dir (make-temp-file "notasi-mode-piece" t))
         (aux (make-temp-file "notasi-mode-aux" t))
         (file (expand-file-name "gilak.nts" dir))
         (log (expand-file-name "fake.log" aux))
         (process-environment (cons (concat "FAKE_NOTASI_LOG=" log)
                                    process-environment))
         (notasi-program notasi-mode-tests--fake)
         (notasi-preview-on-open nil)
         buffer)
    (with-temp-file file (insert notasi-mode-tests--three))
    (unwind-protect
        (progn
          (delete-other-windows)
          (setq buffer (find-file file))
          (should (eq (buffer-local-value 'major-mode buffer) 'notasi-mode))
          (notasi-mode-tests--pause 0.5)
          (should-not (notasi-mode-tests--render-runs log))
          (should-not (notasi-mode-tests--preview file))
          (should (equal (length (window-list)) 1)))
      (when (buffer-live-p buffer)
        (with-current-buffer buffer (set-buffer-modified-p nil))
        (kill-buffer buffer))
      (ignore-errors (notasi-mode-tests--wait))
      (delete-other-windows)
      (delete-directory dir t)
      (delete-directory aux t))))

;;;;; The score shown

(ert-deftest notasi-mode-test-cursor-into-score-draws-it ()
  "Moving the cursor into (score kotekan …) draws it with
`--score kotekan', and the header line names it."
  (notasi-mode-tests--with-live-piece
   (lambda (ctx)
     (let* ((log (plist-get ctx :log))
            (before (notasi-mode-tests--count log)))
       (notasi-mode-tests--move "(score kotekan")
       (let ((runs (notasi-mode-tests--next-drawing log before)))
         (should runs)
         (should (equal (notasi-mode-tests--score-of (car (last runs)))
                        "kotekan")))
       (let ((header (notasi-mode-tests--live-header ctx)))
         (should (string-search "Gilak: pangawit — kotekan" header))
         (should-not (string-search "(chosen)" header))
         (should-not (notasi-mode-tests--drawing-p header)))
       (should (string-search "fake-notasi: kotekan,"
                              (notasi-mode-tests--shown
                               (plist-get ctx :file))))))))

(ert-deftest notasi-mode-test-moving-out-keeps-score ()
  "Moving out of a score, into a pattern, a part or between forms,
keeps it shown, without drawing."
  (notasi-mode-tests--with-live-piece
   (lambda (ctx)
     (let ((log (plist-get ctx :log)))
       (notasi-mode-tests--move "(score kotekan")
       (notasi-mode-tests--must-draw log)
       (let ((before (notasi-mode-tests--count log)))
         (notasi-mode-tests--move "(part :instrument")
         (notasi-mode-tests--move "(pattern pokok")
         (notasi-mode-tests--move "\n\n(part" -6)
         (notasi-mode-tests--move (point-max))
         (notasi-mode-tests--pause 0.5)
         (should-not (notasi-mode-tests--runs-after log before)))
       (should (string-search "Gilak: pangawit — kotekan"
                              (notasi-mode-tests--live-header ctx)))
       (should (string-search "fake-notasi: kotekan,"
                              (notasi-mode-tests--shown
                               (plist-get ctx :file))))))))

(ert-deftest notasi-mode-test-typing-in-score-redraws-it ()
  "Typing in a score that isn't the first redraws it with `--score'."
  (notasi-mode-tests--with-live-piece
   (lambda (ctx)
     (let ((log (plist-get ctx :log)))
       (notasi-mode-tests--move "(score kotekan")
       (notasi-mode-tests--must-draw log)
       (let ((before (notasi-mode-tests--count log)))
         (notasi-mode-tests--type "\n  ;; typed")
         (let ((runs (notasi-mode-tests--next-drawing log before)))
           (should (= (length runs) 1))
           (should (equal (notasi-mode-tests--score-of (car runs))
                          "kotekan"))))
       (should (string-search
                (format "kotekan, %d lines"
                        (count-lines (point-min) (point-max)))
                (notasi-mode-tests--shown (plist-get ctx :file))))))))

(ert-deftest notasi-mode-test-cursor-into-first-score-no-score-option ()
  "Moving the cursor back into the first score, changed since it was
drawn, draws it without `--score'."
  (notasi-mode-tests--with-live-piece
   (lambda (ctx)
     (let ((log (plist-get ctx :log)))
       (notasi-mode-tests--move "(score kotekan")
       (notasi-mode-tests--must-draw log)
       (notasi-mode-tests--type "\n  ;; typed")
       (notasi-mode-tests--must-draw log)
       (let ((before (notasi-mode-tests--count log)))
         (notasi-mode-tests--move "(score full")
         (let ((runs (notasi-mode-tests--next-drawing log before)))
           (should (= (length runs) 1))
           (should-not (member "--score" (car runs)))))
       (let ((header (notasi-mode-tests--live-header ctx)))
         (should (string-search "Gilak: pangawit — full" header))
         (should-not (string-search "(chosen)" header)))))))

;;;;; Kept pictures

(ert-deftest notasi-mode-test-switching-back-shows-kept-picture ()
  "Switching back to a score drawn before, the text unchanged, shows
its kept picture at once and draws nothing."
  (notasi-mode-tests--with-live-piece
   (lambda (ctx)
     (let* ((log (plist-get ctx :log))
            (file (plist-get ctx :file))
            (full (notasi-mode-tests--shown file)))
       (should (string-search "fake-notasi: first score," full))
       (notasi-mode-tests--move "(score kotekan")
       (notasi-mode-tests--must-draw log)
       (should (string-search "fake-notasi: kotekan,"
                              (notasi-mode-tests--shown file)))
       (let ((before (notasi-mode-tests--count log))
             (process-environment (cons "FAKE_NOTASI_SLEEP=3"
                                        process-environment)))
         (notasi-mode-tests--move "(score full")
         (notasi-mode-tests--pause 0.05)
         (should (equal (notasi-mode-tests--shown file) full))
         (should (string-search "Gilak: pangawit — full"
                                (notasi-mode-tests--live-header ctx)))
         (notasi-mode-tests--pause 0.5)
         (should-not (notasi-mode-tests--runs-after log before)))))))

(ert-deftest notasi-mode-test-switching-back-redraws-if-changed ()
  "Switching back to a score whose text changed since it was drawn shows
its kept picture at once, and redraws it in the background."
  (notasi-mode-tests--with-live-piece
   (lambda (ctx)
     (let* ((log (plist-get ctx :log))
            (file (plist-get ctx :file))
            (full (notasi-mode-tests--shown file)))
       (should (string-search "fake-notasi: first score," full))
       (notasi-mode-tests--move "(score kotekan")
       (notasi-mode-tests--must-draw log)
       (notasi-mode-tests--type "\n  ;; typed")
       (notasi-mode-tests--must-draw log)
       (let ((before (notasi-mode-tests--count log))
             (process-environment (cons "FAKE_NOTASI_SLEEP=3"
                                        process-environment)))
         (notasi-mode-tests--move "(score full")
         (notasi-mode-tests--pause 0.05)
         (should (equal (notasi-mode-tests--shown file) full))
         (should (notasi-mode-tests--wait-until
                  (lambda () (notasi-mode-tests--runs-after log before))))
         (let ((runs (notasi-mode-tests--runs-after log before)))
           (should (= (length runs) 1))
           (should-not (member "--score" (car runs))))
         ;; While it draws, the kept picture stays.
         (should (equal (notasi-mode-tests--shown file) full)))))))

;;;;; Choosing a score

(ert-deftest notasi-mode-test-choose-score-shows-it ()
  "`notasi-choose-score' with a name draws that score, marked (chosen)
in the header line."
  (notasi-mode-tests--with-live-piece
   (lambda (ctx)
     (let* ((log (plist-get ctx :log))
            (before (notasi-mode-tests--count log)))
       (ert-simulate-command '(notasi-choose-score "third"))
       (let ((runs (notasi-mode-tests--next-drawing log before)))
         (should runs)
         (should (equal (notasi-mode-tests--score-of (car (last runs)))
                        "third")))
       (should (string-search "Gilak: pangawit — third (chosen)"
                              (notasi-mode-tests--live-header ctx)))
       (should (string-search "fake-notasi: third,"
                              (notasi-mode-tests--shown
                               (plist-get ctx :file))))))))

(ert-deftest notasi-mode-test-chosen-score-stays ()
  "A chosen score stays shown when the cursor moves into another score."
  (notasi-mode-tests--with-live-piece
   (lambda (ctx)
     (let ((log (plist-get ctx :log)))
       (ert-simulate-command '(notasi-choose-score "third"))
       (notasi-mode-tests--must-draw log)
       (let ((before (notasi-mode-tests--count log)))
         (notasi-mode-tests--move "(score kotekan")
         (notasi-mode-tests--pause 0.5)
         (should-not (seq-find (lambda (run)
                                 (equal (notasi-mode-tests--score-of run)
                                        "kotekan"))
                               (notasi-mode-tests--runs-after log before))))
       (should (string-search "Gilak: pangawit — third (chosen)"
                              (notasi-mode-tests--live-header ctx)))))))

(ert-deftest notasi-mode-test-choose-score-nil-follows-cursor ()
  "`(notasi-choose-score nil)' follows the cursor again, and the header
line loses its (chosen) mark."
  (notasi-mode-tests--with-live-piece
   (lambda (ctx)
     (let ((log (plist-get ctx :log)))
       (ert-simulate-command '(notasi-choose-score "third"))
       (notasi-mode-tests--must-draw log)
       (notasi-mode-tests--move "(score kotekan")
       (let ((before (notasi-mode-tests--count log)))
         (ert-simulate-command '(notasi-choose-score nil))
         (notasi-mode-tests--move "(score kotekan" 1)
         (should (notasi-mode-tests--wait-until
                  (lambda ()
                    (seq-find (lambda (run)
                                (equal (notasi-mode-tests--score-of run)
                                       "kotekan"))
                              (notasi-mode-tests--runs-after log before)))))
         (notasi-mode-tests--wait))
       (let ((header (notasi-mode-tests--live-header ctx)))
         (should (string-search "Gilak: pangawit — kotekan" header))
         (should-not (string-search "(chosen)" header)))))))

(ert-deftest notasi-mode-test-choose-score-interactively ()
  "Interactively, `notasi-choose-score' offers the file's scores and
\"follow the cursor\"."
  (notasi-mode-tests--with-live-piece
   (lambda (ctx)
     (let* ((log (plist-get ctx :log))
            (before (notasi-mode-tests--count log))
            offered
            (answer "kotekan")
            (completing-read-function
             (lambda (_prompt collection &rest _)
               (setq offered (all-completions "" collection))
               answer)))
       (call-interactively #'notasi-choose-score)
       (should (member "full" offered))
       (should (member "kotekan" offered))
       (should (member "third" offered))
       (let ((follow (seq-find (lambda (c)
                                 (string-match-p "follow the cursor"
                                                 (downcase c)))
                               offered)))
         (should follow)
         (notasi-mode-tests--next-drawing log before)
         (should (string-search "Gilak: pangawit — kotekan (chosen)"
                                (notasi-mode-tests--live-header ctx)))
         (setq answer follow)
         (call-interactively #'notasi-choose-score)
         (notasi-mode-tests--pause 0.2)
         (notasi-mode-tests--wait)
         (should-not (string-search "(chosen)"
                                    (notasi-mode-tests--live-header ctx))))))))

(ert-deftest notasi-mode-test-chosen-score-renamed-follows-cursor ()
  "A chosen score renamed in the text goes back to following the cursor:
the next drawing is the cursor's score, not marked (chosen)."
  (notasi-mode-tests--with-live-piece
   (lambda (ctx)
     (let ((log (plist-get ctx :log)))
       (ert-simulate-command '(notasi-choose-score "third"))
       (notasi-mode-tests--must-draw log)
       (notasi-mode-tests--move "(score kotekan")
       (notasi-mode-tests--pause 0.3)
       (notasi-mode-tests--wait)
       (let ((before (notasi-mode-tests--count log)))
         (notasi-mode-tests--command
          (lambda ()
            (save-excursion
              (goto-char (point-min))
              (search-forward "(score third")
              (replace-match "(score fourth" t t))))
         (should (notasi-mode-tests--wait-until
                  (lambda ()
                    (seq-find (lambda (run)
                                (equal (notasi-mode-tests--score-of run)
                                       "kotekan"))
                              (notasi-mode-tests--runs-after log before)))))
         (notasi-mode-tests--wait)
         (should-not (seq-find (lambda (run)
                                 (equal (notasi-mode-tests--score-of run)
                                        "third"))
                               (notasi-mode-tests--runs-after log before))))
       (let ((header (notasi-mode-tests--live-header ctx)))
         (should (string-search "Gilak: pangawit — kotekan" header))
         (should-not (string-search "(chosen)" header)))))))

(ert-deftest notasi-mode-test-chosen-score-deleted-follows-cursor ()
  "A chosen score deleted from the text goes back to following the
cursor: the next drawing is the cursor's score, not marked (chosen)."
  (notasi-mode-tests--with-live-piece
   (lambda (ctx)
     (let ((log (plist-get ctx :log)))
       (ert-simulate-command '(notasi-choose-score "third"))
       (notasi-mode-tests--must-draw log)
       (notasi-mode-tests--move "(score kotekan")
       (notasi-mode-tests--pause 0.3)
       (notasi-mode-tests--wait)
       (let ((before (notasi-mode-tests--count log)))
         (notasi-mode-tests--command
          (lambda ()
            (save-excursion
              (goto-char (point-min))
              (search-forward "(score third")
              (delete-region (match-beginning 0) (point-max)))))
         (should (notasi-mode-tests--wait-until
                  (lambda ()
                    (seq-find (lambda (run)
                                (equal (notasi-mode-tests--score-of run)
                                       "kotekan"))
                              (notasi-mode-tests--runs-after log before)))))
         (notasi-mode-tests--wait)
         (should-not (seq-find (lambda (run)
                                 (equal (notasi-mode-tests--score-of run)
                                        "third"))
                               (notasi-mode-tests--runs-after log before))))
       (let ((header (notasi-mode-tests--live-header ctx)))
         (should (string-search "Gilak: pangawit — kotekan" header))
         (should-not (string-search "(chosen)" header)))))))

;;;; The preview: mistakes (slice feat/emacs-preview-errors)

;; Written from 08 ("Mistakes", "Testing" and "Slices", item 3 and its
;; decided list) before the code.  Choices where 08 leaves room:
;;
;; - Files are opened in the selected window (`find-file'), so Flymake's
;;   deferred start can run.  The tests never call `flymake-start' to
;;   get a drawing's result, since 08 says each drawing's result is
;;   reported to Flymake when it ends: they wait up to 3 s for
;;   `flymake-diagnostics' to show it.  They call `flymake-start' only
;;   to check that Flymake runs no notasi of its own.
;; - "The whole line" is marked: the diagnostic starts at the line's
;;   start and ends at its end, or just after its newline.  A template's
;;   `(use …)' form is marked from its "(" to its ")".
;; - "Red" means the text of the preview's header line in the face
;;   `notasi-preview-error'.  `format-mode-line' gives "" in batch
;;   Emacs, so it is read from `header-line-format' by a walker like
;;   `notasi-mode-tests--format': the characters of a string whose
;;   `face' property is, or lists, the face, and everything inside
;;   (:propertize ELT face FACE).  A good drawing has no text in it.
;; - Other problems: the header line holds the sentence (with notasi's
;;   "notasi: " or without it) followed by " — see the manual's chapter
;;   on Emacs", all of it red.  "Shown in the echo area" means a
;;   message logged in *Messages* holding the sentence (batch Emacs logs
;;   there too; "[N times]" counts N).  Whether a problem that goes away and comes
;;   back is shown again is left open.
;; - Exit status 2 is made by a wrapper around the fake that adds an
;;   unknown option when the piece contains USAGE-PROBLEM, so the fake
;;   prints its usage ("notasi: unknown option …") and exits with 2.
;; - notasi not found is tested in a fresh Emacs that loads a copy of
;;   the package from a folder outside any clone, with an empty PATH, as
;;   in `notasi-mode-test-find-program-none'; it loads this file too, for
;;   its helpers.

(require 'flymake)

(defconst notasi-mode-tests--manual-pointer
  " — see the manual's chapter on Emacs"
  "What the header line adds after another problem's sentence.")

(defconst notasi-mode-tests--problem
  "typst is not installed"
  "The sentence of the fake's other problem (after \"notasi: \").")

(defconst notasi-mode-tests--uses
  "(piece \"Gilak: pangawit\" :colotomy gilak :pickup 1)

(use kendang)
(use gong-kebyar)
(use \"lib/my.nts\")

(score full :fill none
  (group \"Ugal\" ugal))
"
  "A piece using three templates; its first `(use …)' form is `kendang''s.")

;;;;; Helpers for mistakes

(defun notasi-mode-tests--face-p (face value)
  "Return non-nil if the `face' property VALUE is FACE or lists it."
  (or (eq value face)
      (and (consp value) (memq face value) t)))

(defun notasi-mode-tests--text-in-face (format face &optional in-face)
  "Return the text of the mode line construct FORMAT that is in FACE.
As `notasi-mode-tests--format', keeping only the characters whose
`face' property is FACE or lists it, and those inside (:propertize ELT
face FACE ...).  IN-FACE non-nil means FORMAT is inside such a form."
  (let ((walk (lambda (elt) (notasi-mode-tests--text-in-face elt face in-face))))
    (pcase format
      ('nil "")
      ((pred stringp)
       (let ((kept nil))
         (dotimes (i (length format))
           (when (or in-face
                     (notasi-mode-tests--face-p
                      face (get-text-property i 'face format)))
             (push (aref format i) kept)))
         (string-replace "%%" "%" (concat (nreverse kept)))))
      ((pred symbolp)
       (if (boundp format) (funcall walk (symbol-value format)) ""))
      (`(:eval ,form) (funcall walk (eval form t)))
      (`(:propertize ,elt . ,props)
       (notasi-mode-tests--text-in-face
        elt face (or in-face
                     (notasi-mode-tests--face-p face (plist-get props 'face)))))
      (`(,(and (pred integerp)) ,elt) (funcall walk elt))
      (`(,(and (pred symbolp) (pred (not keywordp)) sym) ,then . ,else)
       (if (and (boundp sym) (symbol-value sym))
           (funcall walk then)
         (mapconcat walk else "")))
      ((pred consp) (mapconcat walk format ""))
      (_ ""))))

(defun notasi-mode-tests--red (preview)
  "Return the text of the buffer PREVIEW's header line that is red.
That is, in the face `notasi-preview-error'."
  (with-current-buffer preview
    (notasi-mode-tests--text-in-face header-line-format
                                     'notasi-preview-error)))

(defun notasi-mode-tests--diagnostics (buffer predicate &optional timeout)
  "Wait until PREDICATE is true of BUFFER's Flymake diagnostics.
Wait at most TIMEOUT seconds (3).  Return the diagnostics."
  (let ((get (lambda () (with-current-buffer buffer (flymake-diagnostics)))))
    (notasi-mode-tests--wait-until
     (lambda () (funcall predicate (funcall get)))
     (or timeout 3))
    (funcall get)))

(defun notasi-mode-tests--diagnostic-saying (buffer text)
  "Wait for BUFFER's diagnostics to be one, saying TEXT; return it.
Return nil if they don't become that within 3 seconds; then the test
fails on what they are."
  (let ((found (notasi-mode-tests--diagnostics
                buffer
                (lambda (ds)
                  (and (= (length ds) 1)
                       (equal (flymake-diagnostic-text (car ds)) text))))))
    (should (= (length found) 1))
    (should (equal (flymake-diagnostic-text (car found)) text))
    (car found)))

(defun notasi-mode-tests--no-diagnostics (buffer)
  "Wait for BUFFER to have no Flymake diagnostics; fail if it keeps some."
  (should-not (notasi-mode-tests--diagnostics buffer #'null)))

(defun notasi-mode-tests--redraw-with (line)
  "Add the comment LINE at the end of the buffer, redraw and wait.
Return the drawing's process."
  (goto-char (point-max))
  (insert line "\n")
  (let ((p (notasi-preview-redraw)))
    (notasi-mode-tests--wait p)
    p))

(defun notasi-mode-tests--remove-line (text)
  "Remove the first line of the buffer holding TEXT."
  (save-excursion
    (goto-char (point-min))
    (search-forward text)
    (delete-region (line-beginning-position) (line-beginning-position 2))))

(defun notasi-mode-tests--should-mark-line (diagnostic line)
  "Check that DIAGNOSTIC marks the whole LINE of the current buffer."
  (save-excursion
    (goto-char (point-min))
    (forward-line (1- line))
    (should (= (flymake-diagnostic-beg diagnostic) (point)))
    (should (member (flymake-diagnostic-end diagnostic)
                    (list (line-end-position) (1+ (line-end-position)))))))

(defun notasi-mode-tests--should-mark-form (diagnostic form)
  "Check that DIAGNOSTIC marks the first FORM (its text) in the buffer."
  (save-excursion
    (goto-char (point-min))
    (search-forward form)
    (should (= (flymake-diagnostic-beg diagnostic) (match-beginning 0)))
    (should (= (flymake-diagnostic-end diagnostic) (match-end 0)))))

(defun notasi-mode-tests--messages-end ()
  "Return the end of *Messages*, to count what is echoed after it."
  (with-current-buffer (messages-buffer) (point-max)))

(defun notasi-mode-tests--echoed (since text)
  "Return how many times TEXT was echoed after SINCE in *Messages*.
A line ending in \"[N times]\" (Emacs's way of logging a message
repeated N times) counts N."
  (with-current-buffer (messages-buffer)
    (apply #'+ 0
           (mapcar (lambda (line)
                     (cond ((not (string-search text line)) 0)
                           ((string-match "\\[\\([0-9]+\\) times\\]\\'" line)
                            (string-to-number (match-string 1 line)))
                           (t 1)))
                   (split-string (buffer-substring-no-properties
                                  (min since (point-max)) (point-max))
                                 "\n" t)))))

(defun notasi-mode-tests--usage-wrapper ()
  "Write a notasi that is the fake, but used wrongly for USAGE-PROBLEM.
When the piece it is given contains USAGE-PROBLEM, it runs the fake with
an unknown option, so the fake prints \"notasi: unknown option …\" and
exits with status 2.  Return its file name, in a folder of its own."
  (let ((wrapper (expand-file-name
                  "notasi" (make-temp-file "notasi-mode-wrapper" t))))
    (with-temp-file wrapper
      (insert "#!/bin/sh\n"
              "piece=\n"
              "for arg in \"$@\"; do\n"
              "  case \"$arg\" in *.nts) piece=$arg ;; esac\n"
              "done\n"
              "if [ -n \"$piece\" ] && grep -q USAGE-PROBLEM \"$piece\"; then\n"
              "  exec " (shell-quote-argument notasi-mode-tests--fake)
              " \"$@\" --no-such-option\n"
              "fi\n"
              "exec " (shell-quote-argument notasi-mode-tests--fake) " \"$@\"\n"))
    (set-file-modes wrapper #o755)
    wrapper))

;;;;; Flymake and the face

(ert-deftest notasi-mode-test-preview-error-face ()
  "The red header's face, `notasi-preview-error', inherits `error' and is
in the `notasi' group, with a docstring."
  (should (facep 'notasi-preview-error))
  (let ((inherit (face-attribute 'notasi-preview-error :inherit)))
    (should (or (eq inherit 'error)
                (and (consp inherit) (memq 'error inherit)))))
  (should (member '(notasi-preview-error custom-face)
                  (get 'notasi 'custom-group)))
  (should (get 'notasi-preview-error 'face-documentation)))

(ert-deftest notasi-mode-test-flymake-on-in-file-buffer ()
  "In a buffer visiting a .nts file, `flymake-mode' is on, with
`notasi-flymake' its only backend."
  (notasi-mode-tests--with-piece
   (lambda (ctx)
     (with-current-buffer (plist-get ctx :buffer)
       (should (functionp 'notasi-flymake))
       (should flymake-mode)
       (should (equal flymake-diagnostic-functions '(notasi-flymake)))))
   :select t))

(ert-deftest notasi-mode-test-flymake-backend-always-safe ()
  "`notasi-flymake' runs nothing, so it is marked safe for buffers Emacs
doesn't trust; Flymake in Emacs 31 runs no other backend there."
  (should (function-get 'notasi-flymake 'flymake-always-safe)))

(ert-deftest notasi-mode-test-flymake-off-without-file ()
  "In a `notasi-mode' buffer that visits no file, `flymake-mode' stays off."
  (let ((notasi-program notasi-mode-tests--fake))
    (with-temp-buffer
      (insert notasi-mode-tests--gilak)
      (notasi-mode)
      (should-not flymake-mode))))

(ert-deftest notasi-mode-test-flymake-runs-no-notasi ()
  "Flymake runs no notasi of its own: starting it adds no run, and it
reports the last drawing's mistake again."
  (notasi-mode-tests--with-piece
   (lambda (ctx)
     (let* ((buffer (plist-get ctx :buffer))
            (log (plist-get ctx :log))
            (before (notasi-mode-tests--count log)))
       (should (functionp 'notasi-flymake))
       (flymake-start)
       (notasi-mode-tests--pause 0.5)
       (should (= (notasi-mode-tests--count log) before))
       (notasi-mode-tests--redraw-with ";; MISTAKE")
       (notasi-mode-tests--diagnostic-saying buffer "a mistake")
       (should (= (notasi-mode-tests--count log) (1+ before)))
       (flymake-start)
       (notasi-mode-tests--pause 0.5)
       (should (= (notasi-mode-tests--count log) (1+ before)))
       (notasi-mode-tests--diagnostic-saying buffer "a mistake")))
   :select t))

(ert-deftest notasi-mode-test-flymake-can-be-turned-off ()
  "With `flymake-mode' turned off by the user, a mistake still turns the
header red, and drawing does not turn Flymake back on."
  (notasi-mode-tests--with-piece
   (lambda (ctx)
     (let ((preview (notasi-mode-tests--preview (plist-get ctx :file))))
       (flymake-mode -1)
       (notasi-mode-tests--redraw-with ";; MISTAKE")
       (should-not flymake-mode)
       (should (string-search "gilak.nts:3: a mistake"
                              (notasi-mode-tests--red preview)))))
   :select t))

;;;;; A mistake in the piece

(ert-deftest notasi-mode-test-mistake-marked ()
  "A mistake in the piece is one Flymake error on its whole line, saying
notasi's message without FILE:LINE:; the header line turns red with the
whole line, under the real file's name; the last picture stays."
  (notasi-mode-tests--with-piece
   (lambda (ctx)
     (let* ((buffer (plist-get ctx :buffer))
            (file (plist-get ctx :file))
            (preview (notasi-mode-tests--preview file))
            (before (notasi-mode-tests--shown file)))
       (should before)
       (should (= (process-exit-status
                   (notasi-mode-tests--redraw-with ";; MISTAKE"))
                  1))
       (let ((d (notasi-mode-tests--diagnostic-saying buffer "a mistake")))
         (should (eq (flymake-diagnostic-type d) :error))
         (notasi-mode-tests--should-mark-line d 3))
       (let ((header (notasi-mode-tests--header preview))
             (red (notasi-mode-tests--red preview)))
         (should (string-search "gilak.nts:3: a mistake" header))
         (should-not (string-search ".notasi-preview" header))
         (should (string-search "gilak.nts:3: a mistake" red)))
       (should (equal (notasi-mode-tests--shown file) before))))
   :select t))

(ert-deftest notasi-mode-test-mistake-on-opening ()
  "A file opened with a mistake in it has it marked, and a red header."
  (notasi-mode-tests--with-piece
   (lambda (ctx)
     (let ((d (notasi-mode-tests--diagnostic-saying
               (plist-get ctx :buffer) "a mistake")))
       (should (eq (flymake-diagnostic-type d) :error))
       (notasi-mode-tests--should-mark-line d 3))
     (should (string-search "gilak.nts:3: a mistake"
                            (notasi-mode-tests--red
                             (notasi-mode-tests--preview
                              (plist-get ctx :file))))))
   :text (concat notasi-mode-tests--gilak ";; MISTAKE\n")
   :select t))

(ert-deftest notasi-mode-test-fixing-mistake-clears-it ()
  "Fixing the mistake clears its mark and the red header, and the
picture is redrawn."
  (notasi-mode-tests--with-piece
   (lambda (ctx)
     (let* ((buffer (plist-get ctx :buffer))
            (file (plist-get ctx :file))
            (preview (notasi-mode-tests--preview file)))
       (notasi-mode-tests--redraw-with ";; MISTAKE")
       (notasi-mode-tests--diagnostic-saying buffer "a mistake")
       (notasi-mode-tests--remove-line "MISTAKE")
       (insert ";; fixed\n;; and longer\n")
       (let ((p (notasi-preview-redraw)))
         (notasi-mode-tests--wait p)
         (should (= (process-exit-status p) 0)))
       (notasi-mode-tests--no-diagnostics buffer)
       (let ((header (notasi-mode-tests--header preview)))
         (should (string-search "Gilak: pangawit — full" header))
         (should-not (string-search "mistake" header)))
       (should (equal (notasi-mode-tests--red preview) ""))
       (should (string-search
                (format "%d lines" (count-lines (point-min) (point-max)))
                (notasi-mode-tests--shown file)))))
   :select t))

;;;;; A mistake in a template

(ert-deftest notasi-mode-test-template-mistake-marks-use ()
  "A mistake in gong-kebyar.nts marks the whole (use gong-kebyar) form,
saying notasi's message with its FILE:LINE:; the header line is red."
  (notasi-mode-tests--with-piece
   (lambda (ctx)
     (let* ((buffer (plist-get ctx :buffer))
            (preview (notasi-mode-tests--preview (plist-get ctx :file)))
            (said "gong-kebyar.nts:2: a mistake in a template"))
       (notasi-mode-tests--redraw-with ";; TEMPLATE-MISTAKE gong-kebyar")
       (let ((d (notasi-mode-tests--diagnostic-saying buffer said)))
         (should (eq (flymake-diagnostic-type d) :error))
         (notasi-mode-tests--should-mark-form d "(use gong-kebyar)"))
       (should (string-search said (notasi-mode-tests--header preview)))
       (should (string-search said (notasi-mode-tests--red preview)))))
   :text notasi-mode-tests--uses :select t))

(ert-deftest notasi-mode-test-template-mistake-string-use ()
  "A mistake in my.nts, or lib/my.nts, marks (use \"lib/my.nts\"): names
are compared without their folder and .nts."
  (notasi-mode-tests--with-piece
   (lambda (ctx)
     (let ((buffer (plist-get ctx :buffer)))
       (dolist (name '("my" "lib/my"))
         (notasi-mode-tests--redraw-with
          (concat ";; TEMPLATE-MISTAKE " name))
         (let ((d (notasi-mode-tests--diagnostic-saying
                   buffer (concat name ".nts:2: a mistake in a template"))))
           (notasi-mode-tests--should-mark-form d "(use \"lib/my.nts\")"))
         (notasi-mode-tests--remove-line "TEMPLATE-MISTAKE"))))
   :text notasi-mode-tests--uses :select t))

(ert-deftest notasi-mode-test-template-mistake-no-match ()
  "A mistake in a template no `(use …)' form names (gong.nts is not
gong-kebyar.nts) marks the first `(use …)' form."
  (notasi-mode-tests--with-piece
   (lambda (ctx)
     (let ((buffer (plist-get ctx :buffer)))
       (dolist (name '("nowhere" "gong"))
         (notasi-mode-tests--redraw-with
          (concat ";; TEMPLATE-MISTAKE " name))
         (let ((d (notasi-mode-tests--diagnostic-saying
                   buffer (concat name ".nts:2: a mistake in a template"))))
           (notasi-mode-tests--should-mark-form d "(use kendang)"))
         (notasi-mode-tests--remove-line "TEMPLATE-MISTAKE"))))
   :text notasi-mode-tests--uses :select t))

;;;;; Other problems

(ert-deftest notasi-mode-test-problem-red-header ()
  "Another problem (a `notasi: ' line) turns the header red with its
sentence and the manual's chapter; Flymake marks nothing; the picture
stays."
  (notasi-mode-tests--with-piece
   (lambda (ctx)
     (let* ((buffer (plist-get ctx :buffer))
            (file (plist-get ctx :file))
            (preview (notasi-mode-tests--preview file))
            (before (notasi-mode-tests--shown file))
            (said (concat notasi-mode-tests--problem
                          notasi-mode-tests--manual-pointer)))
       (should before)
       (notasi-mode-tests--redraw-with ";; NOTASI-PROBLEM")
       (should (string-search said (notasi-mode-tests--header preview)))
       (should (string-search said (notasi-mode-tests--red preview)))
       (notasi-mode-tests--pause 0.5)
       (should-not (with-current-buffer buffer (flymake-diagnostics)))
       (should (equal (notasi-mode-tests--shown file) before))))
   :select t))

(ert-deftest notasi-mode-test-problem-clears-mistake-mark ()
  "A drawing that ends in another problem, after one with a mistake,
leaves no mark: Flymake reports the last drawing's mistake, or none."
  (notasi-mode-tests--with-piece
   (lambda (ctx)
     (let ((buffer (plist-get ctx :buffer)))
       (notasi-mode-tests--redraw-with ";; MISTAKE")
       (notasi-mode-tests--diagnostic-saying buffer "a mistake")
       (notasi-mode-tests--remove-line "MISTAKE")
       (notasi-mode-tests--redraw-with ";; NOTASI-PROBLEM")
       (notasi-mode-tests--no-diagnostics buffer)))
   :select t))

(ert-deftest notasi-mode-test-problem-echoed-once ()
  "Another problem is shown in the echo area the first time it appears
in the buffer, not on each redraw; the header stays red."
  (notasi-mode-tests--with-piece
   (lambda (ctx)
     (let ((preview (notasi-mode-tests--preview (plist-get ctx :file)))
           (since (notasi-mode-tests--messages-end)))
       (notasi-mode-tests--redraw-with ";; NOTASI-PROBLEM")
       (should (= (notasi-mode-tests--echoed
                   since notasi-mode-tests--problem)
                  1))
       (notasi-mode-tests--wait (notasi-preview-redraw))
       (notasi-mode-tests--wait (notasi-preview-redraw))
       (should (= (notasi-mode-tests--echoed
                   since notasi-mode-tests--problem)
                  1))
       (should (string-search (concat notasi-mode-tests--problem
                                      notasi-mode-tests--manual-pointer)
                              (notasi-mode-tests--red preview)))))
   :select t))

(ert-deftest notasi-mode-test-problem-pause-still-redraws ()
  "With another problem, a pause still redraws, so fixing its cause is
picked up by itself: the header loses its red, and the picture is new."
  (notasi-mode-tests--with-live-piece
   (lambda (ctx)
     (let* ((log (plist-get ctx :log))
            (file (plist-get ctx :file))
            (preview (notasi-mode-tests--preview file)))
       (notasi-mode-tests--type ";; NOTASI-PROBLEM\n" (point-max))
       (notasi-mode-tests--must-draw log)
       (should (string-search notasi-mode-tests--manual-pointer
                              (notasi-mode-tests--red preview)))
       (notasi-mode-tests--type ";; more\n")
       (notasi-mode-tests--must-draw log)
       (should (string-search notasi-mode-tests--manual-pointer
                              (notasi-mode-tests--red preview)))
       (notasi-mode-tests--command
        (lambda () (notasi-mode-tests--remove-line "NOTASI-PROBLEM")))
       (notasi-mode-tests--must-draw log)
       (should (equal (notasi-mode-tests--red preview) ""))
       (let ((header (notasi-mode-tests--header preview)))
         (should (string-search "Gilak: pangawit — full" header))
         (should-not (string-search notasi-mode-tests--problem header)))
       (should (string-search
                (format "%d lines" (count-lines (point-min) (point-max)))
                (notasi-mode-tests--shown file)))
       (should-not (flymake-diagnostics))))))

(ert-deftest notasi-mode-test-exit-status-two-is-a-problem ()
  "notasi used wrongly (exit status 2) is another problem: a red header
with the manual's chapter, no Flymake mark, the picture kept."
  (let ((program (notasi-mode-tests--usage-wrapper)))
    (unwind-protect
        (notasi-mode-tests--with-piece
         (lambda (ctx)
           (let* ((buffer (plist-get ctx :buffer))
                  (file (plist-get ctx :file))
                  (preview (notasi-mode-tests--preview file))
                  (before (notasi-mode-tests--shown file)))
             (should before)
             (should (= (process-exit-status
                         (notasi-mode-tests--redraw-with ";; USAGE-PROBLEM"))
                        2))
             (let ((header (notasi-mode-tests--header preview))
                   (red (notasi-mode-tests--red preview)))
               (should (string-search "unknown option" header))
               (should (string-search notasi-mode-tests--manual-pointer header))
               (should (string-search "unknown option" red))
               (should (string-search notasi-mode-tests--manual-pointer red)))
             (notasi-mode-tests--pause 0.5)
             (should-not (with-current-buffer buffer (flymake-diagnostics)))
             (should (equal (notasi-mode-tests--shown file) before))))
         :program program :select t)
      (delete-directory (file-name-directory program) t))))

(ert-deftest notasi-mode-test-not-found-red-header ()
  "When no notasi is found, the preview's header line is red and points
to the manual's chapter on Emacs; Flymake marks nothing.  Tested in a
fresh Emacs loading a copy of the package from outside any clone."
  (let* ((tmp (make-temp-file "notasi-mode-notfound" t))
         (lisp (expand-file-name "pkg/lisp" tmp))
         (empty (expand-file-name "empty" tmp))
         (nts (expand-file-name "songs/gilak.nts" tmp)))
    (unwind-protect
        (progn
          (make-directory lisp t)
          (make-directory empty t)
          (make-directory (file-name-directory nts) t)
          (copy-file notasi-mode-tests--package-file
                     (file-name-as-directory lisp))
          (with-temp-file nts (insert notasi-mode-tests--gilak))
          (pcase-let
              ((`(,header ,red ,marks)
                (notasi-mode-tests--run-emacs-for
                 `(progn
                    (setq exec-path (list ,empty))
                    (let* ((buffer (find-file ,nts))
                           (preview nil)
                           (result nil))
                      (notasi-mode-tests--wait-until
                       (lambda ()
                         (setq preview (get-buffer "*notasi: gilak.nts*"))
                         (and preview
                              (string-search
                               "see the manual"
                               (notasi-mode-tests--header preview))))
                       5)
                      (setq result
                            (list (and preview
                                       (notasi-mode-tests--header preview))
                                  (and preview
                                       (notasi-mode-tests--red preview))
                                  (with-current-buffer buffer
                                    (length (flymake-diagnostics)))))
                      (kill-buffer buffer)
                      result))
                 "-L" lisp
                 "-l" (expand-file-name "notasi-mode-tests.el"
                                        notasi-mode-tests--dir))))
            (should (stringp header))
            (should (string-search notasi-mode-tests--manual-pointer header))
            (should (string-search notasi-mode-tests--manual-pointer red))
            (should (= marks 0))))
      (delete-directory tmp t))))

;;;; Documentation (feat/emacs-docs)

;; Written from 08 ("Documentation", "Decided when `feat/emacs-docs'
;; started") before the README section, the manual's chapter, the
;; Commentary and the docstring: the README's Emacs configuration
;; reads as Lisp and installs from the right place, the manual's
;; "Keys and settings" page names every setting and key, the chapter
;; is in the manual, and the docstring and Commentary point to it.

(defconst notasi-mode-tests--readme
  (expand-file-name "README.md" notasi-mode-tests--repo)
  "The repository's README.")

(defconst notasi-mode-tests--manual-src
  (expand-file-name "doc/manual/src/" notasi-mode-tests--repo)
  "The manual's source directory.")

(defconst notasi-mode-tests--chapter-pages
  '("emacs-installing.md" "emacs-first-score.md" "emacs-mistakes.md"
    "emacs-several-scores.md" "emacs-keys-and-settings.md"
    "emacs-problems.md")
  "The pages of the manual's chapter \"Writing in Emacs\", in order.")

(defconst notasi-mode-tests--vc-plist
  '(:url "https://github.com/hsinhaoyu/notasi"
    :lisp-dir "editors/emacs"
    :branch "dev")
  "What the README's configuration must install the package from.")

(defun notasi-mode-tests--file-text (file)
  "Return the text of FILE, or nil if it doesn't exist."
  (when (file-exists-p file)
    (with-temp-buffer
      (insert-file-contents file)
      (buffer-string))))

(defun notasi-mode-tests--squeeze (text)
  "Return TEXT with each run of whitespace made one space.
So a phrase found in TEXT may be split across lines."
  (replace-regexp-in-string "[ \t\n]+" " " text))

(defun notasi-mode-tests--readme-section (heading)
  "Return README's section under the `## ' HEADING, or nil.
It runs to the next `## ' heading or the end of the file."
  (let ((text (notasi-mode-tests--file-text notasi-mode-tests--readme)))
    (when (and text
               (string-match (concat "^## " (regexp-quote heading) "[ \t]*$")
                             text))
      (let* ((start (match-end 0))
             (end (and (string-match "^## " text start) (match-beginning 0))))
        (substring text start end)))))

(defun notasi-mode-tests--elisp-blocks (text)
  "Return the contents of TEXT's fenced code blocks marked elisp.
A block is marked `elisp' or `emacs-lisp'."
  (let ((start 0) blocks)
    (while (string-match
            "^```\\(?:elisp\\|emacs-lisp\\)[ \t]*\n\\(\\(?:.*\n\\)*?\\)```"
            text start)
      (push (match-string 1 text) blocks)
      (setq start (match-end 0)))
    (nreverse blocks)))

(defun notasi-mode-tests--read-all (text)
  "Read every Lisp form in TEXT and return them in a list.
A form that can't be read signals an error."
  (with-temp-buffer
    (insert text)
    (goto-char (point-min))
    (let (forms)
      (forward-comment (buffer-size))
      (while (not (eobp))
        (push (read (current-buffer)) forms)
        (forward-comment (buffer-size)))
      (nreverse forms))))

(defun notasi-mode-tests--subforms (pred form)
  "Return every list within FORM, FORM included, that satisfies PRED."
  (let (found)
    (named-let walk ((x form))
      (when (consp x)
        (when (and (proper-list-p x) (funcall pred x))
          (push x found))
        (walk (car x))
        (walk (cdr x))))
    (nreverse found)))

(defun notasi-mode-tests--readme-forms ()
  "Return the forms read from README's Emacs code blocks."
  (let ((section (notasi-mode-tests--readme-section "Using notasi in Emacs")))
    (and section
         (apply #'append
                (mapcar #'notasi-mode-tests--read-all
                        (notasi-mode-tests--elisp-blocks section))))))

(defun notasi-mode-tests--should-install-from (plist)
  "Check that PLIST has the `:url', `:lisp-dir' and `:branch' of 08."
  (should (listp plist))
  (dolist (key '(:url :lisp-dir :branch))
    (should (equal (list key (plist-get plist key))
                   (list key (plist-get notasi-mode-tests--vc-plist key))))))

(ert-deftest notasi-mode-test-readme-has-emacs-section ()
  "README has a section \"Using notasi in Emacs\" with Lisp code blocks."
  (let ((section (notasi-mode-tests--readme-section "Using notasi in Emacs")))
    (should section)
    (should (notasi-mode-tests--elisp-blocks section))))

(ert-deftest notasi-mode-test-readme-code-reads ()
  "Every elisp code block in README's Emacs section reads as Lisp."
  (let ((section (notasi-mode-tests--readme-section "Using notasi in Emacs")))
    (should section)
    (dolist (block (notasi-mode-tests--elisp-blocks section))
      (should-not (condition-case err
                      (progn (notasi-mode-tests--read-all block) nil)
                    (error (list 'unreadable block err)))))))

(ert-deftest notasi-mode-test-readme-use-package ()
  "README configures Emacs 30 with `use-package' and `:vc' from `dev'."
  (let* ((forms (notasi-mode-tests--readme-forms))
         (found (notasi-mode-tests--subforms
                 (lambda (x) (and (eq (car x) 'use-package)
                                  (eq (cadr x) 'notasi-mode)
                                  (memq :vc x)))
                 forms)))
    (should found)
    (dolist (form found)
      (notasi-mode-tests--should-install-from (cadr (memq :vc form))))))

(ert-deftest notasi-mode-test-readme-package-vc-install ()
  "README configures Emacs 29 with `package-vc-install' from `dev'."
  (let* ((forms (notasi-mode-tests--readme-forms))
         (found (notasi-mode-tests--subforms
                 (lambda (x)
                   (and (eq (car x) 'package-vc-install)
                        (pcase (cadr x)
                          (`(quote (notasi-mode . ,_)) t))))
                 forms)))
    (should found)
    (dolist (form found)
      (pcase-let ((`(quote (notasi-mode . ,plist)) (cadr form)))
        (notasi-mode-tests--should-install-from plist)))))

(defun notasi-mode-tests--settings ()
  "Return the package's settings: the variables of the `notasi' group."
  (mapcar #'car
          (seq-filter (lambda (member) (eq (cadr member) 'custom-variable))
                      (get 'notasi 'custom-group))))

(defun notasi-mode-tests--own-keys (map &optional prefix)
  "Return the keys bound to commands in MAP itself, not its parents.
Prefix keymaps are followed; PREFIX is the key sequence leading to MAP.
Each key is a string like \"C-c C-c\"."
  (let ((own (copy-keymap map))
        keys)
    (set-keymap-parent own nil)
    (map-keymap
     (lambda (event binding)
       (let ((key (vconcat prefix (vector event))))
         (cond ((memq event '(menu-bar tool-bar remap)))
               ((keymapp binding)
                (setq keys (append (notasi-mode-tests--own-keys binding key)
                                   keys)))
               ((commandp binding)
                (push (key-description key) keys)))))
     own)
    keys))

(ert-deftest notasi-mode-test-settings-and-keys-known ()
  "The package has settings and keys for the page to name."
  (should (memq 'notasi-program (notasi-mode-tests--settings)))
  (should (member "C-c C-c" (notasi-mode-tests--own-keys notasi-mode-map))))

(ert-deftest notasi-mode-test-manual-names-settings ()
  "The manual's \"Keys and settings\" page names every setting."
  (let ((page (notasi-mode-tests--file-text
               (expand-file-name "emacs-keys-and-settings.md"
                                 notasi-mode-tests--manual-src))))
    (should page)
    (dolist (setting (notasi-mode-tests--settings))
      (ert-info ((format "setting `%s'" setting))
        (should (string-search (format "`%s`" setting) page))))))

(ert-deftest notasi-mode-test-manual-names-keys ()
  "The manual's \"Keys and settings\" page names every key of the mode."
  (let ((page (notasi-mode-tests--file-text
               (expand-file-name "emacs-keys-and-settings.md"
                                 notasi-mode-tests--manual-src))))
    (should page)
    (dolist (key (notasi-mode-tests--own-keys notasi-mode-map))
      (ert-info ((format "key %s" key))
        (should (string-search (format "`%s`" key) page))))))

(ert-deftest notasi-mode-test-manual-has-chapter ()
  "SUMMARY.md has the part \"Writing in Emacs\" with its six pages."
  (let ((summary (notasi-mode-tests--file-text
                  (expand-file-name "SUMMARY.md"
                                    notasi-mode-tests--manual-src))))
    (should summary)
    (should (string-match "^# Writing in Emacs[ \t]*$" summary))
    (let* ((start (match-end 0))
           (end (and (string-match "^# " summary start) (match-beginning 0)))
           (part (substring summary start end))
           (pos 0)
           links)
      (while (string-match "^[ \t]*- \\[[^]\n]+\\](\\([^)\n]+\\))" part pos)
        (push (match-string 1 part) links)
        (setq pos (match-end 0)))
      (should (equal (nreverse links) notasi-mode-tests--chapter-pages)))
    (dolist (page notasi-mode-tests--chapter-pages)
      (ert-info ((format "page %s" page))
        (should (file-exists-p
                 (expand-file-name page notasi-mode-tests--manual-src)))))))

(ert-deftest notasi-mode-test-introduction-points-to-chapter ()
  "The manual's Introduction links to the chapter's first page."
  (let ((intro (notasi-mode-tests--file-text
                (expand-file-name "introduction.md"
                                  notasi-mode-tests--manual-src))))
    (should intro)
    (should (string-match-p "\\[[^]]+\\](emacs-installing\\.md)" intro))))

(ert-deftest notasi-mode-test-docstring-describes-preview ()
  "The mode's docstring describes the preview and points to the manual.
The raw docstring is checked, since the expanded one lists the
key bindings, and so the commands, whatever the text says."
  (let ((raw (notasi-mode-tests--squeeze (documentation 'notasi-mode t))))
    (should (string-search "preview" raw))
    (should (string-search "Writing in Emacs" raw))
    (should (string-search "\\{notasi-mode-map}" raw))))

(defun notasi-mode-tests--commentary ()
  "Return the package's Commentary, without its comment starts."
  (let ((text (notasi-mode-tests--file-text notasi-mode-tests--package-file)))
    (string-match "^;;; Commentary:[ \t]*$" text)
    (let* ((start (match-end 0))
           (end (and (string-match "^;;; Code:" text start)
                     (match-beginning 0))))
      (notasi-mode-tests--squeeze
       (replace-regexp-in-string "^;+" "" (substring text start end))))))

(ert-deftest notasi-mode-test-commentary-describes-preview ()
  "The Commentary describes the preview, its settings and the chapter."
  (let ((commentary (notasi-mode-tests--commentary)))
    (should (string-search "preview" commentary))
    (should (string-search "Writing in Emacs" commentary))
    (dolist (setting (notasi-mode-tests--settings))
      (ert-info ((format "setting `%s'" setting))
        (should (string-search (symbol-name setting) commentary))))))

(provide 'notasi-mode-tests)

;;; notasi-mode-tests.el ends here
