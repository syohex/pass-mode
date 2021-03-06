;;; pass-mode.el --- Major mode for password-store.el -*- lexical-binding: t; -*-

;; Copyright (C) 2015  Nicolas Petton & Damien Cassou

;; Author: Nicolas Petton <petton.nicolas@gmail.com>
;;         Damien Cassou <damien@cassou.me>
;; Version: 0.1
;; GIT: https://github.com/NicolasPetton/password-store-mode
;; Package-Requires: ((emacs "24") (password-store "0.1") (f "0.17"))
;; Created: 09 Jun 2015
;; Keywords: password-store, password, keychain

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Major mode for password-store.el

;;; Code:
(require 'password-store)
(require 'f)

(defgroup pass-mode '()
  "Major mode for password-store."
  :group 'password-store)

(defvar pass-mode-buffer-name "*Password-Store*"
  "Name of the pass-mode buffer.")

(defvar pass-mode-hook nil
  "Mode hook for `pass-mode'.")

(defvar pass-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "n") #'pass-mode-next-entry)
    (define-key map (kbd "p") #'pass-mode-prev-entry)
    (define-key map (kbd "M-n") #'pass-mode-next-directory)
    (define-key map (kbd "M-p") #'pass-mode-prev-directory)
    (define-key map (kbd "k") #'pass-mode-kill)
    (define-key map (kbd "s") #'isearch-forward)
    (define-key map (kbd "r") #'isearch-backward)
    (define-key map (kbd "?") #'describe-mode)
    (define-key map (kbd "g") #'pass-mode-update-buffer)
    (define-key map (kbd "i") #'pass-mode-insert)
    (define-key map (kbd "w") #'pass-mode-copy)
    (define-key map (kbd "v") #'pass-mode-view)
    (define-key map (kbd "RET") #'pass-mode-view)
    (define-key map (kbd "q") #'pass-mode-quit)
    map)
  "Keymap for `pass-mode'.")

(defface pass-mode-header-face '((t . (:inherit font-lock-keyword-face)))
  "Face for displaying the header of the pass-mode buffer."
  :group 'pass-mode)

(defface pass-mode-entry-face '((t . ()))
  "Face for displaying pass-mode entry names."
  :group 'pass-mode)

(defface pass-mode-directory-face '((t . (:inherit
                                          font-lock-function-name-face
                                          :weight
                                          bold)))
  "Face for displaying password-store directory names."
  :group 'pass-mode)

(defface pass-mode-password-face '((t . (:inherit widget-field)))
  "Face for displaying password-store entrys names."
  :group 'pass-mode)

(defun pass-mode ()
  "Major mode for editing password-stores.

\\{pass-mode-map}"
  (kill-all-local-variables)
  (setq major-mode 'pass-mode
        mode-name 'Password-Store)
  (read-only-mode)
  (use-local-map pass-mode-map)
  (run-hooks 'pass-mode-hook))

(defun pass-mode-setup-buffer ()
  "Setup the password-store buffer."
  (pass-mode)
  (pass-mode-update-buffer))

;;;###autoload
(defun pass ()
  "Open the password-store buffer."
  (interactive)
  (if (get-buffer pass-mode-buffer-name)
      (switch-to-buffer pass-mode-buffer-name)
    (progn
      (let ((buf (get-buffer-create pass-mode-buffer-name)))
        (pop-to-buffer buf)
        (pass-mode-setup-buffer)))))

(defun pass-mode-quit ()
  "Kill the buffer quitting the window and forget the pass-mode."
  (interactive)
  (quit-window t))

(defun pass-mode-next-entry ()
  "Move point to the next entry found."
  (interactive)
  (pass-mode--goto-next #'pass-mode-entry-at-point))

(defun pass-mode-prev-entry ()
  "Move point to the previous entry."
  (interactive)
  (pass-mode--goto-prev #'pass-mode-entry-at-point))

(defun pass-mode-next-directory ()
  "Move point to the next directory found."
  (interactive)
  (pass-mode--goto-next #'pass-mode-directory-at-point))

(defun pass-mode-prev-directory ()
  "Move point to the previous directory."
  (interactive)
  (pass-mode--goto-prev #'pass-mode-directory-at-point))

(defmacro pass-mode--with-closest-entry (varname &rest body)
  "Bound VARNAME to the closest entry before point and evaluate BODY."
  (declare (indent 1) (debug t))
  `(let ((,varname (pass-mode-closest-entry)))
     (if ,varname
         ,@body
       (message "No entry at point"))))

(defun pass-mode-kill ()
  "Remove the entry at point."
  (interactive)
  (pass-mode--with-closest-entry entry
    (when (yes-or-no-p (format "Do you want remove the entry %s? " entry))
      (password-store-remove entry)
      (pass-mode-update-buffer))))

(defun pass-mode-update-buffer ()
  "Update the current buffer contents."
  (interactive)
  (pass-mode--save-point
    (pass-mode--with-writable-buffer
      (delete-region (point-min) (point-max))
      (pass-mode-display-data))))

(defun pass-mode-insert (&optional arg)
  "Insert an entry to the password-store.
When called with a prefix argument ARG, use a generated password
instead of reading the password from user input."
  (interactive "P")
  (if arg
      (call-interactively #'password-store-generate)
    (call-interactively #'password-store-insert))
  (pass-mode-update-buffer))

(defun pass-mode-view ()
  "Visit the entry at point."
  (interactive)
  (pass-mode--with-closest-entry entry
    (password-store-edit entry)))

(defun pass-mode-copy ()
  "Visit the entry at point."
  (interactive)
  (pass-mode--with-closest-entry entry
    (password-store-copy entry)))

(defun pass-mode-display-data ()
  "Display the password-store data into the current buffer."
  (let ((items (pass-mode--tree)))
    (pass-mode-display-header)
    (pass-mode-display-item items)))

(defun pass-mode-display-header ()
  "Display the header in to the current buffer."
  (insert (format "Password-store directory:"))
  (put-text-property (point-at-bol) (point) 'face 'pass-mode-header-face)
  (insert " ")
  (newline)
  (newline))

(defun pass-mode-display-item (item &optional indent-level)
  "Display the directory or entry ITEM into the current buffer.
If INDENT-LEVEL is specified, add enough spaces before displaying
ITEM."
  (unless indent-level (setq indent-level 0))
  (let ((directory (listp item)))
    (pass-mode-display-item-prefix indent-level)
    (if directory
        (pass-mode-display-directory item indent-level)
      (pass-mode-display-entry item))))

(defun pass-mode-display-entry (entry)
  "Display the password-store entry ENTRY into the current buffer."
  (let ((entry-name (f-filename entry)))
    (insert entry-name)
    (add-text-properties (point-at-bol) (point)
                         `(face pass-mode-entry-face pass-mode-entry ,entry))
    (newline)))

(defun pass-mode-display-directory (directory indent-level)
  "Display the directory DIRECTORY into the current buffer.

DIRECTORY is a list, its CAR being the name of the directory and its CDR
the entries of the directory.  Add enough spaces so that each entry is
indented according to INDENT-LEVEL."
  (let ((name (car directory))
        (items (cdr directory)))
    (when (not (string= name ".git"))
      (insert name)
      (add-text-properties (point-at-bol) (point)
                           `(face pass-mode-directory-face pass-mode-directory ,name))
      (newline)
      (dolist (item items)
        (pass-mode-display-item item (1+ indent-level))))))

(defun pass-mode-display-item-prefix (indent-level)
  "Display some indenting text according to INDENT-LEVEL."
  (dotimes (_ (max 0 (* (1- indent-level) 4)))
    (insert " "))
  (unless (zerop indent-level)
    (insert "├── ")))

(defun pass-mode-entry-at-point ()
  "Return the `pass-mode-entry' property at point."
  (get-text-property (point) 'pass-mode-entry))

(defun pass-mode-directory-at-point ()
  "Return the `pass-mode-directory' property at point."
  (get-text-property (point) 'pass-mode-directory))

(defun pass-mode-closest-entry ()
  "Return the closest entry in the current buffer, looking backward."
  (save-excursion
    (unless (bobp)
      (or (pass-mode-entry-at-point)
          (progn
            (forward-line -1)
            (pass-mode-closest-entry))))))

(defun pass-mode--goto-next (pred)
  "Move point to the next match of PRED."
  (forward-line)
  (while (not (or (eobp) (funcall pred)))
    (forward-line)))

(defun pass-mode--goto-prev (pred)
  "Move point to the previous match of PRED."
  (forward-line -1)
  (while (not (or (bobp) (funcall pred)))
    (forward-line -1)))

(defmacro pass-mode--with-writable-buffer (&rest body)
  "Evaluate BODY with the current buffer not in `read-only-mode'."
  (declare (indent 0) (debug t))
  (let ((read-only (make-symbol "ro")))
    `(let ((,read-only buffer-read-only))
       (read-only-mode -1)
       ,@body
       (when ,read-only
         (read-only-mode 1)))))

(defmacro pass-mode--save-point (&rest body)
  "Evaluate BODY and restore the point.
Similar to `save-excursion' but only restore the point."
  (declare (indent 0) (debug t))
  (let ((point (make-symbol "point")))
    `(let ((,point (point)))
       ,@body
       (goto-char (min ,point (point-max))))))

(defun pass-mode--tree (&optional subdir)
  "Return a tree of all entries in SUBDIR.
If SUBDIR is nil, return the entries of `(password-store-dir)'."
  (unless subdir (setq subdir ""))
  (let ((path (f-join (password-store-dir) subdir)))
    (delq nil
          (if (f-directory? path)
              (cons (f-filename path)
                    (mapcar 'pass-mode--tree
                            (f-entries path)))
            (when (equal (f-ext path) "gpg")
              (password-store--file-to-entry path))))))

(string-match-p "/" "hello/world")
(split-string "hello/world" "/")

(provide 'pass-mode)
;;; pass-mode.el ends here
