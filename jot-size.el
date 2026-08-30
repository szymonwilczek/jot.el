;;; jot-size.el --- Interactive popup resizing for jot.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Szymon Wilczek

;; Author: Szymon Wilczek <swilczek.lx@gmail.com>
;; Keywords: convenience, tools, frames

;;; Commentary:
;; Dynamic resizing commands and geometry parameter adjustments.

;;; Code:

(require 'jot-config)
(require 'jot-frame)

(defun jot--refresh-frame-geometry ()
  "Recalculate and apply geometry parameters to the live child frame."
  (when (frame-live-p jot--frame)
    (let* ((parent (frame-parent jot--frame))
           (params (jot--frame-parameters parent)))
      (modify-frame-parameters jot--frame params))))

(defun jot-increase-size ()
  "Increase floating jot popup width and height."
  (interactive)
  (setq jot--size-delta (+ jot--size-delta jot-resize-step))
  (jot--refresh-frame-geometry)
  (message "Jot size delta: %+.0f%%" (* 100 jot--size-delta)))

(defun jot-decrease-size ()
  "Decrease floating jot popup width and height."
  (interactive)
  (setq jot--size-delta (max -0.30 (- jot--size-delta jot-resize-step)))
  (jot--refresh-frame-geometry)
  (message "Jot size delta: %+.0f%%" (* 100 jot--size-delta)))

(defun jot-reset-size ()
  "Reset floating jot popup size delta to 0."
  (interactive)
  (setq jot--size-delta 0.0)
  (jot--refresh-frame-geometry)
  (message "Jot size delta reset to default (0%%)"))

(provide 'jot-size)
;;; jot-size.el ends here
