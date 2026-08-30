;;; jot-picker.el --- Note selection and creation for jot.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Szymon Wilczek

;; Author: Szymon Wilczek <swilczek.lx@gmail.com>
;; Keywords: convenience, tools

;;; Commentary:
;; Completing-read note selector, opener, and on-the-fly creator.

;;; Code:

(require 'subr-x)
(require 'jot-config)
(require 'jot-context)
(require 'jot-storage)
(require 'jot-frame)
(require 'jot-buffer)

(defun jot-open-note (file-path &optional note-name session-name link)
  "Open note FILE-PATH in the floating frame.
Optionally associate with NOTE-NAME, SESSION-NAME, and create LINK when non-nil."
  (let* ((session (or session-name (jot-current-session-name)))
         (note (or note-name (jot--note-name-from-file file-path)))
         (parent (selected-frame)))
    (when link
      (jot-link-note-to-session file-path session))
    (setq jot--active-note note
          jot--active-session session)
    (let ((buf (jot--get-or-create-buffer file-path note session)))
      (jot--create-or-update-frame buf parent))))

(defun jot-find-note (&optional session-name)
  "Open note selector with `completing-read'.
Selecting an existing note links it to SESSION-NAME (or current workspace).
Entering a new name creates the note and links it."
  (interactive)
  (let* ((session (or session-name (jot-current-session-name)))
         (notes (jot--all-notes))
         (icon (if jot-icons (or jot-picker-icon "") ""))
         (prompt (replace-regexp-in-string "{icon}" icon jot-picker-prompt))
         (candidates (mapcar #'car notes))
         (choice (string-trim (completing-read prompt candidates nil nil))))
    (when (jot--valid-note-name-p choice)
      (let* ((existing (alist-get choice notes nil nil #'string=))
             (file (or existing (jot--note-path choice))))
        (unless (file-exists-p file)
          (write-region "" nil file nil 'silent))
        (jot-open-note file choice session t)))))

(provide 'jot-picker)
;;; jot-picker.el ends here
