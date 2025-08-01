;;;; SPDX-FileCopyrightText: Atlas Engineer LLC
;;;; SPDX-License-Identifier: BSD-3-Clause

(in-package :nyxt)

(hooks:define-hook-type keymaps-buffer
    (function ((list-of keymaps:keymap) buffer)
              (values &optional (list-of keymaps:keymap) buffer))
  "Hook to modify keymaps.
Get a list of `nkeymaps:keymap's and `buffer' and return a new list and buffer.")
(export-always '(hook-keymaps-buffer))
(hooks:define-hook-type url->url (function (quri:uri) quri:uri)
  "Hook getting a `quri:uri' and returning same/another one. ")

(export-always 'renderer-buffer)
(defclass renderer-buffer ()
  ()
  (:metaclass interface-class)
  (:documentation "Renderer-specific buffer objects.
Should be redefined by the renderer."))

(defvar %default-modes '(base-mode)
  "The default modes for unspecialized buffers.
This is useful when there is no current buffer.")

(define-class buffer (renderer-buffer)
  ((default-modes
    %default-modes
    :accessor nil
    :type (list-of symbol)
    :documentation "The symbols of the modes to instantiate on buffer creation.
The mode instances are stored in the `modes' BUFFER slot.

The default modes returned by this method are appended to the default modes
inherited from the superclasses.")
   (id
    (new-id)
    :type unsigned-byte
    :documentation "Unique identifier for a buffer.")
   (key-stack
    '()
    :documentation "A stack of the key chords a user has pressed.")
   (last-access
    (time:now)
    :export nil
    :documentation "Timestamp when the buffer was last switched to.")
   (last-key
    nil
    :export nil
    :type (or null keymaps:key)
    :documentation "Last pressed key.")
   (url (quri:uri ""))
   (url-at-point (quri:uri ""))
   (title "")
   (style
    (theme:themed-css (theme *browser*)
      '(:font-face :font-family "public sans" :font-style "normal" :font-weight
        "400" :src "url('nyxt-resource:PublicSans-Regular.woff')"
        "format('woff')")
      '(:font-face :font-family "public sans" :font-style "italic" :font-weight
        "400" :src "url('nyxt-resource:PublicSans-Italic.woff')"
        "format('woff')")
      '(:font-face :font-family "public sans" :font-style "normal" :font-weight
        "100" :src "url('nyxt-resource:PublicSans-Thin.woff')"
        "format('woff')")
      '(:font-face :font-family "public sans" :font-style "italic" :font-weight
        "100" :src "url('nyxt-resource:PublicSans-ThinItalic.woff')"
        "format('woff')")
      '(:font-face :font-family "public sans" :font-style "normal" :font-weight
        "200" :src "url('nyxt-resource:PublicSans-ExtraLight.woff')"
        "format('woff')")
      '(:font-face :font-family "public sans" :font-style "italic" :font-weight
        "200" :src "url('nyxt-resource:PublicSans-ExtraLightItalic.woff')"
        "format('woff')")
      '(:font-face :font-family "public sans" :font-style "normal" :font-weight
        "300" :src "url('nyxt-resource:PublicSans-Light.woff')"
        "format('woff')")
      '(:font-face :font-family "public sans" :font-style "italic" :font-weight
        "300" :src "url('nyxt-resource:PublicSans-LightItalic.woff')"
        "format('woff')")
      '(:font-face :font-family "public sans" :font-style "normal" :font-weight
        "500" :src "url('nyxt-resource:PublicSans-Medium.woff')"
        "format('woff')")
      '(:font-face :font-family "public sans" :font-style "italic" :font-weight
        "500" :src "url('nyxt-resource:PublicSans-MediumItalic.woff')"
        "format('woff')")
      '(:font-face :font-family "public sans" :font-style "normal" :font-weight
        "600" :src "url('nyxt-resource:PublicSans-SemiBold.woff')"
        "format('woff')")
      '(:font-face :font-family "public sans" :font-style "italic" :font-weight
        "600" :src "url('nyxt-resource:PublicSans-SemiBoldItalic.woff')"
        "format('woff')")
      '(:font-face :font-family "public sans" :font-style "normal" :font-weight
        "700" :src "url('nyxt-resource:PublicSans-Bold.woff')"
        "format('woff')")
      '(:font-face :font-family "public sans" :font-style "italic" :font-weight
        "700" :src "url('nyxt-resource:PublicSans-BoldItalic.woff')"
        "format('woff')")
      '(:font-face :font-family "public sans" :font-style "normal" :font-weight
        "800" :src "url('nyxt-resource:PublicSans-ExtraBold.woff')"
        "format('woff')")
      '(:font-face :font-family "public sans" :font-style "italic" :font-weight
        "800" :src "url('nyxt-resource:PublicSans-ExtraBoldItalic.woff')"
        "format('woff')")
      '(:font-face :font-family "public sans" :font-style "normal" :font-weight
        "900" :src "url('nyxt-resource:PublicSans-Black.woff')"
        "format('woff')")
      '(:font-face :font-family "public sans" :font-style "italic" :font-weight
        "900" :src "url('nyxt-resource:PublicSans-BlackItalic.woff')"
        "format('woff')")
      '(:font-face :font-family "dejavu sans mono"
        :src "url('nyxt-resource:DejaVuSansMono.ttf')" "format('ttf')")
      '(*
        :box-sizing border-box)
      `(body
        :background-color ,theme:background-color
        :color ,theme:on-background-color
        :font-family ,theme:font-family
        :margin-left "20px"
        :margin-top "20px")
      '(ul
        :margin-top "0"
        :margin-bottom "0")
      '("details > *"
        :margin-left "18px")
      '("details > ul"
        :margin-left "inherit")
      '("details summary"
        :margin-left "inherit"
        :margin-bottom "8px"
        :cursor "pointer")
      '("summary::-webkit-details-marker"
        :padding-bottom "4px")
      '("details > summary"
        :list-style-type "none")
      '("details > summary::-webkit-details-marker"
        :display "none")
      '("details > summary::before"
        :font-weight "bold"
        :content "+"
        :margin-right "5px"
        :display "inline-block")
      '("details[open] > summary::before"
        :content "−")
      '(.section
        :margin-top "2em")
      `("h1,h2,h3,h4,h5,h6"
        :color ,theme:primary-color)
      `(hr
        :background-color ,theme:secondary-color
        :color ,theme:on-secondary-color
        :height "2px"
        :border-radius "2px"
        :border-width "0")
      '(button
        :background "transparent"
        :color "inherit"
        :border "none"
        :padding 0
        :font "inherit"
        :outline "inherit")
      `(.button
        :appearance "menulist-button"
        :background-color ,theme:primary-color
        :color ,theme:on-primary-color
        :display "inline-block"
        :text-decoration "none"
        :border-radius "4px"
        :border-color ,theme:primary-color
        :border-style "solid"
        :border-width "0.2em"
        :padding "0.2em"
        :margin "0.2em")
      `(select.button
        :appearance auto
        :background-color ,theme:primary-color
        :color ,theme:on-primary-color)
      `(code
        :font-family ,theme:monospace-font-family
        :font-size "0.9rem")
      `(.code-select
        :position "absolute"
        :top "0"
        :right "0"
        :padding-right "8px !important"
        :direction "rtl"
        :appearance "none !important"
        :border "none"
        :background-color "transparent !important"
        :color "black !important")
      `(".code-select:hover"
        :color ,theme:action-color !important)
      '((:and .button :hover)
        :cursor "pointer"
        :opacity 0.8)
      `((:and .button (:or :visited :active))
        :color ,theme:background-color)
      `(.link
        :appearance none
        :text-decoration "underline"
        :display "inline"
        :color ,theme:primary-color)
      '(".link:hover"
        :opacity 0.8)
      `(.action
        :color ,theme:action-color)
      `(.button.action
        :background-color ,theme:action-color
        :color ,theme:on-action-color
        :border-color ,theme:action-color+)
      `(.warning
        :color ,theme:warning-color)
      `(.button.warning
        :background-color ,theme:warning-color
        :color ,theme:on-warning-color
        :border-color ,theme:warning-color+)
      `(.success
        :color ,theme:success-color)
      `(.button.success
        :background-color ,theme:success-color
        :color ,theme:on-success-color
        :border-color ,theme:success-color+)
      `(.highlight
        :color ,theme:highlight-color)
      `(.button.highlight
        :background-color ,theme:highlight-color
        :color ,theme:on-highlight-color
        :border-color ,theme:highlight-color+)
      `(.plain
        :color ,theme:on-background-color
        :background-color ,theme:background-color)
      `(.input
        :appearance "textfield"
        :display "inline-block"
        :color "black"
        :background-color "white"
        :border "0.2em" solid ,theme:secondary-color
        :border-radius "4px"
        :outline "none"
        :padding "0.2em"
        :margin "0.2em")
      `(a
        :color ,theme:primary-color)
      `("a:hover"
        :opacity 0.8)
      `(pre
        :font-family ,theme:monospace-font-family
        :font-size "0.9rem"
        :border-radius "2px"
        :overflow "auto"
        :padding "5px")
      '("table"
        :border-radius "2px"
        :border-spacing "0"
        :width "100%")
      `("pre, p code"
        :color ,theme:on-background-color
        :background-color ,theme:background-color-)
      '("a code"
        :text-decoration underline)
      `("table, th, td"
        :border-color ,theme:primary-color
        :border-width "1px"
        :border-style "solid"
        :background-color ,theme:background-color
        :color ,theme:on-background-color)
      '("td, th"
        :padding "6px")
      `(th
        :background-color ,theme:primary-color
        :color ,theme:on-primary-color
        :text-align "left")
      '("th:first-of-type"
        :border-top-left-radius "1px")
      '("th:last-of-type"
        :border-top-right-radius "1px")
      '("tr:last-of-type td:first-of-type"
        :border-bottom-left-radius "2px")
      '("tr:last-of-type td:last-of-type"
        :border-bottom-right-radius "2px")
      '("table.resizable-table th"
        :resize "horizontal"
        :overflow "auto")
      `("::selection"
        :color ,theme:on-action-color
        :background-color ,theme:action-color)
      `(".mode-menu"
        :overflow-x "scroll"
        :white-space "nowrap"
        :background-color ,theme:background-color-
        :position "sticky"
        :margin-top "-20px"
        :top 0
        :width "100%"
        :height "32px")
      `(".mode-menu > button"
        :color ,theme:on-secondary-color
        :padding-left "8px"
        :padding-right "8px"
        :font-size "14px"
        :border-radius "2px"
        :margin "0"
        :margin-right "12px"
        :border "none"
        :height "32px")
      `(".mode-menu > .binding"
        :background-color ,theme:secondary-color)
      `(".mode-menu > .command"
        :background-color ,theme:background-color-)
      '(".mode-menu::-webkit-scrollbar"
        :display "none")
      '("dl"
        :display "grid"
        :grid-template-columns "max-content auto"
        :row-gap "10px"
        :column-gap "10px")
      `("dt"
        :grid-column-start 1
        :padding "4px"
        :padding-left "8px"
        :padding-right "8px"
        :border-radius "2px"
        :font-weight "bold"
        :background-color ,theme:background-color-)
      '("dd"
        :margin-inline-start "0"
        :grid-column-start 2)
      '("dd pre"
        :margin-top "0"
        :margin-bottom "0")
      '(".nsection-anchor"
        :display "none")
      '(".nsection-summary:hover .nsection-anchor"
        :display "inline-block")))
   (buffer-delete-hook
    (make-instance 'hook-buffer)
    :type hook-buffer
    :documentation "Hook run before `buffer-delete'.
The handlers take the buffer as argument."))
  (:export-class-name-p t)
  (:export-accessor-names-p t)
  (:export-predicate-name-p t)
  (:metaclass user-class)
  (:documentation "A buffer is the fundamental unit of displayed content.
Buffers result from the computations of a web renderer, which generates a visual
representation of HTML documents.

Rendered URLs or the Nyxt's manual qualify as examples.  Buffers are fully
separated from one another, so that each has its own behavior and settings."))

(defmethod request-resource-hook ((buffer buffer))
  "A method to not error out if the buffer has no `request-resource-hook'.

Useful in FFI functions where we usually specialize things against
`renderer-buffer', not knowing the exact class of those."
  nil)

(defmethod initialize-instance :after ((buffer buffer) &key &allow-other-keys)
  "Dummy method to allow forwarding other key arguments."
  buffer)

(define-class modable-buffer (buffer)
  ((modes
    '()
    :documentation "The list of mode instances.
Modes are instantiated over the result of the `default-modes' method, with
`customize-instance' and not in the initform so that the instantiation form can
access the initialized buffer.")
   (page-mode
    nil
    :documentation "A single mode enabled for internal pages.
This slot stores the mode enabled by internal pages. When the user navigates
away from the internal page, this mode is disabled.")
   (enable-mode-hook
    (make-instance 'hook-mode)
    :type hook-mode
    :documentation "Hook run on mode enabling, after the mode-specific hook.")
   (disable-mode-hook
    (make-instance 'hook-mode)
    :type hook-mode
    :documentation "Hook run on mode disabling, after the mode-specific hook."))
  (:export-class-name-p t)
  (:export-accessor-names-p t)
  (:export-predicate-name-p t)
  (:metaclass user-class)
  (:documentation "A buffer whose behavior can be modified with `mode's."))

(defmethod enable-page-mode ((modable-buffer modable-buffer) mode)
  (enable-modes* mode modable-buffer)
  (setf (page-mode modable-buffer) mode))

(defmethod disable-page-mode ((modable-buffer modable-buffer))
  (when (page-mode modable-buffer)
    (disable-modes* (page-mode modable-buffer) modable-buffer)
    (setf (page-mode modable-buffer) nil)))

(defmethod modes ((buffer buffer))
  "Return the modes active in BUFFER.

Non-`modable-buffer's never have modes.
The default specialization on `buffer' is useful to be able to call the method
regardless of the buffer, with a meaningful result."
  '())

(export-always 'enabled-modes)
(defmethod enabled-modes ((buffer modable-buffer))
  "Only return enabled modes."
  (sera:filter #'enabled-p (modes buffer)))

(defmethod enabled-modes ((buffer buffer))
  "Unless a modable buffer, return NIL for modes."
  nil)

(define-class input-buffer (buffer)
  ((keyscheme
    keyscheme:cua
    :documentation "The keyscheme that will be used for all modes.")
   (current-keymaps-hook
    (make-instance 'hook-keymaps-buffer
                   :combination #'hooks:combine-composed-hook)
    :type hook-keymaps-buffer
    :documentation "Hook run as a return value of `current-keymaps'.")
   (conservative-word-move
    t
    :documentation "If non-nil, the cursor moves to the end
(resp. beginning) of the word when `move-forward-word'
(resp. `move-backward-word') is called.")
   (forward-input-events-p
    nil
    :documentation "When non-nil, keyboard events are
forwarded to the renderer when no binding is found.  Pointer
events (e.g. mouse events) are not affected by this, they are always
forwarded when no binding is found.")
   (last-event
    nil
    :type t
    :export nil
    ;; TODO: Store multiple events?  Maybe when implementing keyboard macros.
    :documentation "The last event received in the current buffer.")
   (lisp-url-callbacks
    (sera:dict)
    :type hash-table
    :export nil
    :documentation "The index of callbacks for `lisp://' URLs.
They are populated by the `nyxt/ps:lisp-eval' Parenscript macro.

It's part of `input-buffer' since any (even offline) buffer that can be clicked
on may want to have dynamic interactions."))
  (:export-class-name-p t)
  (:export-accessor-names-p t)
  (:export-predicate-name-p t)
  (:metaclass user-class)
  (:documentation "A buffer in which the user can input."))

(define-class document-buffer (buffer)
  ((document-model-delta-threshold
    10
    :documentation "The `document-model' is updated when the changed elements
exceed this amount."
    :export nil)
   (document-model
    nil
    :reader nil                         ; We use a custom reader.
    :writer t
    :export t
    :type (or null plump:node)
    :documentation "A parsed representation of the rendered buffer.
Computed by `plump:parse', see `update-document-model' for details.")
   (keep-search-marks-p
    t
    :type boolean
    :documentation "Whether to keep search marks after exiting the prompt
buffer.")
   (scroll-distance
    32
    :type integer
    :documentation "The distance in pixels for `scroll-down' or `scroll-up'.")
   (smooth-scrolling
    nil
    :documentation "Whether to scroll smoothly.")
   (horizontal-scroll-distance
    50
    :type integer
    :documentation "The distance in pixels for `scroll-left' or `scroll-right'.")
   (zoom-ratio
    nil
    :type (or null float)
    :reader t
    :export t
    :documentation "The current zoom ratio as per `ffi-buffer-zoom-ratio'.
It is an implementation detail and must not be set by the user. For the
user-facing slot, see `zoom-ratio-default'.")
   (zoom-ratio-step
    0.1
    :type float
    :documentation "The step size for zooming in and out.")
   (zoom-ratio-default
    1.0
    :type float
    :documentation "The default zoom ratio.")
   (page-scroll-ratio
    0.90
    :type float
    :documentation "The ratio of the page to scroll.
A value of 0.95 means that the bottom 5% will be the top 5% when scrolling
down."))
  (:export-class-name-p t)
  (:export-accessor-names-p t)
  (:export-predicate-name-p t)
  (:metaclass user-class)
  (:documentation "Buffers holding structured documents."))

(define-class context-buffer (buffer)
  ((download-directory
    (make-instance 'download-directory)
    :type download-directory
    :documentation "Directory where downloads will be stored.")
   (download-engine
    :initform :renderer
    :type symbol
    :documentation "Select a download engine to use, such as `:lisp' or
`:renderer'."))
  (:export-class-name-p t)
  (:export-accessor-names-p t)
  (:export-predicate-name-p t)
  (:metaclass user-class)
  (:documentation "A buffer that holds buffer-specific settings (see its slots).

Global settings should be stored in `browser' instead.

Conceptually, it's similar to \"private windows\" in popular browsers but the
scope is that of buffers."))

(defmethod print-object ((buffer buffer) stream)
  (print-unreadable-object (buffer stream :type t)
    (format stream "~a ~a" (id buffer) (url buffer))))

(defmethod (setf url) :around (value (buffer document-buffer))
  (declare (ignore value))
  (call-next-method)
  (set-window-title))
(defmethod (setf title) :around (value (buffer document-buffer))
  (declare (ignore value))
  (call-next-method)
  (set-window-title))

(export-always 'default-modes)
(defgeneric default-modes (buffer)
  (:method-combination append)
  ;; TODO: Add a warning method when passing NIL to guard the current buffer not
  ;; bound errors?
  (:method append ((buffer t))
    %default-modes)
  (:method append ((buffer buffer))
    (slot-value buffer 'default-modes))
  (:method :around ((buffer buffer))
    "Remove the duplicates from the `default-modes' and normalize them.
This allows setting modes as :DARK-MODE or 'EMACS-MODE in whatever package, and
Nsymbols will find the proper symbol, unless duplicate."
    (mapcar (alex:rcurry #'resolve-user-symbol :mode (list-all-packages))
            (remove-duplicates (call-next-method)
                               ;; Modes at the beginning of the list have higher
                               ;; priority.
                               :from-end t)))
  (:documentation "BUFFER's default modes. `append's all the methods applicable
to BUFFER to get the full list of modes."))

(define-class network-buffer (buffer)
  ((status
    :unloaded
    :type (member :loading :finished :unloaded :failed)
    :export nil
    :documentation "The status of the buffer.
- `:loading' when loading a web resource.
- `:finished' when done loading a web resource.
- `:unloaded' for buffers that have not been loaded yet, like
  session-restored buffers, dead buffers or new buffers that haven't started the
  loading process yet.")
   (buffer-load-hook
    (make-instance 'hook-url->url
                   :combination #'hooks:combine-composed-hook)
    :type hook-url->url
    :accessor nil
    :export nil
    :documentation "Hook run in `buffer-load' before loading.
The handlers take the URL going to be loaded as argument and must return a
(possibly new) URL.")
   (buffer-loaded-hook
    (make-instance 'hook-buffer)
    :type hook-buffer
    :documentation "Hook run on `on-signal-load-finished'.
The handlers take the buffer as argument.")
   (request-resource-keyscheme-map
    (define-keyscheme-map "request-resource" ()
      keyscheme:default
      (list
       "C-button1" 'request-resource-open-url
       "button2" 'request-resource-open-url
       "C-shift-button1" 'request-resource-open-url-focus
       "shift-button2" 'request-resource-open-url-focus))
    :documentation "Looked up when `request-resource-hook' handlers run.  The
keymap takes functions whose key arguments are `:url' and `:buffer'.")
   (request-resource-hook
    (make-instance 'hook-resource
                   :combination #'combine-composed-hook-until-nil)
    :type hook-resource
    :documentation "Hook run on every resource load.
The handlers are composed, passing a `request-data'
until one of them returns nil or all handlers apply successfully.

Newest hook is run first.
If a `request-data' object is returned, it gets passed to other handlers
or right to the renderer if there are no more handlers.
If nil is returned, stop the hook and cancel the resource load.

The current buffer URL should not be relied upon.  With WebKitGTK, it is the
same as (url REQUEST-DATA).  If you need to access the URL before this request,
inspect the document-mode history.

Example:

\(defmethod configure-instance ((buffer buffer))
  (reduce #'hooks:add-hook
          '(old-reddit-handler auto-proxy-handler)
          :initial-value (request-resource-hook buffer)))")
   (proxy
    nil
    :accessor nil
    :type (or proxy null)
    :documentation "Proxy for buffer.")
   (certificate-exceptions
    '()
    :type (list-of string)
    :documentation "A list of hostnames for ignoring certificate errors."))
  (:export-class-name-p t)
  (:export-accessor-names-p t)
  (:export-predicate-name-p t)
  (:metaclass user-class)
  (:documentation "Buffers that must interact with resources over the network."))

(define-class web-buffer
    (context-buffer network-buffer modable-buffer document-buffer input-buffer)
  ((keywords
    nil
    :reader nil
    :writer t
    :documentation "The keywords parsed from the current web buffer."))
  (:export-class-name-p t)
  (:export-accessor-names-p t)
  (:export-predicate-name-p t)
  (:metaclass user-class)
  (:documentation "Buffer for browsing the web."))

(defmethod customize-instance :after
    ((buffer buffer) &key (browser *browser*) no-hook-p
     &allow-other-keys)
  "Finalize buffer.
Return the created buffer."
  (unless (or no-hook-p (not browser))
    (hooks:run-hook (buffer-before-make-hook browser) buffer))
  buffer)

(defmethod customize-instance :after
    ((buffer modable-buffer)
     &key (browser *browser*) no-hook-p extra-modes
     &allow-other-keys)
  "Finalize instantiation of modable BUFFER.
In particular,
- Run `buffer-make-hook';
- `enable' the modes from the `modes' slot, `default-modes', and the
EXTRA-MODES
- Run `buffer-after-make-hook'."
  (unless no-hook-p
    (hooks:run-hook (buffer-make-hook browser) buffer))
  (mapc #'enable (modes buffer))
  (enable-modes* (append (reverse (default-modes buffer))
                         (uiop:ensure-list extra-modes))
                 buffer)
  (unless no-hook-p
    (hooks:run-hook (buffer-after-make-hook browser) buffer))
  buffer)

(defmethod customize-instance :after ((buffer context-buffer)
                                      &key &allow-other-keys)
  "Finalize buffer.
Return the created buffer."
  (buffer-set (id buffer) buffer)
  buffer)

(export-always 'update-document-model)
(defun update-document-model (&key (buffer (current-buffer)))
  "Update BUFFER's `document-model' as to include Nyxt identifiers."
  (ps-eval :buffer buffer
    (defvar nyxt-identifier-counter 0)
    (defun add-nyxt-identifiers (node)
      (unless (ps:chain node (has-attribute "nyxt-identifier"))
        (ps:chain node (set-attribute "nyxt-identifier"
                                      (ps:stringify nyxt-identifier-counter))))
      (incf nyxt-identifier-counter)
      (dolist
          (child
           (if (ps:chain node shadow-root)
               (ps:chain *array
                         (from (ps:@ node shadow-root children))
                         (concat (ps:chain *array (from (ps:@ node children)))))
                   (ps:chain node children)))
        (add-nyxt-identifiers child))
      (when (ps:@ node shadow-root)
        (ps:chain node (set-attribute "nyxt-shadow-root" "")))
      nyxt-identifier-counter)
    (setf nyxt-identifier-counter
          (add-nyxt-identifiers (ps:chain document body))))
  (when-let ((body-json (with-current-buffer buffer
                          (nyxt/dom::get-document-body-json))))
    (let ((dom (nyxt/dom::named-json-parse body-json)))
      (unless (uiop:emptyp (plump:text dom))
        (when (slot-boundp buffer 'keywords) (setf (keywords buffer) nil))
        (setf (document-model buffer) dom)))))

(defun dead-buffer-p (buffer)
  (not (buffer-get (id buffer))))

(defmethod document-model ((buffer buffer) &key use-cached-p)
  "A wraparound accessor to BUFFER's `document-model'.

In case the page changed more than `document-model-delta-threshold', runs
`update-document-model'."
  (if use-cached-p
      (slot-value buffer 'document-model)
      (ps-labels :buffer buffer
        ((%count-dom-elements
          ()
          (defvar dom-counter 0)
          (defun count-dom-elements (node)
            (incf dom-counter)
            (dolist (child (ps:chain node children))
              (count-dom-elements child))
            dom-counter)
          (setf dom-counter 0)
          (count-dom-elements (nyxt/ps:qs document "html"))))
        (if (dead-buffer-p buffer)
            (slot-value buffer 'document-model)
            (let ((value (slot-value buffer 'document-model))
                  (element-count (%count-dom-elements)))
              (if (and value
                       element-count
                       ;; Check the difference in element count.
                       (< (abs (- (length (clss:select "*" value))
                                  (truncate element-count)))
                          (document-model-delta-threshold buffer)))
                  value
                  (progn
                    (update-document-model :buffer buffer)
                    (slot-value buffer 'document-model))))))))

(defmethod proxy ((buffer buffer))
  (slot-value buffer 'proxy))

(defmethod (setf proxy) (proxy (buffer buffer))
  (setf (slot-value buffer 'proxy) proxy)
  (if proxy
      (setf (ffi-buffer-proxy buffer)
            (list (url proxy)
                  (allowlist proxy)))
      (setf (ffi-buffer-proxy buffer)
            (quri:uri ""))))

(defmethod keywords ((buffer web-buffer))
  "Return the terms that best describe the contents of BUFFER."
  (or (slot-value buffer 'keywords)
      (when-let ((document (document-model buffer)))
        (setf (slot-value buffer 'keywords)
              (analysis:extract-keywords
               (str:join " "
                         (map 'list #'plump:text
                              (clss:select "p" document))))))))

(define-class keyword-source (prompter:source)
  ((prompter:name "Keywords")
   (buffer
    (current-buffer)
    :type buffer)
   (prompter:enable-marks-p t)
   (prompter:constructor (lambda (source)
                           (mapcar #'first (nyxt::keywords (buffer source))))))
  (:export-class-name-p t)
  (:documentation "Source listing the keywords for source `buffer'."))

(-> proxy-url (buffer &key (:downloads-only boolean)) *)
(defun proxy-url (buffer &key (downloads-only nil))
  "Return the proxy address, nil if not set.
If DOWNLOADS-ONLY is non-nil, then it only returns the proxy address (if any)
when `proxied-downloads-p' is true."
  (let* ((proxy (and buffer (proxy buffer)))
         (proxied-downloads (and proxy (proxied-downloads-p proxy))))
    (when (or (and (not downloads-only) proxy)
              proxied-downloads)
      (url proxy))))

(defun load-failed-p (buffer)
  "Only `network-buffer' loads can fail."
  (and (network-buffer-p buffer)
       (eq (slot-value buffer 'status) :failed)))

(hooks:define-hook-type buffer (function (buffer))
  "Hook acting on `buffer's.")

(define-command make-buffer (&rest args &key (title "") modes
                             (url (if *browser*
                                      (default-new-buffer-url *browser*)
                                      (quri:uri (nyxt-url 'new))))
                             (load-url-p t) (buffer-class 'web-buffer)
                             &allow-other-keys)
  "Create a new buffer.
MODES is a list of mode symbols.
If URL is empty, the `default-new-buffer-url' browser slot is used instead.
To load nothing, set it to 'about:blank'.
LOAD-URL-P controls whether to load URL right at buffer creation."
  (let* ((url (url url))
         (buffer (apply #'make-instance
                        buffer-class
                        :title title
                        :extra-modes modes
                        (append (unless (url-empty-p url) (list :url url))
                                (uiop:remove-plist-keys '(:title :modes :url)
                                                        args)))))
    (when load-url-p
      (ffi-buffer-load buffer url))
    buffer))

(define-command make-buffer-focus (&key (url (default-new-buffer-url *browser*)))
  "Switch to a new buffer.
See `make-buffer'."
  (let ((buffer (make-buffer :url url)))
    (set-current-buffer buffer)
    buffer))

(-> add-to-recent-buffers (buffer) *)
(defun add-to-recent-buffers (buffer)
  "Push BUFFER to the front of `recent-buffers'.
The notion of first element is dictated by `containers:first-item'."
  (when (web-buffer-p buffer)
    (containers:delete-item (recent-buffers *browser*) buffer)
    (containers:insert-item (recent-buffers *browser*) buffer)))

(export-always 'buffer-list)
(defun buffer-list ()
  "Order is stable."
  (sort (alex:hash-table-values (buffers *browser*))
        #'>
        :key #'id))

(export-always 'internal-buffers)
(defun internal-buffer-list (&key (all nil))
  ;; Note that the `buffers' slot only keeps track of "main" buffers.
  (append (sera:filter #'internal-url-p (buffer-list))
          (when all
            (alex:flatten (loop for window in (window-list)
                                collect (active-prompt-buffers window)
                                collect (status-buffer window)
                                collect (message-buffer window))))))

(defun buffer-get (id)
  "Get the `buffer' with the corresponding ID."
  (or (gethash id (slot-value *browser* 'buffers))
      (find-if
       (lambda (prompt-buffer) (eql (id prompt-buffer) id))
       (mapcan
        #'active-prompt-buffers
        (alexandria:hash-table-values (windows *browser*))))))

(defun buffer-set (id buffer)
  "Ensure that entry ID->BUFFER belongs to `buffers' hash table."
  (when *browser*
    ;; Mutate state of the hash table.
    (setf (gethash id (slot-value *browser* 'buffers)) buffer)
    ;; Notify `buffers' of the new hash table state. Useful, for example, to
    ;; update the status buffer.
    (setf (buffers *browser*) (buffers *browser*))))

(defun buffer-delete (id)
  "Remove `buffers' hash table entry matching key ID.

This is a low-level function.  See `buffer-delete' and `delete-buffer'."
  ;; Mutate state of the hash table.
  (when *browser*
    (remhash id (slot-value *browser* 'buffers))
    ;; Notify `buffers' of the new hash table state. Useful, for example, to
    ;; update the status buffer.
    (setf (buffers *browser*) (buffers *browser*))))

(export-always 'window-list)
(defun window-list ()
  "Return a list of all the open `windows'."
  (when *browser*
    (alex:hash-table-values (windows *browser*))))

(defmethod window ((buffer buffer))
  "Get the window containing a buffer."
  (find buffer (alex:hash-table-values (windows *browser*))
        :key #'active-buffer))

(defun last-active-buffer ()
  "Return buffer with most recent `last-access'."
  (first (sort-by-time (buffer-list))))

(defmethod active-buffer-p ((buffer buffer))
  (find buffer (mapcar #'active-buffer (window-list))))

(defun get-inactive-buffer ()
  "Return inactive buffers sorted by `last-access', when applicable.
If none exist, make a new inactive buffer."
  (if-let ((inactive (set-difference (buffer-list)
                                     (mapcar #'active-buffer (window-list)))))
    (first (sort-by-time inactive))
    (make-buffer)))

(define-command copy-url ()
  "Save current URL to clipboard."
  (echo "~s copied to clipboard."
        (copy-to-clipboard (render-url (url (current-buffer))))))

(define-command copy-title ()
  "Save current page title to clipboard."
  (echo "~a copied to clipboard."
        (copy-to-clipboard (title (current-buffer)))))

(define-class buffer-source (prompter:source)
  ((prompter:name "Buffer list")
   (prompter:constructor (append (list (active-buffer (current-window)))
                                 (remove (active-buffer (current-window))
                                         (buffer-list))))
   (prompter:filter-preprocessor #'prompter:filter-exact-matches)
   (prompter:enable-marks-p t)
   (prompter:actions-on-return (list (lambda-unmapped-command set-current-buffer)
                                     (lambda-mapped-command ffi-buffer-delete)
                                     'reload-buffers))
   (prompter:actions-on-current-suggestion-enabled-p t)
   (prompter:actions-on-current-suggestion
    (lambda-command set-current-buffer* (buffer)
      "Set current BUFFER for the active window."
      (set-current-buffer buffer :focus nil)))
   (prompter:destructor (let ((buffer (current-buffer)))
                          (lambda (prompter source)
                            (declare (ignore source))
                            (unless (or (prompter:returned-p prompter)
                                        (eq buffer (current-buffer)))
                              (set-current-buffer buffer)))))
   (prompter:active-attributes-keys
    '("Title" "URL" "Keywords")
    :accessor nil))
  (:export-class-name-p t)
  (:metaclass user-class)
  (:documentation "Source for choosing one (or several) of the open buffers.

The `prompter:actions-on-current-suggestion' are set up to preview/switch to the
buffer currently chosen as suggestion."))

(defmethod prompter:object-attributes ((buffer buffer) (source prompter:source))
  (declare (ignore source))
  `(("Title" ,(title buffer) (:width 3))
    ("URL" ,(render-url (url buffer)) (:width 2))
    ,(when (web-buffer-p buffer)
       `("Keywords" ,(format nil "~:{~a~^ ~}" (keywords buffer)) (:width 2)))
    ("ID" ,(id buffer) (:width 1))))

(define-command switch-buffer ()
  "Switch buffer using fuzzy completion."
  (prompt
   :prompt "Switch to buffer"
   :sources (make-instance 'buffer-source)))

(define-command switch-buffer-domain (&key domain (buffer (current-buffer)))
  "Switch to buffer sharing the same domain as the current one."
  (let ((domain (or domain (quri:uri-domain (url buffer)))))
    (prompt
     :prompt "Switch to buffer in current domain"
     :sources (make-instance 'buffer-source
                             :constructor
                             (sera:filter (match-domain domain)
                                          (sort-by-time (buffer-list)))))))

(define-command toggle-prompt-buffer-focus ()
  "Toggle the focus between the current buffer and the current prompt buffer."
  (let ((prompt-buffer (current-prompt-buffer)))
    (if (ffi-focused-p prompt-buffer)
        (prog1 (ffi-focus-buffer (current-buffer))
          (ps-eval :buffer prompt-buffer
            (setf (ps:@ (nyxt/ps:qs document "*") style opacity) "0.5")))
        (prog1 (ffi-focus-buffer prompt-buffer)
          (ps-eval :buffer prompt-buffer
            (setf (ps:@ (nyxt/ps:qs document "*") style opacity) "1"))))))


(flet ((delete-all (buffers &optional predicate)
         (mapcar #'ffi-buffer-delete
                 (sera:filter (or predicate #'identity) buffers))))
  (define-command delete-buffer
      (&key
       (buffers
        (prompt
         :prompt "Delete buffer(s)"
         :sources (make-instance
                   'buffer-source
                   :enable-marks-p t
                   :actions-on-return
                   (list
                    (lambda-mapped-command ffi-buffer-delete)
                    (lambda-command buffer-delete-duplicates* (buffers)
                      "Delete all buffers with same URLs, except selected."
                      (delete-all
                       (set-difference (buffer-list) buffers)
                       (lambda (buffer)
                         (member (url buffer) buffers
                                 :key #'url :test #'quri:uri-equal))))
                    (lambda-command buffer-delete-same-host* (buffers)
                      "Delete all the buffers with the same website open."
                      (delete-all
                       (buffer-list)
                       (lambda (buffer)
                         (member (quri:uri-host (url buffer))
                                 (mapcar #'url buffers)
                                 :key #'quri:uri-host
                                 :test #'string-equal))))
                    (lambda-command buffer-delete-same-url* (buffers)
                      "Delete all the buffers with the same page open."
                      (delete-all
                       (buffer-list)
                       (lambda (buffer)
                         (member (url buffer) buffers
                                 :key #'url :test #'quri:uri-equal)))))))
        buffers-supplied-p))
    "Query the buffer(s) to delete.

BUFFERS should be a list of `buffer's."
    (when buffers-supplied-p
      (delete-all (uiop:ensure-list buffers)))))

(define-command delete-all-buffers ()
  "Delete all buffers, with confirmation."
  (if-confirm ((format nil "Delete ~a buffer(s)?" (length (buffer-list))))
      (mapcar #'ffi-buffer-delete (buffer-list))))

(define-command delete-current-buffer ()
  "Delete the current buffer and switch to the last visited one.
If no other buffers exist, load the start page."
  (ffi-buffer-delete (current-buffer)))

(define-command delete-other-buffers (&optional (buffer (current-buffer)))
  "Delete all buffers except BUFFER.
When BUFFER is omitted, it defaults to the current one."
  (let ((buffers-to-delete (remove buffer (buffer-list))))
    (if-confirm ((format nil "Delete ~a buffer(s)?" (length buffers-to-delete)))
        (mapcar #'ffi-buffer-delete buffers-to-delete))))

;; Useful to be used by prompt buffer actions, since they take a list as
;; argument.
(export-always 'buffer-load*)
(defun buffer-load* (url-list)
  "Load first element of URL-LIST in current buffer and the rest in new buffers."
  (mapc (lambda (url) (make-buffer :url (url url))) (rest url-list))
  (ffi-buffer-load (current-buffer) (url (first url-list))))

(define-class global-history-source (prompter:source)
  ((prompter:name "Global history")
   (prompter:constructor (recent-history-entries 200 *browser* :deduplicate-p t))
   (prompter:enable-marks-p t)
   (prompter:filter-preprocessor #'prompter:filter-exact-matches)
   (prompter:actions-on-return #'buffer-load*))
  (:export-class-name-p t)
  (:metaclass user-class)
  (:documentation "Source listing all the entries in history.
Loads the entry with default `prompter:actions-on-return'."))

(define-class url-or-query ()
  ((data
    ""
    :type string
    :documentation "A string to be resolved to a URL via `url'.")
   (kind
    :initarg nil
    :type (maybe keyword)
    :documentation "A keyword that classifies `data' based on its content.
One of `:url' or `:search-query'.")
   (search-engine
    :type (maybe search-engine)
    :documentation "Applicable when `kind' is `:search-query'.")
   (search-query
    :initarg nil
    :type (maybe string)
    :documentation "Applicable when `kind' is `:search-query'."))
  (:export-class-name-p t)
  (:export-accessor-names-p t)
  (:documentation "Helper structure that resolves user input to a URL.

Determine whether a valid https URL, local file or a search engine query is
requested.  When the first word of `data' matches the `shortcut' of a
`search-engine', then it is interpreted as a search engine query."))

(defmethod print-object ((query url-or-query) stream)
  (print-unreadable-object (query stream :type t)
    (format stream "~a" (data query))))

(defmethod initialize-instance :after ((query url-or-query)
                                       &key &allow-other-keys)
  (with-slots (data kind search-engine search-query) query
    (setf data (str:trim data))
    (cond ((str:blankp data) t)
          ((valid-url-p data :check-tld-p nil) (setf kind :url))
          ((ignore-errors (valid-url-p (str:concat "https://" data)
                                       :check-tld-p t))
           (setf kind :url
                 data (str:concat "https://" data)))
          ((uiop:file-exists-p data)
           (setf kind :url
                 data (str:concat "file://" (uiop:native-namestring data))))
          (t
           (let* ((terms (sera:tokens data))
                  (explicit-engine
                    (find (first terms) (search-engines *browser*)
                          :key #'shortcut :test #'string-equal))
                  (engine (or explicit-engine
                              (default-search-engine *browser*))))
             (setf kind :search-query
                   search-engine engine)
             (if explicit-engine
                 (setf search-query (str:join " " (rest terms)))
                 (setf search-query data
                       data (format-query data engine))))))))

(export-always 'search-suggestions)
(defmethod search-suggestions ((query url-or-query))
  (with-slots (search-engine search-query) query
    (when search-engine
      (let ((suggestions (suggestions search-query search-engine)))
        (mapcar (lambda (suggestion)
                  (make-instance 'url-or-query
                                 :data (format-query suggestion search-engine)))
                ;; Ensure that search-query is the first suggestion.
                (if (string-equal search-query (first suggestions))
                    suggestions
                    (append (list search-query) suggestions)))))))

(defmethod url ((query url-or-query))
  (with-slots (data kind search-engine search-query) query
    (quri:uri (if (eq :search-query kind)
                  (format-url search-query search-engine)
                  data))))

(define-class url-or-query-source (prompter:source)
  ((prompter:name "URL or search query")
   (prompter:filter-preprocessor
    (lambda (suggestions source input)
      (declare (ignore suggestions source))
      (list (make-instance 'url-or-query :data input))))
   (prompter:filter-postprocessor
    (lambda (prompt-suggestions source input)
      (declare (ignore source input))
      (sleep 0.15) ; Delay search suggestions while typing.
      (if-let ((_ (search-engine-suggestions-p *browser*))
               (completion (search-suggestions
                            (prompter:value (first prompt-suggestions)))))
        completion
        prompt-suggestions)))
   (prompter:filter nil)
   (prompter:actions-on-return #'buffer-load*))
  (:export-class-name-p t)
  (:metaclass user-class)
  (:documentation "Source listing URL queries from user input in a DWIM fashion.
See `url-or-query'."))

(defmethod prompter:object-attributes ((query url-or-query)
                                       (source url-or-query-source))
  (declare (ignore source))
  (with-slots (data kind search-engine search-query) query
    `(("Input" ,(or search-query data) (:width 5))
      ("Type" ,(cond ((null kind) "")
                     ((eq kind :search-query) (name search-engine))
                     (t kind))
              (:width 2)))))

(export-always 'url-sources)
(defmethod url-sources ((buffer buffer) actions-on-return)
  "Return list of `set-url' sources.
The returned sources should have `url' or `prompter:actions-on-return' methods
specified for their contents."
  (let ((actions-on-return (uiop:ensure-list actions-on-return)))
    (append
     (list (make-instance 'url-or-query-source
                          :actions-on-return actions-on-return)
           (make-instance 'global-history-source
                          :actions-on-return actions-on-return))
     (mappend (rcurry #'url-sources (uiop:ensure-list actions-on-return))
              (enabled-modes buffer)))))

(define-command set-url (&key (default-action #'buffer-load*))
  "Set the URL for the current buffer, completing with history."
  (let* ((history (set-url-history *browser*))
         (actions-on-return
           (list #'buffer-load*
                 (lambda-command copy-url* (suggestions)
                   "Copy the URL of the chosen suggestion."
                   (trivial-clipboard:text
                    (render-url (url (first suggestions))))))))
    (pushnew default-action actions-on-return)
    (prompt :prompt "Open URL"
            :input (render-url (url (current-buffer)))
            :history history
            :sources (url-sources (current-buffer) actions-on-return))
    (current-buffer)))

(define-command set-url-new-buffer ()
  (set-url :default-action
           (lambda-command new-buffer-load* (suggestion-values)
             "Load URL(s) in new buffer(s)."
             (mapc (lambda (suggestion) (make-buffer :url (url suggestion)))
                   (rest suggestion-values))
             (make-buffer-focus :url (url (first suggestion-values))))))

(define-command reload-current-buffer ()
  "Reload current buffer.
Return it."
  (ffi-buffer-reload (current-buffer)))

(define-command reload-buffers
    (&optional (buffers
                (prompt
                 :prompt "Reload buffer(s)"
                 :sources (make-instance 'buffer-source :enable-marks-p t))))
  "Prompt for BUFFERS to be reloaded.
Return BUFFERS."
  (mapcar #'ffi-buffer-reload (alex:ensure-list buffers))
  buffers)

(define-command switch-buffer-previous (&key (offset 1) (buffer (current-buffer)))
  "Switch to the previous buffer."
  (let ((buffer-list (buffer-list)))
    (set-current-buffer (nth (mod (+ offset (position buffer buffer-list))
                                  (length buffer-list))
                             buffer-list))))

(define-command switch-buffer-next
    (&key (offset 1) (buffer (current-buffer)))
  "Switch to the next buffer."
  (switch-buffer-previous :offset (- offset) :buffer buffer))

(define-command switch-buffer-last ()
  "Switch to the last visited buffer.

The buffer with the most recent access time is returned."
  (when-let ((buffer (second (sort-by-time (buffer-list)))))
    (set-current-buffer buffer)))

(define-command open-inspector ()
  "Open the inspector, a graphical tool to inspect the buffer."
  (ffi-inspector-show (current-buffer))
  (current-buffer))
