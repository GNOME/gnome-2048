SUBDIRS = icons

gsettings_SCHEMAS = org.gnome.2048.gschema.xml
@GSETTINGS_RULES@

desktopdir = $(datadir)/applications
desktop_in_files = org.gnome.gnome-2048.desktop.in
desktop_DATA = $(desktop_in_files:.desktop.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

appstream_in_files = org.gnome.gnome-2048.appdata.xml.in
appstream_XML = $(appdata_in_files:.xml.in=.xml)
@APPSTREAM_XML_RULES@
@INTLTOOL_XML_RULE@

EXTRA_DIST = \
	$(appstream_in_files) \
	$(gsettings_SCHEMAS) \
	$(desktop_in_files)

CLEANFILES = \
	$(appstream_XML) \
	$(desktop_DATA)

check-local: $(desktop_DATA)
	$(DESKTOP_FILE_VALIDATE) $(desktop_DATA)

DISTCHECK_CONFIGURE_FLAGS == --enable-appdata-check

-include $(top_srcdir)/git.mk
