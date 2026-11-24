;;; notasi-mode.el --- Write Balinese gamelan notation with notasi  -*- lexical-binding: t; -*-

;; Author: Hsin-Hao Yu
;; URL: https://github.com/hsinhaoyu/notasi
;; Version: 0.4.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages

;; This file is not part of GNU Emacs.

;;; Commentary:

;; A major mode for notasi's notation files (.nts), which notate
;; Balinese gamelan music as s-expressions.  It highlights the forms
;; and, in the music of parts, patterns and colotomies, the notes,
;; holds, rests, bars and pattern calls, each in a face of its own.
;; Forms such as `score' and `pattern' indent their body by 2.
;;
;; notasi is at https://github.com/hsinhaoyu/notasi; its manual
;; explains the notation.

;;; Code:

(require 'lisp-mode)

(defgroup notasi nil
  "Write Balinese gamelan notation with notasi."
  :group 'languages
  :link '(url-link "https://github.com/hsinhaoyu/notasi")
  :prefix "notasi-")

;;;; Faces

(defface notasi-note '((t :inherit font-lock-constant-face))
  "Face for notes in the music, by name or number, e.g. `a1' or `5'."
  :group 'notasi)

(defface notasi-hold '((t :inherit shadow))
  "Face for holds in the music, `_' and `_:D'."
  :group 'notasi)

(defface notasi-rest '((t :inherit font-lock-comment-face))
  "Face for rests in the music, `-' and `-:D'."
  :group 'notasi)

(defface notasi-bar '((t :inherit font-lock-delimiter-face))
  "Face for bar marks in the music, `|' and `||'."
  :group 'notasi)

(defface notasi-pattern '((t :inherit font-lock-function-name-face))
  "Face for pattern calls in the music, `@NAME' and `(@ NAME ...)'."
  :group 'notasi)

;;;; Syntax

(defvar notasi-mode-syntax-table
  (let ((table (make-syntax-table lisp-data-mode-syntax-table)))
    ;; `|' and `||' are bar marks, not Lisp's symbol quotes; `@' starts
    ;; a pattern call such as `@polos-1'.
    (modify-syntax-entry ?| "_" table)
    (modify-syntax-entry ?@ "_" table)
    table)
  "Syntax table for `notasi-mode'.")

(defconst notasi-mode--forms
  '("piece" "use" "scale" "strokes" "instrument" "colotomy"
    "pattern" "part" "score" "group" "rep" "@")
  "The names of notasi's forms.")

(defconst notasi-mode--body-forms
  '("piece" "scale" "strokes" "instrument" "colotomy"
    "part" "pattern" "score" "group" "rep")
  "The forms whose body is indented by 2, like `defun'.")

;;;; Indentation

(defun notasi-mode--list-head (open)
  "Return the name at the head of the list that opens at OPEN, or nil."
  (save-excursion
    (goto-char (1+ open))
    (and (looking-at "\\(?:\\sw\\|\\s_\\)+")
         (match-string-no-properties 0))))

(defun notasi-mode--indent-function (indent-point state)
  "Indent like function `lisp-indent-function', notasi's forms like `defun'.
INDENT-POINT and STATE are as for function `lisp-indent-function'.  The forms
in `notasi-mode--body-forms' indent their body by 2, and a line of
options (starting with `:') by 4.  Nothing is put on the symbols, so
Emacs Lisp elsewhere is unaffected."
  (cond
   ((not (member (notasi-mode--list-head (nth 1 state)) notasi-mode--body-forms))
    (lisp-indent-function indent-point state))
   (t
    (let ((column (save-excursion (goto-char (nth 1 state)) (current-column)))
          (options-line
           (save-excursion (goto-char indent-point)
                           (skip-chars-forward " \t")
                           (eq (char-after) ?:))))
      ;; Options on a line of their own go to 4, so they stand apart
      ;; from the body at 2.  A piece has only options, so they are its
      ;; body.  The result is a list, so that Emacs works out each line
      ;; again instead of reusing this one's column for the next.
      (list (+ column
               (if (and options-line
                        (not (equal (notasi-mode--list-head (nth 1 state))
                                    "piece")))
                   (* 2 lisp-body-indent)
                 lisp-body-indent))
            (nth 1 state))))))

;;;; The music

(defun notasi-mode--children (open)
  "Return the start of each element of the list that opens at OPEN."
  (save-excursion
    (goto-char (1+ open))
    (let (starts)
      (condition-case nil
          (while (progn (forward-comment (buffer-size))
                        (not (eq (char-after) ?\))))
            (push (point) starts)
            (forward-sexp 1))
        (error nil))
      (nreverse starts))))

(defun notasi-mode--skip-options (children)
  "Return CHILDREN after any leading `:key value' pairs."
  (while (and children (eq (char-after (car children)) ?:))
    (setq children (cddr children)))
  children)

(defun notasi-mode--music-start (open)
  "Return where the music begins in the list that opens at OPEN, or nil.
The music is the elements from that position to the list's end."
  (let ((head (notasi-mode--list-head open))
        (children (notasi-mode--children open)))
    (pcase head
      ("part" (car (notasi-mode--skip-options (cdr children))))
      ("pattern" (car (notasi-mode--skip-options (cddr children))))
      ("rep" (and (notasi-mode--in-music-p open) (nth 2 children)))
      ("@" nil)
      ((pred (lambda (h) (member h notasi-mode--forms))) nil)
      ;; A chord, e.g. (2 5): all of it is music, if it is in the music.
      (_ (and (notasi-mode--in-music-p open) (car children))))))

(defun notasi-mode--in-music-p (pos)
  "Return non-nil if POS is in the music of its enclosing list."
  (let ((open (nth 1 (syntax-ppss pos))))
    (and open
         (let ((start (notasi-mode--music-start open)))
           (and start (>= pos start))))))

(defun notasi-mode--token-face (beg end)
  "Return the music face of the token from BEG to END, or nil."
  (let ((open (nth 1 (syntax-ppss beg)))
        (token (buffer-substring-no-properties beg end)))
    (cond
     ((null open) nil)
     ;; The name in (@ NAME ...), when that call is in the music.
     ((equal (notasi-mode--list-head open) "@")
      (and (equal (nth 1 (notasi-mode--children open)) beg)
           (notasi-mode--in-music-p open)
           'notasi-pattern))
     ((not (notasi-mode--in-music-p beg)) nil)
     ((string-match-p "\\`_\\(?::.*\\)?\\'" token) 'notasi-hold)
     ((string-match-p "\\`-\\(?::.*\\)?\\'" token) 'notasi-rest)
     ((member token '("|" "||")) 'notasi-bar)
     ((string-prefix-p "@" token) 'notasi-pattern)
     (t 'notasi-note))))

(defvar notasi-mode--face nil
  "The face of the last token `notasi-mode--next-music-token' found.")

(defun notasi-mode--next-music-token (limit)
  "Find the next token of music before LIMIT, for font lock.
Set the match data to it, and `notasi-mode--face' to its face."
  (let (found)
    (while (and (not found)
                (re-search-forward "\\_<\\(?:\\sw\\|\\s_\\)+\\_>" limit t))
      (let ((beg (match-beginning 0))
            (end (match-end 0)))
        ;; `syntax-ppss' moves point, so everything is in `save-excursion'.
        (unless (save-excursion (nth 8 (syntax-ppss beg)))
          (let ((face (save-excursion (save-match-data
                                        (notasi-mode--token-face beg end)))))
            (when face
              (setq notasi-mode--face face
                    found t))))))
    found))

(defconst notasi-mode--font-lock-keywords
  `((,(concat "(\\(" (regexp-opt notasi-mode--forms) "\\)\\_>")
     1 font-lock-keyword-face)
    ("\\_<:\\(?:\\sw\\|\\s_\\)+" 0 font-lock-builtin-face)
    (notasi-mode--next-music-token 0 notasi-mode--face))
  "Font lock keywords for `notasi-mode'.")

;;;; The mode

;;;###autoload
(define-derived-mode notasi-mode lisp-data-mode "notasi"
  "Major mode for writing notasi's gamelan notation (.nts files).

The forms are highlighted, and in the music of parts, patterns and
colotomies, notes, holds, rests, bars and pattern calls each have a
face: `notasi-note', `notasi-hold', `notasi-rest', `notasi-bar' and
`notasi-pattern'.  `piece', `score', `pattern' and the other forms
indent their body by 2.

\\{notasi-mode-map}"
  :group 'notasi
  :syntax-table notasi-mode-syntax-table
  (setq-local lisp-indent-function #'notasi-mode--indent-function)
  (setq-local comment-start ";")
  (setq-local indent-tabs-mode nil)
  (setq-local font-lock-defaults '(notasi-mode--font-lock-keywords)))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.nts\\'" . notasi-mode))

(provide 'notasi-mode)

;;; notasi-mode.el ends here
