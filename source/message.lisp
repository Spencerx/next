;;;; SPDX-FileCopyrightText: Atlas Engineer LLC
;;;; SPDX-License-Identifier: BSD-3-Clause

(in-package :nyxt)

(define-class message-buffer (input-buffer)
  ((window
    nil
    :type (maybe window)
    :documentation "The `window' to which the message buffer is attached.")
   (height
    16
    :type integer
    :writer nil
    :reader height
    :export t
    :documentation "The height of the message buffer in pixels.")
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
      '(:font-face :font-family "dejavu sans mono" :src
        "url('nyxt-resource:DejaVuSansMono.ttf')" "format('ttf')")
      `(body
        :background-color ,theme:background-color-
        :color ,theme:on-background-color
        :font-family ,theme:font-family
        :font-size "75vh"
        :line-height "100vh"
        :padding 0
        :padding-left "4px"
        :margin 0))))
  (:export-class-name-p t)
  (:export-accessor-names-p t)
  (:export-predicate-name-p t)
  (:metaclass user-class))

(defmethod initialize-instance :after ((message-buffer message-buffer)
                                       &key &allow-other-keys)
  (ffi-print-message message-buffer "Ready."))

(defmethod (setf height) (value (message-buffer message-buffer))
  (setf (ffi-height message-buffer) value)
  (setf (slot-value message-buffer 'height) value))

(defclass messages-appender (log4cl-impl:appender) ())

(defmethod log4cl-impl:appender-do-append ((appender messages-appender)
                                           logger level log-func)
  (when (<= level (if (getf *options* :verbose)
                      log4cl:+log-level-warn+
                      log4cl:+log-level-error+))
    (uiop:print-backtrace))
  (when *browser*
    (push
     ;; TODO: Include time in *Messages* entries.
     ;; (make-instance 'log4cl:pattern-layout :conversion-pattern "<%p>
     ;; [%D{%H:%M:%S}] %m%n" )
     (with-output-to-string (s)
       (log4cl-impl:layout-to-stream
        (slot-value appender 'log4cl-impl:layout) s logger level log-func))
     (slot-value *browser* 'messages-content))))

(defmacro %echo (text &key (logger 'log:info))
  "Echo TEXT in the message buffer.
LOGGER is the log4cl logger to user, for instance `log:warn'."
  (alex:with-gensyms (expanded-text)
    `(progn
       (let ((,expanded-text ,text))
         (unless (str:emptyp ,expanded-text)
           (,logger "~a" ,expanded-text))
         ;; Allow empty strings to clear message buffer.
         (print-message ,expanded-text)))))

(export-always 'echo)
(defun echo (&rest args)
  "Echo ARGS in the message view.
The first argument can be a format string and the following arguments will be
interpreted by `format'.
Untrusted content should be given as argument with a format string."
  (handler-case
      (let ((text (apply #'format nil args)))
        (%echo text))
    (error (c)
      (log:warn "Warning while echoing: ~a" c))))

(export-always 'echo-warning)
(defun echo-warning (&rest args)
  "Like `echo' but prefix with \"Warning\" and output to the standard error."
  (handler-case
      (let ((text (apply #'format nil args)))
        (%echo (format nil "Warning: ~a" text)
               :logger log:warn))
    (error (c)
      (log:warn "Warning while echoing: ~a" c))))

(export-always 'echo-dismiss)
(defmethod echo-dismiss ()
  "Clean the message buffer from the previous `echo'/`echo-warning' message."
  (%echo ""))
