(setq gc-cons-threshold most-positive-fixnum gc-cons-percentage 0.6)
(add-hook 'emacs-startup-hook
          (defun reset-gc-cons-threshold ()
            (setq gc-cons-threshold 100000000 gc-cons-percentage 0.1)))

(setq package-enable-at-startup nil) ;; 禁止包初始化
(setq frame-inhibit-implied-resize t) ;; 禁止调整帧大小
(setq byte-compile-warnings nil) ;; 禁止字节编译器警告

;; 删除一些不需要的 UI 元素
(push '(menu-bar-lines . 0) default-frame-alist) ;; 菜单栏
(push '(tool-bar-lines . 0) default-frame-alist) ;; 工具栏
(push '(vertical-scroll-bars) default-frame-alist)
(push '(internal-border-width . 0) default-frame-alist)
(when (featurep 'ns)
  (push '(ns-transparent-titlebar . t) default-frame-alist))
