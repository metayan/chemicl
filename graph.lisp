;;; file: graph.lisp
;;; author: cyrus harmon
;;;
;;; Copyright (c) 2008 Cyrus Harmon (ch-lisp@bobobeach.com)
;;; All rights reserved.
;;;
;;; Redistribution and use in source and binary forms, with or without
;;; modification, are permitted provided that the following conditions
;;; are met:
;;;
;;;   * Redistributions of source code must retain the above copyright
;;;     notice, this list of conditions and the following disclaimer.
;;;
;;;   * Redistributions in binary form must reproduce the above
;;;     copyright notice, this list of conditions and the following
;;;     disclaimer in the documentation and/or other materials
;;;     provided with the distribution.
;;;
;;; THIS SOFTWARE IS PROVIDED BY THE AUTHOR 'AS IS' AND ANY EXPRESSED
;;; OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
;;; WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
;;; ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
;;; DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
;;; DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
;;; GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
;;; INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
;;; WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
;;; NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
;;; SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

(in-package :chemicl)

;;;
;;; nodes
(defclass node ()
  ((name :accessor node-name :initarg :name :initform nil)
   (data :accessor node-data :initarg :data :initform nil))
  (:documentation "A simple class for representing nodes in a graph,
  which will consist of a set of nodes, and a set of edges between the
  nodes."))

(defmethod print-object ((object node) stream)
  (print-unreadable-object (object stream :type t :identity t)
    (format stream "~S" (node-name object))))

;;;
;;; graphs and generic functions for operating on graphs
(defclass graph ()
  ((nodes :accessor graph-nodes :initarg :nodes :initform nil))
  (:documentation "The protocol class of graphs. The intent is that
  there will be concrete subclasses of graph with different
  implementations of storing the nodes and edges."))

(defgeneric add-edge (graph node1 node2)
  (:documentation "Adds an edge to the graph from node1 to node2."))

(defgeneric remove-edge (graph node1 node2)
  (:documentation "Removes the edge from node1 to node2 in the
  graph."))

(defgeneric edgep (graph node1 node2)
  (:documentation "Returns the edge that connects node1 and node2 in
  graph if the edge is present in the graph, otherwise returns NIL."))

(defgeneric find-edges-from (graph node)
  (:documentation "Returns a list of the edges in graph that begin
  with node."))

(defgeneric find-edges-to (graph node)
  (:documentation "Returns a list of the edges in graph that end
  with node."))

(defgeneric find-edges-containing (graph node)
  (:documentation "Returns a list of the edges in graph that start or
  end with node."))

(defgeneric bfs (graph start end)
  (:documentation "Performs a breadth-first-search on graph starting
  at start and returns a path end if end is
  reachable from start, otherwise returns NIL."))

(defgeneric dfs (graph start end)
  (:documentation "Performs a depth-first-search on graph starting
  at start and returns a path end if end is
  reachable from start, otherwise returns NIL."))

;; note that saved the path in bfs results in possible quadratic
;; storage for bfs. There's probably a better way to do this. The
;; good news is that the path can't be longer than the number of
;; nodes, so it doesn't require exponential storage.
(defmethod bfs ((graph graph) start end)
  (let (visited)
    (labels
        ((bfs-visit (node-set-list)
           (let (children)
             (map nil
                  (lambda (node-and-path)
                    (destructuring-bind (node . path)
                        node-and-path
                      (when (eq node end)
                        (return-from bfs
                          (nreverse (cons node path))))
                      (push node visited)
                      (let ((edges (find-edges-containing graph node)))
                        (let ((neighbors (map (type-of edges) #'cdr edges)))
                          (map nil
                               (lambda (x)
                                 (unless (member x visited)
                                   (push (cons x (cons node path)) children)))
                               neighbors)))))
                  node-set-list)
             (when children
               (bfs-visit children)))))
      (bfs-visit (list (cons start nil))))))

(defmethod bfs-map ((graph graph) start fn &key end)
  (let (visited)
    (labels
        ((bfs-visit (node-list)
           (let (children)
             (map nil
                  (lambda (node)
                    (funcall fn node)
                    (when (and end
                             (eq node end))
                      (return-from bfs-map))
                    (push node visited)
                    (let ((edges (find-edges-containing graph node)))
                      (let ((neighbors (map (type-of edges) #'cdr edges)))
                        (map nil
                             (lambda (x)
                               (unless (member x visited)
                                 (push x children)))
                             neighbors))))
                  node-list)
             (when children
               (bfs-visit children)))))
      (bfs-visit (list start)))))

(defmethod dfs ((graph graph) start end)
  (let ((visited (list start)))
    (labels ((dfs-visit (node path)
               (if (eq node end)
                   (return-from dfs (nreverse (cons node path)))
                   (let ((edges (find-edges-containing graph node)))
                     (let ((neighbors (map (type-of edges) #'cdr edges)))
                       (map nil
                            (lambda (x)
                              (unless (member x visited)
                                (push x visited)
                                (dfs-visit x (cons node path))))
                            neighbors))))))
      (dfs-visit start nil))))

(defmethod dfs-map ((graph graph) start fn &key end)
  (let ((visited (list start)))
    (labels ((dfs-visit (node path)
               (funcall fn node)
               (when (and end
                          (eq node end))
                 (return-from dfs-map))
               (let ((edges (find-edges-containing graph node)))
                 (let ((neighbors (map (type-of edges) #'cdr edges)))
                   (map nil
                        (lambda (x)
                          (unless (member x visited)
                            (push x visited)
                            (dfs-visit x (cons node path))))
                        neighbors)))))
      (dfs-visit start nil))))


;;;
;;; edge list graph
(defclass edge-list-graph (graph)
  ((edges :accessor graph-edge-list :initarg :edges :initform nil))
  (:documentation "A concrete subclass of graph that represents the
  edges in the graph with a list of edges between nodes."))

(defmethod graph-edges ((graph edge-list-graph))
  (graph-edge-list graph))

(defmethod add-edge ((graph edge-list-graph) (node1 node) (node2 node))
  (pushnew node1 (graph-nodes graph))
  (pushnew node2 (graph-nodes graph))
  (let ((edge (cons node1 node2)))
    (pushnew edge (graph-edges graph) :test 'equalp)))

(defmethod remove-edge ((graph edge-list-graph) (node1 node) (node2 node))
  (let ((edge (cons node1 node2)))
    (setf (graph-edges graph)
          (remove edge (graph-edges graph) :test 'equalp))))

(defmethod edgep ((graph edge-list-graph) (node1 node) (node2 node))
  (find (cons node1 node2) (graph-edges graph) :test 'equalp))

(defmethod find-edges-from ((graph edge-list-graph) node)
  (remove-if-not (lambda (x)
                   (eq node x))
                 (graph-edges graph) :key #'car))

(defmethod find-edges-to ((graph edge-list-graph) node)
  (remove-if-not (lambda (x)
                   (eq node x))
                 (graph-edges graph) :key #'cdr))

(defmethod find-edges-containing ((graph edge-list-graph) node)
  (union (find-edges-from graph node)
         (find-edges-to graph node)))

