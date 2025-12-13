project(
  'gnome-2048', ['rust'],
  version: '50.alpha.2',
  license: 'GPLv3+',
  meson_version: '>= >=1.1',
)

gnome = import('gnome')
i18n = import('i18n')

# Paths
localedir = join_paths(get_option('prefix'), get_option('localedir'))
datadir = join_paths(get_option('prefix'), get_option('datadir'))
bindir = join_paths (get_option ('prefix'), get_option ('bindir'))
icondir = join_paths(datadir, 'icons', 'hicolor')
schemadir = join_paths(datadir, 'glib-2.0', 'schemas')

podir = join_paths(meson.current_source_dir(), 'po')

# Dependencies
gio_dependency = dependency('gio-2.0', version: '>= 2.80.0')
glib_dependency = dependency('glib-2.0', version: '>= 2.80.0')
gtk_dependency = dependency('gtk4', version: '>= 4.16.0')
adw_dependency = dependency('libadwaita-1', version: '>= 1.8')
libgnome_games_support = subproject ('libgnome-games-support',
                                     default_options: 'superproject_name=gnome-2048')
libgnome_games_support_dependency = libgnome_games_support.get_variable ('lggs_dependency')

cargo = find_program('cargo', required: true)
cargo_version = run_command(cargo, '--version', check: true).stdout().strip()
message(cargo_version)
rustc_version = run_command('rustc', '--version', check: true).stdout().strip()
message(rustc_version)

if get_option('debug')
    profile = 'debug'
else
    profile = 'release'
endif

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
