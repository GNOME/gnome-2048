project(
  'gnome-2048', ['vala', 'c'],
  version: '3.31.90',
  license: 'GPLv3+',
  meson_version: '>= 0.37.1',
)

gnome = import('gnome')
i18n = import('i18n')
# the new python module would be better but it does not have path method in meson 0.49
# https://github.com/mesonbuild/meson/issues/4070
python3 = import('python3')

cc = meson.get_compiler('c')
valac = meson.get_compiler('vala')

# Paths
localedir = join_paths(get_option('prefix'), get_option('localedir'))
datadir = join_paths(get_option('prefix'), get_option('datadir'))
icondir = join_paths(datadir, 'icons', 'hicolor')
pkgdatadir = join_paths(datadir, 'gnome-2048')
schemadir = join_paths(datadir, 'glib-2.0', 'schemas')

podir = join_paths(meson.current_source_dir(), 'po')

# Dependencies
posix_dependency = valac.find_library('posix')
libm_dependency = cc.find_library('m', required: false) # some platforms do not have libm separated from libc
gio_dependency = dependency('gio-2.0', version: '>= 2.40.0')
glib_dependency = dependency('glib-2.0', version: '>= 2.40.0')
gtk_dependency = dependency('gtk+-3.0', version: '>= 3.12.0')
clutter_dependency = dependency('clutter-1.0', version: '>= 1.12.0')
clutter_gtk_dependency = dependency('clutter-gtk-1.0', version: '>= 1.6.0')
gee_dependency = dependency('gee-0.8', version: '>= 0.14.0')
libgnome_games_support_dependency = dependency('libgnome-games-support-1')

appstream_util = find_program('appstream-util', required: false)
desktop_file_validate = find_program('desktop-file-validate', required: false)

subdir('po')
subdir('data')
subdir('help')
subdir('src')

meson.add_install_script(
  python3.find_python().path(),
  join_paths(meson.source_root(), 'meson_post_install.py'),
  icondir,
  schemadir,
)
