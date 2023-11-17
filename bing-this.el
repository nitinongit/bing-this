;;; bing-this.el --- A set of functions and bindings to bing under point.

;; Copyright (C) 2012-2013 Artur Malabarba <bruce.connor.am@gmail.com>

;; Author: Artur Malabarba <bruce.connor.am@gmail.com>
;; URL: http://github.com/Malabarba/emacs-bing-this
;; Version: 1.10
;; Package-Requires: ((emacs "24.1"))
;; Keywords: convenience hypermedia
;; Prefix: bing-this
;; Separator: -

;;; Commentary:

;; bing-this is a package that provides a set of functions and
;; keybindings for launching bing searches from within Emacs.

;; The main function is `bing-this' (bound to C-c / g). It does a
;; bing search using the currently selected region, or the
;; expression under point. All functions are bound under "C-c /"
;; prefix, in order to comply with Emacs' standards. If that's a
;; problem see `bing-this-keybind'. To view all keybindings type "C-c
;; / C-h".
;;
;; If you don't like this keybind, just reassign the
;; `bing-this-mode-submap' variable.
;; My personal preference is "C-x g":
;;
;;        (global-set-key (kbd "C-x g") 'bing-this-mode-submap)
;;
;; Or, if you don't want bing-this to overwrite the default ("C-c /")
;; key insert the following line BEFORE everything else (even before
;; the `require' command):
;;
;;        (setq bing-this-keybind (kbd "C-x g"))
;;

;; To start a blank search, do `bing-search' (C-c / RET). If you
;; want more control of what "under point" means for the `bing-this'
;; command, there are the `bing-word', `bing-symbol',
;; `bing-line' and `bing-region' functions, bound as w, s, l and space,
;; respectively. They all do a search for what's under point.

;; If the `bing-wrap-in-quotes' variable is t, than searches are
;; enclosed by double quotes (default is NOT). If a prefix argument is
;; given to any of the functions, invert the effect of
;; `bing-wrap-in-quotes'.

;; There is also a `bing-error' (C-c / e) function. It checks the
;; current error in the compilation buffer, tries to do some parsing
;; (to remove file name, line number, etc), and bings it. It's still
;; experimental, and has only really been tested with gcc error
;; reports.

;; Finally there's also a bing-cpp-reference function (C-c / r).

;;; Instructions:

;; INSTALLATION

;;  Make sure "bing-this.el" is in your load path, then place
;;      this code in your .emacs file:
;;		(require 'bing-this)
;;              (bing-this-mode 1)

;;; License:
;;
;; This file is NOT part of GNU Emacs.
;;
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License
;; as published by the Free Software Foundation; either version 2
;; of the License, or (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;;; Code:

(require 'url)
(eval-when-compile
  (progn
    (require 'compile)
    (require 'simple)))

(defgroup bing-this '()
  "Customization group for `bing-this-mode'."
  :link '(url-link "http://github.com/Malabarba/emacs-bing-this")
  :group 'convenience
  :group 'comm)

(defconst bing-this-version "1.10"
  "Version string of the `bing-this' package.")
(defcustom bing-this-wrap-in-quotes nil
  "If not nil, searches are wrapped in double quotes.

If a prefix argument is given to any of the functions, the
opposite happens."
  :type 'boolean
  :group 'bing-this)

(defcustom bing-this-suspend-after-search nil
  "Whether Emacs should be minimized after a search is launched (calls `suspend-frame')."
  :type 'boolean
  :group 'bing-this)

(defcustom bing-this-browse-url-function 'browse-url
  "Function used to browse urls.
Possible values include: `browse-url', `browse-url-generic',
`browse-url-emacs', `eww-browse-url'."
  :type 'function
  :group 'bing-this)

(defvar bing-this-mode-submap)
(define-prefix-command 'bing-this-mode-submap)
(define-key bing-this-mode-submap [return] #'bing-this-search)
(define-key bing-this-mode-submap " " #'bing-this-region)
(define-key bing-this-mode-submap "t" #'bing-this)
(define-key bing-this-mode-submap "n" #'bing-this-noconfirm)
(define-key bing-this-mode-submap "g" #'bing-this-lucky-search)
(define-key bing-this-mode-submap "i" #'bing-this-lucky-and-insert-url)
(define-key bing-this-mode-submap "w" #'bing-this-word)
(define-key bing-this-mode-submap "s" #'bing-this-symbol)
(define-key bing-this-mode-submap "l" #'bing-this-line)
(define-key bing-this-mode-submap "e" #'bing-this-error)
(define-key bing-this-mode-submap "f" #'bing-this-forecast)
(define-key bing-this-mode-submap "r" #'bing-this-cpp-reference)
(define-key bing-this-mode-submap "m" #'bing-this-maps)
(define-key bing-this-mode-submap "a" #'bing-this-ray)
(define-key bing-this-mode-submap "m" #'bing-maps)
;; "c" is for "convert language" :-P
(define-key bing-this-mode-submap "c" #'bing-this-translate-query-or-region)

(defun bing-this-translate-query-or-region ()
  "If region is active `bing-translate-at-point', otherwise `bing-translate-query-translate'."
  (interactive)
  (unless (require 'bing-translate nil t)
    (error "[bing-this]: This command requires the 'bing-translate' package"))
  (if (region-active-p)
      (if (functionp 'bing-translate-at-point)
          (call-interactively 'bing-translate-at-point)
        (error "[bing-this]: `bing-translate-at-point' function not found in `bing-translate' package"))
    (if (functionp 'bing-translate-query-translate)
        (call-interactively 'bing-translate-query-translate)
      (error "[bing-this]: `bing-translate-query-translate' function not found in `bing-translate' package"))))

(defcustom bing-this-base-url "https://www.bing."
  "The base url to use in bing searches.

This will be appended with `bing-this-location-suffix', so you
shouldn't include the final \"com\" here."
  :type 'string
  :group 'bing-this)

(defcustom bing-this-location-suffix "com"
  "The url suffix associated with your location (com, co.uk, fr, etc)."
  :type 'string
  :group 'bing-this)

(defun bing-this-url ()
  "URL for bing searches."
  (concat bing-this-base-url bing-this-location-suffix "/search?ion=1&q=%s"))

(defcustom bing-this-error-regexp '(("^[^:]*:[0-9 ]*:\\([0-9 ]*:\\)? *" ""))
  "List of (REGEXP REPLACEMENT) pairs to parse error strings."
  :type '(repeat (list regexp string))
  :group 'bing-this)

(defun bing-this-pick-term (prefix)
  "Decide what \"this\" and return it.
PREFIX determines quoting."
  (let* ((term (if (region-active-p)
                   (buffer-substring-no-properties (region-beginning) (region-end))
                 (or (thing-at-point 'symbol)
                     (thing-at-point 'word)
                     (buffer-substring-no-properties (line-beginning-position)
                                                     (line-end-position)))))
         (term (read-string (concat "Binging [" term "]: ") nil nil term)))
    term))

;;;###autoload
(defun bing-this-search (prefix &optional search-string)
  "Write and do a bing search.
Interactively PREFIX determines quoting.
Non-interactively SEARCH-STRING is the string to search."
  (interactive "P")
  (let* ((term (bing-this-pick-term prefix)))
    (if (stringp term)
        (bing-this-parse-and-search-string term prefix search-string)
      (message "[bing-this-string] Empty query."))))

(defun bing-this-lucky-search-url ()
  "Return the url for a feeling-lucky bing search."
  (format "%s%s/search?q=%%s&btnI" bing-this-base-url bing-this-location-suffix))

(defalias 'bing-this--do-lucky-search
  (with-no-warnings
    (if (version< emacs-version "24")
        (lambda (term callback)
          "Build the URL using TERM, perform the `url-retrieve' and call CALLBACK if we get redirected."
          (url-retrieve (format (bing-this-lucky-search-url) (url-hexify-string term))
                        `(lambda (status)
                           (if status
                               (if (eq :redirect (car status))
                                   (progn (message "Received URL: %s" (cadr status))
                                          (funcall ,callback (cadr status)))
                                 (message "Unkown response: %S" status))
                             (message "Search returned no results.")))
                        nil))
      (lambda (term callback)
        "Build the URL using TERM, perform the `url-retrieve' and call CALLBACK if we get redirected."
        (url-retrieve (format (bing-this-lucky-search-url) (url-hexify-string term))
                      `(lambda (status)
                         (if status
                             (if (eq :redirect (car status))
                                 (progn (message "Received URL: %s" (cadr status))
                                        (funcall ,callback (cadr status)))
                               (message "Unkown response: %S" status))
                           (message "Search returned no results.")))
                      nil t t)))))

(defvar bing-this--last-url nil "Last url that was fetched by `bing-this-lucky-and-insert-url'.")

;;;###autoload
(defun bing-this-lucky-and-insert-url (term &optional insert)
  "Fetch the url that would be visited by `bing-this-lucky'.

If you just want to do an \"I'm feeling lucky search\", use
`bing-this-lucky-search' instead.

Interactively:
* Insert the URL at point,
* Kill the searched term, removing it from the buffer (it is killed, not
  deleted, so it can be easily yanked back if desired).
* Search term defaults to region or line, and always queries for
  confirmation.

Non-Interactively:
* Runs synchronously,
* Search TERM is an argument without confirmation,
* Only insert if INSERT is non-nil, otherwise return."
  (interactive '(needsQuerying t))
  (let ((nint (null (called-interactively-p 'any)))
        (l (if (region-active-p) (region-beginning) (line-beginning-position)))
        (r (if (region-active-p) (region-end) (line-end-position)))
        ;; We get current-buffer and point here, because it's
        ;; conceivable that they could change while waiting for input
        ;; from read-string
        (p (point))
        (b (current-buffer)))
    (when nint (setq bing-this--last-url nil))
    (when (eq term 'needsQuerying)
      (setq term (read-string "Lucky Term: " (buffer-substring-no-properties l r))))
    (unless (stringp term) (error "TERM must be a string!"))
    (bing-this--do-lucky-search
     term
     `(lambda (url)
        (unless url (error "Received nil url"))
        (with-current-buffer ,b
          (save-excursion
            (if ,nint (goto-char ,p)
              (kill-region ,l ,r)
              (goto-char ,l))
            (when ,insert (insert url))))
        (setq bing-this--last-url url)))
    (unless nint (deactivate-mark))
    (when nint
      (while (null bing-this--last-url) (sleep-for 0 10))
      bing-this--last-url)))

;;;###autoload
(defun bing-this-lucky-search (prefix)
  "Exactly like `bing-this-search', but use the \"I'm feeling lucky\" option.
PREFIX determines quoting."
  (interactive "P")
  (bing-this-search prefix (bing-this-lucky-search-url)))

(defun bing-this--maybe-wrap-in-quotes (text flip)
  "Wrap TEXT in quotes.
Depends on the value of FLIP and `bing-this-wrap-in-quotes'."
  (if (if flip (not bing-this-wrap-in-quotes) bing-this-wrap-in-quotes)
      (format "\"%s\"" text)
    text))

(defun bing-this-parse-and-search-string (text prefix &optional search-url)
  "Convert illegal characters in TEXT to their %XX versions, and then bings.
PREFIX determines quoting.
SEARCH-URL is usually either the regular or the lucky bing
search url.

Don't call this function directly, it could change depending on
version. Use `bing-this-string' instead (or any of the other
bing-this-\"something\" functions)."
  (let* (;; Create the url
         (query-string (bing-this--maybe-wrap-in-quotes text prefix))
         ;; Perform the actual search.
         (browse-result (funcall bing-this-browse-url-function
                                 (format (or search-url (bing-this-url))
                                         (url-hexify-string query-string)))))
    ;; Maybe suspend emacs.
    (when bing-this-suspend-after-search (suspend-frame))
    ;; Return what browse-url returned (very usefull for tests).
    browse-result))

;;;###autoload
(defun bing-this-string (prefix &optional text noconfirm)
  "Bing given TEXT, but ask the user first if NOCONFIRM is nil.
PREFIX determines quoting."
  (unless noconfirm
    (setq text (read-string "Binging: "
                            (if (stringp text) (replace-regexp-in-string "^[[:blank:]]*" "" text)))))
  (if (stringp text)
      (bing-this-parse-and-search-string text prefix)
    (message "[bing-this-string] Empty query.")))

;;;###autoload
(defun bing-this-line (prefix &optional noconfirm)
  "Bing the current line.
PREFIX determines quoting.
NOCONFIRM goes without asking for confirmation."
  (interactive "P")
  (let ((line (buffer-substring (line-beginning-position) (line-end-position))))
    (bing-this-string prefix line noconfirm)))

;;;###autoload
(defun bing-this-ray (prefix &optional noconfirm noregion)
  "Bing text between the point and end of the line.
If there is a selected region, bings the region.
PREFIX determines quoting. Negative arguments invert the line segment.
NOCONFIRM goes without asking for confirmation.
NOREGION ignores the region."
  (interactive "P")
  (if (and (region-active-p) (not noregion))
      (bing-this-region prefix noconfirm)
    (let (beg end pref (arg (prefix-numeric-value prefix)))
      (if (<= arg -1)
          (progn
            (setq beg (line-beginning-position))
            (setq end (point))
            (setq pref (< arg -1)))
        (setq beg (point))
        (setq end (line-end-position))
        (setq pref prefix))
      (bing-this-string pref (buffer-substring beg end) noconfirm))))

;;;###autoload
(defun bing-this-word (prefix)
  "Bing the current word.
PREFIX determines quoting."
  (interactive "P")
  (bing-this-string prefix (thing-at-point 'word) t))

;;;###autoload
(defun bing-this-symbol (prefix)
  "Bing the current symbol.
PREFIX determines quoting."
  (interactive "P")
  (bing-this-string prefix (thing-at-point 'symbol) t))


;;;###autoload
(defun bing-this-region (prefix &optional noconfirm)
  "Bing the current region.
PREFIX determines quoting.
NOCONFIRM goes without asking for confirmation."
  (interactive "P")
  (bing-this-string
   prefix (buffer-substring-no-properties (region-beginning) (region-end))
   noconfirm))

;;;###autoload
(defun bing-this (prefix &optional noconfirm)
  "Decide what the user wants to bing (always something under point).
Unlike `bing-this-search' (which presents an empty prompt with
\"this\" as the default value), this function inserts the query
in the minibuffer to be edited.
PREFIX argument determines quoting.
NOCONFIRM goes without asking for confirmation."
  (interactive "P")
  (cond
   ((region-active-p) (bing-this-region prefix noconfirm))
   ((thing-at-point 'symbol) (bing-this-string prefix (thing-at-point 'symbol) noconfirm))
   ((thing-at-point 'word) (bing-this-string prefix (thing-at-point 'word) noconfirm))
   (t (bing-this-line prefix noconfirm))))

;;;###autoload
(defun bing-this-noconfirm (prefix)
  "Decide what the user wants to bing and go without confirmation.
Exactly like `bing-this' or `bing-this-search', but don't ask
for confirmation.
PREFIX determines quoting."
  (interactive "P")
  (bing-this prefix 'noconfirm))

;;;###autoload
(defun bing-this-error (prefix)
  "Bing the current error in the compilation buffer.
PREFIX determines quoting."
  (interactive "P")
  (unless (boundp 'compilation-mode-map)
    (error "No compilation active"))
  (require 'compile)
  (require 'simple)
  (save-excursion
    (let ((pt (point))
          (buffer-name (next-error-find-buffer)))
      (unless (compilation-buffer-internal-p)
        (set-buffer buffer-name))
      (bing-this-string prefix
                     (bing-this-clean-error-string
                      (buffer-substring (line-beginning-position) (line-end-position)))))))


;;;###autoload
(defun bing-this-clean-error-string (s)
  "Parse error string S and turn it into bingable strings.

Removes unhelpful details like file names and line numbers from
simple error strings (such as c-like erros).

Uses replacements in `bing-this-error-regexp' and stops at the first match."
  (interactive)
  (let (out)
    (catch 'result
      (dolist (cur bing-this-error-regexp out)
        (when (string-match (car cur) s)
          (setq out (replace-regexp-in-string
                     (car cur) (car (cdr cur)) s))
          (throw 'result out))))))

;;;###autoload
(defun bing-this-cpp-reference ()
  "Visit the most probable cppreference.com page for this word."
  (interactive)
  (bing-this-parse-and-search-string
   (concat "site:cppreference.com " (thing-at-point 'symbol))
   nil (bing-this-lucky-search-url)))

;;;###autoload
(defun bing-this-forecast (prefix)
  "Search bing for \"weather\".
With PREFIX, ask for location."
  (interactive "P")
  (if (not prefix) (bing-this-parse-and-search-string "weather" nil)
    (bing-this-parse-and-search-string
     (concat "weather " (read-string "Location: " nil nil "")) nil)))

(defcustom bing-this-keybind (kbd "C-c /")
  "Keybinding under which `bing-this-mode-submap' is assigned.

To change this do something like:
    (setq bing-this-keybind (kbd \"C-x g\"))
BEFORE activating the function `bing-this-mode' and BEFORE `require'ing the
`bing-this' feature."
  :type 'string
  :group 'bing-this
  :package-version '(bing-this . "1.4"))

(defcustom bing-this-modeline-indicator " Bing"
  "String to display in the modeline when command `bing-this-mode' is activated."
  :type 'string
  :group 'bing-this
  :package-version '(bing-this . "1.8"))

;;;###autoload
(define-minor-mode bing-this-mode nil nil bing-this-modeline-indicator
  `((,bing-this-keybind . ,bing-this-mode-submap))
  :global t
  :group 'bing-this)
;; (setq bing-this-keybind (kbd \"C-x g\"))

(provide 'bing-this)

;;; bing-this.el ends here
