;;; test-jot.el --- Unit tests for jot.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Szymon Wilczek

;;; Commentary:
;; ERT test suite for jot.el.

;;; Code:

(require 'ert)
(require 'jot)

(ert-deftest jot-test-safe-name ()
  "Test name sanitization for sessions and note filenames."
  (should (string= (jot--safe-name "my-session") "my-session"))
  (should (string= (jot--safe-name "my/session/nested") "my-session-nested"))
  (should (string= (jot--safe-name "session with spaces") "session_with_spaces"))
  (should (string= (jot--safe-name "evil\nnewline") "evil_newline"))
  (should (string= (jot--safe-name "") "default"))
  (should (string= (jot--safe-name nil) "default")))

(ert-deftest jot-test-valid-note-name ()
  "Test note name validation predicate."
  (should (jot--valid-note-name-p "valid-note"))
  (should (jot--valid-note-name-p "note_123"))
  (should-not (jot--valid-note-name-p ""))
  (should-not (jot--valid-note-name-p "   "))
  (should-not (jot--valid-note-name-p "invalid/name"))
  (should-not (jot--valid-note-name-p "invalid\nname"))
  (should-not (jot--valid-note-name-p nil)))

(ert-deftest jot-test-normalize-extension ()
  "Test extension normalization."
  (should (string= (jot--normalize-extension "org") "org"))
  (should (string= (jot--normalize-extension ".org") "org"))
  (should (string= (jot--normalize-extension "md") "md"))
  (should (string= (jot--normalize-extension ".md") "md")))

(ert-deftest jot-test-dimension-resolution ()
  "Test fractional and absolute dimension calculations."
  (should (= (jot--resolve-dimension 0.40 1000) 400))
  ;; absolute 550 pixels
  (should (= (jot--resolve-dimension 550 1000) 550))
  ;; clamping upper bound
  (should (= (jot--resolve-dimension 1200 1000) 1000))
  ;; clamping lower bound
  (should (= (jot--resolve-dimension 10 1000) 50)))

(ert-deftest jot-test-header-formatting ()
  "Test header string template replacement."
  (let ((jot-icons t)
        (jot-title-icon "📌")
        (jot-title-template " {icon} {note} [{session}] "))
    (let ((hdr (jot--format-header "todo" "dotfiles" "/path/to/todo.org")))
      (should (string-match-p "📌 todo \\[dotfiles\\]" hdr)))))

(ert-deftest jot-test-session-linking ()
  "Test session symlink creation, reading, and unlinking in temp directory."
  (let* ((temp-dir (make-temp-file "jot-test-" t))
         (jot-dir temp-dir)
         (jot-session-dir nil)
         (note-file (expand-file-name "test-note.org" temp-dir))
         (session "test-session"))
    (unwind-protect
        (progn
          ;; create note file
          (write-region "Test Note Content" nil note-file nil 'silent)
          ;; link note to session
          (jot-link-note-to-session note-file session)
          ;; verify link resolves to target
          (should (string= (jot-session-linked-file session) note-file))
          ;; unlink session
          (jot-unlink-session session)
          (should-not (jot-session-linked-file session)))
      (delete-directory temp-dir t))))

(ert-deftest jot-test-cleanup-broken-symlinks ()
  "Test cleanup of dangling broken symlinks."
  (let* ((temp-dir (make-temp-file "jot-cleanup-test-" t))
         (jot-dir temp-dir)
         (jot-session-dir nil)
         (broken-target (expand-file-name "deleted-note.org" temp-dir))
         (session "ghost-session"))
    (unwind-protect
        (progn
          ;; create broken symlink
          (jot-link-note-to-session broken-target session)
          (should (file-symlink-p (jot--session-link-path session)))
          ;; run cleanup
          (jot-cleanup)
          ;; verify broken symlink was removed
          (should-not (file-exists-p (jot--session-link-path session))))
      (delete-directory temp-dir t))))

(provide 'test-jot)
;;; test-jot.el ends here
