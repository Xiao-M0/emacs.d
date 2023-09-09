(provide 'core-config)
(set-language-environment 'utf-8)
(set-default-coding-systems 'utf-8)

(setq user-full-name "XiaoM0"
      user-mail-address "m19357513004@168.com")

;; basic
(menu-bar-mode -1); 菜单栏
(tool-bar-mode -1) ; 工具栏
(toggle-scroll-bar -1) ; 滚动条
(defalias 'yes-or-no-p 'y-or-n-p) ; 简化
(electric-pair-mode t) ; 自动补全括号
(global-auto-revert-mode t)
(setq make-backup-files nil ; 关闭自动备份
      auto-save-default nil
      auto-save-list-file-prefix nil
      create-lockfiles nil
      inhibit-startup-message t)  ;关闭欢迎界面
(delete-selection-mode t) ; 选中文本后输入文本会替换文本
(add-hook 'prog-mode-hook #'hs-minor-mode) ; 编程模式下,可以折叠代码块
(add-hook 'prog-mode-hook #'show-paren-mode) ; 编程模式下，光标在括号上时高亮另一个括号
(display-time-mode -1)

;; 字体
(set-face-attribute 'default nil :family "JetBrains Mono"  :height 150 :weight 'bold)
(set-face-attribute 'fixed-pitch nil :family "JetBrains Mono"  :weight 'bold)
(set-face-attribute 'variable-pitch nil :family "inconsolata" :weight 'bold)

;; 透明背景(linux)
(setq default-frame-alist '((width . 90)
                            (height . 50)
                            (alpha-background . 90)))


(when (eq system-type 'darwin)
  (setq ns-pop-up-frames nil
        frame-resize-pixelwise t))

(setq initial-scratch-message nil   ;; 将暂存缓冲区设为空
      inhibit-startup-message t)    ;; 禁用初始屏幕
(setq-default indent-tabs-mode nil) ;; 使用空格而不是制表符
;; 更改“选项卡宽度”和“填充列”
(setq-default tab-width 4
              fill-column 80)

;; no beep
(setq ring-bell-function 'ignore)


;; (global-hl-line-mode 1) ;; 高亮当前行
(global-prettify-symbols-mode 1) ;; prettify symbols
(setq sentence-end-double-space nil) ;; 句子之间的单空格比双倍更普遍
(setq scroll-conservatively 101 scroll-margin 2) ;; 平滑滚动
(setq compilation-scroll-output 'first-error) ;; 将编译滚动到第一个错误或结尾
(setq delete-by-moving-to-trash t) ;;使用系统垃圾删除文件。
(setq bookmark-save-flag 1) ;; 自动保存每个更改
(setq help-window-select t) ;; keep focus while navigating help buffers
(setq use-short-answers t) ;; yes no 简写
(setq load-prefer-newer t) ;; 不加载过时的编译文件。
(setq kill-do-not-save-duplicates t) ;; 不在kill-ring中保存重复项
;; (setq word-wrap-by-category t) ;; 更多字符后的换行符

;;  如果文件在其他客户端中打开，则删除提示
(defun server-remove-kill-buffer-hook ()
  (remove-hook 'kill-buffer-query-functions 'server-kill-buffer-query-function))
(add-hook 'server-visit-hook #'server-remove-kill-buffer-hook)

;; 不允许光标出现在微型缓冲区提示符中
(setq minibuffer-prompt-properties
      '(read-only t cursor-intangible t face minibuffer-prompt))
(add-hook 'minibuffer-setup-hook #'cursor-intangible-mode)


;; (add-hook 'prog-mode-hook #'goto-address-prog-mode) ;; 转到地址程序模式仅突出显示字符串和注释中的链接
;; (add-hook 'prog-mode-hook #'bug-reference-prog-mode) ;;突出显示并跟踪注释和字符串中的错误引用
;; (add-hook 'prog-mode-hook #'subword-mode) ;; 在程序模式下启用subword-mode
