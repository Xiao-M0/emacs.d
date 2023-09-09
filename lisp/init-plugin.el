(provide 'init-plugin)
;; Theme
(use-package doom-themes
             :config
             (setq doom-themes-enable-bold t
                   doom-themes-enable-italic t)
             (load-theme 'doom-one t)
             (doom-themes-visual-bell-config)
             (doom-themes-neotree-config)
             (setq doom-themes-treemacs-theme "doom-tokyo-night")
             (doom-themes-treemacs-config)
             (doom-themes-org-config)
             )

(defun lc/load-theme ()
  (load-theme 'doom-tokyo-night t)
  )

(add-hook 'emacs-startup-hook 'lc/load-theme)

;; dashboard
(use-package dashboard
             :elpaca t
             :init
             (setq dashboard-center-content t)
             (setq dashboard-projects-backend 'projectile)
             (setq dashboard-set-heading-icons t)
             (setq dashboard-set-file-icons t)
             (setq dashboard-banner-logo-title nil)
             (setq dashboard-set-footer nil)
             (setq dashboard-startup-banner "~/.emacs.d/logo.png")
             (setq dashboard-set-navigator t)
             (setq dashboard-navigator-buttons
                   `((
                      ;; github
                      ("¤", "hub","go to gitee"
                       (lambda (&rest _) (browse-url "https://gitee.com/xiaom0/org-note")))
                      )))

             :config
             (dashboard-setup-startup-hook)
             (setq dashboard-items '())
             )

;; darkroom
(use-package darkroom
             :elpaca t
             :init (setq darkroom-text-scale-increase 3)
             ;; :hook (org-mode . darkroom-tentative-mode)
             )

;; fanyi
(setq read-extended-command-predicate #'command-completion-default-include-p)
(use-package fanyi 
             :elpaca t
             :custom
             (fanyi-providers '(
                                fanyi-haici-provider
                                fanyi-youdao-thesaurus-provider
                                ))
             )

;; snippet
(use-package yasnippet
             :elpaca t
             :general
             (yas-minor-mode-map
               :states 'insert
               "TAB" 'nil
               )
              :hook (org-mode . yas-global-mode)
              )

(elpaca ivy-yasnippet)
(global-set-key (kbd "M-/") 'ivy-yasnippet)

;; whitespace
(use-package whitespace
  :elpaca nil
  :hook ((org-mode . show-trailing-whitespace)
         (diff-mode . whitespace-mode))
  :config
  (defun show-trailing-whitespace ()
    (set-face-attribute 'trailing-whitespace nil :background
                        (face-attribute 'font-lock-comment-face
                                        :foreground))
    (setq show-trailing-whitespace t)))


;; 输入法
(defun st()
  "转化并选择"
  (interactive)
    (pyim-convert-string-at-point)
    (execute-kbd-macro (read-kbd-macro "SPC"))
  )

(use-package pyim
             :elpaca t
             :init
             (setq default-input-method "pyim")
             (setq pyim-page-posframe-min-with 2)
             :config
             ; add flypy method
             (pyim-scheme-add
               '(x
                  :document "形码"
                  :class xingma
                  :first-chars "abcdefghijklmnopqrstuvwxyz"
                  :rest-chars "abcdefghijklmnopqrstuvwxyz'"
                  :code-prefix "x/"
                  :code-split-length 4
                  :code-maximum-length 4
                  :prefer-triggers nil))
           (define-key pyim-mode-map ";"
              (lambda ()
                (interactive)
                (pyim-select-word-by-number 2)))
             (pyim-default-scheme 'x)

             )

(setq pyim-dicts
      '((:name "x" :file "/home/xiaomo/.emacs.d/dict/pyim-x.pyim")
        ))

(add-hook 'org-mode
          (lambda () (pyim-restart-1 t)))
;; 金手指
;; (global-set-key (kbd "M-j") 'st)
;; (global-set-key (kbd "M-h") 'pyim-convert-string-at-point)
(setq pyim-page-length 2) ;; 显示 2 个候选词
(global-set-key (kbd "<f6>") 'toggle-input-method)
(global-set-key (kbd "M-m") 'toggle-input-method)
(setq pyim-page-tooltip '(posframe popup minibuffer))
(setq pyim-page-style 'one-line)


(setq-default pyim-punctuation-translate-p '(no)) ;; 半角

;; 关闭
(setq pyim-cloudim nil)
(setq pyim-candidates-search-buffer-p nil)
(setq pyim-enable-shortcode nil)
(setq pyim-dcache-auto-update nil)
