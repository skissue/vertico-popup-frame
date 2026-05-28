;;; vertico-popup-frame.el --- Show Vertico in a popup frame -*- lexical-binding: t -*-

;; Author: Ad <me@skissue.xyz>
;; Maintainer: Ad <me@skissue.xyz>
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1") (vertico "2.6"))
;; Homepage: https://github.com/skissue/gxy/tree/main/elisp
;; Keywords: frames


;; This file is not part of GNU Emacs

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.


;;; Commentary:

;; Show Vertico in a popup frame by hijacking `vertico-buffer-mode'.

;;; Code:

(require 'cl-lib)
(require 'vertico-buffer)

(defcustom vertico-popup-frame-parameters
  `((minibuffer . nil)
    ;; Add one line for the prompt.
    (height . ,(1+ vertico-count)))
  "Frame parameters used for pop-up frames.
The default value removes the minibuffer and sets the height of the
window based on `vertico-count'."
  :group 'vertico
  :type '(repeat (cons :format "%v"
                       (symbol :tag "Parameter")
                       (sexp :tag "Value"))))

(defvar-local vertico-popup-frame--frame nil
  "Frame currently showing Vertico for this minibuffer.")

(defvar-local vertico-popup-frame--restore nil
  "Cleanup function for this minibuffer's Vertico popup frame.")

(defconst vertico-popup-frame--display-action
  '(vertico-popup-frame--display-buffer-action)
  "Display action used while `vertico-popup-frame-mode' is enabled.")

(defvar vertico-popup-frame--saved-display-action nil
  "Previous value of `vertico-buffer-display-action'.")

(defvar vertico-popup-frame--saved-vertico-buffer-mode nil
  "Previous value of `vertico-buffer-mode'.")

(defvar vertico-popup-frame--active nil
  "Non-nil if `vertico-popup-frame-mode' has saved global state.")

(defun vertico-popup-frame--frame-name ()
  "Return the popup frame name for the current minibuffer."
  (format "*vertico-popup-%d*" (max 0 (1- (minibuffer-depth)))))

(defun vertico-popup-frame--restore-frame (restore)
  "Delete popup frame for the minibuffer owned by RESTORE."
  (when-let* ((window (active-minibuffer-window))
              (buffer (window-buffer window)))
    (with-current-buffer buffer
      (when (eq vertico-popup-frame--restore restore)
        (remove-hook 'minibuffer-exit-hook restore)
        (fset restore nil)
        (let ((frame vertico-popup-frame--frame))
          (setq-local vertico-popup-frame--frame nil
                      vertico-popup-frame--restore nil)
          (when (and (framep frame) (frame-live-p frame))
            (ignore-errors
              (delete-frame frame))))))))

(defun vertico-popup-frame--make-restore ()
  "Return a cleanup function for the current minibuffer."
  (let ((restore (make-symbol "vertico-popup-frame--restore")))
    (fset restore (lambda ()
                    (vertico-popup-frame--restore-frame restore)))
    restore))

(defun vertico-popup-frame--setup-minibuffer (frame)
  "Store FRAME and cleanup state in the active minibuffer buffer."
  (when-let* ((window (active-minibuffer-window))
              (buffer (window-buffer window)))
    (with-current-buffer buffer
      (setq-local mode-line-format nil
                  vertico-popup-frame--frame frame)
      (unless vertico-popup-frame--restore
        (setq-local vertico-popup-frame--restore
                    (vertico-popup-frame--make-restore))
        (add-hook 'minibuffer-exit-hook vertico-popup-frame--restore)))))

(defun vertico-popup-frame--display-buffer-action (buffer alist)
  "Custom display buffer action for `vertico-buffer-display-action'.
See `display-buffer' for information on BUFFER and ALIST."
  (let ((window
         (display-buffer-pop-up-frame
          buffer `((pop-up-frame-parameters
                    (name . ,(vertico-popup-frame--frame-name))
                    ,@vertico-popup-frame-parameters)
                   ,@alist))))
    (when (window-live-p window)
      (vertico-popup-frame--setup-minibuffer (window-frame window)))
    window))

(defun vertico-popup-frame--enable ()
  "Enable and set up `vertico-popup-frame-mode'."
  (unless vertico-popup-frame--active
    (setq vertico-popup-frame--saved-display-action
          vertico-buffer-display-action
          vertico-popup-frame--saved-vertico-buffer-mode
          vertico-buffer-mode
          vertico-popup-frame--active t))
  (setq vertico-buffer-display-action
        vertico-popup-frame--display-action)
  (vertico-buffer-mode 1))

(defun vertico-popup-frame--disable ()
  "Disable and clean up `vertico-popup-frame-mode'."
  (when vertico-popup-frame--active
    (when (equal vertico-buffer-display-action
                 vertico-popup-frame--display-action)
      (setq vertico-buffer-display-action
            vertico-popup-frame--saved-display-action))
    (unless vertico-popup-frame--saved-vertico-buffer-mode
      (vertico-buffer-mode -1))
    (setq vertico-popup-frame--saved-display-action nil
          vertico-popup-frame--saved-vertico-buffer-mode nil
          vertico-popup-frame--active nil)))

;;;###autoload
(define-minor-mode vertico-popup-frame-mode
  "Display Vertico in a pop-up frame."
  :global t :group 'vertico
  ;; Synchronize mode state with `vertico-buffer-mode'.
  (if vertico-popup-frame-mode
      (vertico-popup-frame--enable)
    (vertico-popup-frame--disable)))

(provide 'vertico-popup-frame)

;;; vertico-popup-frame.el ends here
