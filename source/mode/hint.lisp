;;;; SPDX-FileCopyrightText: Atlas Engineer LLC
;;;; SPDX-License-Identifier: BSD-3-Clause

(nyxt:define-package :nyxt/mode/hint
  (:documentation "Package for element hints infrastructure and `hint-mode'.

Exposes the APIs below:
- `query-hints' as the main driver for hinting procedures.
- `hint-source' for `prompt-buffer' interaction."))
(in-package :nyxt/mode/hint)

(define-mode hint-mode ()
  "Interact with elements by typing a short character sequence."
  ((visible-in-status-p nil)
   (hinting-type
    :emacs
    :type (member :emacs :vi)
    :documentation "Set the hinting mechanism.
In :emacs, hints are computed for the whole page, and the usual `prompt-buffer'
facilities are available.
In :vi, the `prompt-buffer' is collapsed to the input area, hints are computed
in viewport only and they're followed when user input matches the hint string.")
   (show-hint-scope-p
    nil
    :type boolean
    :documentation "Whether `style' is applied to the hinted element.
When t, the hinted element is, by default, shown its scope by applying a
background color.")
   (hints-alphabet
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    :type string
    :documentation "The alphabet (charset) to use for hints.
Order matters -- the ones that go first are more likely to appear more often and
to index the top of the page.")
   (hints-selector
    "a, button, input, textarea, details, select"
    :type string
    :documentation "The elements to be hinted.
The hints-selector syntax is that of CLSS, and broadly, that of CSS. Use it to
define which elements are picked up by element hinting.

For instance, to include images:

    a, button, input, textarea, details, select, img:not([alt=\"\"])")
   (x-translation
    0
    :type integer
    :documentation "The horizontal translation as a percentage of the hint's size.
A positive value shifts to the right.")
   (y-translation
    0
    :type integer
    :documentation "The vertical translation as a percentage of the hint's size.
A positive value shifts to the bottom.")
   (x-placement
    :left
    :type (member :left :right)
    :documentation "The horizontal placement of the hints: either `:left' or `:right'.")
   (keyscheme-map
    (define-keyscheme-map "hint-mode" ()
      keyscheme:cua
      (list
       "C-j" 'follow-hint
       "C-J" 'follow-hint-new-buffer
       "C-u C-j" 'follow-hint-new-buffer-focus
       "M-c h" 'copy-hint-url)
      keyscheme:emacs
      (list
       "M-g" 'follow-hint
       "M-G" 'follow-hint-new-buffer
       "C-u M-g" 'follow-hint-new-buffer-focus
       "C-x C-w" 'copy-hint-url)
      keyscheme:vi-normal
      (list
       "f" 'follow-hint
       "; f" 'follow-hint-new-buffer
       "F" 'follow-hint-new-buffer-focus)))))

(defmethod style ((mode hint-mode))
  "The style of the hint overlays."
  (theme:themed-css (theme *browser*)
    `(".nyxt-hint"
      :background-color ,theme:background-color-
      :color ,theme:on-background-color
      :font-family ,theme:monospace-font-family
      :font-size ".85rem"
      :transform ,(format nil "translate(~a%,~a%)"
                          (+ (x-translation mode)
                             (if (eq (x-placement mode) :right) -100 0))
                          (y-translation mode))
      :padding "0px 0.3em"
      :border-color ,theme:primary-color+
      :border-radius "4px"
      :border-width "2px"
      :border-style "solid"
      :z-index #.(1- (expt 2 31)))
    `(".nyxt-hint.nyxt-mark-hint"
      :background-color ,theme:secondary-color
      :color ,theme:on-secondary-color
      :font-weight "bold")
    `(".nyxt-hint.nyxt-current-hint"
      :background-color ,theme:action-color
      :color ,theme:on-action-color)
    '(".nyxt-hint.nyxt-match-hint"
      :padding "0px"
      :border-style "none"
      :opacity "0.5")
    `(".nyxt-element-hint"
      :background-color ,theme:action-color)))

(define-configuration document-buffer
  ((default-modes (cons 'hint-mode %slot-value%))))

(define-parenscript-async hint-elements (hints)
  (defun create-hint-element (hint)
    (let ((hint-element (ps:chain document (create-element "span"))))
      (setf (ps:@ hint-element class-name) "nyxt-hint"
            (ps:@ hint-element id) (+ "nyxt-hint-" hint)
            (ps:@ hint-element text-content) hint)
      hint-element))

  (defun set-hint-element-style (hint-element hinted-element)
    (let* ((right-x-alignment-p (eq (ps:lisp (x-placement (find-submode 'hint-mode)))
                                    :right))
           (rect (ps:chain hinted-element (get-bounding-client-rect))))
      (setf (ps:@ hint-element style position) "absolute"
            (ps:@ hint-element style top) (+ (ps:@ window scroll-y) (ps:@ rect top) "px")
            (ps:@ hint-element style left) (+ (ps:@ window scroll-x) (ps:@ rect left)
                                              (when right-x-alignment-p (ps:@ rect width)) "px"))))

  (defun create-hint-overlay (hinted-element hint)
    "Create a DOM element to be used as a hint."
    (let ((hint-element (create-hint-element hint)))
      (set-hint-element-style hint-element hinted-element))
    hint-element)

  (let* ((hints-parent (ps:chain document (create-element "div")))
         (shadow (ps:chain hints-parent (attach-shadow (ps:create mode "open"))))
         (style (ps:new (|CSSStyleSheet|)))
         (hints (ps:lisp (list 'quote hints)))
         (i 0))
    (dolist (hinted-element (nyxt/ps:rqsa document "[nyxt-hintable]"))
      (let ((hint (aref hints i)))
        (ps:chain hinted-element (set-attribute "nyxt-hint" hint))
        (ps:chain shadow (append-child (create-hint-overlay hinted-element hint)))
        (when (ps:lisp (show-hint-scope-p (find-submode 'hint-mode)))
          (ps:chain hinted-element class-list (add "nyxt-element-hint")))
        (setf i (1+ i))))
    (ps:chain style (replace-sync (ps:lisp (style (find-submode 'hint-mode)))))
    (setf (ps:chain shadow adopted-style-sheets) (array style))
    (setf (ps:@ hints-parent id) "nyxt-hints"
          (ps:@ hints-parent style) "all: unset !important;")
    ;; Unless the hints root is a child of body, zooming the page breaks the
    ;; hint positioning.
    (ps:chain document body (append-child hints-parent))
    ;; Don't return a value.  Only the side-effects are of importance.
    nil))

(-> select-from-alphabet (t alex:non-negative-integer string) (values string &optional))
(defun select-from-alphabet (code subsequence-length alphabet)
  (let ((exponents (nreverse (loop for pow below subsequence-length
                                   collect (expt (length alphabet) pow)))))
    (coerce (loop for exp in exponents
                  for quotient = (floor (/ code exp))
                  collect (aref alphabet quotient)
                  do (decf code (* quotient exp)))
            'string)))

(-> generate-hints (alex:non-negative-integer) (list-of string))
(defun generate-hints (length)
  (let ((alphabet (hints-alphabet (find-submode 'hint-mode))))
    (cond
      ((sera:single alphabet)
       (loop for i from 1 to length
             collect (select-from-alphabet 0 i alphabet)))
      (t
       (loop for i below length
             collect (select-from-alphabet i
                                           (max (ceiling (log length (length alphabet)))
                                                1)
                                           alphabet))))))

(define-parenscript set-hintable-attribute (selector)
  (ps:dolist (element (nyxt/ps:rqsa document (ps:lisp selector)))
    (if (ps:lisp (eq :vi (hinting-type (find-submode 'hint-mode))))
        (unless (nyxt/ps:element-overlapped-p element)
          (ps:chain element (set-attribute "nyxt-hintable" "")))
        (ps:chain element (set-attribute "nyxt-hintable" "")))))

(define-parenscript remove-hintable-attribute ()
  (ps:dolist (element (nyxt/ps:rqsa document "[nyxt-hintable]"))
    (ps:chain element (remove-attribute "nyxt-hintable"))))

(defun add-hints (&key selector (buffer (current-buffer)))
  (set-hintable-attribute selector)
  (update-document-model :buffer buffer)
  (loop with hintable-elements = (sera:filter
                                  (lambda (el) (plump:attribute el "nyxt-identifier"))
                                  (clss:select "[nyxt-hintable]" (document-model buffer :use-cached-p t)))
        with hints = (generate-hints (length hintable-elements))
        for elem across hintable-elements
        for hint in hints
        initially (hint-elements hints)
        do (plump:set-attribute elem "nyxt-hint" hint)
        collect elem))

(define-parenscript-async remove-hint-elements ()
  (ps:let ((hints-parent (nyxt/ps:qs-id document "nyxt-hints")))
    (ps:when hints-parent
      (ps:chain hints-parent (remove))))
  (when (ps:lisp (show-hint-scope-p (find-submode 'hint-mode)))
    (ps:dolist (element (nyxt/ps:rqsa document ".nyxt-element-hint"))
      (ps:chain element class-list (remove "nyxt-element-hint")))))

(defun remove-hints (&key (buffer (current-buffer)))
  (remove-hint-elements)
  (remove-hintable-attribute)
  (update-document-model :buffer buffer))

(export-always 'identifier)
(defmethod identifier ((element plump:element))
  "ELEMENT's on-page identifier (constructed from `hint-alphabet' characters.)"
  (plump:attribute element "nyxt-hint"))

(export-always 'highlight-current-hint)
(define-parenscript highlight-current-hint (&key element scroll)
  "Accent the hint for the ELEMENT to be distinguishable from other hints.
If SCROLL (default to NIL), scroll the hint into view."
  (let* ((shadow (ps:@ (nyxt/ps:qs document "#nyxt-hints") shadow-root))
         (%element (nyxt/ps:qs shadow
                               (ps:lisp (str:concat "#nyxt-hint-" (identifier element))))))
    (when %element
      (unless (ps:chain %element class-list (contains "nyxt-current-hint"))
        ;; There should be, at most, a unique element with the
        ;; "nyxt-current-hint" class.
        ;; querySelectAll, unlike querySelect, handles the case when none are
        ;; found.
        (ps:dolist (current-hint (nyxt/ps:qsa shadow ".nyxt-current-hint"))
          (ps:chain current-hint class-list (remove "nyxt-current-hint"))))
      (ps:chain %element class-list (add "nyxt-current-hint"))
      (when (ps:lisp scroll)
        (ps:chain %element (scroll-into-view (ps:create block "center")))))))

(define-parenscript-async set-hint-visibility (hint state)
  "Set visibility STATE of HINT element.

Consult https://developer.mozilla.org/en-US/docs/Web/CSS/visibility."
  (let* ((shadow (ps:@ (nyxt/ps:qs document "#nyxt-hints") shadow-root))
         (el (nyxt/ps:qs shadow (ps:lisp (str:concat "#nyxt-hint-" (identifier hint))))))
    (when el (setf (ps:@ el style "visibility") (ps:lisp state)))))

(define-parenscript-async dim-hint-prefix (hint prefix-length)
  "Dim the first PREFIX-LENGTH characters of HINT element."
  (let* ((shadow (ps:@ (nyxt/ps:qs document "#nyxt-hints") shadow-root))
         (el (nyxt/ps:qs shadow (ps:lisp (str:concat "#nyxt-hint-" (identifier hint))))))
    (when el
      (let ((span-element (ps:chain document (create-element "span"))))
        (setf (ps:@ span-element class-name) "nyxt-hint nyxt-match-hint"
              (ps:@ span-element style font-size) "inherit"
              (ps:@ span-element text-content) (ps:lisp (subseq (identifier hint)
                                                                0
                                                                prefix-length))
              (ps:chain el inner-h-t-m-l) (+ (ps:@ span-element outer-h-t-m-l)
                                             (ps:lisp (subseq (identifier hint)
                                                              prefix-length))))))))

(define-class hint-source (prompter:source)
  ((prompter:name "Hints")
   (prompter:actions-on-current-suggestion-enabled-p t)
   (prompter:filter-preprocessor
    (if (eq :vi (hinting-type (find-submode 'hint-mode)))
        (lambda (suggestions source input)
          (declare (ignore source))
          (loop for suggestion in suggestions
                for hint = (prompter:value suggestion)
                for hinted-element-id = (nyxt/dom:get-nyxt-id hint)
                if (str:starts-with-p input
                                      (prompter:attributes-default suggestion)
                                      :ignore-case t)
                  do (set-hint-visibility hint "visible")
                  and do (when (show-hint-scope-p (find-submode 'hint-mode))
                           (ps-eval
                             (nyxt/ps:add-class-nyxt-id hinted-element-id
                                                        "nyxt-element-hint")))
                  and do (dim-hint-prefix hint (length input))
                  and collect suggestion
                else do (set-hint-visibility hint "hidden")
                     and do (when (show-hint-scope-p (find-submode 'hint-mode))
                              (ps-eval
                                (nyxt/ps:remove-class-nyxt-id hinted-element-id
                                                              "nyxt-element-hint")))))
        #'prompter:delete-inexact-matches))
   (prompter:filter
    (if (eq :vi (hinting-type (find-submode 'hint-mode)))
        (lambda (suggestion source input)
          (declare (ignore source))
          (str:starts-with-p input
                             (prompter:attributes-default suggestion)
                             :ignore-case t))
        #'prompter:fuzzy-match))
   (prompter:filter-postprocessor
    (lambda (suggestions source input)
      (declare (ignore source))
      (multiple-value-bind (matching-hints other-hints)
          (sera:partition
           (lambda (element)
             (str:starts-with-p input (plump:attribute element "nyxt-hint") :ignore-case t))
           suggestions
           :key #'prompter:value)
        (append matching-hints other-hints))))
   (prompter:actions-on-current-suggestion
    (when (eq :emacs (hinting-type (find-submode 'hint-mode)))
      (lambda-command highlight-current-hint* (suggestion)
        "Highlight hint."
        (highlight-current-hint :element suggestion
                                :scroll nil))))
   (prompter:actions-on-marks
    (lambda (marks)
      (let ((%marks (mapcar (lambda (mark) (str:concat "#nyxt-hint-" (identifier mark)))
                            marks)))
        (ps-eval
          (let ((shadow (ps:@ (nyxt/ps:qs document "#nyxt-hints") shadow-root)))
            (dolist (marked (nyxt/ps:qsa shadow ".nyxt-mark-hint"))
              (ps:chain marked class-list (remove "nyxt-mark-hint")))
            (dolist (mark (ps:lisp (list 'quote %marks)))
              (ps:chain (nyxt/ps:qs shadow mark) class-list (add "nyxt-mark-hint"))))))))
   (prompter:actions-on-return
    (list 'identity
          (lambda-command click* (elements)
            (dolist (element (rest elements))
              (nyxt/dom:click-element element))
            (nyxt/dom:click-element (first elements))
            nil)
          (lambda-command focus* (elements)
            (dolist (element (rest elements))
              (nyxt/dom:focus-select-element element))
            (nyxt/dom:focus-select-element (first elements))
            nil)))))

(export-always 'query-hints)
(defun query-hints (prompt function
                    &key (enable-marks-p t)
                         (selector (hints-selector (find-submode 'hint-mode))))
  "Prompt for elements matching SELECTOR, hinting them visually.
ENABLE-MARKS-P defines whether several elements can be chosen.
PROMPT is the text to show while prompting for hinted elements.
FUNCTION is the action to perform on the selected elements."
  (when-let*
      ((buffer (current-buffer))
       (result (prompt
                :prompt prompt
                ;; TODO: No need to find the symbol if we move this code (and
                ;; the rest) to the hint-mode package.
                :extra-modes (list (sym:resolve-symbol :hint-prompt-buffer-mode :mode))
                :auto-return-p (eq :vi (hinting-type (find-submode 'hint-mode)))
                :history nil
                :height (if (eq :vi (hinting-type (find-submode 'hint-mode)))
                            :fit-to-prompt
                            :default)
                :hide-suggestion-count-p (eq :vi (hinting-type (find-submode 'hint-mode)))
                :sources (make-instance 'hint-source
                                        :enable-marks-p enable-marks-p
                                        :constructor
                                        (lambda (source)
                                          (declare (ignore source))
                                          (add-hints :selector selector)))
                :after-destructor (lambda () (with-current-buffer buffer (remove-hints))))))
    (funcall function result)))

(defmethod prompter:object-attributes :around ((element plump:element) (source hint-source))
  `(,@(when (plump:attribute element "nyxt-hint")
        `(("Hint" ,(plump:attribute element "nyxt-hint") (:width 1))))
    ;; Ensure that all of Body and URL are there, even if empty.
    ,@(loop with attributes = (call-next-method)
            for attr in '("Body" "URL")
            for (same-attr val) = (assoc attr attributes :test 'string=)
            if same-attr
              collect `(,same-attr ,val (:width 3))
            else collect `(,attr "" (:width 3)))
    ("Type" ,(str:capitalize (str:string-case
                                 (plump:tag-name element)
                               ("a" "link")
                               ("img" "image")
                               (otherwise (plump:tag-name element))))
            (:width 1))))

(defmethod prompter:object-attributes ((input nyxt/dom:input-element) (source prompter:source))
  (declare (ignore source))
  (when (nyxt/dom:body input)
    `(("Body" ,(str:shorten 80 (nyxt/dom:body input))))))

(defmethod prompter:object-attributes ((textarea nyxt/dom:textarea-element) (source prompter:source))
  (declare (ignore source))
  (when (nyxt/dom:body textarea)
    `(("Body" ,(str:shorten 80 (nyxt/dom:body textarea))))))

(defmethod prompter:object-attributes ((a nyxt/dom:a-element) (source prompter:source))
  (declare (ignore source))
  (append
   (and-let* (((plump:has-attribute a "href"))
              (url-string (plump:attribute a "href")))
     `(("URL" ,url-string)))
   (when (nyxt/dom:body a)
     `(("Body" ,(str:shorten 80 (nyxt/dom:body a)))))))

(defmethod prompter:object-attributes ((button nyxt/dom:button-element) (source prompter:source))
  (declare (ignore source))
  (when (nyxt/dom:body button)
    `(("Body" ,(str:shorten 80 (nyxt/dom:body button))))))

(defmethod prompter:object-attributes ((details nyxt/dom:details-element) (source prompter:source))
  (declare (ignore source))
  (when (nyxt/dom:body details)
    `(("Body" ,(str:shorten 80 (nyxt/dom:body details))))))

(defmethod prompter:object-attributes ((select nyxt/dom:select-element) (source prompter:source))
  (declare (ignore source))
  `(("Body" ,(str:shorten 80 (nyxt/dom:body select)))))

(defmethod prompter:object-attributes ((option nyxt/dom:option-element) (source prompter:source))
  (declare (ignore source))
  `(("Body" ,(nyxt/dom:body option))))

(defmethod prompter:object-attributes ((img nyxt/dom:img-element) (source hint-source))
  (append
   (and-let* (((plump:has-attribute img "href"))
              (url-string (plump:attribute img "href")))
     `(("URL" ,url-string)))
   (when (nyxt/dom:body img)
     `(("Body" ,(str:shorten 80 (nyxt/dom:body img)))))))

(defmethod %follow-hint ((element plump:element))
  (nyxt/dom:click-element element))

(defmethod %follow-hint ((a nyxt/dom:a-element))
  (ffi-buffer-load (current-buffer) (url a)))

(defmethod %follow-hint ((input nyxt/dom:input-element))
  (str:string-case (plump:attribute input "type")
                   ("button" (nyxt/dom:click-element input))
                   ("radio" (nyxt/dom:check-element input))
                   ("checkbox" (nyxt/dom:check-element input))
                   (otherwise (nyxt/dom:focus-select-element input))))

(defmethod %follow-hint ((textarea nyxt/dom:textarea-element))
  (nyxt/dom:focus-select-element textarea))

(defmethod %follow-hint ((details nyxt/dom:details-element))
  (nyxt/dom:toggle-details-element details))

(define-class options-source (prompter:source)
  ((prompter:name "Options")
   (prompter:filter-preprocessor #'prompter:filter-exact-matches))
  (:export-class-name-p t)
  (:documentation "Prompt source for select tag options."))

(defmethod %follow-hint ((select nyxt/dom:select-element))
  (and-let* ((options (coerce (clss:select "option" select) 'list))
             (values (prompt :prompt "Value to select"
                             :sources (make-instance 'options-source
                                                     :constructor options
                                                     :enable-marks-p
                                                     (plump:attribute select "multiple")))))
    (dolist (option (mapcar (rcurry #'find options :test #'equalp) values))
      (nyxt/dom:select-option-element option select))))

(defmethod %follow-hint-new-buffer-focus ((a nyxt/dom:a-element))
  (make-buffer-focus :url (url a)))

(defmethod %follow-hint-new-buffer-focus ((element plump:element))
  (%follow-hint element))

(defmethod %follow-hint-new-buffer ((a nyxt/dom:a-element))
  (make-buffer :url (url a) :load-url-p t))

(defmethod %follow-hint-new-buffer ((element plump:element))
  (%follow-hint element))

(defmethod %copy-hint-url ((a nyxt/dom:a-element))
  (ffi-buffer-copy (current-buffer) (render-url (url a))))

(defmethod %copy-hint-url ((img nyxt/dom:img-element))
  (ffi-buffer-copy (current-buffer) (render-url (url img))))

(defmethod %copy-hint-url ((element plump:element))
  (echo "Unsupported operation for <~a> hint: can't copy hint URL."
        (plump:tag-name element)))

(define-command follow-hint ()
  "Follow the top element hint selection in the current buffer."
  (query-hints "Select elements"
               (lambda (results)
                 (%follow-hint (first results))
                 (mapcar #'%follow-hint-new-buffer (rest results)))))

(define-command follow-hint-new-buffer ()
  "Like `follow-hint', but selection is handled in background buffers."
  (query-hints "Select elements"
               (lambda (result)
                 (mapcar #'%follow-hint-new-buffer result))))

(define-command follow-hint-new-buffer-focus ()
  "Like `follow-hint-new-buffer', but switch to the top background buffer."
  (query-hints "Select elements"
               (lambda (result)
                 (%follow-hint-new-buffer-focus (first result))
                 (mapcar #'%follow-hint-new-buffer (rest result)))))

(define-command copy-hint-url ()
  "Save the element hint's URL to the clipboard."
  (query-hints "Select element"
               (lambda (result) (%copy-hint-url (first result)))
               :enable-marks-p nil
               :selector "a"))
