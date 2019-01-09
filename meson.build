project(
  'gnome-2048', ['vala', 'c'],
  version: '3.30.0',
  license: 'GPLv3+',
  meson_version: '>= 0.37.1',
)

gnome = import('gnome')
i18n = import('i18n')

cc = meson.get_compiler('c')
valac = meson.get_compiler('vala')

# Paths
localedir = join_paths(get_option('prefix'), get_option('localedir'))
datadir = join_paths(get_option('prefix'), get_option('datadir'))
pkgdatadir = join_paths(datadir, 'gnome-2048')
schemadir = join_paths(datadir, 'glib-2.0', 'schemas')

podir = join_paths(meson.current_source_dir(), 'po')

# Dependencies
posix = valac.find_library('posix')
libm = cc.find_library('m', required: false) # some platforms do not have libm separated from libc
gtk = dependency('gtk+-3.0', version: '>= 3.12.0')
clutter = dependency('clutter-1.0', version: '>= 1.12.0')
clutter_gtk = dependency('clutter-gtk-1.0', version: '>= 1.6.0')
gee = dependency('gee-0.8', version: '>= 0.14.0')
libgnome_games_support = dependency('libgnome-games-support-1')

appstream_util = find_program('appstream-util', required: false)
desktop_file_validate = find_program('desktop-file-validate', required: false)

subdir('po')
subdir('data')
subdir('help')
subdir('src')
