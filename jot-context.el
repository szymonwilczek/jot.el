;;; jot-context.el --- Workspace and session context resolvers for jot.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Szymon Wilczek

;; Author: Szymon Wilczek <swilczek.lx@gmail.com>
;; Keywords: convenience, tools

;;; Commentary:
;; Workspace, perspective, tab-bar, and project context detection.

;;; Code:

(require 'cl-lib)
(require 'subr-x)
(require 'jot-config)
(require 'jot-frame)

(declare-function project-current "project" (&optional maybe-prompt directory))
(declare-function project-root "project" (project))
(declare-function projectile-project-name "projectile" (&optional dir))
(declare-function projectile-project-p "projectile" (&optional dir))
(declare-function get-current-persp "persp-mode" ())
(declare-function safe-persp-name "persp-mode" (persp))
(declare-function persp-current-name "persp-mode" ())
(declare-function persp-curr "perspective" ())
(declare-function persp-name "perspective" (persp))
(declare-function +workspace-current-name "+workspaces" ())
(declare-function spacemacs/workspace-name "core-spacemacs" ())
(declare-function tab-bar--current-tab "tab-bar" (&optional tab frame))

(defvar jot-buffer-mode)

(defcustom jot-session-backend 'auto
  "Backend used to determine the active workspace / session name.
Can be:
  `auto'       - Tries `persp-mode', `perspective.el', `tab-bar',
                 `project', or default
  `persp'      - Uses `persp-mode', `perspective.el', or Doom/Spacemacs
  `tab-bar'    - Uses current tab name in `tab-bar-mode'
  `project'    - Uses `project.el' / `projectile' root directory name
  `frame'      - Uses the current frame title or name
  function     - A custom nullary function returning a string"
  :type '(choice (const :tag "Automatic detection" auto)
                 (const :tag "Perspective (persp-mode / perspective)" persp)
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

(defun jot--get-perspective-name ()
  "Detect perspective or workspace name from active perspective packages."
  (or
   ;; Doom Emacs workspace
   (when (and (fboundp '+workspace-current-name)
              (bound-and-true-p +workspace-mode))
     (let ((name (+workspace-current-name)))
       (when (and (stringp name) (not (string-empty-p name)))
         name)))
   ;; persp-mode
   (when (and (bound-and-true-p persp-mode)
              (fboundp 'safe-persp-name)
              (fboundp 'get-current-persp))
     (let ((name (safe-persp-name (get-current-persp))))
       (when (and (stringp name)
                  (not (string-empty-p name))
                  (not (string= name "none")))
         name)))
   ;; perspective.el
   (when (and (fboundp 'persp-curr) (fboundp 'persp-name))
     (let ((p (persp-curr)))
       (when p
         (let ((name (persp-name p)))
           (when (and (stringp name) (not (string-empty-p name)))
             name)))))
   ;; persp-current-name
   (when (fboundp 'persp-current-name)
     (let ((name (persp-current-name)))
       (when (and (stringp name)
                  (not (string-empty-p name))
                  (not (string= name "none")))
         name)))
   ;; Spacemacs workspace
   (when (fboundp 'spacemacs/workspace-name)
     (let ((name (spacemacs/workspace-name)))
       (when (and (stringp name) (not (string-empty-p name)))
         name)))
   nil))

(defun jot--get-project-name ()
  "Detect project name using `project.el' or `projectile'."
  (or
   ;; project.el
   (when-let* ((proj (and (fboundp 'project-current) (project-current))))
     (file-name-nondirectory (directory-file-name (project-root proj))))
   ;; projectile
   (when (and (fboundp 'projectile-project-name)
              (or (not (fboundp 'projectile-project-p))
                  (projectile-project-p)))
     (let ((name (projectile-project-name)))
       (when (and (stringp name)
                  (not (string-empty-p name))
                  (not (string= name "-")))
         name)))
   nil))

(defun jot--target-context (&optional frame)
  "Return a cons (ROOT-PARENT-FRAME . BUFFER) for context resolution."
  (let* ((f (or frame (selected-frame)))
         (root (jot--root-parent-frame f))
         (buf (if (and (frame-live-p root) (frame-selected-window root))
                  (window-buffer (frame-selected-window root))
                (current-buffer))))
    (when (and buf (buffer-local-value 'jot-buffer-mode buf))
      (let ((other (cl-find-if
                    (lambda (b)
                      (and (buffer-live-p b)
                           (not (buffer-local-value 'jot-buffer-mode b))
                           (not (string-prefix-p " " (buffer-name b)))))
                    (buffer-list))))
        (when other
          (setq buf other))))
    (cons root (or buf (current-buffer)))))

(defun jot-current-session-name (&optional frame)
  "Return the active workspace / session name based on `jot-session-backend'.
FRAME specifies the frame context (defaults to `selected-frame').
If called from inside the jot child frame or a jot buffer, automatically
resolves the context against the root parent frame and its active buffer."
  (let* ((ctx (jot--target-context frame))
         (root (car ctx))
         (buf (cdr ctx))
         (session
          (with-selected-frame root
            (with-current-buffer buf
              (pcase jot-session-backend
                ('persp
                 (jot--get-perspective-name))
                ('tab-bar
                 (when (bound-and-true-p tab-bar-mode)
                   (alist-get 'name (tab-bar--current-tab nil root))))
                ('project
                 (jot--get-project-name))
                ('frame
                 (frame-parameter root 'name))
                ((pred functionp)
                 (funcall jot-session-backend))
                ('auto
                 (or
                  ;; Perspective / Persp-mode / Workspaces
                  (jot--get-perspective-name)
                  ;; Tab-bar
                  (when (bound-and-true-p tab-bar-mode)
                    (alist-get 'name (tab-bar--current-tab nil root)))
                  ;; Project
                  (jot--get-project-name)
                  ;; Fallback
                  "default"))
                (_ "default"))))))
    (jot--safe-name (or session "default"))))

(provide 'jot-context)
;;; jot-context.el ends here
