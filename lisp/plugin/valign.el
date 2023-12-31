(require 'cl-generic)
(require 'cl-lib)
(require 'pcase)

(defgroup valign nil
  "Visually align text tables on GUI."
  :group 'text)

(defcustom valign-lighter " valign"
  "The lighter string used by function `valign-mode'."
  :type 'string)

(defcustom valign-fancy-bar nil
  "Non-nil means to render bar as a full-height line.
You need to restart valign mode for this setting to take effect."
  :type '(choice
          (const :tag "Enable fancy bar" t)
          (const :tag "Disable fancy bar" nil)))

;;; Backstage

(define-error 'valign-not-gui "Valign only works in GUI environment")
(define-error 'valign-not-on-table "Valign is asked to align a table, but the point is not on one")
(define-error 'valign-parse-error "Valign cannot parse the table")

;;;; Table.el tables

(defvar valign-box-charset-alist
  '((ascii . "
+-++
| ||
+-++
+-++")
    (unicode . "
┌─┬┐
│ ││
├─┼┤
└─┴┘"))
  "An alist of (NAME . CHARSET).
A charset tells ftable how to parse the table.  I.e., what are the
box drawing characters to use.  Don’t forget the first newline.
NAME is the mnemonic for that charset.")

(defun valign-box-char (code charset)
  "Return a specific box drawing character in CHARSET.

Return a string.  CHARSET should be like `ftable-box-char-set'.
Mapping between CODE and position:

    ┌┬┐     123
    ├┼┤ <-> 456
    └┴┘     789

    ┌─┐     1 H 3    H: horizontal
    │ │ <-> V   V    V: vertical
    └─┘     7 H 9

Examples:

    (ftable-box-char 'h charset) => \"─\"
    (ftable-box-char 2 charset)  => \"┬\""
  (let ((index (pcase code
                 ('h 10)
                 ('v 11)
                 ('n 12)
                 ('s 13)
                 (_ code))))

    (char-to-string
     (aref charset ;        1 2 3 4  5  6  7  8  9  H V N S
           (nth index '(nil 1 3 4 11 13 14 16 18 19 2 6 0 7))))))

;;;; Auxilary

(defun valign--cell-alignment ()
  "Return how is current cell aligned.
Return 'left if aligned left, 'right if aligned right.
Assumes point is after the left bar (“|”).
Doesn’t check if we are in a cell."
  (save-excursion
    (if (looking-at " [^ ]")
        'left
      (if (not (search-forward "|" nil t))
          (signal
           'valign-parse-error
           (list (format "Missing the right bar (|) around %s" (point))))
        (if (looking-back
             "[^ ] |" (max (- (point) 3) (point-min)))
            'right
          'left)))))

(defun valign--cell-content-config (&optional bar-char)
  "Return (CELL-BEG CONTENT-BEG CONTENT-END CELL-END).
CELL-BEG is after the left bar, CELL-END is before the right bar.
CELL-CONTENT contains the actual non-white-space content,
possibly with a single white space padding on the either side, if
there are more than one white space on that side.

If the cell is empty, CONTENT-BEG is

    (min (CELL-BEG + 1) CELL-END)

CONTENT-END is

    (max (CELL-END - 1) CELL-BEG)

BAR-CHAR is the separator character (“|”).  It is actually a
string.  Defaults to the normal bar: “|”, but you can provide a
Unicode one for Unicode tables.

Assumes point is after the left bar (“|”).  Assumes there is a
right bar."
  (save-excursion
    (let* ((bar-char (or bar-char "|"))
           (cell-beg (point))
           (cell-end
            (save-excursion
              (unless (search-forward bar-char (line-end-position) t)
                (signal 'valign-parse-error
                        (list (format
                               "Missing the right bar (|) around %d"
                               (line-end-position)))))
              (match-beginning 0)))
           ;; `content-beg-strict' is the beginning of the content
           ;; excluding any white space. Same for `content-end-strict'.
           content-beg-strict content-end-strict)
      (if (save-excursion (skip-chars-forward " ")
                          (looking-at-p bar-char))
          ;; Empty cell.
          (list cell-beg
                (min (1+ cell-beg) cell-end)
                (max (1- cell-end) cell-beg)
                cell-end)
        ;; Non-empty cell.
        (skip-chars-forward " ")
        (setq content-beg-strict (point))
        (goto-char cell-end)
        (skip-chars-backward " ")
        (setq content-end-strict (point))
        (when (and (= content-beg-strict cell-beg)
                   (= content-end-strict cell-end))
          (signal 'valign-parse-error `("The cell should contain at least one space" ,(buffer-substring-no-properties (1- cell-beg) (1+ cell-end)))))
        ;; Calculate delimiters. Basically, we try to preserve a white
        ;; space on the either side of the content, i.e., include them
        ;; in (BEG . END). Because if you are typing in a cell and
        ;; type a space, you probably want valign to keep that space
        ;; as cell content, rather than to consider it as part of the
        ;; padding and add overlay over it.
        (list cell-beg
              (if (<= (- content-beg-strict cell-beg) 1)
                  content-beg-strict
                (1- content-beg-strict))
              (if (<= (- cell-end content-end-strict) 1)
                  content-end-strict
                (1+ content-end-strict))
              cell-end)))))

(defun valign--cell-empty-p ()
  "Return non-nil if cell is empty.
Assumes point is after the left bar (“|”)."
  (save-excursion
    (and (skip-chars-forward " ")
         (looking-at "|"))))

(defun valign--cell-content-width (&optional bar-char)
  "Return the pixel width of the cell at point.
Assumes point is after the left bar (“|”).  Return nil if not in
a cell.  BAR-CHAR is the bar character (“|”)."
  ;; We assumes:
  ;; 1. Point is after the left bar (“|”).
  ;; 2. Cell is delimited by either “|” or “+”.
  ;; 3. There is at least one space on either side of the content,
  ;;    unless the cell is empty.
  ;; IOW: CELL      := <DELIM>(<EMPTY>|<NON-EMPTY>)<DELIM>
  ;;      EMPTY     := <SPACE>+
  ;;      NON-EMPTY := <SPACE>+<NON-SPACE>+<SPACE>+
  ;;      DELIM     := | or +
  (pcase-let* ((`(,_a ,beg ,end ,_b)
                (valign--cell-content-config bar-char)))
    (valign--pixel-width-from-to beg end)))

;; Sometimes, because of Org's table alignment, empty cell is longer
;; than non-empty cell.  This usually happens with CJK text, because
;; CJK characters are shorter than 2x ASCII character but Org treats
;; CJK characters as 2 ASCII characters when aligning.  And if you
;; have 16 CJK char in one cell, Org uses 32 ASCII spaces for the
;; empty cell, which is longer than 16 CJK chars.  So better regard
;; empty cell as 0-width rather than measuring it's white spaces.
(defun valign--cell-nonempty-width (&optional bar-char)
  "Return the pixel width of the cell at point.
If the cell is empty, return 0.  Otherwise return cell content’s
width.  BAR-CHAR is the bar character (“|”)."
  (if (valign--cell-empty-p) 0
    (valign--cell-content-width bar-char)))

;; We used to use a custom functions that calculates the pixel text
;; width that doesn’t require a live window.  However that function
;; has some limitations, including not working right with face remapping.
;; With this function we can avoid some of them.  However we still can’t
;; get the true tab width, see comment in ‘valgn--tab-width’ for more.
(defun valign--pixel-width-from-to (from to)
  "Return the width of the glyphs from FROM (inclusive) to TO (exclusive).
The buffer has to be in a live window.  FROM has to be less than
TO and they should be on the same line.  Valign display
properties must be cleaned before using this."
  (- (car (window-text-pixel-size
           nil (line-beginning-position) to))
     (+ (car (window-text-pixel-size
              nil (line-beginning-position) from))
        ;; HACK: You would expect (window-text-pixel-size WINDOW
        ;; FROM TO) to return line-number-display-width when FROM
        ;; equals to TO, but no, it returns 0.
        (if (eq (line-beginning-position) from)
            (line-number-display-width 'pixel)
          0))))

(defun valign--pixel-x (point)
  "Return the x pixel position of POINT."
  (- (car (window-text-pixel-size nil (line-beginning-position) point))
     (line-number-display-width 'pixel)))

(defun valign--separator-p (&optional point)
  "If the current cell is actually a separator.
POINT should be after the left bar (“|”), default to current point."
  (or (eq (char-after point) ?:) ;; Markdown tables.
      (eq (char-after point) ?-)))

(defun valign--alignment-from-seperator ()
  "Return the alignment of this column.
Assumes point is after the left bar (“|”) of a separator
cell.  We don’t distinguish between left and center aligned."
  (save-excursion
    (if (eq (char-after) ?:)
        'left
      (skip-chars-forward "-")
      (if (eq (char-after) ?:)
          'right
        'left))))

(defmacro valign--do-row (row-idx-sym limit &rest body)
  "Go to each row’s beginning and evaluate BODY.
At each row, stop at the beginning of the line.  Start from point
and stop at LIMIT.  ROW-IDX-SYM is bound to each row’s
index (0-based)."
  (declare (debug (sexp form &rest form))
           (indent 2))
  `(progn
     (setq ,row-idx-sym 0)
     (while (< (point) (min ,limit (point-max)))
       (beginning-of-line)
       ,@body
       (forward-line)
       (cl-incf ,row-idx-sym))))

(defmacro valign--do-column (column-idx-sym bar-char &rest body)
  "Go to each column in the row and evaluate BODY.
Start from point and stop at the end of the line.  Stop after the
cell bar (“|”) in each iteration.  BAR-CHAR is \"|\" for the most
case.  COLUMN-IDX-SYM is bound to the index of the
column (0-based)."
  (declare (debug (sexp &rest form))
           (indent 2))
  `(progn
     (setq ,column-idx-sym 0)
     (beginning-of-line)
     (while (search-forward ,bar-char (line-end-position) t)
       ;; Unless we are after the last bar.
       (unless (looking-at (format "[^%s]*\n" (regexp-quote ,bar-char)))
         ,@body)
       (cl-incf ,column-idx-sym))))

(defun valign--transpose (matrix)
  "Transpose MATRIX."
  (cl-loop for col-idx from 0 to (1- (length (car matrix)))
           collect
           (cl-loop for row in matrix
                    collect (nth col-idx row))))

(defun valign---check-dimension (matrix)
  "Check that the dimension of MATRIX is correct.
Correct dimension means each row has the same number of columns.
Return t if the dimension is correct, nil if not."
  (let ((first-row-column-count (length (car matrix))))
    (cl-loop for row in (cdr matrix)
             if (not (eq first-row-column-count (length row)))
             return nil
             finally return t)))

(defsubst valign--char-after-as-string (&optional pos)
  "Return (char-after POS) as a string."
  ;; (char-to-string (char-after)) doesn’t work because
  ;; ‘char-to-string’ doesn’t accept nil. ‘if-let’ has some problems
  ;; so I replaced it with ‘let’ and ‘if’ (See Bug #25 on GitHub).
  (let ((ch (char-after pos)))
    (if ch (char-to-string ch))))

(defun valign--separator-line-p (&optional charset)
  "Return t if this line is a separator line.
If the table is a table.el table, you need to specify CHARSET.
If the table is not a table.el table, DON’T specify CHARSET.
Assumes the point is at the beginning of the line."
  (save-excursion
    (skip-chars-forward " \t")
    (if charset
        ;; Check for table.el tables.
        (let ((charset (or charset (cdar valign-box-charset-alist))))
          (member (valign--char-after-as-string)
                  (list (valign-box-char 1 charset)
                        (valign-box-char 4 charset)
                        (valign-box-char 7 charset))))
      ;; Check for org/markdown tables.
      (and (eq (char-after) ?|)
           (valign--separator-p (1+ (point)))))))

(defun valign--calculate-cell-width (limit &optional charset)
  "Return a list of column widths.
Each column width is the largest cell width of the column.  Start
from point, stop at LIMIT.  If the table is a table.el table, you
need to specify CHARSET."
  (let* ((bar-char (if charset (valign-box-char 'v charset) "|"))
         row-idx column-idx matrix row)
    (ignore row-idx)
    (save-excursion
      (valign--do-row row-idx limit
        (unless (valign--separator-line-p charset)
          (setq row nil)
          (valign--do-column column-idx bar-char
            ;; Point is after the left “|”.
            (push (valign--cell-nonempty-width bar-char) row))
          (push (reverse row) matrix))))
    ;; Sanity check.
    (unless (valign---check-dimension matrix)
      (signal 'valign-parse-error '("The number of columns for each row don’t match, maybe a bar (|) is missing?")))
    (setq matrix (valign--transpose (reverse matrix)))
    ;; Add 8 pixels of padding.
    (mapcar (lambda (col) (+ (apply #'max col) 8)) matrix)))

(cl-defmethod valign--calculate-alignment ((type (eql markdown)) limit)
  "Return a list of alignments ('left or 'right) for each column.
TYPE must be 'markdown.  Start at point, stop at LIMIT."
  (ignore type)
  (let (row-idx column-idx matrix row)
    (ignore row-idx)
    (save-excursion
      (valign--do-row row-idx limit
        (when (valign--separator-line-p)
          (setq row nil)
          (valign--do-column column-idx "|"
            (push (valign--alignment-from-seperator) row))
          (push (reverse row) matrix))))
    ;; Sanity check.
    (unless (valign---check-dimension matrix)
      (signal 'valign-parse-error '("The number of columns for each row don’t match, maybe a bar (|) is missing?")))
    (setq matrix (valign--transpose (reverse matrix)))
    (if matrix
        (mapcar #'car matrix)
      (dotimes (_ (or column-idx 0) matrix)
        (push 'left matrix)))))

(cl-defmethod valign--calculate-alignment ((type (eql org)) limit)
  "Return a list of alignments ('left or 'right) for each column.
TYPE must be 'org.  Start at point, stop at LIMIT."
  ;; Why can’t infer the alignment on each cell by its space padding?
  ;; Because the widest cell of a column has one space on both side,
  ;; making it impossible to infer the alignment.
  (ignore type)
  (let (column-idx row-idx row matrix)
    (ignore row-idx)
    (save-excursion
      (valign--do-row row-idx limit
        (unless (valign--separator-line-p)
          (setq row nil)
          (valign--do-column column-idx "|"
            (push (valign--cell-alignment) row))
          (push (reverse row) matrix)))
      ;; Sanity check.
      (unless (valign---check-dimension matrix)
        (signal 'valign-parse-error '("The number of columns for each row don’t match, maybe a bar (|) is missing?")))
      (setq matrix (valign--transpose (reverse matrix)))
      ;; For each column, we take the majority.
      (mapcar (lambda (col)
                (let ((left-count (cl-count 'left col))
                      (right-count (cl-count 'right col)))
                  (if (> left-count right-count)
                      'left 'right)))
              matrix))))

(defun valign--at-table-p ()
  "Return non-nil if point is in a table."
  (save-excursion
    (beginning-of-line)
    (skip-chars-forward " \t")
    ;; CHAR is the first character, CHAR 2 is the one after it.
    (let ((char (valign--char-after-as-string))
          (char2 (valign--char-after-as-string (1+ (point)))))
      (or (equal char "|")
          (cl-loop
           for elt in valign-box-charset-alist
           for charset = (cdr elt)
           if (or (equal char (valign-box-char 'v charset))
                  (and (equal char
                              (valign-box-char 1 charset))
                       (member char2
                               (list (valign-box-char 2 charset)
                                     (valign-box-char 3 charset)
                                     (valign-box-char 'h charset))))
                  (and (equal char
                              (valign-box-char 4 charset))
                       (member char2
                               (list (valign-box-char 5 charset)
                                     (valign-box-char 6 charset)
                                     (valign-box-char 'h charset))))
                  (and (equal char
                              (valign-box-char 7 charset))
                       (member char2
                               (list (valign-box-char 8 charset)
                                     (valign-box-char 9 charset)
                                     (valign-box-char 'h charset)))))
           return t
           finally return nil)))))

(defun valign--align-p ()
  "Return non-nil if we should align the table at point."
  (save-excursion
    (beginning-of-line)
    (let ((face (plist-get (text-properties-at (point)) 'face)))
      ;; Don’t align tables in org blocks.
      (not (and (consp face)
                (or (equal face '(org-block))
                    (equal (plist-get face :inherit)
                           '(org-block))))))))

(defun valign--beginning-of-table ()
  "Go backward to the beginning of the table at point.
Assumes point is on a table."
  ;; This implementation allows non-table lines before a table, e.g.,
  ;; #+latex: xxx
  ;; |------+----|
  (when (valign--at-table-p)
    (beginning-of-line))
  (while (and (< (point-min) (point))
              (valign--at-table-p))
    (forward-line -1))
  (unless (valign--at-table-p)
    (forward-line 1)))

(defun valign--end-of-table ()
  "Go forward to the end of the table at point.
Assumes point is on a table."
  (let ((start (point)))
    (when (valign--at-table-p)
      (beginning-of-line))
    (while (and (< (point) (point-max))
                (valign--at-table-p))
      (forward-line 1))
    (unless (<= (point) start)
      (skip-chars-backward "\n"))
    (when (< (point) start)
      (error "End of table goes backwards"))))

(defun valign--put-overlay (beg end &rest props)
  "Put overlay between BEG and END.
PROPS contains properties and values."
  (let ((ov (make-overlay beg end nil t nil)))
    (overlay-put ov 'valign t)
    (overlay-put ov 'evaporate t)
    (while props
      (overlay-put ov (pop props) (pop props)))))

(defun valign--put-text-prop (beg end &rest props)
  "Put text property between BEG and END.
PROPS contains properties and values."
  (with-silent-modifications
    (add-text-properties beg end props)
    (put-text-property beg end 'valign t)))

(defsubst valign--space (xpos)
  "Return a display property that aligns to XPOS."
  `(space :align-to (,xpos)))

(defvar valign-fancy-bar)
(defun valign--maybe-render-bar (point)
  "Make the character at POINT a full height bar.
But only if `valign-fancy-bar' is non-nil."
  (when valign-fancy-bar
    (valign--render-bar point)))

(defun valign--fancy-bar-cursor-fn (window prev-pos action)
  "Run when point enters or left a fancy bar.
Because the bar is so thin, the cursor disappears in it.  We
expands the bar so the cursor is visible.  'cursor-intangible
doesn’t work because it prohibits you to put the cursor at BOL.

WINDOW is just window, PREV-POS is the previous point of cursor
before event, ACTION is either 'entered or 'left."
  (ignore window)
  (with-silent-modifications
    (let ((ov-list (overlays-at (pcase action
                                  ('entered (point))
                                  ('left prev-pos)))))
      (dolist (ov ov-list)
        (when (overlay-get ov 'valign-bar)
          (overlay-put
           ov 'display (pcase action
                         ('entered (if (eq cursor-type 'bar)
                                       '(space :width (3)) " "))
                         ('left '(space :width (1))))))))))

(defun valign--render-bar (point)
  "Make the character at POINT a full-height bar."
  (with-silent-modifications
    (put-text-property point (1+ point)
                       'cursor-sensor-functions
                       '(valign--fancy-bar-cursor-fn))
    (valign--put-overlay point (1+ point)
                         'face '(:inverse-video t)
                         'display '(space :width (1))
                         'valign-bar t)))

(defun valign--clean-text-property (beg end)
  "Clean up the display text property between BEG and END."
  (with-silent-modifications
    (put-text-property beg end 'cursor-sensor-functions nil))
  ;; Remove overlays.
  (let ((ov-list (overlays-in beg end)))
    (dolist (ov ov-list)
      (when (overlay-get ov 'valign)
        (delete-overlay ov))))
  ;; Remove text properties.
  (let ((p beg) tab-end (last-p -1))
    (while (not (eq p last-p))
      (when (plist-get (text-properties-at p) 'valign)
        ;; We are at the beginning of a tab, now find the end.
        (setq tab-end (next-single-char-property-change
                       p 'valign nil end))
        ;; Remove text property.
        (with-silent-modifications
          (put-text-property p tab-end 'display nil)
          (put-text-property p tab-end 'valign nil)))
      (setq last-p p
            p (next-single-char-property-change p 'valign nil end)))))

(defun valign--glyph-width-of (string point)
  "Return the pixel width of STRING with font at POINT.
STRING should have length 1."
  (aref (aref (font-get-glyphs (font-at point) 0 1 string) 0) 4))

(defun valign--separator-row-add-overlay (beg end right-pos)
  "Add overlay to a separator row’s “cell”.
Cell ranges from BEG to END, the pixel position RIGHT-POS marks
the position for the right bar (“|”).
Assumes point is on the right bar or plus sign."
  ;; Make “+” look like “|”
  (if valign-fancy-bar
      ;; Render the right bar.
      (valign--render-bar end)
    (when (eq (char-after end) ?+)
      (let ((ov (make-overlay end (1+ end))))
        (overlay-put ov 'display "|")
        (overlay-put ov 'valign t))))
  ;; Markdown row
  (when (eq (char-after beg) ?:)
    (setq beg (1+ beg)))
  (when (eq (char-before end) ?:)
    (setq end (1- end)
          right-pos (- right-pos
                       (valign--pixel-width-from-to (1- end) end))))
  ;; End of Markdown
  (valign--put-overlay beg end
                       'display (valign--space right-pos)
                       'face '(:strike-through t)))

(defun valign--align-separator-row (column-width-list)
  "Align the separator row in multi column style.
COLUMN-WIDTH-LIST is returned by `valign--calculate-cell-width'."
  (let ((bar-width (valign--glyph-width-of "|" (point)))
        (space-width (valign--glyph-width-of " " (point)))
        (column-start (point))
        (col-idx 0)
        (pos (valign--pixel-x (point))))
    ;; Render the first left bar.
    (valign--maybe-render-bar (1- (point)))
    ;; Add overlay in each column.
    (while (re-search-forward "[|\\+]" (line-end-position) t)
      ;; Render the right bar.
      (valign--maybe-render-bar (1- (point)))
      (let ((column-width (nth col-idx column-width-list)))
        (valign--separator-row-add-overlay
         column-start (1- (point)) (+ pos column-width space-width))
        (setq column-start (point)
              pos (+ pos column-width bar-width space-width))
        (cl-incf col-idx)))))

(defun valign--guess-table-type ()
  "Return either 'org or 'markdown."
  (cond ((derived-mode-p 'org-mode 'org-agenda-mode) 'org)
        ((derived-mode-p 'markdown-mode) 'markdown)
        ((string-match-p "org" (symbol-name major-mode)) 'org)
        ((string-match-p "markdown" (symbol-name major-mode)) 'markdown)
        (t 'org)))


;;; Align

(defcustom valign-not-align-after-list '(self-insert-command
                                         org-self-insert-command
                                         markdown-outdent-or-delete
                                         org-delete-backward-char
                                         backward-kill-word
                                         delete-char
                                         kill-word)
  "Valign doesn’t align table after these commands."
  :type '(list symbol)
  :group 'valign)

(defvar valign-signal-parse-error nil
  "When non-nil and ‘debug-on-error’, signal parse error.
If ‘debug-on-error’ is also non-nil, drop into the debugger.")

(defcustom valign-max-table-size 4000
  "Valign doesn't align tables of size larger than this value.
Valign puts `valign-table-fallback' face onto these tables.  If the
value is zero, valign doesn't check for table sizes."
  :type 'integer
  :group 'valign)

(defface valign-table-fallback
  '((t . (:inherit fixed-pitch)))
  "Fallback face for tables whose size exceeds `valign-max-table-size'."
  :group 'valign)

(defun valign-table-maybe (&optional force go-to-end)
  "Visually align the table at point.
If FORCE non-nil, force align.  If GO-TO-END non-nil, leave point
at the end of the table."
  (condition-case err
      (when (and (display-graphic-p)
                 (valign--at-table-p)
                 (valign--align-p)
                 (or force
                     (not (memq (or this-command last-command)
                                valign-not-align-after-list))))
        (save-excursion
          (valign--beginning-of-table)
          (let ((table-beg (point))
                (table-end (save-excursion
                             (valign--end-of-table)
                             (point))))
            (if (or (eq valign-max-table-size 0)
                    (<= (- table-end table-beg) valign-max-table-size))
                (if (valign--guess-charset)
                    (valign--table-2)
                  (valign-table-1))
              ;; Can't align the table, put fallback-face on.
              (valign--clean-text-property table-beg table-end)
              (valign--put-overlay table-beg table-end
                                   'face 'valign-table-fallback))))
        (when go-to-end (valign--end-of-table)))

    ((valign-parse-error error)
     (valign--clean-text-property
      (save-excursion (valign--beginning-of-table) (point))
      (save-excursion (valign--end-of-table) (point)))
     (when (and (eq (car err) 'valign-parse-error)
                valign-signal-parse-error)
       (if debug-on-error
           (debug 'valign-parse-error)
         (message "%s" (error-message-string err)))))))

(defun valign-table-1 ()
  "Visually align the table at point."
  (valign--beginning-of-table)
  (let* ((space-width (valign--glyph-width-of " " (point)))
         (bar-width (valign--glyph-width-of "|" (point)))
         (table-beg (point))
         (table-end (save-excursion (valign--end-of-table) (point)))
         ;; Very hacky, but..
         (_ (valign--clean-text-property table-beg table-end))
         (column-width-list (valign--calculate-cell-width table-end))
         (column-alignment-list (valign--calculate-alignment
                                 (valign--guess-table-type) table-end))
         row-idx column-idx column-start)
    (ignore row-idx)

    ;; Align each row.
    (valign--do-row row-idx table-end
      (unless (search-forward "|" (line-end-position) t)
        (signal 'valign-parse-error
                (list (format "Missing the right bar (|) around %s"
                              (point)))))
      (if (valign--separator-p)
          ;; Separator row.
          (valign--align-separator-row column-width-list)

        ;; Not separator row, align each cell. ‘column-start’ is the
        ;; pixel position of the current point, i.e., after the left
        ;; bar.
        (setq column-start (valign--pixel-x (point)))

        (valign--do-column column-idx "|"
          (save-excursion
            ;; We are after the left bar (“|”).
            ;; Render the left bar.
            (valign--maybe-render-bar (1- (point)))
            ;; Start aligning this cell.
            ;;      Pixel width of the column.
            (let* ((col-width (nth column-idx column-width-list))
                   ;; left or right aligned.
                   (alignment (nth column-idx column-alignment-list))
                   ;; Pixel width of the cell.
                   (cell-width (valign--cell-content-width)))
              ;; Align cell.
              (pcase-let ((`(,cell-beg ,content-beg
                                       ,content-end ,cell-end)
                           (valign--cell-content-config)))
                (valign--cell col-width alignment cell-width
                              cell-beg content-beg
                              content-end cell-end
                              column-start space-width))
              ;; Update ‘column-start’ for the next cell.
              (setq column-start (+ column-start col-width
                                    bar-width space-width)))))
        ;; Now we are at the last right bar.
        (valign--maybe-render-bar (1- (point)))))))

(defun valign--cell (col-width alignment cell-width
                               cell-beg content-beg
                               content-end cell-end
                               column-start space-width)
  "Align the cell at point.

For an example cell:

|   content content   |
 ↑  ↑              ↑  ↑
 1  2              3  4
    <------5------>
 <--------6---------->

COL-WIDTH     (6) Pixel width of the column
ALIGNMENT         'left or 'right
CELL-WIDTH    (5) Pixel width of the cell content
CELL-BEG      (1) Beginning of the cell
CONTENT-BEG   (2) Beginning of the cell content[1]
CONTENT-END   (3) End of the cell content[1]
CELL-END      (4) End of the cell
COLUMN-START  (1) Pixel x-position of the beginning of the cell
SPACE-WIDTH       Pixel width of a space character

Assumes point is at (2).

[1] This is not completely true, see `valign--cell-content-config'."
  (cl-labels ((valign--put-ov
               (beg end xpos)
               (valign--put-overlay beg end 'display
                                    (valign--space xpos))))
    (cond ((= cell-beg content-beg)
           ;; This cell has only one space.
           (valign--put-ov
            cell-beg cell-end
            (+ column-start col-width space-width)))
          ;; Empty cell.  Sometimes empty cells are
          ;; longer than other non-empty cells (see
          ;; `valign--cell-width'), so we put overlay on
          ;; all but the first white space.
          ((valign--cell-empty-p)
           (valign--put-ov
            content-beg cell-end
            (+ column-start col-width space-width)))
          ;; A normal cell.
          (t
           (pcase alignment
             ;; Align a left-aligned cell.
             ('left (valign--put-ov content-end cell-end
                                    (+ column-start
                                       col-width space-width)))
             ;; Align a right-aligned cell.
             ('right (valign--put-ov
                      cell-beg content-beg
                      (+ column-start
                         (- col-width cell-width)))))))))

(defun valign--table-2 ()
  "Visually align the table.el table at point."
  ;; Instead of overlays, we use text properties in this function.
  ;; Too many overlays degrades performance, and we add a whole bunch
  ;; of them in this function, so better use text properties.
  (valign--beginning-of-table)
  (let* ((charset (valign--guess-charset))
         (ucharset (alist-get 'unicode valign-box-charset-alist))
         (table-beg (point))
         (table-end (save-excursion (valign--end-of-table) (point)))
         ;; Very hacky, but..
         (_ (valign--clean-text-property table-beg table-end))
         ;; Measure char width after cleaning text properties.
         ;; Otherwise the measurement is not accurate.
         (char-width (with-silent-modifications
                       (insert (valign-box-char 'h ucharset))
                       (prog1 (valign--pixel-width-from-to
                               (1- (point)) (point))
                         (backward-delete-char 1))))
         (column-width-list
          ;; Make every width multiples of CHAR-WIDTH.
          (mapcar (lambda (x)
                    ;; Remove the 8 pixels of padding added by
                    ;; `valign--calculate-cell-width'.
                    (* char-width (1+ (/ (- x 8) char-width))))
                  (valign--calculate-cell-width table-end charset)))
         (row-idx 0)
         (column-idx 0)
         (column-start 0))
    (while (< (point) table-end)
      (save-excursion
        (skip-chars-forward " \t")
        (if (not (equal (valign--char-after-as-string)
                        (valign-box-char 'v charset)))
            ;; Render separator line.
            (valign--align-separator-row-full
             column-width-list
             (cond ((valign--first-line-p table-beg table-end)
                    '(1 2 3))
                   ((valign--last-line-p table-beg table-end)
                    '(7 8 9))
                   (t '(4 5 6)))
             charset char-width)
          ;; Render normal line.
          (setq column-start (valign--pixel-x (point))
                column-idx 0)
          (while (search-forward (valign-box-char 'v charset)
                                 (line-end-position) t)
            (valign--put-text-prop
             (1- (point)) (point)
             'display (valign-box-char 'v ucharset))
            (unless (looking-at "\n")
              (pcase-let ((col-width (nth column-idx column-width-list))
                          (`(,cell-beg ,content-beg
                                       ,content-end ,cell-end)
                           (valign--cell-content-config
                            (valign-box-char 'v charset))))
                (valign--put-text-prop
                 content-end cell-end 'display
                 (valign--space (+ column-start col-width char-width)))
                (cl-incf column-idx)
                (setq column-start
                      (+ column-start col-width char-width)))))))
      (cl-incf row-idx)
      (forward-line))))

(defun valign--first-line-p (beg end)
  "Return t if the point is in the first line between BEG and END."
  (ignore end)
  (save-excursion
    (not (search-backward "\n" beg t))))

(defun valign--last-line-p (beg end)
  "Return t if the point is in the last line between BEG and END."
  (ignore beg)
  (save-excursion
    (not (search-forward "\n" end t))))

(defun valign--align-separator-row-full
    (column-width-list codeset charset char-width)
  "Align separator row for a full table (table.el table).

COLUMN-WIDTH-LIST is a list of column widths.  CODESET is a list
of codes that corresponds to the left, middle and right box
drawing character codes to pass to `valign-box-char'.  It can
be (1 2 3), (4 5 6), or (7 8 9).  CHARSET is the same as in
`valign-box-charset-alist'.  CHAR-WIDTH is the pixel width of a
character.

Assumes point before the first character."
  (let* ((middle (valign-box-char (nth 1 codeset) charset))
         (right (valign-box-char (nth 2 codeset) charset))
         ;; UNICODE-CHARSET is used for overlay, CHARSET is used for
         ;; the physical table.
         (unicode-charset (alist-get 'unicode valign-box-charset-alist))
         (uleft (valign-box-char (nth 0 codeset) unicode-charset))
         (umiddle (valign-box-char (nth 1 codeset) unicode-charset))
         (uright (valign-box-char (nth 2 codeset) unicode-charset))
         ;; Aka unicode horizontal.
         (uh (valign-box-char 'h unicode-charset))
         (eol (line-end-position))
         (col-idx 0))
    (valign--put-text-prop (point) (1+ (point)) 'display uleft)
    (goto-char (1+ (point)))
    (while (re-search-forward (rx-to-string `(or ,middle ,right)) eol t)
      ;; Render joints.
      (if (looking-at "\n")
          (valign--put-text-prop (1- (point)) (point) 'display uright)
        (valign--put-text-prop (1- (point)) (point) 'display umiddle))
      ;; Render horizontal lines.
      (save-excursion
        (let ((p (1- (point)))
              (width (nth col-idx column-width-list)))
          (goto-char p)
          (skip-chars-backward (valign-box-char 'h charset))
          (valign--put-text-prop (point) p 'display
                                 (make-string (/ width char-width)
                                              (aref uh 0)))))
      (cl-incf col-idx))))

(defun valign--guess-charset ()
  "Return the charset used by the table at point.
Assumes point at the beginning of the table."
  (cl-loop for charset
           in (mapcar #'cdr valign-box-charset-alist)
           if (equal (valign--char-after-as-string)
                     (valign-box-char 1 charset))
           return charset
           finally return nil))

;;; Mode intergration

(defun valign-region (&optional beg end)
  "Align tables between BEG and END.
Supposed to be called from jit-lock.
Force align if FORCE non-nil."
  ;; Text sized can differ between frames, only use current frame.
  ;; We only align when this buffer is in a live window, because we
  ;; need ‘window-text-pixel-size’ to calculate text size.
  (let* ((beg (or beg (point-min)))
         (end (or end (point-max)))
         (fontified-end end)
         (table-beg-list
          (cons "|" (cl-loop for elt in valign-box-charset-alist
                             for charset = (cdr elt)
                             collect (valign-box-char 1 charset))))
         (table-re (rx-to-string `(or ,@table-beg-list))))
    (when (window-live-p (get-buffer-window nil (selected-frame)))
      (save-excursion
        (goto-char beg)
        (while (and (< (point) end)
                    (re-search-forward table-re end t))
          (condition-case err
              (valign-table-maybe nil t)
            (error (message "Error when aligning table: %s"
                            (error-message-string err))))
          (setq fontified-end (point)))))
    (cons 'jit-lock-bounds (cons beg (max end fontified-end)))))

(defvar valign-mode)
(defun valign--buffer-advice (&rest _)
  "Realign whole buffer."
  (when valign-mode
    (valign-region)))

(defvar org-indent-agentized-buffers)
(defun valign--org-indent-advice (&rest _)
  "Re-align after org-indent is done."
  ;; See ‘org-indent-initialize-agent’.
  (when (not org-indent-agentized-buffers)
    (valign--buffer-advice)))

;; When an org link is in an outline fold, it’s full length
;; is used, when the subtree is unveiled, org link only shows
;; part of it’s text, so we need to re-align.  This function
;; runs after the region is flagged. When the text
;; is shown, jit-lock will make valign realign the text.
(defun valign--flag-region-advice (beg end flag &optional _)
  "Valign hook, realign table between BEG and END.
FLAG is the same as in ‘org-flag-region’."
  (when (and valign-mode (not flag))
    (with-silent-modifications
      ;; Outline has a bug that passes 0 as a buffer position
      ;; to `org-flag-region', so we need to patch that up.
      (put-text-property (max 1 beg) end 'fontified nil))))

(defun valign--tab-advice (&rest _)
  "Force realign after tab so user can force realign."
  (when (and valign-mode
             (valign--at-table-p)
             (valign--align-p))
    (valign-table)))

(defun valign-reset-buffer ()
  "Remove alignment in the buffer."
  (with-silent-modifications
    (valign--clean-text-property (point-min) (point-max))
    (jit-lock-refontify)))

(defun valign-remove-advice ()
  "Remove advices added by valign."
  (interactive)
  (dolist (fn '(org-cycle
                org-table-blank-field
                markdown-cycle))
    (advice-remove fn #'valign--tab-advice))
  (dolist (fn '(text-scale-increase
                text-scale-decrease
                org-toggle-inline-images))
    (advice-remove fn #'valign--buffer-advice))
  (dolist (fn '(org-flag-region outline-flag-region))
    (advice-remove fn #'valign--flag-region-advice))
  (when (featurep 'org-indent)
    (advice-remove 'org-indent-initialize-agent
                   #'valign--org-indent-advice)))

(defun valign--maybe-clean-advice ()
  "Remove advices if there is no buffer with valign-mode enabled.
This runs in `kill-buffer-hook'."
  (when (eq 1 (cl-count-if
               (lambda (buf)
                 (buffer-local-value 'valign-mode buf))
               (buffer-list)))
    (valign-remove-advice)))

;;; Userland

;;;###autoload
(defun valign-table ()
  "Visually align the table at point."
  (interactive)
  (valign-table-maybe t))

;;;###autoload
(define-minor-mode valign-mode
  "Visually align Org tables."
  :require 'valign
  :group 'valign
  :lighter valign-lighter
  (if (not (display-graphic-p))
      (when valign-mode
        (message "Valign mode has no effect in non-graphical display"))
    (if valign-mode
        (progn
          (add-hook 'jit-lock-functions #'valign-region 98 t)
          (dolist (fn '(org-cycle
                        ;; Why this function?  If you tab into an org
                        ;; field (cell) and start typing right away,
                        ;; org clears that field for you with this
                        ;; function.  The problem is, this functions
                        ;; messes up the overlay and makes the bar
                        ;; invisible.  So we have to fix the overlay
                        ;; after this function.
                        org-table-blank-field
                        markdown-cycle))
            (advice-add fn :after #'valign--tab-advice))
          (dolist (fn '(text-scale-increase
                        text-scale-decrease
                        org-toggle-inline-images))
            (advice-add fn :after #'valign--buffer-advice))
          (dolist (fn '(org-flag-region outline-flag-region))
            (advice-add fn :after #'valign--flag-region-advice))
          (when (featurep 'org-indent)
            (advice-add 'org-indent-initialize-agent
                        :after #'valign--org-indent-advice))
          (add-hook 'org-indent-mode-hook #'valign--buffer-advice 0 t)
          (add-hook 'kill-buffer-hook #'valign--maybe-clean-advice 0 t)
          (if valign-fancy-bar (cursor-sensor-mode))
          (jit-lock-refontify))
      (remove-hook 'jit-lock-functions #'valign-region t)
      (remove-hook 'kill-buffer-hook #'valign--maybe-clean-advice t)
      (valign-reset-buffer)
      (cursor-sensor-mode -1)
      (valign--maybe-clean-advice))))

(provide 'valign)
