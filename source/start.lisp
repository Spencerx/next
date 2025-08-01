;;;; SPDX-FileCopyrightText: Atlas Engineer LLC
;;;; SPDX-License-Identifier: BSD-3-Clause

(in-package :nyxt)

(define-class socket-file (files:runtime-file nyxt-file)
  ((files:base-path #p"nyxt.socket")
   (editable-p nil))
  (:export-class-name-p t)
  (:export-accessor-names-p t)
  (:documentation "Socket files are typically stored in a dedicated directory."))

(defmethod files:resolve ((profile nyxt-profile) (socket socket-file))
  "Return finalized path for socket files."
  (uiop:ensure-pathname (or (getf *options* :socket) (call-next-method))
                        :truenamize t))

(export-always '*socket-file*)
(defvar *socket-file* (make-instance 'socket-file)
  "Path of the Unix socket used to communicate between different instances of
Nyxt.

This path cannot be set from the configuration file because we want to be able
to set and use the socket without parsing any file.  Instead, the socket can be
set from the corresponding command line option.")

(defun handle-malformed-cli-arg (condition)
  (format t "Error parsing argument ~a: ~a.~&" (opts:option condition) condition)
  (opts:describe)
  (uiop:quit 0 #+bsd nil))

(eval-always
  (defun define-opts ()
    "Define command line options.
This must be called on startup so that code is executed in the user environment
and not the build environment."
    (opts:define-opts
      (:name :help
       :description "Print this help and exit."
       :short #\h
       :long "help")
      (:name :verbose
       :short #\v
       :long "verbose"
       :description "Print debugging information to stdout.")
      (:name :version
       :long "version"
       :description "Print version and exit.")
      (:name :system-information
       :long "system-information"
       :description "Print system information and exit.")
      (:name :config
       :short #\i
       :long "config"
       :arg-parser #'identity
       :description (format nil "Set path to configuration file.
Default: ~s" (files:expand *config-file*)))
      (:name :no-config
       :short #\I
       :long "no-config"
       :description "Do not load the configuration file.")
      (:name :auto-config
       :short #\c
       :long "auto-config"
       :arg-parser #'identity
       :description (format nil "Set path to auto-configuration file.
Default: ~s" (files:expand *auto-config-file*)))
      (:name :no-auto-config
       :short #\C
       :long "no-auto-config"
       :description "Do not load the user auto-configuration file.")
      (:name :socket
       :short #\s
       :long "socket"
       :arg-parser #'identity
       :description "Set path to socket.
Unless evaluating remotely (see --remote).")
      (:name :eval
       :short #\e
       :long "eval"
       :arg-parser #'identity
       :description "Eval the Lisp expressions.  Can be specified multiple times.
Without --quit or --remote, the evaluation is done after parsing the config file
(if any) and before initializing the browser.")
      (:name :load
       :short #\l
       :long "load"
       :arg-parser #'identity
       :description "Load the Lisp file.  Can be specified multiple times.
Without --quit or --remote, the loading is done after parsing the config file
(if any) and before initializing the browser.")
      (:name :quit
       :short #\q
       :long "quit"
       :description "Quit after --load or --eval.")
      (:name :remote
       :short #\r
       :long "remote"
       :description
       "Send the --eval and --load arguments to the running instance of Nyxt.
Unless --quit is specified, also send s-expressions from the standard input.
The remote instance must be listening on a socket which you can specify with
--socket and have the `remote-execution-p' browser slot to non-nil.")
      (:name :headless
       :long "headless"
       :description "Start Nyxt without showing any graphical element.
This is useful to run scripts for instance.")
      (:name :electron-opts
       :long "electron-opts"
       :arg-parser #'identity
       :description "Command-line options to pass to Electron"))))
;; Also define command line options at read-time because we parse
;; `opts::*options*' in `start'.
(eval-always (define-opts))

(define-command quit (&optional (code 0))
  "Quit Nyxt."
  (let ((*quitting-nyxt-p* t))
    (when (slot-value *browser* 'ready-p)
      (hooks:run-hook (before-exit-hook *browser*))
      ;; Unready browser:
      ;; - after the hook, so that on hook error the browser is still ready;
      ;; - before the rest, so to avoid nested `quit' calls.
      (setf (slot-value *browser* 'ready-p) nil)
      (setf (slot-value *browser* 'exit-code) code)
      (mapcar #'ffi-window-delete (window-list))
      (when (socket-thread *browser*)
        (destroy-thread* (socket-thread *browser*))
        ;; Warning: Don't attempt to remove socket-path if socket-thread was not
        ;; running or we risk removing an unrelated file.
        (let ((socket (files:expand *socket-file*)))
          (when (uiop:file-exists-p socket)
            (log:info "Deleting socket ~s." socket)
            (uiop:delete-file-if-exists socket))))
      (ffi-kill-browser *browser*)
      ;; Reset global state.
      (setf *browser* nil
            *options* nil)
      (uninstall *renderer*)
      ;; Destroy all kernel threads.
      (lparallel.kernel:end-kernel))))

(cffi:defcallback handle-interrupt
    :void ((signum :int) (siginfo :pointer) (ptr :pointer))
  (declare (ignore signum siginfo ptr))
  (quit))

(export-always 'entry-point)
(defun entry-point ()
  "Read the CLI arguments and start the browser.
This is the entry point of the binary program.
Don't run this from a REPL, prefer `start' instead."
  (define-opts)
  (multiple-value-bind (options free-args)
      (handler-bind ((opts:unknown-option #'handle-malformed-cli-arg)
                     (opts:missing-arg #'handle-malformed-cli-arg)
                     (opts:arg-parser-failed #'handle-malformed-cli-arg))
        (opts:get-opts))
    (setf *run-from-repl-p* nil)
    (apply #'start (append options (list :urls free-args)))))

(defun eval-expr (expr)
  "Evaluate the form EXPR (string) and print the result of the last expression."
  (with-input-from-string (input expr)
    (let ((*package* (find-package :nyxt-user)))
      (flet ((eval-protect (s-exp)
               (with-protect ("Error in s-exp evaluation: ~a" :condition)
                 (eval s-exp))))
        (let* ((sexps (safe-slurp-stream-forms input))
               (but-last (butlast sexps))
               (last (alex:last-elt sexps)))
          (mapc #'eval-protect but-last)
          (format t "~&~a~&" (eval-protect last)))))))

(defun parse-urls (expr)
  "Do _not_ evaluate EXPR and try to parse URLs that were sent to it.
EXPR is expected to be as per the expression sent in `listen-or-query-socket'."
  (let* ((urls (ignore-errors (rest (read-from-string expr nil))))
         (urls (ignore-errors (remove-if #'url-empty-p (mapcar #'url urls)))))
    (unless urls
      (log:warn "Could not extract URLs from ~s." expr))
    urls))

(defun listen-socket ()
  "Listen to to see if requests arise to open URLs or evaluate s-expressions."
  (files:with-paths ((socket-path *socket-file*))
    (let ((native-socket-path (uiop:native-namestring socket-path)))
      (ensure-directories-exist socket-path :mode #o700)
      (iolib:with-open-socket (s :address-family :local
                                 :connect :passive
                                 :local-filename native-socket-path)
        (isys:chmod native-socket-path #o600)
        (log:info "Listening to socket: ~s" socket-path)
        (loop as connection = (iolib:accept-connection s)
              while connection
              do (when-let
                     ((expr (alex:read-stream-content-into-string connection)))
                   (unless (uiop:emptyp expr)
                     (cond ((remote-execution-p *browser*)
                            (log:info "External evaluation request: ~s" expr)
                            (eval-expr expr))
                           ((parse-urls expr)
                            (ffi-within-renderer-thread
                             (lambda () (open-urls (parse-urls expr))))
                            (when (current-window)
                                (ffi-window-to-foreground
                                 (current-window))))
                           (t (make-window))))))))))

(defun listening-socket-p ()
  (ignore-errors
   (iolib:with-open-socket (s :address-family :local
                              :remote-filename (uiop:native-namestring
                                                (files:expand *socket-file*)))
     (iolib:socket-connected-p s))))

(-> listen-or-query-socket ((or null (cons quri:uri *))) *)
(defun listen-or-query-socket (urls)
  "If another Nyxt is listening on the socket, tell it to open URLS.
Otherwise bind socket and return the listening thread."
  (let ((socket-path (files:expand *socket-file*)))
    (if (listening-socket-p) ;; Check if Nyxt is already running.
        (iolib:with-open-socket
            (s :address-family :local
               :remote-filename (uiop:native-namestring socket-path))
          (if urls
            (progn
              (log:info "Nyxt started, trying to open URL(s): ~{~a~^, ~}" urls)
              (format s "~s" `(open-urls ,@(mapcar #'quri:render-uri urls))))
            (progn
              (log:info "Nyxt started, opening new window.")
              (format s "~s" `(make-window)))))
        (progn
          (uiop:delete-file-if-exists socket-path)
          (run-thread "socket listener"
            (listen-socket))))))

(defun remote-eval (expr)
  "If another Nyxt is listening on the socket, tell it to evaluate EXPR."
  (if (listening-socket-p)
      (iolib:with-open-socket (s :address-family :local
                                 :remote-filename (uiop:native-namestring
                                                   (files:expand *socket-file*)))
        (write-string expr s))
      (progn
        (log:info "No instance running.")
        (uiop:quit 0 #+bsd nil))))

(eval-always
  (defvar %start-args
    (mapcar (compose #'intern #'symbol-name #'opts::name) opts::*options*)))

(export-always 'start)
(defun start #.(append '(&rest options &key urls) %start-args)
  #.(format nil "Parse command line or REPL options then start the browser.
Load URLS if any (a list of strings).

This function focuses on OPTIONS parsing.  For the actual startup procedure, see
`start-browser'.

The OPTIONS are the same as the command line options.

~a" (with-output-to-string (s) (opts:describe :stream s)))
  (declare #.(cons 'ignorable %start-args))
  ;; Nyxt extensions should be made accessible straight from the beginning,
  ;; e.g. before a script is run.
  (pushnew 'nyxt-source-registry asdf:*default-source-registries*)
  (asdf:clear-configuration)
  (let ((source-directory (files:expand *source-directory*)))
    (if (uiop:directory-exists-p source-directory)
        (set-nyxt-source-location source-directory)
        (log:debug "Nyxt source directory not found.")))
  ;; Initialize the lparallel kernel.
  (initialize-lparallel-kernel)
  ;; Options should be accessible anytime, even when run from the REPL.
  (setf *options* options)
  (destructuring-bind (&key (headless *headless-p*) verbose help version
                         system-information load eval quit remote
                       &allow-other-keys)
      options
    (setf *headless-p* headless)
    (if verbose
        (progn
          (log:config :debug)
          (format t "Arguments parsed: ~a and ~a~&" options urls))
        (log:config :pattern *log-pattern*))
    (cond
      (help
       (opts:describe :prefix "nyxt [options] [URLs]"))
      (version
       (format t "Nyxt version ~a~&" +version+))
      (system-information
       (princ (system-information)))
      ((or remote (and (or load eval) quit))
       (start-load-or-eval))
      (t
       (with-protect ("Error: ~a" :condition)
         (start-browser urls))))
    (unless *run-from-repl-p* (uiop:quit 0 #+bsd nil))))

(defun load-or-eval (&key remote)
  (when remote
    (log:info "Probing remote instance listening to ~a."
              (files:expand *socket-file*)))
  (loop for (opt value . nil) on *options*
        do (match opt
             (:load (let ((value (uiop:truename* value)))
                      (if remote
                          (remote-eval (format nil "~s" `(load-lisp ,value)))
                          (load-lisp value))))
             (:eval (if remote
                        (remote-eval value)
                        (eval-expr value)))))
  (when (and remote (not (getf *options* :quit)))
    (log:info "Reading s-expressions from standard input (end with Ctrl+d).")
    (handler-case (loop for sexp = (read)
                        do (remote-eval (write-to-string sexp)))
      (end-of-file ()
        (log:info "Quitting interpreter."))))
  (when remote
    (uiop:quit 0 #+bsd nil)))

(defun start-load-or-eval ()
  "Evaluate Lisp.
The evaluation may happen on its own instance or on an already running instance."
  (let ((remote (getf *options* :remote)))
    (unless remote
      (let ((user-package (find-package :nyxt-user)))
        (load-lisp (files:expand *auto-config-file*) :package user-package)
        (load-lisp (files:expand *config-file*) :package user-package)))
    (load-or-eval :remote remote)))

(defun start-browser (url-strings)
  "Start Nyxt.
First load `*auto-config-file*' if any.
Then load `*config-file*' if any.
Instantiate `*browser*'.
Finally, run the browser, load URL-STRINGS if any, then run
`after-init-hook'."
  (restart-case
      (progn
        (when *browser*
          (error 'browser-already-started
                 :message "Another global browser instance is already running."))
        (let ((log-path (files:expand *log-file*)))
          (unless (files:nil-pathname-p log-path)
            (uiop:delete-file-if-exists log-path) ; Otherwise `log4cl' appends.
            (log:config :backup nil :pattern *log-pattern* :daily log-path)))
        (format t "Nyxt version ~a~&" +version+)
        (log:info "Source location: ~s" (files:expand *source-directory*))
        (install *renderer*)
        (let* ((urls (remove-if #'url-empty-p (mapcar #'url url-strings)))
               (startup-timestamp (time:now))
               (startup-error-reporter nil))
          (if (or (null (files:expand *socket-file*))
                  (not (listening-socket-p)))
              (progn
                (load-lisp (files:expand *auto-config-file*)
                           :package (find-package :nyxt-user))
                (multiple-value-bind (condition backtrace)
                    (load-lisp (files:expand *config-file*)
                               :package (find-package :nyxt-user))
                  (when backtrace
                    (setf startup-error-reporter
                          (lambda ()
                            (echo-warning "~a" condition)
                            (error-in-new-window "Configuration file errors"
                                                 (princ-to-string condition)
                                                 backtrace)))))
                (load-or-eval :remote nil)
                (setf *browser*
                      (make-instance
                       'browser
                       :startup-error-reporter-function startup-error-reporter
                       :startup-timestamp startup-timestamp
                       :socket-thread
                       (unless
                           (nfiles:nil-pathname-p (files:expand *socket-file*))
                         (listen-or-query-socket urls))))
                ;; This must be done in a separate thread because the calling
                ;; thread may have set `*package*' as an initial-binding (see
                ;; `bt:make-thread'), as is the case with the SLY mrepl thread.
                (bt:make-thread (lambda () (in-package :nyxt-user)))
                (ffi-initialize *browser* urls startup-timestamp)
                (lpara:force (slot-value *browser* 'startup-promise)))
              (listen-or-query-socket urls))))
    (quit ()
      :report "Run `nyxt:quit' and try again."
      (quit)
      (start-browser url-strings))
    (force-quit ()
      :report "Run `nyxt:quit' and set `*browser*' to NIL in any case."
      (ignore-errors (quit))
      (setf *browser* nil)
      (start-browser url-strings))))

(defun restart-with-message (&key condition backtrace)
  (flet ((set-error-message (condition backtrace)
           (let ((*package* (find-package :cl)))
             (write-to-string
              `(hooks:add-hook
                (nyxt:after-init-hook nyxt:*browser*)
                (make-instance
                 'hooks:handler
                 :fn (lambda ()
                       (setf (nyxt::startup-error-reporter-function *browser*)
                             (lambda ()
                               (nyxt:echo-warning
                                "Restarted due to configuration error: ~a"
                                ,(princ-to-string condition))
                               (nyxt::error-in-new-window
                                "Initialization error"
                                ,(princ-to-string condition)
                                ,backtrace))))
                 :name 'error-reporter))))))
    (log:warn "Restarting with ~s."
              (append (uiop:raw-command-line-arguments) '("--no-config"
                                                          "--no-auto-config")))
    (uiop:launch-program (append (uiop:raw-command-line-arguments)
                                 `("--no-config"
                                   "--no-auto-config"
                                   "--eval"
                                   ,(set-error-message condition backtrace))))
    (quit 1)))

(define-command nyxt-init-time ()
  "Return the duration of Nyxt initialization."
  (echo "~,2f seconds" (slot-value *browser* 'init-time)))
