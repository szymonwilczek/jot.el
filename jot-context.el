;;; jot-context.el --- Workspace and session context resolvers for jot.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Szymon Wilczek

;; Author: Szymon Wilczek <swilczek.lx@gmail.com>
;; Keywords: convenience, tools

;;; Commentary:
;; Workspace, perspective, tab-bar, and project context detection.

;;; Code:

(require 'subr-x)
(require 'jot-config)

(declare-function project-current "project" (&optional maybe-prompt directory))
(declare-function project-root "project" (project))
(declare-function get-current-persp "persp-mode" ())
(declare-function safe-persp-name "persp-mode" (persp))
(declare-function persp-current-name "persp-mode" ())
(declare-function persp-curr "perspective" ())
(declare-function persp-name "perspective" (persp))
(declare-function tab-bar--current-tab "tab-bar" (&optional tab frame))

(defcustom jot-session-backend 'auto
  "Backend used to determine the active workspace / session name.
Can be:
  `auto'       - Tries `persp-mode', `tab-bar', `project', or default
  `persp'      - Uses `persp-mode' or `perspective.el'
  `tab-bar'    - Uses current tab name in `tab-bar-mode'
  `project'    - Uses `project.el' / `projectile' root directory name
  `frame'      - Uses the current frame title or name
  function     - A custom nullary function returning a string"
  :type '(choice (const :tag "Automatic detection" auto)
                 (const :tag "Perspective (persp-mode)" persp)
                 (const :tag "Tab bar (tab-bar-mode)" tab-bar)
                 (const :tag "Project (project.el / projectile)" project)
                 (const :tag "Frame name" frame)
                 (function :tag "Custom function"))
  :group 'jot)

(defun jot--safe-name (name)
  "Convert NAME into a safe filename component without slashes or newlines."
  (let* ((str (string-trim (or name "")))
         (clean (replace-regexp-in-string "[\n\r\t]" " " str))
         (no-slash (replace-regexp-in-string "[/\\\\]" "-" clean))
         (safe (replace-regexp-in-string "[^[:alnum:]_.-]" "_" no-slash)))
    (if (string-empty-p safe) "default" safe)))

(defun jot-current-session-name ()
  "Return the active workspace / session name based on `jot-session-backend'."
  (let ((session
         (pcase jot-session-backend
           ('persp
            (cond
             ((bound-and-true-p persp-mode)
              (if (fboundp 'safe-persp-name)
                  (safe-persp-name (get-current-persp))
                (when (fboundp 'persp-current-name)
                  (persp-current-name))))
             ((and (fboundp 'persp-curr) (fboundp 'persp-name))
              (persp-name (persp-curr)))
             (t nil)))
           ('tab-bar
            (when (bound-and-true-p tab-bar-mode)
              (alist-get 'name (tab-bar--current-tab))))
           ('project
            (when-let* ((proj (and (fboundp 'project-current) (project-current))))
              (file-name-nondirectory (directory-file-name (project-root proj)))))
           ('frame
            (frame-parameter nil 'name))
           ((pred functionp)
            (funcall jot-session-backend))
           ('auto
            (or
             ;; Perspective / Persp-mode
             (when (bound-and-true-p persp-mode)
               (if (fboundp 'safe-persp-name)
                   (safe-persp-name (get-current-persp))
                 (when (fboundp 'persp-current-name)
                   (persp-current-name))))
             (when (and (fboundp 'persp-curr) (fboundp 'persp-name))
               (persp-name (persp-curr)))
             ;; Tab-bar
             (when (bound-and-true-p tab-bar-mode)
               (alist-get 'name (tab-bar--current-tab)))
             ;; Project
             (when-let* ((proj (and (fboundp 'project-current) (project-current))))
               (file-name-nondirectory (directory-file-name (project-root proj))))
             ;; Fallback
             "default"))
           (_ "default"))))
    (jot--safe-name (or session "default"))))

(provide 'jot-context)
;;; jot-context.el ends here
