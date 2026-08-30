;;; jot-search.el --- Full-text content search for jot.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Szymon Wilczek

;; Author: Szymon Wilczek <swilczek.lx@gmail.com>
;; Keywords: convenience, tools

;;; Commentary:
;; Content search integration using consult-ripgrep, ripgrep, or rgrep.

;;; Code:

(require 'grep)
(require 'jot-config)
(require 'jot-storage)

(declare-function consult-ripgrep "consult" (&optional dir initial))

(defun jot-search ()
  "Search across all notes in `jot-dir' using `consult-ripgrep', `rg', or `grep'."
  (interactive)
  (jot--ensure-storage)
  (let ((dir (expand-file-name jot-dir)))
    (cond
     ((fboundp 'consult-ripgrep)
      (consult-ripgrep dir))
     ((executable-find "rg")
      (let ((default-directory dir))
        (grep-find (format "rg --color=always -n -H --no-heading -- %s ."
                           (shell-quote-argument
                            (read-string
                             (replace-regexp-in-string
                              "{icon}" (if jot-icons (or jot-search-icon "") "")
                              jot-search-prompt)))))))
     (t
      (rgrep (read-string "Search jot notes for: ")
             (format "*.%s" (jot--normalize-extension jot-extension))
             dir)))))

(defalias 'jot-content-search #'jot-search)

(provide 'jot-search)
;;; jot-search.el ends here
