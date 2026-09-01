;;; jot.el --- Perspective-aware floating sticky notes for Emacs -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Szymon Wilczek

;; Author: Szymon Wilczek <swilczek.lx@gmail.com>
;; Maintainer: Szymon Wilczek <swilczek.lx@gmail.com>
;; URL: https://github.com/szymonwilczek/jot.el
;; Version: 0.1.0
;; Package-Requires: ((emacs "31.1"))
;; Keywords: convenience, tools, matching, frames

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;;; Commentary:

;; jot.el is small, fast, perspective-aware floating sticky note manager
;; for GNU Emacs.
;; Directly inspired by tmux-jot, it keeps notes on disk, links one active
;; note to each perspective/workspace, and presents notes inside
;; pixel-customizable floating child frame with zero latency.

;;; Code:

(require 'jot-config)
(require 'jot-context)
(require 'jot-storage)
(require 'jot-frame)
(require 'jot-buffer)
(require 'jot-size)
(require 'jot-picker)
(require 'jot-search)
(require 'jot-doctor)
(require 'jot-cleanup)

;;;###autoload
(defun jot-toggle ()
  "Toggle the floating jot note for the current workspace / perspective.
If the popup is already visible for the current session, hide it.
If the popup is visible for a different session or not visible, open the note
for the current session (or prompt to select/create one)."
  (interactive)
  (let* ((session (jot-current-session-name))
         (frame-alive (jot--frame-alive-p)))
    (if (and frame-alive (string= session (or jot--active-session "")))
        (jot-hide)
      (let ((linked (jot-session-linked-file session)))
        (if (and linked (file-exists-p linked))
            (jot-open-note linked (jot--note-name-from-file linked) session nil)
          (jot-find-note session))))))

(defalias 'jot #'jot-toggle)

(defvar-keymap jot-mode-map
  :doc "Global keymap for `jot-mode' with tmux-jot parity keybindings."
  "C-c j"   #'jot-toggle
  "C-c M-j" #'jot-find-note
  "C-c M-w" #'jot-search
  "C-c M-i" #'jot-doctor
  "C-c M-k" #'jot-cleanup
  "C-c M-=" #'jot-increase-size
  "C-c M-+" #'jot-increase-size
  "C-c M--" #'jot-decrease-size
  "C-c M-_" #'jot-decrease-size
  "C-c M-r" #'jot-reset-size)

;;;###autoload
(define-minor-mode jot-mode
  "Global minor mode providing fast floating sticky notes across workspaces."
  :global t
  :group 'jot
  :lighter " Jot"
  :keymap jot-mode-map)

(provide 'jot)
;;; jot.el ends here
