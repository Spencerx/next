;;;; SPDX-FileCopyrightText: Atlas Engineer LLC
;;;; SPDX-License-Identifier: BSD-3-Clause

(nyxt:define-package :nyxt/mode/macro-edit
    (:documentation "Package for `macro-edit-mode', mode for editing macros.

There are implementation details for (almost) every command in this mode:
- `edit-macro': `render-functions'.
- `add-command': `add-function', `remove-function', `macro-name', and
  `generate-macro-form'.
- `save-macro': `macro-form-valid-p'."))
(in-package :nyxt/mode/macro-edit)

(define-mode macro-edit-mode ()
  "Mode for creating and editing macros.

See `nyxt/mode/macro-edit' package documentation for implementation details."
  ((macro-name
    ""
    :accessor nil
    :documentation "The descriptive name used for the macro.")
   (macro-description
    ""
    :accessor nil
    :documentation "The description used for the macro.")
   (functions
    '()
    :documentation "Functions the user has added to their macro."))
  (:toggler-command-p nil))

(defmethod render-functions ((macro-editor macro-edit-mode))
  (spinneret:with-html
    (if (functions macro-editor)
        (:table
         (:tr
          (:th "Operations")
          (:th "Command"))
         (loop for function in (functions macro-editor)
               for index from 0
               collect
               (:tr (:td (:nbutton :class "button"
                           :text "Remove Command"
                           :title "Remove from the macro"
                           `(nyxt/mode/macro-edit::remove-function
                             (find-submode 'macro-edit-mode)
                             ,index))
                         (:a.button
                          :title "Help"
                          :target "_blank"
                          :href (nyxt-url 'describe-function
                                          :fn (name (nth
                                                     index
                                                     (functions macro-editor))))
                          "Command Information"))
                    (:td (let ((name (symbol-name (name function))))
                           (if (str:upcase? name)
                               (string-downcase name)
                               name))))))
        (:p "No commands added to macro."))))

(define-internal-page-command-global edit-macro ()
    (buffer "*Macro edit*" 'nyxt/mode/macro-edit:macro-edit-mode)
  "Edit a macro."
  (spinneret:with-html-string
    (render-menu 'nyxt/mode/macro-edit:macro-edit-mode buffer)
    (:h1 "Macro editor")
    (:dl
     (:dt "Name")
     (:dd (:input :type "text" :id "macro-name"))
     (:dt "Description")
     (:dd (:input :type "text" :id "macro-description")))
    (:h2 "Commands")
    (:div
     :id "commands"
     (render-functions
      (find-submode 'nyxt/mode/macro-edit:macro-edit-mode)))))

(defmethod add-function ((macro-editor macro-edit-mode) command)
  (alex:appendf (functions macro-editor)
                (list command))
  (ffi-buffer-reload (buffer macro-editor)))

(defun delete-nth (n list)
  (nconc (subseq list 0 n) (nthcdr (1+ n) list)))

(defmethod remove-function ((macro-editor macro-edit-mode) command-index)
  (setf (functions macro-editor)
        (delete-nth command-index (functions macro-editor)))
  (ffi-buffer-reload (buffer macro-editor)))

(defmethod macro-name ((macro-editor macro-edit-mode))
  (let ((name (ps-eval :buffer (buffer macro-editor)
                (ps:chain (nyxt/ps:qs document "#macro-name") value))))
    (cond ((not (str:emptyp name))
           (setf (slot-value macro-editor 'macro-name) (string-upcase name)))
          ((slot-value macro-editor 'macro-name)
           (slot-value macro-editor 'macro-name))
          (t nil))))

(defmethod macro-description ((macro-editor macro-edit-mode))
  (let ((name (ps-eval :buffer (buffer macro-editor)
                (ps:chain (nyxt/ps:qs document "#macro-description") value))))
    (cond ((not (str:emptyp name))
           (setf (slot-value macro-editor 'macro-description) name))
          ((slot-value macro-editor 'macro-description)
           (slot-value macro-editor 'macro-description))
          (t nil))))

(defmethod generate-macro-form ((macro-editor macro-edit-mode))
  (let ((name (intern (macro-name macro-editor)))
        (description (macro-description macro-editor))
        (commands (mapcar
                   (lambda (command) `(,(name command)))
                   (functions macro-editor))))
    `(define-command-global ,name () ,description ,@commands)))

(define-command add-command
    (&optional (macro-editor (find-submode 'macro-edit-mode)))
  "Add a command to the macro."
  (add-function macro-editor (prompt1
                              :prompt "Add command"
                              :sources 'command-source)))

(defmethod macro-form-valid-p ((macro-editor macro-edit-mode))
  (and (macro-name macro-editor)
       (functions macro-editor)))

(define-command save-macro
    (&optional (macro-editor (find-submode 'macro-edit-mode)))
  "Save the macro to the `*auto-config-file*' file."
  (if (macro-form-valid-p macro-editor)
      (progn
        (nyxt::auto-configure :form (generate-macro-form macro-editor))
        (echo "Saved macro to ~s." (files:expand *auto-config-file*)))
      (echo "Macro form is invalid; check it has a title and functions.")))

(define-command evaluate-macro
    (&optional (macro-editor (find-submode 'macro-edit-mode)))
  "Evaluate the macro for testing."
  (if (macro-form-valid-p macro-editor)
      (progn
        (eval (generate-macro-form macro-editor))
        (echo "Macro compiled, you may now use the ~s command."
              (macro-name macro-editor)))
      (echo "Macro form is invalid; check it has a title and functions.")))
