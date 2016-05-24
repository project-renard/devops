brew update
brew install gtk\+3 gtk-doc clutter-gtk gtk-engines gtk-gnutella gtk-mac-integration gtk-murrine-engine gtk-vnc gtkdatabox gtkextra gtkglext gtkmm gtkmm3 gtksourceview gtksourceview3 gtksourceviewmm gtksourceviewmm3 gtkspell3 lablgtk pygtk pygtkglext pygtksourceview webkitgtk

export PKG_CONFIG_PATH==/usr/local/Cellar/libffi/3.0.13/lib/pkgconfig/

cpanm --installdeps ../curie/
