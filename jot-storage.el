;;; jot-storage.el --- Storage paths and note file discovery for jot.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Szymon Wilczek

;; Author: Szymon Wilczek <swilczek.lx@gmail.com>
;; Keywords: convenience, tools

;;; Commentary:
;; Filesystem path expansion, session symlinks, and note discovery.

;;; Code:

(require 'cl-lib)
(require 'subr-x)
(require 'jot-config)
(require 'jot-context)

(defun jot--session-dir ()
  "Return the expanded session directory path."
  (if jot-session-dir
      (expand-file-name jot-session-dir)
    (expand-file-name ".sessions" (expand-file-name jot-dir))))

(defun jot--ensure-storage ()
  "Ensure `jot-dir' and session directory exist on the filesystem."
  (let ((dir (expand-file-name jot-dir))
        (sdir (jot--session-dir)))
    (unless (file-directory-p dir)
      (make-directory dir t))
    (unless (file-directory-p sdir)
      (make-directory sdir t))))

(defun jot--valid-note-name-p (name)
  "Return non-nil if NAME is a valid note name."
  (and (stringp name)
       (not (string-empty-p (string-trim name)))
       (not (string-match-p "[/\\]" name))
       (not (string-match-p "[\n\r]" name))))

(defun jot--normalize-extension (ext)
  "Strip leading dot from extension string EXT."
  (let ((clean (string-trim (or ext ""))))
    (if (string-prefix-p "." clean)
        (substring clean 1)
      clean)))

(defun jot--note-path (note-name)
  "Return the absolute file path for NOTE-NAME in `jot-dir'."
  (jot--ensure-storage)
  (let* ((trimmed (string-trim (or note-name "")))
         (has-ext (file-name-extension trimmed))
         (base (jot--safe-name (if has-ext (file-name-sans-extension trimmed) trimmed)))
         (ext (jot--normalize-extension (or has-ext jot-extension))))
    (expand-file-name (format "%s.%s" base ext) (expand-file-name jot-dir))))

(defun jot--session-link-path (session-name &optional ext)
  "Return the symlink file path for SESSION-NAME with optional EXT."
  (jot--ensure-storage)
  (let* ((safe (jot--safe-name session-name))
         (extension (jot--normalize-extension (or ext jot-extension))))
    (expand-file-name (format "%s.%s" safe extension) (jot--session-dir))))

(defun jot--find-session-links (session-name)
  "Return a list of all existing symlinks in session directory.
Matches files for SESSION-NAME."
  (jot--ensure-storage)
  (let* ((sdir (jot--session-dir))
         (safe (jot--safe-name session-name))
         (results nil))
    (when (file-directory-p sdir)
      (dolist (f (directory-files sdir t directory-files-no-dot-files-regexp))
        (when (or (string= (file-name-base f) safe)
                  (string= (file-name-nondirectory f) safe))
          (push f results))))
    (nreverse results)))

(defun jot-session-linked-file (&optional session-name)
  "Return the target note file path linked to SESSION-NAME (or current session)."
  (let* ((session (or session-name (jot-current-session-name)))
         (primary (jot--session-link-path session)))
    (if (and (file-symlink-p primary)
             (file-exists-p (file-truename primary)))
        (file-truename primary)
      (let ((links (jot--find-session-links session))
            (target nil))
        (while (and links (not target))
          (let ((l (pop links)))
            (when (file-symlink-p l)
              (let ((truename (file-truename l)))
                (when (file-exists-p truename)
                  (setq target truename))))))
        target))))

(defun jot-link-note-to-session (file-path &optional session-name)
  "Link note FILE-PATH to SESSION-NAME (or current session).
Removes previous session links for SESSION-NAME first for clean replacement."
  (jot--ensure-storage)
  (let* ((session (or session-name (jot-current-session-name)))
         (target-file (expand-file-name file-path))
         (target-ext (file-name-extension target-file))
         (link (jot--session-link-path session (or target-ext jot-extension))))

    ;; remove all existing links matching this session name to avoid duplicate links
    (dolist (old-link (jot--find-session-links session))
      (when (or (file-exists-p old-link) (file-symlink-p old-link))
        (delete-file old-link)))
    (make-symbolic-link target-file link t)))

(defun jot-unlink-session (&optional session-name)
  "Remove all note links for SESSION-NAME (or current session)."
  (interactive)
  (jot--ensure-storage)
  (let* ((session (or session-name
                      (and (bound-and-true-p jot-buffer-mode)
                           (bound-and-true-p jot--buffer-session))
                      (jot-current-session-name)))
         (links (jot--find-session-links session)))
    (if links
        (progn
          (dolist (link links)
            (when (or (file-exists-p link) (file-symlink-p link))
              (delete-file link)))
          (message "Unlinked note for session '%s'" session))
      (message "No link found for session '%s'" session))))

(defun jot--note-name-from-file (file-path)
  "Extract base note name from FILE-PATH without extension."
  (file-name-base file-path))

(defun jot--list-note-files ()
  "Return a list of all note file paths inside `jot-dir'."
  (jot--ensure-storage)
  (let ((dir (expand-file-name jot-dir)))
    (when (file-directory-p dir)
      (cl-remove-if
       (lambda (f)
         (or (file-directory-p f)
             (string-prefix-p "." (file-name-nondirectory f))))
       (directory-files dir t directory-files-no-dot-files-regexp)))))

(defun jot--all-notes ()
  "Return an alist of ((NOTE-NAME . FILE-PATH) ...) sorted by `jot-sort-notes'."
  (let* ((files (jot--list-note-files))
         (items (mapcar (lambda (f) (cons (jot--note-name-from-file f) f)) files)))
    (if jot-sort-notes
        (sort items (lambda (a b) (string< (car a) (car b))))
      (sort items
            (lambda (a b)
              (let ((ta (float-time (file-attribute-modification-time (file-attributes (cdr a))))))
                (let ((tb (float-time (file-attribute-modification-time (file-attributes (cdr b))))))
                  (> ta tb))))))))

(provide 'jot-storage)
;;; jot-storage.el ends here
