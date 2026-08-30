;;; jot-buffer.el --- Note buffer management and modes for jot.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Szymon Wilczek

;; Author: Szymon Wilczek <swilczek.lx@gmail.com>
;; Keywords: convenience, tools

;;; Commentary:
;; Buffer initialization, header-line rendering, and buffer-local keymap.

;;; Code:

(require 'subr-x)
(require 'jot-config)
(require 'jot-frame)

(declare-function jot-unlink-session "jot-storage" (&optional session-name))
(declare-function jot-find-note "jot-picker" (&optional session-name))
(declare-function jot-increase-size "jot-size" ())
(declare-function jot-decrease-size "jot-size" ())
(declare-function jot-reset-size "jot-size" ())
(declare-function evil-local-set-key "evil-core" (state key def))

(defun jot--format-header (note-name session-name file-path)
  "Format header-line string for NOTE-NAME in SESSION-NAME at FILE-PATH."
  (let* ((icon (if jot-icons (or jot-title-icon "") ""))
         (tmpl jot-title-template)
         (str (replace-regexp-in-string "{icon}" icon tmpl))
         (str (replace-regexp-in-string "{note}" (or note-name "untitled") str))
         (str (replace-regexp-in-string "{session}" (or session-name "default") str))
         (str (replace-regexp-in-string "{file}" (or file-path "") str)))
    (propertize (string-trim-left str) 'face 'jot-header-face)))

(defvar-keymap jot-buffer-mode-map
  :doc "Keymap used in active jot note buffers."
  "C-c C-c" #'jot-save-and-hide
  "C-c C-k" #'jot-unlink-session
  "C-c C-j" #'jot-find-note
  "M-+"     #'jot-increase-size
  "M-="     #'jot-increase-size
  "M--"     #'jot-decrease-size
  "M-_"     #'jot-decrease-size
  "M-r"     #'jot-reset-size)

(define-minor-mode jot-buffer-mode
  "Minor mode enabled inside floating jot note buffers."
  :lighter " Jot"
  :keymap jot-buffer-mode-map
  (when (and jot-buffer-mode (bound-and-true-p evil-mode))
    (when (fboundp 'evil-local-set-key)
      (evil-local-set-key 'normal (kbd "q") #'jot-hide))))

(defun jot-save-and-hide ()
  "Save the current jot buffer and hide the floating frame."
  (interactive)
  (when (buffer-modified-p)
    (save-buffer))
  (jot-hide))

(defun jot--get-or-create-buffer (file-path note-name session-name)
  "Open or create buffer for FILE-PATH with NOTE-NAME and SESSION-NAME context."
  (let* ((buf (find-file-noselect file-path))
         (hdr (jot--format-header note-name session-name file-path)))
    (with-current-buffer buf
      (unless (eq major-mode jot-default-mode)
        (funcall jot-default-mode))
      (setq-local header-line-format hdr)
      (setq-local tab-line-format nil)
      (when (fboundp 'tab-line-mode)
        (tab-line-mode -1))
      (jot-buffer-mode 1))
    buf))

(provide 'jot-buffer)
;;; jot-buffer.el ends here
