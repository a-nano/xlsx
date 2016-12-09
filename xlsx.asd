#|
  This file is a part of xlsx project.
  Copyright (c) 2015 Carlos Ungil
|#

#|
  Author: Carlos Ungil <ungil@mac.com>
|#

(in-package :cl-user)
(defpackage xlsx-asd
  (:use :cl :asdf))
(in-package :xlsx-asd)

(defsystem xlsx
  :version "0.1"
  :author "Carlos Ungil"
  :license "MIT license"
  :depends-on (:zip
               :babel
               :xmls)
  :components ((:module "src"
                :components
                ((:file "xlsx"))))
  :description ""
  :long-description
  #.(with-open-file (stream (merge-pathnames
                             #p"README.markdown"
                             (or *load-pathname* *compile-file-pathname*))
                            :if-does-not-exist nil
                            :direction :input)
      (when stream
        (let ((seq (make-array (file-length stream)
                               :element-type 'character
                               :fill-pointer t)))
          (setf (fill-pointer seq) (read-sequence seq stream))
          seq)))
  :in-order-to ((test-op (test-op xlsx-test))))
