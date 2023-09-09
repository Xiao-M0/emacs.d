(provide 'init-org)

; org-标记隐藏
(setq org-hide-emphasis-markers t)

; org-font
(with-eval-after-load 'org-faces
                      (dolist (face '((org-level-1 . 1.8)
                                      (org-level-2 . 1.6)
                                      (org-level-3 . 1.4)
                                      (org-level-4 . 1.4)
                                      (org-level-5 . 1.4)
                                      (org-level-6 . 1.4)
                                      (org-level-7 . 1.4)
                                      (org-level-8 . 1.4)))
                        (set-face-attribute (car face) nil :font "inconsolata" :weight 'bold :height (cdr face))))
(use-package org :elpaca t)

;; org-roam
(use-package org-roam
             :elpaca t
             :after org
             :init
             (setq org-roam-directory (file-truename "~/roam"))
             (setq org-roam-v2-ack t)
             (setq org-roam-capture-templates
                   '(("d" "default" plain "%?" :target
                      (file+head "personal/%<%Y%m%d%H%M%S>-${slug}.org" "#+title: ${title}\n") :unnarrowed t)
                     ("w" "work" plain "%?" :target
                      (file+head "work/%<%Y%m%d%H%M%S>-${slug}.org"  "#+title: ${title}\n") :unnarrowed t)
                     ("s" "english" plain "%?" :target
                      (file+head "english/%<%Y%m%d%H%M%S>-${slug}.org"  "#+title: ${title}\n") :unnarrowed t)
                     ))
             :config
             (org-roam-setup)
             (add-to-list 'display-buffer-alist
                          '(("*org-roam*"
                             (display-buffer-in-direction)
                             (direction . right)
                             (window-width . 0.33)
                             (window-height . fit-window-to-buffer))))

             )


(use-package org-modern
             :elpaca t
             :hook (org-mode . org-modern-mode)
             :config
             (setq org-modern-keyword
                   (quote (
                           ("author" . "")
                           ("title" . "")
                           ("subtitle" . "")
                           ("html" . "")
                           )))
             (setq org-modern-star
                   '("" "" "" "" "" ""))

             (setq org-modern-list
                   '((43. "•") (45 . "•") (42 . "•")))
             (setq org-modern-block-name
                   '("" . ""))
             )





;; org-roam-ui
(use-package org-roam-ui
             :elpaca t
             :after org-roam
             :custom
             (org-roam-ui-sync-theme t)
             (org-roam-ui-follow t)
             (org-roam-ui-update-on-save t)
             (org-roam-ui-open-on-start t))

;; org-emphasis
(defun org-emphasis()
  (add-to-list 'org-emphasis-alist
               '("=" (:foreground "#3aa7da"
                                  :background "#333333")))
  (add-to-list 'org-emphasis-alist
               '("*" (bold
                       :foreground "#ff77ca")))
  (add-to-list 'org-emphasis-alist
               '("+" (:foreground "7777ca"
                                  :strike-through t)))
  (add-to-list 'org-emphasis-alist
               '("\/" (italic
                        :foreground "#2ff79a")))
  (add-to-list 'org-emphasis-alist
               '("_" underline
                 :foreground "7777ca"
                 ))
  (add-to-list 'org-emphasis-alist
               '("~" (:box (:line-width 1
                                        :color "grey75"
                                        :style button)))))

(add-hook 'org-mode-hook 'org-emphasis)


(require 'valign)
(add-hook 'org-mode-hook #'valign-mode)
