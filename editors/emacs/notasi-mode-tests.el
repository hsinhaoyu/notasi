;;; notasi-mode-tests.el --- Tests for notasi-mode  -*- lexical-binding: t; -*-

;;; Commentary:

;; ERT tests for notasi-mode, written from doc/design/08-emacs.md
;; ("The package", "Writing" and "Testing") before the package itself,
;; for the milestone feat/emacs-package: the package's headers, its
;; autoloads, the `notasi' customisation group, the major mode,
;; indentation and highlighting.
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
FUNCTION is called with the file name of the generated loaddefs."
  (let* ((out (make-temp-file "notasi-mode-autoloads" t))
         (file (expand-file-name "notasi-mode-autoloads.el" out)))
    (unwind-protect
        (progn
          (loaddefs-generate notasi-mode-tests--dir file)
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
                    "-L" notasi-mode-tests--dir "-l" file
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
                    "-L" notasi-mode-tests--dir "-l" file
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
                     "-L" notasi-mode-tests--dir "-l" file
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

(ert-deftest notasi-mode-test-indent-other-forms-as-lisp ()
  "Other forms (`use', pattern calls, chords) follow Lisp's usual rule,
as in `lisp-data-mode'."
  (dolist (text '("(use\ngong-kebyar)"
                  "(@ polos-1 :step 1\n:short \"2\")"
                  "(o2\ne2)"))
    (should (equal (notasi-mode-tests--indent #'notasi-mode text)
                   (notasi-mode-tests--indent #'lisp-data-mode text)))))

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

(provide 'notasi-mode-tests)

;;; notasi-mode-tests.el ends here
