project(
  'gnome-2048', ['vala', 'c'],
  version: '4.0.0',
  license: 'GPLv3+',
  meson_version: '>= >=1.1',
)
add_project_arguments(['-DGDK_DISABLE_DEPRECATED, -GTK_DISABLE_DEPRECATED'], language : 'c')

gnome = import('gnome')
i18n = import('i18n')

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
gio_dependency = dependency('gio-2.0', version: '>= 2.80.0')
glib_dependency = dependency('glib-2.0', version: '>= 2.80.0')
gtk_dependency = dependency('gtk4', version: '>= 4.16.0')
adw_dependency = dependency('libadwaita-1', version: '>= 1.7')
gee_dependency = dependency('gee-0.8', version: '>= 0.14.0')
libgnome_games_support_dependency = dependency('libgnome-games-support-2', version: '>= 2.0')

appstreamcli = find_program('appstreamcli', required: false)
desktop_file_validate = find_program('desktop-file-validate', required: false)

subdir('po')
subdir('data')
subdir('help')
subdir('src')

gnome.post_install(
  glib_compile_schemas: true,
  gtk_update_icon_cache: true,
  update_desktop_database: true
)
