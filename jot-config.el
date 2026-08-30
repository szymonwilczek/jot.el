;;; jot-config.el --- Customization options and faces for jot.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Szymon Wilczek

;; Author: Szymon Wilczek <swilczek.lx@gmail.com>
;; Keywords: convenience, tools

;;; Commentary:
;; Customization group, variables, and faces for jot.el.

;;; Code:

(defgroup jot nil
  "Perspective-aware floating sticky notes for GNU Emacs."
  :group 'convenience
  :prefix "jot-"
  :link '(url-link "https://github.com/szymonwilczek/jot.el"))

(defconst jot-version "0.1.0"
  "Current version of jot.el.")

(defcustom jot-dir (expand-file-name "~/.local/share/tmux-jot")
  "Directory where jot note files are stored.
Can be shared directly with tmux-jot."
  :type 'directory
  :group 'jot)

(defcustom jot-session-dir nil
  "Directory where per-session symlinks are stored.
When nil, defaults to `.sessions' subdirectory under `jot-dir'."
  :type '(choice (const :tag "Default (.sessions under jot-dir)" nil)
                 (directory :tag "Custom directory"))
  :group 'jot)

(defcustom jot-extension "org"
  "Default file extension for notes (e.g. \"org\", \"md\", \"txt\")."
  :type 'string
  :group 'jot)

(defcustom jot-default-mode 'org-mode
  "Default major mode used when opening note buffers."
  :type 'function
  :group 'jot)

(defcustom jot-sort-notes nil
  "Whether to sort notes alphabetically in pickers.
When nil, notes are sorted by modification time (most recent first)."
  :type 'boolean
  :group 'jot)

(defcustom jot-popup-width 0.40
  "Width of the floating jot frame.
A float represents a fraction of parent width; integer means pixels."
  :type '(choice (float :tag "Fraction of parent width")
                 (integer :tag "Absolute pixels"))
  :group 'jot)

(defcustom jot-popup-height 0.50
  "Height of the floating jot frame.
A float represents a fraction of parent height; integer means pixels."
  :type '(choice (float :tag "Fraction of parent height")
                 (integer :tag "Absolute pixels"))
  :group 'jot)

(defcustom jot-popup-x 'right
  "Horizontal anchor or offset for the floating jot frame.
Can be `right' (or \"R\"), `left' (or \"L\"), `center' (or \"C\"),
a float fraction, or an integer pixel offset."
  :type '(choice (const :tag "Right aligned" right)
                 (const :tag "Left aligned" left)
                 (const :tag "Centered" center)
                 (float :tag "Fraction from left")
                 (integer :tag "Pixel offset from left"))
  :group 'jot)

(defcustom jot-popup-y 0
  "Vertical anchor or offset for the floating jot frame.
Can be `top', `bottom', `center', float fraction, or pixel offset."
  :type '(choice (integer :tag "Pixel offset from top")
                 (float :tag "Fraction from top")
                 (const :tag "Top aligned" top)
                 (const :tag "Bottom aligned" bottom)
                 (const :tag "Centered" center))
  :group 'jot)

(defcustom jot-border-width 2
  "Border width in pixels for the floating child frame."
  :type 'integer
  :group 'jot)

(defcustom jot-internal-border-width 1
  "Internal border width in pixels around the note buffer."
  :type 'integer
  :group 'jot)

(defcustom jot-border-color nil
  "Color string for the floating child frame border.
When nil (default), dynamically inherits the active theme border/keyword color."
  :type '(choice (const :tag "Active theme color (auto)" nil)
                 (string :tag "Custom hex color"))
  :group 'jot)

(defcustom jot-resize-step 0.05
  "Fractional step added or subtracted when resizing the popup."
  :type 'float
  :group 'jot)

(defcustom jot-icons t
  "Whether to display icons in headers and prompts."
  :type 'boolean
  :group 'jot)

(defcustom jot-title-icon "📌"
  "Icon string used in floating frame headers."
  :type 'string
  :group 'jot)

(defcustom jot-picker-icon "📝"
  "Icon string used in note selector prompts."
  :type 'string
  :group 'jot)

(defcustom jot-search-icon "🔎"
  "Icon string used in content search prompts."
  :type 'string
  :group 'jot)

(defcustom jot-title-template " {icon} {note} [{session}] "
  "Template string for the header-line title."
  :type 'string
  :group 'jot)

(defcustom jot-picker-prompt "{icon} Select / Create note: "
  "Prompt template for `completing-read' note switcher."
  :type 'string
  :group 'jot)

(defcustom jot-search-prompt "{icon} Search jot content: "
  "Prompt template for content search."
  :type 'string
  :group 'jot)

(defface jot-header-face
  '((t :inherit header-line :weight bold))
  "Face used for the floating jot header line."
  :group 'jot)

(defface jot-border-face
  '((t :inherit (child-frame-border font-lock-keyword-face highlight)))
  "Face used for the child frame border."
  :group 'jot)

(provide 'jot-config)
;;; jot-config.el ends here
