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
;; - The real test draws a copy of examples/jaya-semara.nts in a
;;   temporary folder (its template is found by notasi), so nothing is
;;   written in examples/.
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

FUNCTION is called in the file's buffer, with a plist: :buffer, :dir (the file's folder),
:file, :log (the fake's log) and :input (the text it was last given).
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
          (copy-file (expand-file-name "examples/jaya-semara.nts"
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

(provide 'notasi-mode-tests)

;;; notasi-mode-tests.el ends here
