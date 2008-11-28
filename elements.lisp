
(in-package :chemicl)

(defclass element ()
  (;; modeling elements after the entries in data/elementdata.xml

   ;; from XML attributes
   (atomic-number :initarg :atomic-number :accessor atomic-number)
   (id :initarg :id :accessor id)
   (name :initarg :name :accessor name)
   (group :initarg :group :accessor group)
   (period :initarg :period :accessor period)

   ;; from XML elements
   (radii :initarg :radii :accessor :radii :initform nil)
   (max-bond-order :initarg :max-bond-order :accessor :max-bond-order)
   (mass :initarg :mass :accessor mass)
   (electronegativity :initarg :electronegativity :accessor electronegativity)

   (isotopes :initarg :isotopes :accessor isotopes :initform nil))
  (:documentation "A class for representing elements of the periodic table."))

(defclass isotope ()
  ((number :initarg :number :accessor isotope-number)
   (exact-mass :initarg :exact-mass :accessor isotope-exact-mass)
   (relative-abundance :initarg :relative-abundance
                       :accessor isotope-relative-abundance)))


(defgeneric print-element-data (object stream)
  (:method ((object element) stream)
    (format stream
            "~S ~S ~S ~S"
            (atomic-number object)
            (id object)
            (name object)
            (mass object))))

(defmethod print-object ((object element) stream)
  (print-unreadable-object (object stream :type t :identity t)
    (print-element-data object stream)))

(defun get-element (identifier)
  "Gets the element indicated by identifier. If identifer is a number,
gets the element whose atomic number is identifier. If identifier is a
string, gets the element whose symbol is identifier."
  (etypecase identifier
    (number (aref *elements* identifier))
    (string (gethash identifier *element-hash*))
    (symbol (gethash (symbol-name identifier) *element-hash*))))

(defmacro with-cml-namespace (&body body)
  `(xpath:with-namespaces ((nil "http://www.xml-cml.org/schema")
                           ("bo" "http://www.blueobelisk.org/dict/terminology" ))
     ,@body))

(defmacro xpath-number (local-name parent-node)
  (let ((node (gensym)))
    `(let ((,node (xpath:evaluate
                   ,local-name
                   ,parent-node)))
       (unless (xpath:node-set-empty-p ,node)
         (xpath:number-value ,node)))))

(defvar *elements*)
(defvar *element-hash* (make-hash-table :test 'equalp))
;;; read in the element data from elementdata.xml, parse it and store
;;; in the *elments* array, with the index into the array specified
;;; by the atomic number of the element.
(macrolet ((parse-integer-if (string-or-nil)
             `(when ,string-or-nil
                (parse-integer ,string-or-nil))))
  (defun read-element-data ()
    (let ((element-list
           (xpath:map-node-set->list 
            (lambda (node)
              (stp:with-attributes ((atomic-number "atomicnumber")
                                    id
                                    name
                                    group
                                    period)
                  node
                (let ((max-bond-order (xpath-number "maxbondorder" node))
                      (mass (xpath-number "mass" node))
                      (electronegativity (xpath-number "electronegativity" node)))                  
                  (make-instance 'element
                                 :atomic-number (parse-integer-if atomic-number)
                                 :id id
                                 :name name
                                 :group group
                                 :period (parse-integer-if period)
                                 :mass mass
                                 :electronegativity electronegativity
                                 :max-bond-order max-bond-order))))
            (xpath:evaluate "/elements/element"
                            (cxml:parse-file 
                             (asdf:component-pathname
                              (let ((path '("chemicl" "data" "elementdata.xml")))
                                (reduce #'asdf:find-component (cdr path)
                                        :initial-value (asdf:find-system (car path)))))
                             (stp:make-builder))))))
      (let ((max-element (apply #'max (map 'list #'atomic-number element-list))))
        (let ((array (make-array (1+ max-element) :adjustable nil)))
          (loop for l in element-list
             do (setf (aref array (atomic-number l)) l
                      (gethash (id l) *element-hash*) l))
          (setf *elements* array)))))
  (defun read-isotope-data ()
    (declare (optimize (debug 3)))
    (with-cml-namespace
      (xpath:map-node-set
       (lambda (isotope-list-node)
         (stp:with-attributes (id)
             isotope-list-node
           (setf (isotopes (get-element id))
                 (sort 
                  (xpath:map-node-set->list
                   (lambda (isotope-node)
                     (stp:with-attributes (number)
                         isotope-node
                       (make-instance
                        'isotope
                        :number (xpath:number-value number)
                        :exact-mass
                        (xpath-number
                         "scalar[attribute::dictRef=\"bo:exactMass\"]"
                         isotope-node)
                        :relative-abundance
                        (/ (or (xpath-number
                                "scalar[attribute::dictRef=\"bo:relativeAbundance\"]"
                                isotope-node)
                               0) 100))))
                   (xpath:evaluate "isotope" isotope-list-node))
                  #'> :key #'isotope-relative-abundance))))
       (xpath:evaluate "/cml/isotopeList"
                       (cxml:parse-file 
                        (asdf:component-pathname
                         (let ((path '("chemicl" "data" "isotopes.xml")))
                           (reduce #'asdf:find-component (cdr path)
                                   :initial-value (asdf:find-system (car path)))))
                        (stp:make-builder)))))))
(read-element-data)
(read-isotope-data)

(defparameter *element-normal-valences*
  (let ((hash (make-hash-table :test 'eq))
        (valence-list '(("B" 3)
                        ("C" 4)
                        ("N" 3 5)
                        ("O" 2)
                        ("P" 3 5)
                        ("S" 2 4 6)
                        ("F" 1)
                        ("Cl" 1)
                        ("Br" 1)
                        ("I" 1))))
    (map nil (lambda (x)
               (destructuring-bind (symbol &rest valences)
                   x
                 (let ((element (get-element symbol)))
                   (setf (gethash element hash) valences))))
         valence-list)
    hash))

(defgeneric get-normal-valence (element)
  (:method ((element element))
    (gethash element *element-normal-valences*)))
