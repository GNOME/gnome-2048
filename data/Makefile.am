SUBDIRS = icons

gsettings_SCHEMAS = org.gnome.2048.gschema.xml
@GSETTINGS_RULES@

desktopdir = $(datadir)/applications
desktop_in_files = gnome-2048.desktop.in
desktop_DATA = $(desktop_in_files:.desktop.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

EXTRA_DIST = \
	$(gsettings_SCHEMAS) \
	$(desktop_in_files)

CLEANFILES = \
	$(desktop_DATA)

check-local: $(desktop_DATA)
	$(DESKTOP_FILE_VALIDATE) $(desktop_DATA)

-include $(top_srcdir)/git.mk
