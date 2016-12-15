# xlsx
Carlos Ungil's Basic reader for Excel files.
Modified to Japanese version.
Added function as-alist and as-plist.

Original  [https://gitlab.common-lisp.net/cungil/xlsx](https://gitlab.common-lisp.net/cungil/xlsx)

## Usage

```common-lisp

(xlsx:list-sheets "test.xlsx")
;-> ((1 "Sheet1" "worksheets/sheet1.xml") (2 "Sheet2" "worksheets/sheet2.xml"))

(xlsx:read-sheet "test.xlsx" "Sheet1")
;-> (((:A . 1) . 82) ((:B . 1) . "日本語の確認１") ((:A . 2) . 41))

(xlsx:as-matrix (xlsx:read-sheet "test.xlsx" "Sheet1"))
;-> #2A((82 "日本語の確認１") (41 NIL))
;-> (:A :B)
;-> (1 2)

(xlsx:as-alist (xlsx:read-sheet "test.xlsx" "Sheet1"))
;-> ((:A1 . 82) (:B1 . "日本語の確認１") (:A2 . 41))

(xlsx:as-plist (xlsx:read-sheet "test.xlsx" "Sheet1"))
;-> (:A1 82 :B2 "日本語の確認１" :A2 41)

```


## Installation
```bash
cd $HOME/quicklisp/local-projects
git clone https://github.com/a-nano/xlsx.git
```
Then, use quicklisp to install the libraries required by xlsx:

Start your lisp. Then, just:

```common-lisp
(ql:quickload :xlsx)
```

## Author

* Carlos Ungil (original)

* Akihide Nano (modified)

## Copyright

Copyright (c) 2015 Carlos Ungil

## License

Licensed under the MIT license License.
