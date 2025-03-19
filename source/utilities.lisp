;;;; SPDX-FileCopyrightText: Atlas Engineer LLC
;;;; SPDX-License-Identifier: BSD-3-Clause

(uiop:define-package :nyxt/utilities
  (:use :cl)
  (:import-from :serapeum #:export-always #:->))

(in-package :nyxt/utilities)
(serapeum:eval-always
  (trivial-package-local-nicknames:add-package-local-nickname
   :alex :alexandria-2 :nyxt/utilities)
  (trivial-package-local-nicknames:add-package-local-nickname
   :sera :serapeum))

(export-always '+newline+)
(alex:define-constant +newline+ (string #\newline)
  :test #'equal
  :documentation "String containing newline.
Useful for functions operating on strings, like `str:concat'.")

(export-always '+escape+)
(alex:define-constant +escape+ (string #\escape)
  :test #'equal
  :documentation "String containing ASCII escape (#x1B) char.
Useful when concatenating escaped strings, like in nyxt: URLs.")

(export-always 'new-id)
(defun new-id ()
  "Generate a new unique numeric ID."
  (parse-integer (symbol-name (gensym ""))))

(export-always 'destroy-thread*)
(defun destroy-thread* (thread)
  "Like `bt:destroy-thread' but does not raise an error.
Particularly useful to avoid errors on already terminated threads."
  (ignore-errors (bt:destroy-thread thread)))

(export-always 'funcall*)
(defun funcall* (f &rest args)
  "Like `funcall' but does nothing when F is nil."
  (when f (apply #'funcall f args)))

(export-always 'prini)
(defun prini (value stream &rest keys
              &key (case :downcase) (pretty t) (circle nil)
                (readably nil) (package *package*) &allow-other-keys)
  "PRINt for Interface: a printing primitive with the best aesthetics for Nyxt.
`write'-s the VALUE to STREAM with CASE, PRETTY, CIRCLE, and READABLY set to the
most intuitive values."
  (let ((*print-case* case)
        (*print-pretty* pretty)
        (*print-circle* circle)
        (*print-readably* readably)
        (*package* (find-package package)))
    (remf keys :package)
    (apply #'write value :stream stream keys)))

(export-always 'prini-to-string)
(defun prini-to-string (value &rest keys
                        &key (case :downcase) (pretty t) (circle nil)
                          (readably nil) (package *package*) &allow-other-keys)
  "A string-returning version of `prini'."
  (declare (ignorable case pretty circle readably package))
  (with-output-to-string (s)
    (apply #'prini value s keys)))

(-> documentation-line (t &optional symbol t)
    t)
(export-always 'documentation-line)
(defun documentation-line (object &optional (type t) default)
  "Return the first line of OBJECT `documentation' with TYPE.
If there's no documentation, return DEFAULT."
  (or (first (sera:lines (documentation object type) :count 1))
      default))

(-> last-word (string) string)
(export-always 'last-word)
(defun last-word (s)
  "Last substring of alphanumeric characters, or empty if none."
  (let ((words (sera:words s)))
    (the (values string &optional)
         (if words (alex:last-elt words) ""))))

(export-always 'make-ring)
(defun make-ring (&key (size 1000))
  "Return a new ring buffer."
  (containers:make-ring-buffer size :last-in-first-out))

(export-always 'safe-read)
(defun safe-read (&optional
                    (input-stream *standard-input*)
                    (eof-error-p t)
                    (eof-value nil)
                    (recursive-p nil))
  "Like `read' with standard IO syntax but does not accept reader macros ('#.').
UIOP has `uiop:safe-read-from-string' but no `read' equivalent.
This is useful if you do not trust the input."
  (let ((package *package*))
    (uiop:with-safe-io-syntax (:package package)
      (read input-stream eof-error-p eof-value recursive-p))))

(export-always 'safe-sort)
(defun safe-sort (s &key (predicate #'string-lessp) (key #'string))
  "Sort sequence S of objects by KEY using PREDICATE."
  (sort (copy-seq s) predicate :key key))

(export-always 'safe-slurp-stream-forms)
(defun safe-slurp-stream-forms (stream)
  "Like `uiop:slurp-stream-forms' but wrapped in `uiop:with-safe-io-syntax' and
package set to current package."
  (let ((package *package*))
    (uiop:with-safe-io-syntax (:package package)
      (uiop:slurp-stream-forms stream))))

(export-always 'has-method-p)
(defun has-method-p (object generic-function)
  "Return non-nil if OBJECT has GENERIC-FUNCTION specialization."
  (some (lambda (method)
          (subtypep (type-of object)
                    (class-name
                     (first (closer-mop:method-specializers method)))))
        (closer-mop:generic-function-methods generic-function)))

(export-always 'smart-case-test)
(-> smart-case-test (string) function)
(defun smart-case-test (string)
  "Get the string-comparison test based on STRING.
If the string is all lowercase, then the search is likely case-insensitive.
If there's any uppercase character, then it's case-sensitive."
  (if (str:downcasep string) #'string-equal #'string=))

(setf spinneret:*suppress-inserted-spaces* t)

(-> system-depends-on-all ((or string asdf:system)) (cons string *))
(defun system-depends-on-all (system)
  "List SYSTEM dependencies recursively, even if SYSTEM is an inferred system."
  (let (depends)
    (labels ((deps (system)
               "Return the list of system dependencies as strings."
               (mapcar (trivia:lambda-match
                         ((list _ s _)  ; e.g. (:VERSION "asdf" "3.1.2")
                          (princ-to-string s))
                         (s s))
                       (ignore-errors
                        (asdf:system-depends-on (asdf:find-system system nil)))))
             (subsystem? (system parent-system)
               "Whether PARENT-SYSTEM is a parent of SYSTEM
following the ASDF naming convention.  For instance FOO is a parent of FOO/BAR."
               (alexandria:when-let ((match? (search system parent-system)))
                 (zerop match?)))
             (iter (systems)
               (cond
                 ((null systems)
                  depends)
                 ((subsystem? (first systems) system)
                  (iter (append (deps (first systems)) (rest systems))))
                 ((find (first systems) depends :test 'equalp)
                  (iter (rest systems)))
                 (t
                  (when (asdf:find-system (first systems) nil)
                    (push (first systems) depends))
                  (iter (union (rest systems) (deps (first systems))))))))
      (iter (list (if (typep system 'asdf:system)
                      (asdf:coerce-name system)
                      system))))))
