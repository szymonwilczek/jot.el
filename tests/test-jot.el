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

(ert-deftest jot-test-note-path ()
  "Test note path construction with various extensions."
  (let ((jot-dir "/tmp/test-jot")
        (jot-extension "org"))
    (should (string= (jot--note-path "todo") "/tmp/test-jot/todo.org"))
    (should (string= (jot--note-path "todo.org") "/tmp/test-jot/todo.org"))
    (should (string= (jot--note-path "todo.md") "/tmp/test-jot/todo.md"))))

(ert-deftest jot-test-session-replacement ()
  "Test replacing a session note with another note (overwriting symlink cleanly)."
  (let* ((temp-dir (make-temp-file "jot-replace-test-" t))
         (jot-dir temp-dir)
         (jot-session-dir nil)
         (jot-extension "org")
         (note1 (expand-file-name "first-note.org" temp-dir))
         (note2 (expand-file-name "second-note.md" temp-dir))
         (note3 (expand-file-name "third-note.org" temp-dir))
         (session "my-perspective"))
    (unwind-protect
        (progn
          (write-region "Note 1" nil note1 nil 'silent)
          (write-region "Note 2" nil note2 nil 'silent)
          (write-region "Note 3" nil note3 nil 'silent)

          ;; link note1 to session
          (jot-link-note-to-session note1 session)
          (should (string= (jot-session-linked-file session) note1))

          ;; replace with note2 (.md)
          (jot-link-note-to-session note2 session)
          (should (string= (jot-session-linked-file session) note2))
          (should (= (length (jot--find-session-links session)) 1))

          ;; replace with note3 (.org)
          (jot-link-note-to-session note3 session)
          (should (string= (jot-session-linked-file session) note3))
          (should (= (length (jot--find-session-links session)) 1))

          ;; unlink removes all links for session
          (jot-unlink-session session)
          (should-not (jot-session-linked-file session))
          (should (= (length (jot--find-session-links session)) 0)))
      (delete-directory temp-dir t))))

(ert-deftest jot-test-cross-extension-discovery ()
  "Test discovering session link created with different extension (tmux-jot)."
  (let* ((temp-dir (make-temp-file "jot-cross-test-" t))
         (jot-dir temp-dir)
         (jot-session-dir nil)
         (jot-extension "org")
         (note-md (expand-file-name "from-tmux.md" temp-dir))
         (session "tmux-session"))
    (unwind-protect
        (progn
          (write-region "tmux content" nil note-md nil 'silent)
          ;; simulate tmux-jot creating a .md session link
          (jot--ensure-storage)
          (make-symbolic-link note-md (expand-file-name "tmux-session.md" (jot--session-dir)) t)
          ;; verify jot.el finds the .md session link even though jot-extension is .org
          (should (string= (jot-session-linked-file session) note-md))

          ;; replace it with a new note in Emacs
          (let ((note-org (expand-file-name "from-emacs.org" temp-dir)))
            (write-region "emacs content" nil note-org nil 'silent)
            (jot-link-note-to-session note-org session)
            (should (string= (jot-session-linked-file session) note-org))
            ;; verify old .md link was removed
            (should-not (file-exists-p (expand-file-name "tmux-session.md" (jot--session-dir))))))
      (delete-directory temp-dir t))))

(ert-deftest jot-test-root-parent-frame ()
  "Test root parent frame resolution."
  (let ((current (selected-frame)))
    (should (eq (jot--root-parent-frame current) current))))

(provide 'test-jot)
;;; test-jot.el ends here
