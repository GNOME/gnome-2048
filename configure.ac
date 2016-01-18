AC_PREREQ([2.63])
AC_INIT([gnome-2048], [3.19.4], [http://www.gnome.org],
        [gnome-2048])
AC_CONFIG_MACRO_DIR([m4])

AM_INIT_AUTOMAKE([1.11 no-dist-gzip dist-xz foreign])
AM_SILENT_RULES([yes])
AM_MAINTAINER_MODE

AM_PROG_VALAC([0.24.0])
AM_PROG_CC_C_O

GLIB_GSETTINGS

APPSTREAM_XML

dnl ###########################################################################
dnl Dependencies
dnl ###########################################################################

GTK_REQUIRED=3.12.0
CLUTTER_REQUIRED=1.12.0
CLUTTER_GTK_REQUIRED=1.6.0
GEE_REQUIRED=0.14.0
LIBGAMES_REQUIRED=0.1

PKG_CHECK_MODULES(GNOME_2048, [
  gtk+-3.0 >= $GTK_REQUIRED
  clutter-1.0 >= $CLUTTER_REQUIRED
  clutter-gtk-1.0 >= $CLUTTER_GTK_REQUIRED
  gee-0.8 >= $GEE_REQUIRED
  libgames-support-1.0 >= $LIBGAMES_REQUIRED
])

AC_PATH_PROG([DESKTOP_FILE_VALIDATE], [desktop-file-validate], [/bin/true])

GLIB_COMPILE_RESOURCES=`$PKG_CONFIG --variable glib_compile_resources gio-2.0`
AC_SUBST(GLIB_COMPILE_RESOURCES)

dnl ###########################################################################
dnl Internationalization
dnl ###########################################################################

IT_PROG_INTLTOOL([0.50])
AC_SUBST(GETTEXT_PACKAGE, gnome-2048)

dnl ###########################################################################
dnl Documentation
dnl ###########################################################################

YELP_HELP_INIT

dnl ###########################################################################
dnl Files to generate
dnl ###########################################################################

AC_CONFIG_FILES([
Makefile
po/Makefile.in
data/Makefile
data/icons/Makefile
data/icons/hicolor/Makefile
src/Makefile
help/Makefile
])
AC_OUTPUT
