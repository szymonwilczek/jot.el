;;; jot-frame.el --- Floating child frame engine for jot.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Szymon Wilczek

;; Author: Szymon Wilczek <swilczek.lx@gmail.com>
;; Keywords: convenience, tools, frames

;;; Commentary:
;; Undecorated child frame creation, pixel geometry, and lifecycle.

;;; Code:

(require 'jot-config)

(defvar jot--frame nil
  "The active child frame instance used to display floating jot notes.")

(defvar jot--active-note nil
  "Name of the note currently displayed in the floating frame.")

(defvar jot--active-session nil
  "Session name associated with the currently open floating frame.")

(defvar-local jot--size-delta 0.0
  "Fractional size delta applied on top of base width and height.")

(defun jot--frame-alive-p ()
  "Return non-nil if the jot floating child frame is currently alive and visible."
  (and (frame-live-p jot--frame)
       (frame-visible-p jot--frame)))

(defun jot--resolve-dimension (spec total)
  "Resolve dimension SPEC (fraction or integer pixels) against TOTAL pixel space."
  (let ((px (cond
             ((and (floatp spec) (<= 0.0 spec 1.0))
              (round (* total spec)))
             ((integerp spec)
              spec)
             (t (round (* total 0.5))))))
    (max 50 (min total px))))

(defun jot--calculate-frame-geometry (parent)
  "Calculate child frame geometry plist (:left :top :width :height) for PARENT."
  (let* ((pw (frame-pixel-width parent))
         (ph (frame-pixel-height parent))
         (base-w (if (floatp jot-popup-width)
                     (min 1.0 (max 0.1 (+ jot-popup-width jot--size-delta)))
                   jot-popup-width))
         (base-h (if (floatp jot-popup-height)
                     (min 1.0 (max 0.1 (+ jot-popup-height jot--size-delta)))
                   jot-popup-height))
         (w (jot--resolve-dimension base-w pw))
         (h (jot--resolve-dimension base-h ph))
         (x (pcase jot-popup-x
              ((or 'right "R" "r")
               (max 0 (- pw w (or jot-border-width 0))))
              ((or 'left "L" "l")
               0)
              ((or 'center "C" "c")
               (max 0 (/ (- pw w) 2)))
              ((pred floatp)
               (round (* (- pw w) (max 0.0 (min 1.0 jot-popup-x)))))
              ((pred integerp)
               (max 0 (min (- pw w) jot-popup-x)))
              (_ (max 0 (- pw w (or jot-border-width 0))))))
         (y (pcase jot-popup-y
              ((or 'top 0)
               0)
              ((or 'bottom "B" "b")
               (max 0 (- ph h (or jot-border-width 0))))
              ((or 'center "C" "c")
               (max 0 (/ (- ph h) 2)))
              ((pred floatp)
               (round (* (- ph h) (max 0.0 (min 1.0 jot-popup-y)))))
              ((pred integerp)
               (max 0 (min (- ph h) jot-popup-y)))
              (_ 0))))
    (list :left x :top y :width w :height h)))

(defun jot--frame-parameters (parent)
  "Generate frame parameter alist for child frame anchored to PARENT."
  (let* ((geom (jot--calculate-frame-geometry parent))
         (bg (face-background 'default nil t))
         (fg (face-foreground 'default nil t))
         (bcolor (or jot-border-color
                     (face-background 'jot-border-face nil t)
                     (face-foreground 'font-lock-keyword-face nil t)
                     "#b38d59")))
    `((parent-frame . ,parent)
      (undecorated . t)
      (minibuffer . nil)
      (left . ,(plist-get geom :left))
      (top . ,(plist-get geom :top))
      (width . (text-pixels . ,(plist-get geom :width)))
      (height . (text-pixels . ,(plist-get geom :height)))
      (internal-border-width . ,jot-internal-border-width)
      (border-width . ,jot-border-width)
      (border-color . ,bcolor)
      (background-color . ,bg)
      (foreground-color . ,fg)
      (cursor-type . box)
      (auto-raise . t)
      (no-accept-focus . nil)
      (override-redirect . t)
      (skip-taskbar . t)
      (no-special-glyphs . t)
      (keep-ratio . nil))))

(defun jot--create-or-update-frame (buffer parent)
  "Create or update floating child frame on PARENT displaying BUFFER."
  (let ((params (jot--frame-parameters parent)))
    (if (frame-live-p jot--frame)
        (progn
          (modify-frame-parameters jot--frame params)
          (set-window-buffer (frame-root-window jot--frame) buffer)
          (make-frame-visible jot--frame))
      (setq jot--frame (make-frame params))
      (set-window-buffer (frame-root-window jot--frame) buffer))
    (select-frame-set-input-focus jot--frame)
    jot--frame))

(defun jot-hide ()
  "Hide the active floating jot frame and return focus to main window."
  (interactive)
  (when (frame-live-p jot--frame)
    (let ((parent (frame-parent jot--frame)))
      (delete-frame jot--frame)
      (setq jot--frame nil)
      (when (frame-live-p parent)
        (select-frame-set-input-focus parent)))))

(provide 'jot-frame)
;;; jot-frame.el ends here
