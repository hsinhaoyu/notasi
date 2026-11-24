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
;; Forms such as `score' and `pattern' indent their body by 2, and a
;; line of options by 4.
;;
;; notasi is at https://github.com/hsinhaoyu/notasi; its manual
;; explains the notation.

;;; Code:

(require 'lisp-mode)
(require 'subr-x)
(require 'seq)
(require 'flymake)

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

(defface notasi-preview-error '((t :inherit error))
  "Face of the preview's header line when a drawing fails."
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

;;;; The preview: settings and state

(defconst notasi-mode-version "0.4.0"
  "The package's version, as in its Version: header.")

(defconst notasi-mode--load-file (or load-file-name buffer-file-name)
  "The file this package was loaded from.")

(defcustom notasi-program nil
  "The notasi command to draw with, or nil to find it.
When nil, the mode runs `notasi' on the PATH, else scripts/notasi in
the clone this package was installed from, else scripts/notasi in a
folder above the .nts file."
  :type '(choice (const :tag "Find it" nil) (file :tag "Program"))
  :group 'notasi)

(defcustom notasi-preview-side 'auto
  "Where the preview window goes.
`auto' puts it to the right when the frame is wide enough, below
otherwise; `right' and `below' always put it there; nil lets Emacs
decide."
  :type '(choice (const :tag "Right if wide enough, else below" auto)
                 (const :tag "Right" right)
                 (const :tag "Below" below)
                 (const :tag "Where Emacs decides" nil))
  :group 'notasi)

(defcustom notasi-preview-on-open t
  "Non-nil means opening a .nts file opens its preview and draws it."
  :type 'boolean
  :group 'notasi)

(defcustom notasi-auto-preview t
  "Non-nil means the picture is redrawn when the writing pauses, and on saving.
With nil, \[notasi-preview-redraw] still redraws."
  :type 'boolean
  :group 'notasi)

(defcustom notasi-preview-delay 1
  "Seconds without a change to the text after which the picture is redrawn."
  :type 'number
  :group 'notasi)

(defvar notasi-mode--versions (make-hash-table :test #'equal)
  "The version of each notasi program already asked, by file name.")

(defvar-local notasi-mode--process nil
  "The drawing being made for this buffer, if any.")

(defvar-local notasi-mode--out-dir nil
  "The temporary folder this buffer's pictures are drawn into.")

(defvar-local notasi-mode--note nil
  "A note for the header line after the next drawing, or nil.")

(defvar-local notasi-mode--chosen nil
  "The score chosen with \[notasi-choose-score], or nil to follow the cursor.")

(defvar-local notasi-mode--shown nil
  "The score the preview shows, or nil for a piece without scores.")

(defvar-local notasi-mode--pictures nil
  "The picture kept for each score drawn: an alist of (SCORE FILE . TICK).
TICK is `buffer-chars-modified-tick' when that drawing started.")

(defvar-local notasi-mode--timer nil
  "The timer that redraws when the writing pauses.")

(defvar-local notasi-mode--mistake nil
  "The last drawing's mistake, as (BEG END TEXT), or nil.")

(defvar-local notasi-mode--echoed nil
  "The problems already shown in the echo area for this buffer.")

(defconst notasi-mode--manual-pointer " — see the manual's chapter on Emacs"
  "What follows the sentence saying what is wrong, other than a mistake.")

(defconst notasi-mode--follow-choice "follow the cursor"
  "The choice in \[notasi-choose-score] that follows the cursor again.")

(defvar-local notasi-mode--image-file nil
  "In a preview buffer, the picture it shows.")

;;;; The preview: finding notasi

(defun notasi-mode--executable (file)
  "Return FILE if it is an executable file, else nil."
  (and file (file-regular-p file) (file-executable-p file) file))

(defun notasi-find-program ()
  "Return the notasi program to draw with, or nil if there is none.
In order: `notasi-program'; `notasi' on the PATH; scripts/notasi in
the clone this package was installed from; scripts/notasi in a folder
above the current buffer's file."
  (or (notasi-mode--executable
       (and notasi-program (expand-file-name notasi-program)))
      (executable-find "notasi")
      (and notasi-mode--load-file
           (notasi-mode--executable
            (expand-file-name "../../scripts/notasi"
                              (file-name-directory notasi-mode--load-file))))
      (let ((above (and buffer-file-name
                        (locate-dominating-file
                         (file-name-directory buffer-file-name)
                         (lambda (dir)
                           (notasi-mode--executable
                            (expand-file-name "scripts/notasi" dir)))))))
        (and above (expand-file-name "scripts/notasi" above)))))

(defun notasi-mode--version-of (program)
  "Return PROGRAM's version, as `notasi --version' prints it, or nil."
  (with-temp-buffer
    (and (eq 0 (ignore-errors (call-process program nil t nil "--version")))
         (progn (goto-char (point-min))
                (looking-at "notasi \\([0-9][^ \n]*\\)"))
         (match-string 1))))

(defun notasi-mode--check-version (program)
  "Ask PROGRAM its version, once; note it here if it is older than ours."
  (unless (gethash program notasi-mode--versions)
    (let ((version (or (notasi-mode--version-of program) "unknown")))
      (puthash program version notasi-mode--versions)
      (when (and (not (equal version "unknown"))
                 (version< (string-remove-suffix "-dev" version)
                           notasi-mode-version))
        (setq notasi-mode--note
              (format "This notasi (%s) is older than notasi-mode (%s)"
                      version notasi-mode-version))))))

;;;; The preview: the piece

(defun notasi-mode--top-level-match (regexp)
  "Return group 1 of the first match of REGEXP at the top level, or nil."
  (save-excursion
    (save-match-data
      (goto-char (point-min))
      (let (found)
        (while (and (not found) (re-search-forward regexp nil t))
          (let ((beg (match-beginning 0))
                (name (match-string-no-properties 1)))
            ;; `syntax-ppss' moves point and changes the match data.
            (when (= 0 (save-excursion (save-match-data (car (syntax-ppss beg)))))
              (setq found name))))
        found))))

(defun notasi-mode--title ()
  "Return the piece's title, or the file's name when it has none."
  (or (notasi-mode--top-level-match "^(piece[ \t\n]+\"\\([^\"]*\\)\"")
      (file-name-nondirectory buffer-file-name)))

(defun notasi-mode--scores ()
  "Return the buffer's scores, as a list of (NAME BEG END), in order."
  (save-excursion
    (save-match-data
      (goto-char (point-min))
      (let (scores)
        (while (re-search-forward "^(score[ \t\n]+\\([^ \t\n()\"]+\\)" nil t)
          (let ((beg (match-beginning 0))
                (name (match-string-no-properties 1)))
            ;; `syntax-ppss' moves point and changes the match data.
            (when (= 0 (save-excursion (save-match-data (car (syntax-ppss beg)))))
              (push (list name beg
                          (save-excursion
                            (goto-char beg)
                            (condition-case nil
                                (progn (forward-sexp) (point))
                              (scan-error (point-max)))))
                    scores))))
        (nreverse scores)))))

(defun notasi-mode--first-score ()
  "Return the name of the first score in the buffer, or nil."
  (car (car (notasi-mode--scores))))

(defun notasi-mode--target ()
  "Return the score the preview should show, or nil when there are none.
In order: the score chosen with \[notasi-choose-score]; the score the
cursor is in; the score shown last; the first score.  A chosen score
that has gone is forgotten."
  (let ((scores (notasi-mode--scores)))
    (when (and notasi-mode--chosen (not (assoc notasi-mode--chosen scores)))
      (setq notasi-mode--chosen nil))
    (or notasi-mode--chosen
        (car (seq-find (lambda (score)
                         (and (>= (point) (nth 1 score))
                              (< (point) (nth 2 score))))
                       scores))
        (and notasi-mode--shown (assoc notasi-mode--shown scores)
             notasi-mode--shown)
        (car (car scores)))))

(defun notasi-mode--header (score)
  "Return the header line for a good drawing of SCORE."
  (let ((title (notasi-mode--title)))
    (cond ((null score) title)
          ((equal score notasi-mode--chosen)
           (format "%s — %s (chosen)" title score))
          (t (format "%s — %s" title score)))))

;;;; The preview: its buffer and window

(defun notasi-mode--preview-name ()
  "Return the name of this buffer's preview buffer."
  (format "*notasi: %s*" (file-name-nondirectory buffer-file-name)))

(defun notasi-mode--preview (&optional create)
  "Return this buffer's preview buffer; with CREATE, make it if needed."
  (let ((name (notasi-mode--preview-name)))
    (or (get-buffer name)
        (and create
             (with-current-buffer (get-buffer-create name)
               (special-mode)
               (setq-local cursor-type nil)
               (add-hook 'window-size-change-functions
                         #'notasi-mode--refit nil t)
               (current-buffer))))))

(defun notasi-mode--set-header (preview text &optional face)
  "Show TEXT in the header line of the buffer PREVIEW, in FACE if given."
  (with-current-buffer preview
    (let ((escaped (string-replace "%" "%%" text)))
      (setq header-line-format
            (if face (propertize escaped 'face face) escaped)))
    (force-mode-line-update)))

(defun notasi-mode--image-width (preview)
  "Return the width in pixels the picture in PREVIEW may take."
  (let ((window (get-buffer-window preview t)))
    (if window
        (window-body-width window t)
      (frame-text-width))))

(defun notasi-mode--put-image (preview)
  "Show the picture of the buffer PREVIEW, fitted to its window."
  (with-current-buffer preview
    (when (and notasi-mode--image-file
               (file-exists-p notasi-mode--image-file))
      (let* ((file notasi-mode--image-file)
             (svg (string-suffix-p ".svg" file))
             (data (with-temp-buffer
                     (set-buffer-multibyte nil)
                     (insert-file-contents-literally file)
                     (buffer-string)))
             (image (list 'image :type (if svg 'svg 'png) :data data
                          :max-width (notasi-mode--image-width preview)))
             (inhibit-read-only t))
        (erase-buffer)
        (insert (propertize " " 'display image))
        (goto-char (point-min))))))

(defun notasi-mode--refit (frame)
  "Fit the pictures of the previews shown in FRAME to their windows."
  (dolist (window (window-list frame 'no-minibuffer))
    (let ((buffer (window-buffer window)))
      (when (buffer-local-value 'notasi-mode--image-file buffer)
        (notasi-mode--put-image buffer)))))

(defun notasi-mode--display-action ()
  "Return the `display-buffer' action that puts the preview in place."
  (let ((side (if (eq notasi-preview-side 'auto)
                  (if (>= (frame-width) 160) 'right 'below)
                notasi-preview-side)))
    (pcase side
      ('right '((display-buffer-in-direction) (direction . right)
                (inhibit-same-window . t)))
      ('below '((display-buffer-in-direction) (direction . below)
                (inhibit-same-window . t)))
      (_ '(nil (inhibit-same-window . t))))))

(defun notasi-mode--show-preview ()
  "Show this buffer's preview in a window beside it, without selecting it."
  (let ((preview (notasi-mode--preview t)))
    (unless (get-buffer-window preview)
      (display-buffer preview (notasi-mode--display-action)))
    (notasi-mode--put-image preview)))

;;;; The preview: drawing

(defun notasi-mode--hidden-file ()
  "Return the hidden file beside this buffer's file that is drawn."
  (expand-file-name (concat ".notasi-preview-"
                            (file-name-nondirectory buffer-file-name))
                    (file-name-directory buffer-file-name)))

(defun notasi-mode--write-hidden-file ()
  "Write the buffer's text, saved or not, to the hidden file.
Return its name."
  (let ((hidden (notasi-mode--hidden-file)))
    (save-restriction
      (widen)
      (let ((coding-system-for-write 'utf-8))
        (write-region (point-min) (point-max) hidden nil 'silent)))
    hidden))

(defun notasi-mode--delete-hidden-file ()
  "Delete the hidden file, if it is there."
  (let ((hidden (notasi-mode--hidden-file)))
    (when (file-exists-p hidden)
      (delete-file hidden))))

(defun notasi-mode--stop ()
  "Stop the drawing being made, if any."
  (when (process-live-p notasi-mode--process)
    (delete-process notasi-mode--process))
  (setq notasi-mode--process nil))

(defun notasi-mode--out-file (name)
  "Return the file to draw the score NAME (or the piece) into."
  (unless (and notasi-mode--out-dir (file-directory-p notasi-mode--out-dir))
    (setq notasi-mode--out-dir (make-temp-file "notasi-preview-" t)))
  (expand-file-name (concat (or name "piece")
                            (if (image-type-available-p 'svg) ".svg" ".png"))
                    notasi-mode--out-dir))

(defun notasi-mode--message (output)
  "Return notasi's message in OUTPUT, with the hidden file's name replaced."
  (let ((line (car (split-string (string-trim output) "\n" t))))
    (string-replace (file-name-nondirectory (notasi-mode--hidden-file))
                    (file-name-nondirectory buffer-file-name)
                    (or line "notasi failed"))))

(defun notasi-mode--uses ()
  "Return the buffer's top-level (use X) forms, as a list of (X BEG . END)."
  (save-excursion
    (save-match-data
      (goto-char (point-min))
      (let (uses)
        (while (re-search-forward "^(use[ \t\n]+" nil t)
          (let ((beg (match-beginning 0)))
            ;; `syntax-ppss' moves point and changes the match data.
            (when (= 0 (save-excursion (save-match-data (car (syntax-ppss beg)))))
              (let ((name (ignore-errors (read (current-buffer))))
                    (end (save-excursion
                           (goto-char beg)
                           (condition-case nil
                               (progn (forward-sexp) (point))
                             (scan-error (line-end-position))))))
                (push (cons (if (symbolp name) (symbol-name name) name)
                            (cons beg end))
                      uses)))))
        (nreverse uses)))))

(defun notasi-mode--use-for (file)
  "Return the bounds (BEG . END) of the use form for the template FILE.
That is the form naming FILE without its folder and .nts; or the first
use form; or the first line, when there is none."
  (let ((uses (notasi-mode--uses)))
    (or (cdr (seq-find (lambda (use)
                         (and (stringp (car use))
                              (equal (file-name-base (car use))
                                     (file-name-base file))))
                       uses))
        (cdr (car uses))
        (save-excursion
          (goto-char (point-min))
          (cons (point) (line-end-position))))))

(defun notasi-mode--line-bounds (line)
  "Return the bounds (BEG . END) of LINE, counted from 1, in the buffer."
  (save-excursion
    (save-restriction
      (widen)
      (goto-char (point-min))
      (forward-line (max 0 (1- line)))
      (cons (line-beginning-position) (line-end-position)))))

(defun notasi-mode--failure (output)
  "Return the problem in OUTPUT, notasi's output from a failed drawing.
Either (mistake HEADER BEG END TEXT), for a mistake in the notation
to mark from BEG to END, or (problem SENTENCE) for any other problem."
  (let ((line (or (car (split-string (string-trim output) "\n" t)) "")))
    (if (and (not (string-prefix-p "notasi: " line))
             (string-match "\\`\\(.+?\\):\\([0-9]+\\): \\(.*\\)" line))
        (let* ((file (match-string 1 line))
               (number (string-to-number (match-string 2 line)))
               (said (match-string 3 line))
               (piece (equal file (file-name-nondirectory
                                   (notasi-mode--hidden-file))))
               (bounds (if piece
                           (notasi-mode--line-bounds number)
                         (notasi-mode--use-for file))))
          (list 'mistake (notasi-mode--message output)
                (car bounds) (cdr bounds)
                (if piece said line)))
      (list 'problem
            (concat (if (string-empty-p line)
                        "notasi failed"
                      (string-remove-prefix "notasi: " line))
                    notasi-mode--manual-pointer)))))

(defun notasi-mode--report (mistake)
  "Keep MISTAKE, (BEG END TEXT) or nil, and tell Flymake about it."
  (setq notasi-mode--mistake mistake)
  (when flymake-mode
    (flymake-start nil t)))

(defun notasi-mode--problem (sentence)
  "Show SENTENCE, a problem other than a mistake, in a red header line.
It is shown in the echo area too, the first time it comes up."
  (notasi-mode--set-header (notasi-mode--preview t) sentence
                           'notasi-preview-error)
  (unless (member sentence notasi-mode--echoed)
    (push sentence notasi-mode--echoed)
    (message "%s" sentence))
  (notasi-mode--report nil))

(defun notasi-flymake (report-fn &rest _)
  "Report the last drawing's mistake to Flymake with REPORT-FN.
A Flymake backend: it runs nothing, since each drawing finds the
mistakes."
  (funcall report-fn
           (and notasi-mode--mistake
                (pcase-let ((`(,beg ,end ,text) notasi-mode--mistake))
                  (list (flymake-make-diagnostic
                         (current-buffer)
                         (min beg (point-max)) (min end (point-max))
                         :error text))))))

;; It runs no program and evaluates nothing in the buffer, so it is safe in
;; buffers Emacs doesn't trust (Emacs 31 runs no other backend there).
(function-put 'notasi-flymake 'flymake-always-safe t)

(defun notasi-mode--sentinel (source score out tick)
  "Return a sentinel for a drawing of SCORE in SOURCE's buffer to OUT.
TICK is the buffer's `buffer-chars-modified-tick' when it started."
  (lambda (process _event)
    (unless (process-live-p process)
      (let ((output (with-current-buffer (process-buffer process)
                      (buffer-string))))
        (kill-buffer (process-buffer process))
        (when (and (buffer-live-p source)
                   (buffer-local-value 'buffer-file-name source)
                   (eq process (buffer-local-value 'notasi-mode--process source)))
          (with-current-buffer source
            (setq notasi-mode--process nil)
            (notasi-mode--delete-hidden-file)
            (let ((preview (notasi-mode--preview t)))
              (if (and (eq (process-status process) 'exit)
                       (= (process-exit-status process) 0))
                  (let ((header (notasi-mode--header score)))
                    (setf (alist-get score notasi-mode--pictures nil nil #'equal)
                          (cons out tick))
                    (with-current-buffer preview
                      (setq notasi-mode--image-file out))
                    (notasi-mode--put-image preview)
                    (notasi-mode--set-header
                     preview (if notasi-mode--note
                                 (concat header "  " notasi-mode--note)
                               header))
                    (setq notasi-mode--note nil
                          notasi-mode--echoed nil)
                    (notasi-mode--report nil))
                (pcase (notasi-mode--failure output)
                  (`(mistake ,header ,beg ,end ,text)
                   (notasi-mode--set-header preview header
                                            'notasi-preview-error)
                   (notasi-mode--report (list beg end text)))
                  (`(problem ,sentence)
                   (notasi-mode--problem sentence)))))))))))

(defun notasi-preview-redraw ()
  "Draw the score again, from the text as it is now, saved or not.
Return the drawing's process, or nil when nothing is drawn."
  (interactive)
  (when buffer-file-name
    (notasi-mode--stop)
    (let ((program (notasi-find-program))
          (preview (notasi-mode--preview t)))
      (if (not program)
          (progn
            (notasi-mode--problem
             (concat "Can't find notasi" notasi-mode--manual-pointer))
            nil)
        (notasi-mode--check-version program)
        (let* ((score (notasi-mode--target))
               (header (notasi-mode--header score))
               (out (notasi-mode--out-file score))
               (tick (buffer-chars-modified-tick))
               (hidden (notasi-mode--write-hidden-file))
               (default-directory (file-name-directory buffer-file-name)))
          (setq notasi-mode--process
                (make-process
                 :name "notasi"
                 :buffer (generate-new-buffer " *notasi-output*")
                 :command (append
                           (list program "render" (file-name-nondirectory hidden))
                           (and score (not (equal score (notasi-mode--first-score)))
                                (list "--score" score))
                           (list "-o" out))
                 :connection-type 'pipe
                 :noquery t
                 :sentinel (notasi-mode--sentinel (current-buffer) score out tick)))
          (setq notasi-mode--shown score)
          (notasi-mode--set-header preview (concat header "  drawing…"))
          notasi-mode--process)))))

(defun notasi-mode--show-kept (score)
  "Show the picture kept for SCORE, if any; return non-nil if there is one."
  (let ((kept (cdr (assoc score notasi-mode--pictures))))
    (when (and kept (file-exists-p (car kept)))
      (let ((preview (notasi-mode--preview t)))
        (with-current-buffer preview
          (setq notasi-mode--image-file (car kept)))
        (notasi-mode--put-image preview)
        (notasi-mode--set-header preview (notasi-mode--header score))
        t))))

(defun notasi-mode--switch (score)
  "Show SCORE: its kept picture at once, drawn again if the text changed."
  (notasi-mode--stop)
  (setq notasi-mode--shown score)
  (if (notasi-mode--show-kept score)
      (unless (= (cddr (assoc score notasi-mode--pictures))
                 (buffer-chars-modified-tick))
        (notasi-preview-redraw))
    (notasi-preview-redraw)))

(defun notasi-mode--follow ()
  "After a command, show the score the preview should show, if it changed."
  (when (and buffer-file-name (notasi-mode--preview))
    (let ((target (notasi-mode--target)))
      (unless (equal target notasi-mode--shown)
        (notasi-mode--switch target)))))

(defun notasi-mode--changed (&rest _)
  "Redraw when the writing pauses for `notasi-preview-delay' seconds."
  (when notasi-auto-preview
    (when (timerp notasi-mode--timer)
      (cancel-timer notasi-mode--timer))
    (setq notasi-mode--timer
          (run-at-time notasi-preview-delay nil
                       (lambda (buffer)
                         (when (buffer-live-p buffer)
                           (with-current-buffer buffer
                             (setq notasi-mode--timer nil)
                             (notasi-preview-redraw))))
                       (current-buffer)))))

(defun notasi-mode--saved ()
  "Redraw when the file is saved."
  (when notasi-auto-preview
    (when (timerp notasi-mode--timer)
      (cancel-timer notasi-mode--timer)
      (setq notasi-mode--timer nil))
    (notasi-preview-redraw)))

(defun notasi-choose-score (score)
  "Show SCORE in the preview, whatever score the cursor is in.
With nil (\"follow the cursor\" when asked), show the score the
cursor is in again."
  (interactive
   (let ((choice (completing-read
                  "Show the score: "
                  (append (mapcar #'car (notasi-mode--scores))
                          (list notasi-mode--follow-choice))
                  nil t)))
     (list (unless (equal choice notasi-mode--follow-choice) choice))))
  (setq notasi-mode--chosen score)
  (let ((target (notasi-mode--target)))
    (if (and (equal target notasi-mode--shown)
             (not (process-live-p notasi-mode--process))
             (notasi-mode--show-kept target))
        (unless (= (cddr (assoc target notasi-mode--pictures))
                   (buffer-chars-modified-tick))
          (notasi-preview-redraw))
      (notasi-mode--switch target))))

(defun notasi-preview-toggle ()
  "Show the preview of the score, or hide it if it is shown."
  (interactive)
  (let* ((preview (and buffer-file-name (notasi-mode--preview)))
         (window (and preview (get-buffer-window preview))))
    (cond
     (window (delete-window window))
     (buffer-file-name
      (notasi-mode--show-preview)
      (unless preview (notasi-preview-redraw))))))

(defun notasi-write-score (file)
  "Write the score to FILE, a .pdf, .png or .svg file.
The score is drawn from the text as it is now, saved or not."
  (interactive
   (list (read-file-name "Write the score to (.pdf, .png, .svg): ")))
  (unless buffer-file-name
    (user-error "This buffer has no file, so it can't be drawn"))
  (let ((program (or (notasi-find-program)
                     (user-error "Can't find notasi: see the manual's chapter on Emacs")))
        (file (expand-file-name file)))
    (notasi-mode--stop)
    (let ((hidden (notasi-mode--write-hidden-file))
          (default-directory (file-name-directory buffer-file-name)))
      (unwind-protect
          (with-temp-buffer
            (if (eq 0 (call-process program nil t nil "render"
                                    (file-name-nondirectory hidden) "-o" file))
                (message "Wrote %s" file)
              (let ((output (buffer-string)))
                (with-current-buffer (get-file-buffer buffer-file-name)
                  (message "%s" (notasi-mode--message output))))))
        (notasi-mode--delete-hidden-file)))))

(defun notasi-mode--clean-up ()
  "Stop drawing, and remove the preview and the temporary files."
  (when (timerp notasi-mode--timer)
    (cancel-timer notasi-mode--timer))
  (notasi-mode--stop)
  (when buffer-file-name
    (let ((preview (notasi-mode--preview)))
      (when preview
        ;; Close the preview's windows, so no split is left showing some
        ;; other buffer; a frame's only window stays.
        (dolist (window (get-buffer-window-list preview nil t))
          (unless (frame-root-window-p window)
            (delete-window window)))
        (kill-buffer preview)))
    (ignore-errors (notasi-mode--delete-hidden-file)))
  (when (and notasi-mode--out-dir (file-directory-p notasi-mode--out-dir))
    (delete-directory notasi-mode--out-dir t)))

(defun notasi-mode--open (buffer)
  "Show BUFFER's preview, if BUFFER is shown, and draw it."
  (when (and notasi-preview-on-open
             (buffer-live-p buffer) (buffer-local-value 'buffer-file-name buffer))
    (with-current-buffer buffer
      (when (get-buffer-window buffer)
        (with-selected-window (get-buffer-window buffer)
          (notasi-mode--show-preview)))
      (notasi-preview-redraw))))

;;;; The mode

(defvar-keymap notasi-mode-map
  :parent lisp-data-mode-map
  "C-c C-c" #'notasi-preview-redraw
  "C-c C-p" #'notasi-preview-toggle
  "C-c C-o" #'notasi-write-score
  "C-c C-s" #'notasi-choose-score)

;;;###autoload
(define-derived-mode notasi-mode lisp-data-mode "notasi"
  "Major mode for writing notasi's gamelan notation (.nts files).

The forms are highlighted, and in the music of parts, patterns and
colotomies, notes, holds, rests, bars and pattern calls each have a
face: `notasi-note', `notasi-hold', `notasi-rest', `notasi-bar' and
`notasi-pattern'.  `piece', `score', `pattern' and the other forms
indent their body by 2, and a line of options (starting with `:') by
4.

\\{notasi-mode-map}"
  :group 'notasi
  :syntax-table notasi-mode-syntax-table
  (setq-local lisp-indent-function #'notasi-mode--indent-function)
  (setq-local comment-start ";")
  (setq-local indent-tabs-mode nil)
  (setq-local font-lock-defaults '(notasi-mode--font-lock-keywords))
  (when buffer-file-name
    (add-hook 'kill-buffer-hook #'notasi-mode--clean-up nil t)
    (add-hook 'after-change-functions #'notasi-mode--changed nil t)
    (add-hook 'after-save-hook #'notasi-mode--saved nil t)
    (add-hook 'post-command-hook #'notasi-mode--follow nil t)
    (setq-local flymake-diagnostic-functions '(notasi-flymake))
    (flymake-mode 1)
    ;; `find-file' shows the buffer only after the mode has run.
    (run-at-time 0 nil #'notasi-mode--open (current-buffer))))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.nts\\'" . notasi-mode))

(provide 'notasi-mode)

;;; notasi-mode.el ends here
