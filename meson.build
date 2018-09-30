project(
  'gnome-2048', ['vala', 'c'],
  version: '3.30.0',
  license: 'GPLv3+',
  meson_version: '>= 0.37.1',
)

gnome = import('gnome')
i18n = import('i18n')

# Paths
localedir = join_paths(get_option('prefix'), get_option('localedir'))
datadir = join_paths(get_option('prefix'), get_option('datadir'))
pkgdatadir = join_paths(datadir, 'gnome-2048')
schemadir = join_paths(datadir, 'glib-2.0', 'schemas')

# Dependencies
gtk_dep = dependency('gtk+-3.0', version: '>= 3.12.0')
clutter_dep = dependency('clutter-1.0', version: '>= 1.12.0')
clutter_gtk_dep = dependency('clutter-gtk-1.0', version: '>= 1.6.0')
gee_dep = dependency('gee-0.8', version: '>= 0.14.0')
libgnome_games_support_dep = dependency('libgnome-games-support-1')

appstream_util = find_program('appstream-util', required: false)
desktop_file_validate = find_program('desktop-file-validate', required: false)


podir = join_paths(meson.current_source_dir(), 'po')

subdir('po')
subdir('data')
subdir('help')
subdir('src')
