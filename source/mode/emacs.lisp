;;;; SPDX-FileCopyrightText: Atlas Engineer LLC
;;;; SPDX-License-Identifier: BSD-3-Clause

(nyxt:define-package :nyxt/mode/emacs
  (:documentation "Package for `emacs-mode', mode to host Emacs inspired
keybindings."))
(in-package :nyxt/mode/emacs)

(define-mode emacs-mode (nyxt/mode/keyscheme:keyscheme-mode)
  "Enable Emacs inspired keybindings.

To enable them by default, append the mode to the list of `default-modes' in
your configuration file.

Example:

\(define-configuration buffer
  ((default-modes (append '(emacs-mode) %slot-value%))))"
  ((glyph "e")
   (keyscheme keyscheme:emacs)))
