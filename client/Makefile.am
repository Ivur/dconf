include $(INTROSPECTION_MAKEFILE)

AM_CFLAGS = -std=c89 -Wall -Wmissing-prototypes -Wwrite-strings
INCLUDES = -I$(top_srcdir)/{common,gvdb,engine} $(gio_CFLAGS)

dconf-0.3.gir: libdconf.la
dconf_0_3_gir_INCLUDES = Gio-2.0
dconf_0_3_gir_CFLAGS = $(INCLUDES)
dconf_0_3_gir_LIBS = libdconf.la
dconf_0_3_gir_FILES = dconf-client.c dconf-client.h
INTROSPECTION_GIRS = dconf-0.3.gir

lib_LTLIBRARIES = libdconf.la

dconfinclude_HEADERS = \
	dconf-client.h	\
	dconf.h

libdconf_la_LIBADD = $(gio_LIBS)
libdconf_la_SOURCES = \
	../common/dconf-paths.c		\
	../engine/dconf-engine.c	\
	../gvdb/gvdb-reader.c		\
	dconf-client.c

pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = dconf.pc

girdir = $(datadir)/gir-1.0
dist_gir_DATA = $(INTROSPECTION_GIRS)

typelibdir = $(libdir)/girepository-1.0
typelib_DATA = $(INTROSPECTION_GIRS:.gir=.typelib)

CLEANFILES = $(dist_gir_DATA) $(typelib_DATA)