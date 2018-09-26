(in-package #:xlsx)

(defun list-entries (file)
  (zip:with-zipfile (zip file)
    (loop for k being the hash-keys of (zip:zipfile-entries zip) collect k)))

(defun get-entry (name zip)
  (let ((entry (zip:get-zipfile-entry name zip)))
    (when entry (xmls:parse (babel:octets-to-string (zip:zipfile-entry-contents entry))))))

(defun get-relationships (zip)
  (loop for rel in (xmls:xmlrep-find-child-tags 
		    :relationship (get-entry "xl/_rels/workbook.xml.rels" zip))
     collect (cons (xmls:xmlrep-attrib-value "Id" rel)
		   (xmls:xmlrep-attrib-value "Target" rel))))

(defun get-unique-strings (zip)
  (loop for str in (xmls:xmlrep-find-child-tags :si (get-entry "xl/sharedStrings.xml" zip))
     for x = (xmls:xmlrep-find-child-tag :t str)
     collect (xmls:xmlrep-string-child x)))

(defun get-number-formats (zip)
  (let ((format-codes (loop for fmt in (xmls:xmlrep-find-child-tags
					:numFmt (xmls:xmlrep-find-child-tag
						 :numFmts (get-entry "xl/styles.xml" zip) (xmls:make-node)))
			 collect (cons (parse-integer (xmls:xmlrep-attrib-value "numFmtId" fmt))
				       (xmls:xmlrep-attrib-value "formatCode" fmt)))))
    (loop for style in (xmls:xmlrep-find-child-tags
			:xf (xmls:xmlrep-find-child-tag
			     :cellXfs (get-entry "xl/styles.xml" zip)))
       collect (let ((fmt-id (parse-integer (xmls:xmlrep-attrib-value "numFmtId" style))))
		 (cons fmt-id (if (< fmt-id 164)
				  :built-in
				  (cdr (assoc fmt-id format-codes))))))))

(defun column-and-row (colrow)
  (loop for char across colrow
     for pos from 0
     while (alpha-char-p char) collect char into column
     finally (return (cons (intern (coerce column 'string) "KEYWORD")
			   (parse-integer colrow :start pos)))))

(defun excel-date (int)
  (apply #'format nil "~D-~2,'0D-~2,'0D"
	 (reverse (subseq (multiple-value-list (decode-universal-time (* 24 60 60 (- int 2)))) 3 6))))

(defun list-sheets (file)
  "Retrieves the id and name of the worksheets in the .xlsx/.xlsm file."
  (zip:with-zipfile (zip file)
    (loop for sheet in (xmls:xmlrep-find-child-tags
			:sheet (xmls:xmlrep-find-child-tag
				:sheets (get-entry "xl/workbook.xml" zip)))
       with rels = (get-relationships zip)
       for sheet-id = (xmls:xmlrep-attrib-value "sheetId" sheet)
       for sheet-name = (xmls:xmlrep-attrib-value "name" sheet)
       for sheet-rel = (xmls:xmlrep-attrib-value "id" sheet)
       collect (list (parse-integer sheet-id)
		     sheet-name 
		     (cdr (assoc sheet-rel rels :test #'string=))))))

(defun read-sheet (file &optional sheet)
  "Retrives the contents of the given worksheet as a list of cells of the form ((:A . 1) . 42)
A numeric id or name is required unless the file contains a single worksheet."
  (let* ((sheets (list-sheets file))
	 (entry-name (cond ((and (null sheet) (= 1 (length sheets)))
			    (third (first sheets)))
			   ((stringp sheet)
			    (third (find sheet sheets :key #'second :test #'string=)))
			   ((numberp sheet)
			    (third (find sheet sheets :key #'first))))))
    (unless entry-name
      (error "specify one of the following sheet ids or names: ~{~&~{~S~^~5T~}~}"
	     (loop for (id name) in sheets collect (list id name))))
    (zip:with-zipfile (zip file)
      (loop for row in (xmls:xmlrep-find-child-tags
			:row (xmls:xmlrep-find-child-tag
			      :sheetData (get-entry (format nil "xl/~A" entry-name) zip)))
	 with unique-strings = (get-unique-strings zip)
	 with number-formats = (get-number-formats zip)
	 append (loop for c in (xmls:xmlrep-children row)
		   for col-row = (column-and-row (xmls:xmlrep-attrib-value "r" c))
		   for value = (xmls:xmlrep-find-child-tag :v c nil)
		   for type = (xmls:xmlrep-attrib-value "t" c nil)
		   for style = (xmls:xmlrep-attrib-value "s" c nil)
		   for date? = (and style
				    (destructuring-bind (id . fmt) (elt number-formats (parse-integer style))
				      (or (<= 14 id 17) ;; built-in: m/d/yyyy d-mmm-yy d-mmm mmm-yy
					  (and (stringp fmt) (not (search "h" fmt)) (not (search "s" fmt))
					       (search "d" fmt) (search "m" fmt) (search "y" fmt)))))
		   when value
		   collect (let ((value (ignore-errors (xmls:xmlrep-string-child value))))
			     (when (null value) (warn "cell contents missing at ~A ~A [ ~A ~A ]"
						      (car col-row) (cdr col-row) file entry-name))
			     (cons col-row
				   (cond ((equal type "e") (intern value "KEYWORD")) ;;ERROR
					 ((equal type "str") value) ;; CALCULATED STRING
					 ((equal type "s") (nth (parse-integer value) unique-strings))
					 (date? (excel-date (parse-integer value)))
					 (t (read-from-string value))))))))))

(defun as-matrix (xlsx &optional na-string)
  "Creates an array from a list of cells of the form ((:A . 1) . 42)
Empty columns or rows are ignored (column and row names are returned as additional values).
When a value is equal to na-string, nil is returned instead."
  (declare (optimize speed))
  (let* ((refs (mapcar #'first xlsx))
	 (cols (sort (remove-duplicates (mapcar #'car refs)) #'string< :key (lambda (x) (format nil "~3@A" x))))
	 (rows (sort (remove-duplicates (mapcar #'cdr refs)) #'<))
	 (output (make-array (list (length rows) (length cols)) :initial-element nil)))
    (loop for ((col . row) . val) in xlsx
       do (setf (aref output (the fixnum (position row rows)) (the fixnum (position col cols)) )
		(if (equal val na-string) nil val)))
    (values output cols rows)))

(defun as-alist (xlsx)
  "Creates an a-list from a list of cells of the form ((:A1 . 42) (:B1 . 21))"
  (mapcar #'(lambda (lst)
              (cons (intern (concatenate 'string
                                         (symbol-name (caar lst))
                                         (write-to-string (cdar lst))) :keyword)
                    (cdr lst)))
          xlsx))    

(defun as-plist (xlsx)
    "Creates a p-list from a list of cells of the form (:A1 42 :B1 21)"
  (mapcan #'(lambda (lst)
              (cons (intern (concatenate 'string
                                         (symbol-name (caar lst))
                                         (write-to-string (cdar lst))) :keyword)
                    (list (cdr lst))))
          xlsx))
