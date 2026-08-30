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
  (let* ((base (jot--safe-name note-name))
         (ext (jot--normalize-extension jot-extension)))
    (expand-file-name (format "%s.%s" base ext) (expand-file-name jot-dir))))

(defun jot--session-link-path (session-name)
  "Return the symlink file path for SESSION-NAME."
  (jot--ensure-storage)
  (let* ((safe (jot--safe-name session-name))
         (ext (jot--normalize-extension jot-extension)))
    (expand-file-name (format "%s.%s" safe ext) (jot--session-dir))))

(defun jot-session-linked-file (&optional session-name)
  "Return the target note file path linked to SESSION-NAME (or current session)."
  (let* ((session (or session-name (jot-current-session-name)))
         (link (jot--session-link-path session)))
    (when (file-symlink-p link)
      (let ((target (file-truename link)))
        (when (file-exists-p target)
          target)))))

(defun jot-link-note-to-session (file-path &optional session-name)
  "Link note FILE-PATH to SESSION-NAME (or current session)."
  (jot--ensure-storage)
  (let* ((session (or session-name (jot-current-session-name)))
         (link (jot--session-link-path session)))
    (when (file-exists-p link)
      (delete-file link))
    (make-symbolic-link (expand-file-name file-path) link t)))

(defun jot-unlink-session (&optional session-name)
  "Remove the note link for SESSION-NAME (or current session)."
  (interactive)
  (let* ((session (or session-name (jot-current-session-name)))
         (link (jot--session-link-path session)))
    (when (file-exists-p link)
      (delete-file link)
      (message "Unlinked note for session '%s'" session))))

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
