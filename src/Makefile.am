bin_PROGRAMS = gnome-2048

gnome_2048_SOURCES = \
	config.vapi \
	application.vala \
	game.vala \
	grid.vala \
	view.vala \
	gnome-2048-data.h \
	gnome-2048-data.c

gnome_2048_CFLAGS = \
	-DVERSION=\"$(VERSION)\" \
	-DGETTEXT_PACKAGE=\"$(GETTEXT_PACKAGE)\" \
	-DDATA_DIRECTORY=\"$(datadir)/gnome-2048\" \
	-DLOCALEDIR=\"$(datadir)/locale\" \
	$(GNOME_2048_CFLAGS) \
	-w

gnome_2048_VALAFLAGS = \
	--pkg posix \
	--pkg gtk+-3.0 \
	--pkg pango \
	--pkg pangocairo \
	--pkg clutter-1.0 \
	--pkg clutter-gtk-1.0 \
	--pkg cogl-1.0 \
	--pkg gee-0.8 \
	--pkg libgnome-games-support-1

gnome_2048_LDADD = \
	$(GNOME_2048_LIBS) \
	-lm

data_files = $(shell $(GLIB_COMPILE_RESOURCES)				\
		--sourcedir=$(top_srcdir)					\
		--generate-dependencies gnome-2048.gresource.xml)

gnome-2048-data.h: gnome-2048.gresource.xml $(data_files)
	$(AM_V_GEN)							\
		$(GLIB_COMPILE_RESOURCES)				\
		--target=$@						\
		--sourcedir=$(top_srcdir)					\
		--generate						\
		--c-name gnome_2048_data $<
gnome-2048-data.c: gnome-2048.gresource.xml $(data_files)
	$(AM_V_GEN)							\
		$(GLIB_COMPILE_RESOURCES)				\
		--target=$@						\
		--sourcedir=$(top_srcdir)					\
		--generate						\
		--c-name gnome_2048_data $<

EXTRA_DIST = \
	gnome-2048.gresource.xml \
	$(data_files)

MAINTAINERCLEANFILES = \
	gnome-2048-data.h \
	gnome-2048-data.c

-include $(top_srcdir)/git.mk
