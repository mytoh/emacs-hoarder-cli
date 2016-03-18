;;; hoarder --- hoarder -*- lexical-binding: t; coding: utf-8; -*-

(require 'cl-lib)
(require 'cl-generic)
(require 'pcase)

(add-to-list 'load-path (expand-file-name "~/huone/ateljee/emacs-glof"))
(add-to-list 'load-path (expand-file-name "~/huone/ateljee/emacs-colle"))
(add-to-list 'load-path (expand-file-name "~/huone/ateljee/emacs-hoarder"))

(require 'hoarder)
(require 'glof)


(cl-defun hoarder:update-package-git-async-make-process (package)
  (when (glof:get package :origin)
    (cl-letf ((name (glof:get package :name))
              (path (glof:get package :path))
              (type (glof:get package :type)))
      (when (and (cl-equalp :git type)
               (not (file-symlink-p path)))
        (cl-letf* ((proc-buf (get-buffer-create (format "hoarder-git-%s" (glof:get package :origin))))
                   (proc-name (format "hoarder-git-pull-%s" (glof:get package :origin))))
          (cl-labels ((sentinel-cb (process signal)
                        (cond
                          ((equal signal "finished\n")
                           (cl-letf ((result (with-current-buffer (process-buffer process)
                                               (buffer-substring (point-min) (point-max)))))
                             (pcase result
                               ((guard (not (hoarder:git-already-updatedp result)))
                                (hoarder:message "updating package %s" name)
                                (when (glof:get package :compile)
                                  (hoarder:message "compiling package %s" name)
                                  (hoarder:option-compile package path))
                                (hoarder:option-build package)))
                             (kill-buffer (process-buffer process))))
                          (t
                           (message name)
                           (princ (format "error %s\n"
                                          (glof:get package :path)))
                           (message "got signal %s" signal)
                           (display-buffer (process-buffer process))))))
            (make-process
             :name proc-name
             :buffer proc-buf
             :command (list "git" "--no-pager" "-C" path "pull" )
             :sentinel #'sentinel-cb)))))))

(cl-defun hoarder:update-package-hg-async-make-process (package)
  (when (glof:get package :origin)
    (cl-letf ((name (glof:get package :name))
              (path (glof:get package :path))
              (type (glof:get package :type)))
      (when (and (cl-equalp :hg type)
               (not (file-symlink-p path)))
        (cl-letf* ((proc-buf (get-buffer-create (format "hoarder-hg-%s" (glof:get package :origin))))
                   (proc-name (format "hoarder-hg-pull-%s" (glof:get package :origin))))
          (cl-labels ((sentinel-cb (process signal)
                        (cond
                          ((equal signal "finished\n")
                           (cl-letf ((result (with-current-buffer (process-buffer process)
                                               (buffer-substring (point-min) (point-max)))))
                             (pcase result
                               ((guard (not (hoarder:hg-already-updatedp result)))
                                (hoarder:message "updating package %s" name)
                                (when (glof:get package :compile)
                                  (hoarder:message "compiling package %s" name)
                                  (hoarder:option-compile package path))
                                (hoarder:option-build package)))
                             (hoarder:message name)
                             (kill-buffer (process-buffer process))))
                          (t
                           (message name)
                           (princ (format "error %s\n"
                                          (glof:get package :path)))
                           (message "got signal %s" signal)
                           (display-buffer (process-buffer process))))))
            (make-process
             :name proc-name
             :buffer proc-buf
             :command (list "hg" "--cwd" path "pull" "--update" )
             :sentinel #'sentinel-cb)))))))

(cl-defun hoarder:update-package-async-make-process (package)
  (pcase (glof:get package :type)
    (:git (hoarder:update-package-git-async-make-process package))
    (:hg (hoarder:update-package-hg-async-make-process package))))

(cl-defun hoarder-async-update-make-process ()
  (interactive)
  (cl-letf ((pkgs
             (seq-partition
              ;; (seq-take hoarder:*packages* 8)
              hoarder:*packages*
              5)))
    (seq-each
     (lambda (pkg)
       (thread-last pkg
         (seq-map #'hoarder:update-package-async-make-process)
         (seq-each #'accept-process-output)))
     pkgs))
  (message "update finished"))

(defun main (args)
  (cl-letf ((muki:hoarder-directory
             (expand-file-name (file-name-as-directory "vendor")
                               user-emacs-directory)))
    (hoarder:initialize muki:hoarder-directory))

  (load "~/.emacs.d/init.d/layer/package-manager/register/init.el")

  (pcase (car args)
    ((or "up" "update")
     (hoarder-async-update-make-process))
    ("check"
     (hoarder:check))))

(main (cdr argv))

;; Local Variables:
;; mode: emacs-lisp
;; End:
