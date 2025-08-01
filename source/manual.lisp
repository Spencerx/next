;;;; SPDX-FileCopyrightText: Atlas Engineer LLC
;;;; SPDX-License-Identifier: BSD-3-Clause

(in-package :nyxt)

(defun manual-html ()
  (spinneret:with-html-string
    (:ntoc
      (tutorial-content)
      (manual-content))))

(defun manual-content ()
  (spinneret:with-html
    (let ((auto-config-file (namestring (files:expand *auto-config-file*)))
          (config-file (namestring (files:expand *config-file*)))
          (gtk-extensions-directory (namestring (uiop:merge-pathnames* "nyxt/" nasdf:*libdir*))))
      (:nsection :title "Configuration"
        (:p "Nyxt is written in the Common Lisp programming language which offers a
great perk: everything in the browser can be customized by the user, even while
it's running!")
        (:p "To get started with Common Lisp, we recommend checking out
    our web page: "
            (:a :href "https://nyxt-browser.com/learn-lisp" "Learn Lisp")
            ". It contains numerous pointers to other resources, including
        free books both for beginners and seasoned programmers.")
        (unless (str:empty? auto-config-file)
          (:p "Settings created by Nyxt are stored in " (:code auto-config-file) "."))
        (unless (str:empty? config-file)
          (:p "Any settings can be overridden manually by " (:code config-file) "."))
        (:p "The following section assumes knowledge of basic Common Lisp or a
similar programming language.")
        (:p "The user needs to manually create the Nyxt configuration file, and the parent folders if necessary."
            (when (and (current-buffer) ; In case manual is dumped.
                       (not (files:nil-pathname-p config-file))
                       (not (uiop:file-exists-p config-file)))
              (:p "You can also press the button below to create it."
                  (:p (:a :class "button"
                          :onclick (ps:ps
                                     (nyxt/ps:lisp-eval
                                      (:title "create-config-file")
                                      (ensure-directories-exist config-file)
                                      (files:ensure-file-exists config-file)
                                      (echo "Configuration file created at ~s." config-file)))
                          "Create configuration file")))))
        (:p "Example:")
        (:ncode
          '(define-configuration web-buffer
            ((default-modes (pushnew 'nyxt/mode/no-sound:no-sound-mode %slot-value%)))))
        (:p "The above turns on the 'no-sound-mode' (disables sound) by default for
every buffer.")
        (:p "The " (:nxref :macro 'define-configuration) " macro can be used to customize
the slots of classes like the browser, buffers, windows, etc.")
        (:p "To find out about all modes known to Nyxt,
run " (:nxref :command 'describe-command) " and type 'mode'."))

      (:nsection :title "Different types of buffers"
        (:p "There are multiple buffer classes, such as "
            (:nxref :class-name 'document-buffer) " (for structured documents) and "
            (:nxref :class-name 'input-buffer) " (for buffers that can receive user input).  A "
            (:nxref :class-name 'web-buffer) " class is used for web pages, " (:nxref :class-name 'prompt-buffer)
            " for, well, the prompt buffer.  Some buffer classes may inherit from multiple other classes.
For instance " (:nxref :class-name 'web-buffer) " and " (:nxref :class-name 'prompt-buffer)
            " both inherit from " (:nxref :class-name 'input-buffer) ".")
        (:p "You can configure one of the parent " (:nxref :class-name 'buffer) " classes slots and the new
values will automatically cascade down as a new default for all child classes-
unless this slot is specialized by these child classes."))

      (:nsection :title "Keybinding configuration"
        (:p "Nyxt supports multiple " (:i "bindings schemes") " such as CUA (the
    default), Emacs or vi.  Changing scheme is as simple as setting the
    corresponding mode as default, e.g. "
            (:nxref :class-name 'nyxt/mode/emacs:emacs-mode) ".  To make the change persistent across sessions,
add the following to your configuration:")
        (:ul
         (:li "vi bindings:"
              (:ncode
                '(define-configuration input-buffer
                  ((default-modes (pushnew 'nyxt/mode/vi:vi-normal-mode %slot-value%))))))
         (:li "Emacs bindings:"
              (:ncode
                '(define-configuration input-buffer
                  ((default-modes (pushnew 'nyxt/mode/emacs:emacs-mode %slot-value%)))))))
        (:p "You can create new scheme names with " (:nxref :function 'nkeymaps:make-keyscheme)
            ".  Also see the "
            (:nxref :function 'keymaps:define-keyscheme-map "define-keyscheme-map macro") ".")
        (:p "To extend the bindings of a specific mode, you can configure the mode with "
            (:nxref :macro 'define-configuration) " and extend its "
            (:nxref :slot 'keyscheme-map :class-name 'mode) " with "
            (:nxref :function 'keymaps:define-keyscheme-map) ". For example:")
        (:ncode
          '(define-configuration base-mode
            "Note the :import part of the `define-keyscheme-map'.
It re-uses the other keymap (in this case, the one that was slot value before
the configuration) and merely adds/modifies it."
            ((keyscheme-map
              (define-keyscheme-map
               "my-base" (list :import %slot-value%)
               nyxt/keyscheme:vi-normal
               (list "g b" (lambda-command switch-buffer* ()
                             (switch-buffer :current-is-last-p t))))))))
        (:p "The " (:nxref  :command 'nothing) " command is useful to override bindings to do
nothing. Note that it's possible to bind any command, including those of
disabled modes that are not listed in " (:nxref :command 'execute-command)
". Binding to " (:nxref :command 'nothing)
" and binding to NIL means different things (see the documentation of "
(:nxref :function 'keymaps:define-key) " for details):")
        (:dl
         (:dt (:nxref  :command 'nothing))
         (:dd "Binds the key to a command that does nothing. Still discovers the key and
recognizes it as pressed.")
         (:dt "NIL")
         (:dd "Un-binds the key, removing all the bindings that it had in a given
mode/keyscheme-map. If you press the un-bound key, the bindings that used to be
there will not be found anymore, and the key will be forwarded to the renderer.")
         (:dt "Any other symbol/command")
         (:dd "Replaces the command that was there before, with the new one. When the key is
pressed, the new command will fire instead of the old one."))
        (:p "In addition, a more flexible approach is to create your own mode with
your custom keybindings.  When this mode is added first to the buffer mode list,
its keybindings have priorities over the other modes.
Note that this kind of global keymaps also have priority over regular character
insertion, so you should probably not bind anything without modifiers in such a
keymap.")
        (:ncode
          '(defvar *my-keymap* (keymaps:make-keymap "my-map"))
          '(define-key *my-keymap*
            "C-f" 'nyxt/mode/history:history-forwards
            "C-b" 'nyxt/mode/history:history-backwards)

          '(define-mode my-mode ()
            "Dummy mode for the custom key bindings in `*my-keymap*'."
            ((keyscheme-map (keymaps:make-keyscheme-map
                             nyxt/keyscheme:cua *my-keymap*
                             nyxt/keyscheme:emacs *my-keymap*
                             nyxt/keyscheme:vi-normal *my-keymap*))))

          '(define-configuration web-buffer
            "Enable this mode by default."
            ((default-modes (pushnew 'my-mode %slot-value%)))))
        (:p "Bindings are subject to various translations as per "
            (:nxref :variable 'nkeymaps:*translator*) ". "
            "By default if it fails to find a binding it tries again with inverted
shifts.  For instance if " (:code "C-x C-F") " fails to match anything " (:code "C-x C-f")
            " is tried."
            "See the default value of " (:nxref :variable 'nkeymaps:*translator*) " to learn how to
         customize it or set it to " (:code "nil") " to disable all forms of
         translation."))

      (:nsection :title "Search engines"
        (:p "The following search engines are defined, where the default one is
        the first: " (:ncode (getf (mopu:slot-properties 'browser 'search-engines)
                                   :initform)))
        (:p "The " (:code ":shortcut") " parameter above impacts the behavior of
        commands such as " (:nxref :command 'set-url) ". For example, typing "
        (:code "foo") " or " (:code "ddg foo") " both results in querying
        DuckDuckGo for " (:code "foo") " (meaning that the shortcut may be
        omitted when using the default search engine). As you might have
        guessed, " (:code "wiki foo") " queries Wikipedia instead.")

        (:p "The example below exemplifies how to define additional search engines:")
        (:ncode
          '(defvar *my-search-engines*
            (list (make-instance 'search-engine
                   :name "Google"
                   :shortcut "goo"
                   :control-url "https://duckduckgo.com/?q=~a")
             (make-instance 'search-engine
              :name "MDN"
              :shortcut "mdn"
              :control-url "https://developer.mozilla.org/en-US/search?q=~a")))

          '(define-configuration browser
            ((search-engines (append %slot-default% *my-search-engines*)))))
        (:p "Note that the default search engine is determined by "
            (:nxref :function 'default-search-engine)
            " (by default, the first element of "
            (:nxref :slot 'search-engines :class-name 'browser)
            ").  Therefore, the order of arguments passed to "
            (:code "append") " in the code snippet above is key.")
        (:p "For more information on the topic see "
            (:nxref :class-name 'search-engine) "."))

      (:nsection :title "History"
        (:p "Nyxt history model is a vector whose elements are URLs.")
        (:p "History can be navigated with the arrow keys in the status buffer, or with
commands like " (:nxref :command 'nyxt/mode/history:history-backwards) " and "
(:nxref :command 'nyxt/mode/history:history-forwards)
" (which the arrows are bound to)."))
      (:nsection :title "Downloads"
        (:p "See the " (:nxref :command 'nyxt/mode/download:list-downloads) " command and the "
            (:nxref :slot 'download-path :class-name 'buffer) " buffer slot documentation."))

      (:nsection :title "URL-dispatchers"
        (:p "You can configure which actions to take depending on the URL to be
loaded.  For instance, you can configure which Torrent program to start to load
magnet links.  See the " (:nxref :function 'url-dispatching-handler) " function
documentation."))

      (:nsection
        :title "Custom commands"
        :open-p nil
        (:p "Creating your own invocable commands is similar to creating a Common
Lisp function, except the form is " (:code "define-command") " instead of "
(:code "defun") ". If you want this command to be invocable outside of
        the context of a mode, use " (:code "define-command-global") ".")
        (:p "Example:")
        (:ncode
          '(define-command-global my-bookmark-url ()
            "Query which URL to bookmark."
            (let ((url (prompt
                        :prompt "Bookmark URL"
                        :sources 'prompter:raw-source)))
              (nyxt/mode/bookmark:persist-bookmark url))))
        (:p "See the " (:nxref :class-name 'prompt-buffer) " class documentation for how
to write custom prompt buffers.")
        (:p "You can also create your own context menu entries binding those to Lisp commands, using "
            (:nxref :function 'ffi-add-context-menu-command) " function. You can bind the "
            (:code "bookmark-url") " like this:")
        (:ncode '(ffi-add-context-menu-command 'my-bookmark-url "Bookmark URL"))
        (:p "Currently, context menu commands don't have access to the renderer objects (and
shouldn't hope to). Commands you bind to context menu actions should deduce most
of the information from their surroundings, using JavaScript and Lisp functions
Nyxt provides. For example, one can use the "
            (:nxref :slot 'url-at-point :class-name 'buffer)
            " to get thep URL currently under pointer.")
        (:p "With this, one can improve the bookmarking using "
            (:nxref :slot 'url-at-point :class-name 'buffer) ":")
        (:ncode
          '(ffi-add-context-menu-command
            (lambda ()
              (nyxt/mode/bookmark:persist-bookmark (url-at-point (current-buffer))))
            "Bookmark Link")))

      (:nsection :title "Custom URL schemes"
        (:p "Nyxt can register custom schemes that run a handler on URL load.")
        (:p "The example below defines a scheme " (:code "hello") " that replies
            accordingly when loading URLs " (:code "hello:world") " and "
            (:code "hello:mars") ".")
        (:ncode
          '(define-internal-scheme "hello"
            (lambda (url)
              (if (string= (quri:uri-path (url url)) "world")
                  (spinneret:with-html-string (:p "Hello, World!"))
                  (spinneret:with-html-string (:p "Please instruct me on how to greet you!"))))))
        (:p "Note that scheme privileges, such as enabling the Fetch API or
enabling CORS requests are renderer-specific.")

        (:nsection :title "nyxt: URLs and internal pages"
          (:p "You can create pages out of Lisp commands, and make arbitrary computations for
the content of those. More so: these pages can invoke Lisp commands on demand,
be it on button click or on some page event. The macros and functions to look at are:")
          (:ul
           (:li (:nxref :macro 'define-internal-page) " to create new pages.")
           (:li (:nxref :function 'buffer-load-internal-page-focus)
                " to either get or create the buffer for the page.")
           (:li (:nxref :function 'nyxt-url) " to reference the internal pages by their name.")
           (:li (:nxref :macro 'define-internal-page-command)
                " to generate a mode-specific command loading the internal page.")
           (:li (:nxref :macro 'define-internal-page-command-global)
                " to generate a global command loading the internal page."))
          (:p "Using the facilities Nyxt provides, you can make a random number generator
page:")
          (:ncode
            '(define-internal-page-command-global random-number (&key (max 1000000))
              (buffer "*Random*")
              "Generates a random number on every reload."
              (spinneret:with-html-string
                (:h1 (princ-to-string (random max)))
                (:button.button
                 :onclick (ps:ps (nyxt/ps:lisp-eval
                                  (:title "re-load/re-generate the random number")
                                  (ffi-buffer-reload buffer)))
                 :title "Re-generate the random number again"
                 "New number"))))
          (:p "Several things to notice here:")
          (:ul
           (:li "Internal page command is much like a regular command in being a Lisp function
that you can call either from the REPL or from the " (:nxref :command 'execute-command) " menu.")
           (:ul
            (:li "With one important restriction: internal page commands should only have keyword
arguments. Other argument types are not supported. This is to make them
invocable through the URL they are assigned. For example, when you invoke the "
                 (:code "random-number") " command you've written, you'll see the "
                 (:code "nyxt:nyxt-user:random-number?max=%1B1000000")
                 " URL in the status buffer. The keyword argument is being seamlessly translated
into a URL query parameter.")
            (:li "There's yet another important restriction: the values you provide to the
internal page command should be serializable to URLs. Which restricts the
arguments to numbers, symbols, and strings, for instance."))
           (:li "Those commands should return the content of the page in their body, like
internal schemes do.")
           (:li "If you want to return HTML, then " (:nxref :macro 'spinneret:with-html-string)
                " is your best friend, but no one restricts you from producing HTML in any other
way, including simply writing it by hand ;)")
           (:li (:code "nyxt/ps:lisp-eval")
                " is a Parenscript macro to request Nyxt to run arbitrary code. The signature is: "
                (:code "((&key (buffer '(nyxt:current-buffer)) title) &body body)")
                ". You can bind it to a " (:code "<button>") "'s " (:code "onClick")
                " event, for example."))
          (:p "If you're making an extension, you might find other macros more useful. "
              (:nxref :macro 'define-internal-page-command)
              ", for example, defines a command to only be visible when in the corresponding mode
is enabled. Useful to separate the context-specific commands from the
universally useful (" (:code "-global")
              ") ones. If there's a page that you'd rather not have a command for, you can
still define it as:")
          (:ncode
            '(define-internal-page not-a-command ()
              (:title "*Hello*" :page-mode 'base-mode)
              "Hello there!"))
          (:p " and use as:")
          (:ncode
            '(buffer-load-internal-page-focus 'not-a-command))
          (:p "See the slots and documentation of " (:nxref :class-name 'internal-page)
              " to understand what you can pass to "
              (:nxref :macro 'define-internal-page) ".")))

      (:nsection :title "Hooks"
        (:p "Hooks provide a powerful mechanism to tweak the behavior of various
events that occur in the context of windows, buffers, modes, etc.")
        (:p "A hook holds a list of " (:i "handlers") ".  Handlers are named and
typed functions.  Each hook has a dedicated handler constructor.")
        (:p
         "Hooks can be 'run', that is, their handlers are run according to
the " (:nxref :slot 'nhooks:combination :class-name 'nhooks:hook) " slot of the hook.  This combination is a function
of the handlers.  Depending on the combination, a hook can run the handlers
either in parallel, or in order until one fails, or even " (:i "compose")
         " them (pass the result of one as the input of the next).  The handler types
specify which input and output values are expected.")
        (:p "To add or delete a hook, you only need to know a couple of functions:"
            (:ul
             (:li (:nxref :class-name 'nhooks:handler) " a class to wrap hook handlers in.")
             (:li (:nxref :function 'nhooks:add-hook) " (also known as "
                  (:code "hooks:add-hook")
                  ") allows you to add a handler to a hook,for it to be invoked when the hook fires.")
             (:li (:code "nhooks:on") " (also available as " (:code "hooks:on")
                  ") as a shorthand for the " (:code "nhooks:add-hook") ".")
             (:li (:nxref :function 'nhooks:remove-hook) " (also available as "
                  (:code "hooks:remove-hook") ") that removes the handler from a certain hook.")
             (:li (:code "nhooks:once-on") " (also available as " (:code "hooks:once-on")
                  ") as a one-shot version of " (:code "nhooks:on")
                  " that removes the handler right after it's completed.")))
        (:p "Many hooks are executed at different points in Nyxt, among others:")
        (:ul
         (:li "Global hooks, such as " (:nxref :slot 'after-init-hook :class-name 'browser)
              " or " (:nxref :slot 'after-startup-hook :class-name 'browser) ".")
         (:li "Window- or buffer-related hooks.")
         (:ul
          (:li (:nxref :slot 'window-make-hook :class-name 'window) " for when a new window is created.")
          (:li (:nxref :slot 'window-delete-hook :class-name 'window) " for when a window is deleted.")
          (:li (:nxref :slot 'window-set-buffer-hook :class-name 'window)
               " for when the " (:nxref :function 'current-buffer) " changes in the window.")
          (:li (:nxref :slot 'buffer-load-hook :class-name 'network-buffer)
               " for when there's a new page loading in the buffer.")
          (:li (:nxref :slot 'buffer-loaded-hook :class-name 'network-buffer)
               " for when this page is mostly done loading (some scripts/image/styles may not
be fully loaded yet, so you may need to wait a bit after it fires.)")
          (:li (:nxref :slot 'request-resource-hook :class-name 'network-buffer)
               " for when a new request happens. Allows redirecting and blocking requests, and
is a good place to do something conditioned on the links being loaded.")
          (:li (:nxref :slot 'prompt-buffer-ready-hook :class-name 'prompt-buffer)
               " fires when the prompt buffer is ready for user input. You may need to call "
               (:nxref :function 'prompter:all-ready-p)
               " on the prompt to ensure all the sources it contains are ready too, and then
you can safely set new inputs and select the necessary suggestions."))
         (:li "Commands :before and :after methods.")
         (:ul
          (:li "Try, for example, "
               (:code "(defmethod set-url :after (&key (default-action nil)) ...)")
               " to do something after the set-url finishes executing."))
         (:li "Modes 'enable' and 'disable' methods and their :before, :after, and :around methods.")
         (:li "Mode-specific hooks, like " (:nxref :slot 'nyxt/mode/download:before-download-hook
                                             :class-name 'nyxt/mode/download:download-mode)
              " and " (:nxref :slot 'nyxt/mode/download:after-download-hook
                        :class-name 'nyxt/mode/download:download-mode)
              " for " (:nxref :class-name 'nyxt/mode/download:download) "."))
        (:p "For instance, if you want to force 'old.reddit.com' over 'www.reddit.com', you
can set a hook like the following in your configuration file:")
        (:ncode
          '(defun old-reddit-handler (request-data)
            (let ((url (url request-data)))
              (setf (url request-data)
                    (if (search "reddit.com" (quri:uri-host url))
                        (progn
                          (setf (quri:uri-host url) "old.reddit.com")
                          (log:info "Switching to old Reddit: ~s" (render-url url))
                          url)
                        url)))
            request-data)
          '(define-configuration web-buffer
            ((request-resource-hook
              (hooks:add-hook %slot-default% 'old-reddit-handler)))))
        (:p "(See " (:nxref :function 'url-dispatching-handler)
            " for a simpler way to achieve the same result.)")
        (:p "Or, if you want to set multiple handlers at once,")
        (:ncode
          '(define-configuration web-buffer
            ((request-resource-hook
              (reduce #'hooks:add-hook
               '(old-reddit-handler auto-proxy-handler)
               :initial-value %slot-default%)))))
        (:p "Some hooks like the above example expect a return value, so it's
important to make sure we return " (:nxref :class-name 'request-data) " here.  See the
documentation of the respective hooks for more details."))

      (:nsection :title "Password management"
        (:p "Nyxt provides a uniform interface to some password managers including "
            (:a :href "https://keepassxc.org/" "KeepassXC")
            " and " (:a :href "https://www.passwordstore.org/" "Password Store") ". "
            "The supported installed password manager is automatically detected."
            "See the " (:code "password-interface") " buffer slot for customization.")
        (:p "You may use the " (:nxref :macro 'define-configuration) " macro with
any of the password interfaces to configure them. Please make sure to
use the package prefixed class name/slot designators within
the " (:nxref :macro 'define-configuration) ".")
        (:ul
         (:li (:nxref :command 'nyxt/mode/password:save-new-password) ": Query for name and new password to persist in the database.")
         (:li (:nxref :command 'nyxt/mode/password:copy-password) ": " (command-docstring-first-sentence 'nyxt/mode/password:copy-password)))

        (:nsection :title "KeePassXC support"
          (:p "The interface for KeePassXC should cover most use-cases for KeePassXC, as it
supports password database locking with")
          (:ul
           (:li (:nxref :slot 'password:master-password :class-name 'password:keepassxc-interface) ",")
           (:li (:nxref :slot 'password:key-file :class-name 'password:keepassxc-interface) ",")
           (:li "and " (:nxref :slot 'password:yubikey-slot :class-name 'password:keepassxc-interface)))
          (:p "To configure KeePassXC interface, you might need to add something like this
snippet to your config:")
          (:ncode
            ;; FIXME: Why does `define-configuration' not work for password
            ;; interfaces? Something's fishy with user classes...
            '(defmethod initialize-instance :after ((interface password:keepassxc-interface) &key &allow-other-keys)
              "It's obviously not recommended to set master password here,
as your config is likely unencrypted and can reveal your password to someone
peeking at the screen."
              (setf (password:password-file interface) "/path/to/your/passwords.kdbx"
               (password:key-file interface) "/path/to/your/keyfile"
               (password:yubikey-slot interface) "1:1111"))
            '(define-configuration nyxt/mode/password:password-mode
              ((nyxt/mode/password:password-interface (make-instance 'password:keepassxc-interface))))
            '(define-configuration buffer
              ((default-modes (append (list 'nyxt/mode/password:password-mode) %slot-value%)))))))

      (:nsection :title "Appearance"
        (:p "Much of the visual style can be configured by the user. You can use the
facilities provided by " (:nxref :package :theme) " and "
(:nxref :slot 'nyxt:theme :class-name 'nyxt:browser "browser theme slot")
". The simplest option would be to use a built-in theme:")
	(:ncode
          '(define-configuration browser
            ((theme theme:+dark-theme+
              :doc "Setting dark theme.
The default is `theme:+light-theme+'."))))
	(:p "There's also an option of creating a custom theme. For example, to set a theme
to a midnight-like one, you can add this snippet
to your configuration file:")
        (:ncode
          '(define-configuration browser
            ((theme (make-instance
		     'theme:theme
		     :background-color "black"
		     :action-color "#37a8e4"
		     :primary-color "#808080"
		     :secondary-color "darkgray")
              :doc "You can omit the colors you like in default theme, and they will stay as they were."))))
        (:p "This, on the next restart of Nyxt, will repaint all the interface elements into
a dark-ish theme.")
	(:p "As a more involved theme example, here's how one can redefine most of the
semantic colors Nyxt uses to be compliant with Solarized Light theme:")
	(:ncode
	  '(define-configuration browser
            ((theme (make-instance
		     'theme:theme
		     :background-color "#eee8d5"
		     :action-color "#268bd2"
		     :primary-color "#073642"
		     :secondary-color "#586e75"
		     :success-color "#2aa198"
		     :warning-color "#dc322f"
		     :highlight-color "#d33682")
              :doc "Covers all the semantic groups (`warning-color', `codeblock-color' etc.)
Note that you can also define more nuanced colors, like `warning-color+', so
that the interface gets even nicer. Otherwise Nyxt generates the missing colors
automatically, which should be good enough... for most cases."))))
        (:p "As an alternative to the all-encompassing themes, you can alter the style of
every individual class controlling Nyxt interface elements. All such classes have a "
            (:nxref :function 'nyxt:style)
            " slot that you can configure with your own CSS like this:")
        (:ncode
          '(define-configuration nyxt/mode/style:dark-mode
            ((style
              (theme:themed-css (theme *browser*)
                `(*
                  :background-color ,theme:background-color "!important"
                  :background-image none "!important"
                  :color "red" "!important")
                `(a
                  :background-color ,theme:background-color "!important"
                  :background-image none "!important"
                  :color "#AAAAAA" "!important"))))
	    :doc "Notice the use of `theme:themed-css' for convenient theme color injection."))
        (:p "This snippet alters the " (:nxref :slot 'style :class-name 'nyxt/mode/style:dark-mode)
            " of Nyxt dark mode to have a more theme-compliant colors, using the "
            (:code "theme:themed-css")
            " macro (making all the theme colors you've configured earlier available as
variables like " (:code "theme:on-primary-color") ".)")

        (:nsection :title "Status buffer appearance"
          (:p "You can customize the layout and styling of " (:nxref :class-name 'status-buffer)
              " using the methods it uses for layout. These methods are: ")
          (:dl
           (:dt (:nxref :function 'nyxt:format-status))
           (:dd "General layout of the status buffer, including the parts it consists of.")
           (:dt (:nxref :function 'nyxt::format-status-buttons))
           (:dd "The (\"Back\", \"Forward\", \"Reload\") buttons section.")
           (:dt (:nxref :function 'nyxt::format-status-url))
           (:dd "The current URL display section.")
           (:dt (:nxref :function 'nyxt::format-status-tabs))
           (:dd "Tab listing.")
           (:dt (:nxref :function 'nyxt::format-status-modes))
           (:dd "List of modes."))
          (:p "To complement the layout produced by these " (:code "format-*")
              " functions, you might need to add more rules or replace the "
              (:nxref :slot 'style :class-name 'status-buffer "style of status buffer") ".")))

      (:nsection :title "Scripting"
        (:p "You can evaluate code from the command line with "
            (:code "--eval") " and " (:code "--load") ".  From a shell:")
        (:ncode
          "$ nyxt --no-config --eval '+version+' \
  --load my-lib.lisp --eval '(format t \"Hello ~a!~&\" (my-lib:my-world))'")
        (:p "You can evaluate multiple --eval and --load in a row, they are
executed in the order they appear.")
        (:p "You can also evaluate a Lisp file from the Nyxt interface with
the " (:nxref :command 'load-file) " command.  For
convenience, " (:nxref :command 'load-config-file) " (re)loads your initialization file.")
        (:p "You can even make scripts.  Here is an example foo.lisp:")
        (:ncode
          "#!/bin/sh
#|
exec nyxt --script \"$0\"
|#

;; Your code follows:
\(format t \"~a~&\" +version+)")
        (:p "--eval and --load can be commanded to operate over an
existing instance instead of a separate instance that exits immediately.")
        (:p "The " (:nxref :slot 'remote-execution-p :class-name 'browser)
            " of the remote instance must be non-nil:")
        (:ncode
          '(define-configuration browser
            ((remote-execution-p t))))
        (:p "To let know a private instance of Nyxt to load a foo.lisp script and run its "
            (:code "foo") " function:")
        (:ncode
          "nyxt --profile nosave --remote --load foo.lisp --eval '(foo)' --quit")
        (:p "Note that " (:code "--quit")
            " at the end of each Nyxt CLI call here. If you don't provide " (:code "--quit")
            " when dealing with a remote instance, it will go into a REPL mode, allowing an
immediate communication with an instance:")
        (:pre (:code "nyxt --remote
(echo \"~s\" (+ 1 2)) ;; Shows '3' in the message buffer of remote Nyxt")))

      (:nsection :title "Advanced configuration"
        (:p "While " (:nxref :macro 'define-configuration) " is convenient, it is mostly
restricted to class slot configuration.  If you want to do anything else on
class instantiation, you'll have to specialize the
lower-level " (:nxref :function 'customize-instance)
" generic function.  Example:")
        (:ncode
          '(defmethod customize-instance ((buffer buffer) &key)
            (echo "Buffer ~a created." buffer)))
        (:p "All classes with metaclass " (:nxref :class-name 'user-class) " call "
            (:nxref :function 'customize-instance) " on instantiation,
after " (:nxref :function 'initialize-instance)(:code " :after") ".  The primary method is reserved
to the user, however the " (:code ":after") " method is reserved to the Nyxt
core to finalize the instance."))

      (:nsection :title "Extensions"
        (:p "To install an extension, copy inside the "
            (:nxref :variable '*extensions-directory*) " (default to "
            (:code "~/.local/share/nyxt/extensions")").")
        (:p "Extensions are regular Common Lisp systems.")
        (:p "Please find a catalog of Nyxt extensions "
            (:a :href (nyxt-url 'list-extensions) "here") "."))

      (:nsection :title "Blocking ads using AdBlock rules"
        (:p "With WebkitGTK backend you can use "
            (:a :href "https://github.com/dudik/blockit" "BlocKit")
            " extension to block ads.")
        (:p "In short, you have to install "
            (:a :href "https://crates.io/crates/adblock-rust-server" "adblock-rust-server")
            " to a directory visible in " (:code "PATH")
            " environment variable and the shared library ("
            (:code "blockit.so") ") to " (:code gtk-extensions-directory)
            ". After that, follow instructions on BlocKit github page."))

      (:nsection :title "Troubleshooting"

        (:nsection :title "Debugging and reporting errors"
          (:p "Report bugs using " (:nxref :command 'nyxt:report-bug) "."))

        (:nsection :title "Bwrap error on initialization (Ubuntu)"
          (:p "If Nyxt crashes on start due to " (:code "bwrap")
              ", then disable or configure the " (:code "apparmor") " service."))

        (:nsection :title "Playing videos"
          (:p "Nyxt delegates video support to third-party plugins.")
          (:p "When using the WebKitGTK backends, GStreamer and its plugins are
leveraged.  Depending on the video, you will need to install some of the
following packages:")
          (:ul
           (:li "gst-libav")
           (:li "gst-plugins-bad")
           (:li "gst-plugins-base")
           (:li "gst-plugins-good")
           (:li "gst-plugins-ugly"))
          (:p "On Debian-based systems, you might be looking for (adapt the version numbers):")
          (:ul
           (:li "libgstreamer1.0-0")
           (:li "gir1.2-gst-plugins-base-1.0"))
          (:p "For systems from the Fedora family:")
          (:ul
           (:li "gstreamer1-devel")
           (:li "gstreamer1-plugins-base-devel"))
          (:p "After the desired plugins have been installed, clear the GStreamer cache at "
              (:code "~/.cache/gstreamer-1.0") " and restart Nyxt."))

        (:nsection :title "Website crashes"
          (:p "If some websites systematically crash, try to install all the required
GStreamer plugins as mentioned in the 'Playing videos' section."))

        (:nsection :title "Input method support (CJK, etc.)"
          (:p "Depending on your setup, you might have to set some environment variables
or run some commands before starting Nyxt, for instance")
          (:ncode
            "GTK_IM_MODULE=xim
XMODIFIERS=@im=ibus
ibus --daemonize --replace --xim")
          (:p "You can persist this change by saving the commands in
your " (:code ".xprofile") " or similar."))

        (:nsection :title "HiDPI displays"
          (:p "The entire UI may need to be scaled up on HiDPI displays.")
          (:p "When using the WebKitGTK renderer, export the environment
variable below before starting Nyxt.  Note that " (:code "GDK_DPI_SCALE") " (not
to be confused with " (:code "GDK_SCALE") ") scales text only, so tweaking it
may be undesirable.")
          (:pre (:code "export GDK_SCALE=2
nyxt
")))

        (:nsection :title "StumpWM mouse scroll"
          (:p "If the mouse scroll does not work for you, see the "
              (:a
               :href "https://github.com/stumpwm/stumpwm/wiki/FAQ#my-mouse-wheel-doesnt-work-with-gtk3-applications-add-the-following-to"
               "StumpWM FAQ")
              " for a fix."))

        (:nsection :title "Blank WebKitGTK views"
          (:p "When experiencing rendering issues, try to disable compositing as
below: ")
          (:ncode
            '(setf (uiop:getenv "WEBKIT_DISABLE_COMPOSITING_MODE") "1")))

        (:nsection :title "Missing cursor icons"
          (:p "If you are having issues with the cursor not changing when
hovering over buttons or links, it might be because Nyxt can't locate your cursor theme.
To fix that, try adding the following to your" (:code ".bash_profile") " or similar:")
          (:ncode
            "export XCURSOR_PATH=${XCURSOR_PATH}:/usr/share/icons
export XCURSOR_PATH=${XCURSOR_PATH}:~/.local/share/icons"))))))
