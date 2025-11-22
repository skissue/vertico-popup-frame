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

(defcustom vertico-popup-frame-parameters
  `((minibuffer . nil)
    ;; Add one line for the prompt.
    (height . ,(1+ vertico-count)))
  "Frame parameters used for pop-up frames."
  :group 'vertico
  :type '(repeat (cons :format "%v"
                       (symbol :tag "Parameter")
                       (sexp :tag "Value"))))

(defvar vertico-popup-frame--frames nil
  "Stack of frames currently showing Vertico.
This stack will have multiple frames for recursive minibuffers.")

(defun vertico-popup-frame--display-buffer-action (buffer alist)
  "Custom display buffer action for `vertico-buffer-display-action'.
See `display-buffer' for information on BUFFER and ALIST."
  (let ((window
         (display-buffer-pop-up-frame
          buffer `((pop-up-frame-parameters
                    (name . ,(format "*vertico-popup-%d*"
                                     (length vertico-popup-frame--frames)))
                    ,@vertico-popup-frame-parameters)
                   ,@alist))))
    (push (window-frame window) vertico-popup-frame--frames)
    window))

(defun vertico-popup-frame--delete-frame ()
  "Delete current minibuffer frame after minibuffer exit."
  (cl-assert vertico-popup-frame--frames)
  (cl-assert (= (length vertico-popup-frame--frames)
                (minibuffer-depth)))
  (let ((frame (pop vertico-popup-frame--frames)))
    (delete-frame frame)))

(defun vertico-popup-frame--setup (&rest _)
  "Set up the new window and frame appropriately after creation."
  (setq-local mode-line-format nil)
  (add-hook 'minibuffer-exit-hook #'vertico-popup-frame--delete-frame
            nil :local))

(defun vertico-popup-frame--enable ()
  "Enable and set up `vertico-popup-frame-mode'."
  (setq vertico-buffer-display-action
        '(vertico-popup-frame--display-buffer-action))
  (vertico-buffer-mode 1)
  (add-hook 'minibuffer-setup-hook #'vertico-popup-frame--setup))

(defun vertico-popup-frame--disable ()
  "Disable and clean up `vertico-popup-frame-mode'."
  ;; Default value.
  (setq vertico-buffer-display-action
        '(display-buffer-use-least-recent-window))
  (vertico-buffer-mode -1)
  (remove-hook 'minibuffer-setup-hook #'vertico-popup-frame--setup))

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
