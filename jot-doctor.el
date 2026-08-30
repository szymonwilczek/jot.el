;;; jot-doctor.el --- Diagnostic inspection report for jot.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Szymon Wilczek

;; Author: Szymon Wilczek <swilczek.lx@gmail.com>
;; Keywords: convenience, tools

;;; Commentary:
;; Diagnostic inspection report matching tmux-jot doctor.

;;; Code:

(require 'jot-config)
(require 'jot-context)
(require 'jot-storage)
(require 'jot-frame)

(defun jot-doctor ()
  "Display an interactive diagnostic report for `jot.el' configuration and state."
  (interactive)
  (let* ((session (jot-current-session-name))
         (link (jot--session-link-path session))
         (linked-file (jot-session-linked-file session))
         (all-notes (jot--all-notes))
         (buf (get-buffer-create "*jot-doctor*")))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert "jot.el Doctor Report\n")
        (insert "====================\n\n")
        (insert "Context\n")
        (insert (format "  %-22s %s\n" "Emacs version" emacs-version))
        (insert (format "  %-22s %s\n" "jot.el version" jot-version))
        (insert (format "  %-22s %s\n" "session backend" jot-session-backend))
        (insert (format "  %-22s %s\n" "current session" session))
        (insert (format "  %-22s %s\n" "active note" (or jot--active-note "none")))
        (insert (format "  %-22s %s\n\n" "frame live" (if (jot--frame-alive-p) "yes" "no")))

        (insert "Paths\n")
        (insert (format "  %-22s %s (exists=%s)\n" "jot-dir" jot-dir (if (file-directory-p jot-dir) "yes" "no")))
        (insert (format "  %-22s %s (exists=%s)\n" "session-dir" (jot--session-dir) (if (file-directory-p (jot--session-dir)) "yes" "no")))
        (insert (format "  %-22s %s\n" "session link" link))
        (insert (format "  %-22s %s\n\n" "linked note" (or linked-file "none")))

        (insert "Geometry and Appearance\n")
        (insert (format "  %-22s %s\n" "popup width" jot-popup-width))
        (insert (format "  %-22s %s\n" "popup height" jot-popup-height))
        (insert (format "  %-22s %s\n" "popup pos X" jot-popup-x))
        (insert (format "  %-22s %s\n" "popup pos Y" jot-popup-y))
        (insert (format "  %-22s %s\n" "border color" jot-border-color))
        (insert (format "  %-22s %s\n" "size delta" jot--size-delta))
        (insert (format "  %-22s %s\n\n" "icons enabled" (if jot-icons "yes" "no")))

        (insert "Discovered Notes\n")
        (if all-notes
            (dolist (item all-notes)
              (insert (format "  - %-20s %s\n" (car item) (cdr item))))
          (insert "  none\n"))
        (special-mode)))
    (display-buffer buf)))

(provide 'jot-doctor)
;;; jot-doctor.el ends here
