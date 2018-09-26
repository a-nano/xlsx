(asdf:defsystem #:xlsx
  :version "0.3"
  :name "XLSX"
  :description "Basic reader for Excel files."
  :author "Carlos Ungil <ungil@mac.com>, Akihide Nano <an74abc@gmail.com>"
  :license "MIT"
  :serial t
  :components ((:module "src"
			:components
			((:file "package")
			 (:file "xlsx"))))
  :depends-on (:zip
	       :xmls
	       :babel)
  :in-order-to ((test-op (test-op xlsx-test))))
