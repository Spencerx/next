;;;; SPDX-FileCopyrightText: Atlas Engineer LLC
;;;; SPDX-License-Identifier: BSD-3-Clause

;; `uiop:define-package' instead of `nyxt:define-package' since it does not
;; depend on Nyxt.
(uiop:define-package :nyxt/keyscheme
  (:use :cl)
  (:import-from :serapeum #:export-always #:->)
  (:documentation "Nyxt type specialization for `keymap' bound values."))
(in-package :nyxt) ; In case the package is locked.
(trivial-package-local-nicknames:add-package-local-nickname :keyscheme :nyxt/keyscheme :nyxt)
(in-package :nyxt/keyscheme)

(export-always 'nyxt-keymap-value)
(deftype nyxt-keymap-value ()
  "A Nyxt-specific type suitable for `nkeymaps:bound-type'."
  '(or nkeymaps:keymap t))

(export-always 'make-keyscheme)
(defun make-keyscheme (name &rest parents)
  "Return a new `nkeymaps:keyscheme' object of type `nyxt-keymap-value'.
The keyscheme inherits from the optional PARENTS, ordered by priority.

Example:

  (defvar cua-child (make-keyscheme \"cua-child\" cua))

The above example defines a keyscheme called `cua-child', which inherits from
the existing keyscheme `cua'."
  (the (values nkeymaps:keyscheme &optional)
       (make-instance 'nkeymaps:keyscheme
                      :name name
                      :parents parents
                      :bound-type 'nyxt-keymap-value)))

(export-always 'default)
(defvar default (make-keyscheme "default")
  "The root keyscheme from which all the other Nyxt keyschemes (command ones, at least) inherit.")
(export-always 'cua)
(defvar cua (make-keyscheme "cua" default)
  "CUA (Common User Access) keyscheme with conventional bindings typical to major browsers.")
(export-always 'emacs)
(defvar emacs (make-keyscheme "emacs" default)
  "Keyscheme inspired by Emacs text editor.")
(export-always 'vi-normal)
(defvar vi-normal (make-keyscheme "vi-normal" default)
  "Keyscheme inspired by the command mode in VI-family text editors.")
(export-always 'vi-insert)
(defvar vi-insert (make-keyscheme "vi-insert")
  "Keyscheme inspired by the insert mode in VI-family editors.")
