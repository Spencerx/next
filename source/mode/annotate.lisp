;;;; SPDX-FileCopyrightText: Atlas Engineer LLC
;;;; SPDX-License-Identifier: BSD-3-Clause

(nyxt:define-package :nyxt/mode/annotate
  (:documentation "Package for `annotate-mode', mode to annotate documents.

The most important piece of functionality is the `annotation' class and its
subclasses: `url-annotation' and `snippet-annotation'.

See the `annotate-mode' for the external user-facing APIs."))
(in-package :nyxt/mode/annotate)

(define-mode annotate-mode ()
  "Annotate document with arbitrary comments.
Annotations are persisted to disk, see the `annotations-file' mode slot.

See `nyxt/mode/annotate' package documentation for implementation details and
internal programming APIs."
  ((visible-in-status-p nil)
   (annotations-file
    (make-instance 'annotations-file)
    :type annotations-file
    :documentation "File where annotations are saved.")))

(define-configuration context-buffer
  ((default-modes (cons 'annotate-mode %slot-value%))))

(defmethod annotations-file ((buffer buffer))
  (annotations-file (find-submode 'annotate-mode buffer)))

(define-class annotations-file (files:data-file nyxt-lisp-file)
  ((files:base-path #p"annotations")
   (files:name "annotations"))
  (:export-class-name-p t))

(define-class annotation ()
  ((data
    ""
    :export nil
    :documentation "The annotation data.")
   (tags
    '()
    :type (list-of string))
   (date (time:now)))
  (:export-class-name-p t)
  (:export-accessor-names-p t)
  (:documentation "An umbrella annotation type.
Should not be instantiated on its own. Instead, use `url-annotation' and
`snippet-annotation'."))

(define-class url-annotation (annotation)
  ((url nil)
   (page-title ""))
  (:export-class-name-p t)
  (:export-accessor-names-p t)
  (:documentation "Annotation for a page with a certain URL.
Command to create one is `annotate-current-url'."))

(define-class snippet-annotation (url-annotation)
  ((snippet nil :documentation "The snippet of text being annotated."))
  (:export-class-name-p t)
  (:export-accessor-names-p t)
  (:documentation "Annotation in relation to a text on a certain page.
The page is handled by underlying `url-annotation', while the snippet is
extracted by `annotate-highlighted-text' command."))

(defmethod render ((annotation url-annotation))
  (spinneret:with-html
    (:dl
     (:dt "URL")
     (:dd (:a :href (url annotation) (render-url (url annotation))))
     (:dt "Title")
     (:dd (page-title annotation))
     (:dt "Tags")
     (:dd (:pre (format nil "~{~a ~}" (tags annotation))))
     (:dt "Text")
     (:dd (data annotation)))))

(defmethod render ((annotation snippet-annotation))
  (spinneret:with-html
    (:dl
     (:dt "URL")
     (:dd (:a :href (url annotation) (render-url (url annotation))))
     (:dt "Title")
     (:dd (page-title annotation))
     (:dt "Snippet")
     (:dd (snippet annotation))
     (:dt "Tags")
     (:dd (:pre (format nil "~{~a ~}" (tags annotation))))
     (:dt "Text")
     (:dd (data annotation)))))

(defun annotation-add (annotation)
  (files:with-file-content (annotations (annotations-file (current-buffer)))
    (push annotation annotations)))

(defun annotations ()
  (files:content (annotations-file (current-buffer))))

(define-command annotate-current-url
    (&key (buffer (current-buffer))
     (data (prompt1 :prompt "Annotation"
                    :sources (make-instance 'prompter:raw-source
                                            :name "Note")))
     (tags (prompt
            :prompt "Tag(s)"
            :sources (list (make-instance 'prompter:word-source
                                          :name "New tags"
                                          :enable-marks-p t)
                           (make-instance 'keyword-source :buffer buffer)
                           (make-instance 'annotation-tag-source)))))
  "Create an annotation of the URL of BUFFER.

DATA and TAGS are passed as arguments to `url-annotation' make-instance."
  (annotation-add (make-instance 'url-annotation
                                 :url (url buffer)
                                 :data data
                                 :page-title (title buffer)
                                 :tags tags)))

(define-command annotate-highlighted-text
    (&key (buffer (current-buffer))
     (snippet (ffi-buffer-copy buffer))
     (data (prompt1 :prompt "Annotation"
                    :sources (make-instance 'prompter:raw-source
                                            :name "Note")))
     (tags (prompt
            :prompt "Tag(s)"
            :sources (list (make-instance 'prompter:word-source
                                          :name "New tags"
                                          :enable-marks-p t)
                           (make-instance 'keyword-source :buffer buffer)
                           (make-instance 'annotation-tag-source)))))
  "Create an annotation for the highlighted text of BUFFER.

DATA, SNIPPET, and TAGS are passed as arguments to `snippet-annotation'
make-instance."
  (annotation-add (make-instance 'snippet-annotation
                                 :snippet snippet
                                 :url (url buffer)
                                 :page-title (title buffer)
                                 :data data
                                 :tags tags)))

(defun render-annotations (annotations)
  "Show the ANNOTATIONS in a new buffer"
  (spinneret:with-html-string
    (:h1 "Annotations")
    (or
     (loop for annotation in annotations
           collect (:div (render annotation)
                         (:hr)))
     (:p "No annotations available/selected."))))

(define-internal-page show-annotations-for-current-url
    (&key (id (id (current-buffer))))
    (:title "*Annotations*")
  "Display the annotations associated to buffer with ID."
  (let ((buffer (nyxt::buffer-get id)))
    (render-annotations (sera:filter (curry #'url-equal (url buffer))
                                     (files:content (annotations-file buffer))
                                     :key (compose #'quri:uri #'url)))))

(define-command-global show-annotations-for-current-url
    (&key (buffer (current-buffer)))
  "Create a new buffer with the annotations of the current URL of BUFFER."
  (buffer-load-internal-page-focus 'show-annotations-for-current-url
                                   :id (id buffer)))

(define-class annotation-source (prompter:source)
  ((prompter:name "Annotations")
   (prompter:constructor (files:content (annotations-file (current-buffer))))
   (prompter:filter-preprocessor #'prompter:filter-exact-matches)
   (prompter:enable-marks-p t)))

(defmethod prompter:object-attributes ((annotation annotation)
                                       (source prompter:source))
  (declare (ignore source))
  `(("Data" ,(data annotation) (:width 3))
    ("Tags" ,(tags annotation) (:width 3))))

(define-class annotation-tag-source (prompter:source)
  ((prompter:name "Tags")
   (prompter:filter-preprocessor
    (lambda (initial-suggestions-copy source input)
      (prompter:delete-inexact-matches
       initial-suggestions-copy
       source
       (last-word input))))
   (prompter:filter
    (lambda (suggestion source input)
      (prompter:fuzzy-match suggestion source (last-word input))))
   (prompter:enable-marks-p t)
   (prompter:constructor
    (let ((annotations (files:content (annotations-file (current-buffer)))))
      (sort (remove-duplicates
             (mappend #'tags annotations)
             :test #'string-equal)
            #'string-lessp)))))

(define-internal-page-command-global show-annotation ()
    (buffer "*Annotations*")
  "Show prompted annotations."
  (handler-case (render-annotations
                 (prompt :prompt "Show annotation(s)"
                         :sources (make-instance 'annotation-source)))
    (nyxt:prompt-buffer-canceled () (render-annotations nil))))

(define-internal-page-command-global show-annotations ()
    (buffer "*Annotations*")
  "Show all annotations"
  (render-annotations (files:content (annotations-file buffer))))
