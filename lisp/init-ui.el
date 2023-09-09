(provide 'init-ui)

(use-package hl-todo
             :elpaca t
             :hook ((prog-mode org-mode) . lc/hl-todo-init)
             :init
             (defun lc/hl-todo-init ()
               (setq-local hl-todo-keyword-faces '(("HOLD" . "#cfdf30")
                                                   ("TODO" . "#ff9977")
                                                   ("NEXT" . "#b6a0ff")
                                                   ("PROG" . "#00d3d0")
                                                   ("FIXME" . "#ff9977")
                                                   ("DONE" . "#44bc44")
                                                   ("REVIEW" . "#6ae4b9")
                                                   ("DEPRECATED" . "#bfd9ff")))
               (hl-todo-mode))
             )

(use-package highlight-parentheses
             :elpaca t
             :hook (prog-mode . highlight-parentheses-mode)
             :config
             (setq highlight-parentheses-colors '("Springgreen3"
                                                  "IndianRed1"
                                                  "IndianRed3"
                                                  "IndianRed4"))
             (set-face-attribute 'highlight-parentheses-highlight nil :weight 'ultra-bold))

;; hide-mode-line
(use-package hide-mode-line
             :elpaca t
             :config
             (global-hide-mode-line-mode)
             )
;; ivy
(use-package ivy
             :elpaca t
             :config
             (ivy-mode)
             )

(use-package ivy-posframe
             :elpaca t
             :init
             (ivy-posframe-mode)
             )
(setq ivy-posframe-display-functions-alist '((t . ivy-posframe-display-at-frame-center)))

;; tag
(use-package svg-tag-mode
             :elpaca t
             :hook (org-mode . svg-tag-mode)
             :config
             (setq svg-tag-tags
                   '(
                     (":TODO:" .  (( lambda (tag)  (svg-tag-make tag :beg 1 :end -1 :face "#ddee88" :inverse t :height 0.7 :font-size 11 :margin -2))))
                     (":DOME:" .  (( lambda (tag)  (svg-tag-make tag :beg 1 :end -1 :face "#ddddee" :inverse t :height 0.7 :font-size 11 :margin -2))))

                     ("adj\\." .  (( lambda (tag)  (svg-tag-make tag :end -1 :face "#eeadae" :inverse t :height 0.7 :font-size 10 ))))
                     ("adv\\." .  (( lambda (tag)  (svg-tag-make tag :end -1 :face "#3e8dae" :inverse t :height 0.7 :font-size 10 ))))
                     ("conj\\." .  (( lambda (tag)  (svg-tag-make tag :end -1 :face "#ae9d3e" :inverse t :height 0.7 :font-size 10 ))))
                     ("eg\\."   .  (( lambda (tag)  (svg-tag-make "例" :face "#fe6d4e" :inverse t :height 0.7 :font-size 10 ))))
                     )
                   )
             )
