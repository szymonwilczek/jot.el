;;; jot-cleanup.el --- Stale resource cleanup for jot.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Szymon Wilczek

;; Author: Szymon Wilczek <swilczek.lx@gmail.com>
;; Keywords: convenience, tools

;;; Commentary:
;; Cleanup of dangling session symlinks and inactive note buffers.

;;; Code:

(require 'jot-storage)

(defvar jot-buffer-mode)

(defun jot-cleanup ()
  "Clean up broken session symlinks and inactive jot note buffers."
  (interactive)
  (let ((sdir (jot--session-dir))
        (broken 0)
        (killed-bufs 0))
    ;; Broken symlinks
    (when (file-directory-p sdir)
      (dolist (f (directory-files sdir t directory-files-no-dot-files-regexp))
        (when (and (file-symlink-p f) (not (file-exists-p (file-truename f))))
          (delete-file f)
          (setq broken (1+ broken)))))
    ;; Inactive jot buffers
    (dolist (buf (buffer-list))
      (when (and (buffer-local-value 'jot-buffer-mode buf)
                 (not (get-buffer-window buf t))
                 (not (buffer-modified-p buf)))
        (kill-buffer buf)
        (setq killed-bufs (1+ killed-bufs))))
    (message "Jot cleanup complete: removed %d broken symlink(s), killed %d inactive buffer(s)"
             broken killed-bufs)))

(provide 'jot-cleanup)
;;; jot-cleanup.el ends here
