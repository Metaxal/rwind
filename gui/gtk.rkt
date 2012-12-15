#lang racket/base

(require rwind/doc-string
         mred/private/wx/gtk/x11
         mred/private/wx/gtk/utils
         mred/private/wx/gtk/types
         ffi/unsafe
         racket/class
         )

#| Resources
- GtkWidget: http://developer.gnome.org/gtk/2.24/GtkWidget.html
- Extending the Racket GUI with native widgets: 
  - https://groups.google.com/d/topic/racket-users/cduCU_kiY-w/discussion
    + see misc/test-gtk-Crust.rkt
  - https://groups.google.com/d/topic/racket-users/T2OHHz7Im48/discussion
|#


;(define-gtk gtk_widget_get_root_window (_fun _GtkWidget -> _GdkWindow))
(define-gtk gtk_widget_get_parent_window  (_fun _GtkWidget -> _GdkWindow))
(define-gtk gtk_widget_get_parent         (_fun _GtkWidget -> _GtkWidget))
(define-gtk gtk_widget_get_name           (_fun _GtkWidget -> _string))
(define-gtk gtk_widget_get_toplevel       (_fun _GtkWidget -> _GtkWidget))
(define-gtk gtk_widget_get_window         (_fun _GtkWidget -> _GdkWindow))

(define* (widget-x11-window widget [client? #f])
  (gdk_x11_drawable_get_xid 
   (gtk_widget_get_window 
    (if client?
        (send widget get-client-handle)
        (send widget get-handle)))))

(define* (widget-x11-top-level-window widget [client? #f])
  (widget-x11-window (send widget get-top-level-window) client?))