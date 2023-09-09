(provide 'init-git)
(use-package magit
  :elpaca (:files (:defaults "lisp/*.el" :exclude "lisp/magit-libgit.el" "lisp/magit-libgit-pkg"))
  :defer t
  :init
  (setq magit-define-global-key-bindings nil)
  (with-eval-after-load 'project
    (define-key project-prefix-map "m" #'magit-project-status)
    (add-to-list 'project-switch-commands '(magit-project-status "Magit") t))
  :config
  (setq magit-diff-refine-hunk t
        magit-display-buffer-function 'magit-display-buffer-same-window-except-diff-v1
        magit-revision-show-gravatars '("^Author:     " . "^Commit:     ")
        magit-save-repository-buffers 'dontask)

  (add-hook 'magit-diff-mode-hook (lambda () (toggle-truncate-lines -1)))
  (add-hook 'magit-process-find-password-functions 'magit-process-password-auth-source)

  (defun org-reveal-advice (&rest _args)
    "Unfold the org headings for a target line.
    This can be used to advice functions that might open .org files.

    For example: To unfold from a magit diff buffer, evaluate the following:
    (advice-add 'magit-diff-visit-file :after #'org-reveal-advice)"
    (when (derived-mode-p 'org-mode) (org-reveal)))

  (advice-add 'magit-blame-addition           :after #'org-reveal-advice)
  (advice-add 'magit-diff-visit-file          :after #'org-reveal-advice)
  (advice-add 'magit-diff-visit-worktree-file :after #'org-reveal-advice)
  :general
  (tyrant-def
    "g"   (cons "git" (make-sparse-keymap))
    "gb"  'magit-blame
    "gc"  'magit-clone
    "gd"  'magit-diff
    "gf"  'magit-file-dispatch
    "gi"  'magit-init
    "gl"  'magit-log-buffer-file
    "gm"  'magit-dispatch
    "gs"  'magit-status
    "gS"  'magit-stage-file
    "gU"  'magit-unstage-file))

(use-package diff-hl
  :elpaca t
  :after vc magit
  :hook (after-init . global-diff-hl-mode)
  :config
  (setq diff-hl-side 'left)

  (with-eval-after-load 'magit
    (add-hook 'magit-pre-refresh-hook 'diff-hl-magit-pre-refresh)
    (add-hook 'magit-post-refresh-hook 'diff-hl-magit-post-refresh))

  (general-def 'normal
    "[ h" '(diff-hl-previous-hunk :jump t)
    "] h" '(diff-hl-next-hunk :jump t)))
