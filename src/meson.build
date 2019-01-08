resources = gnome.compile_resources(
  'resources',
  'gnome-2048.gresource.xml',
  source_dir: '..',
  c_name: 'resources',
)

gnome_2048_sources = [
  'application.vala',
  'config.vapi',
  'game.vala',
  'grid.vala',
  'view.vala',
] + resources

gnome_2048 = executable(
  'gnome-2048',
  gnome_2048_sources,
  dependencies: [
    posix,
    libm,
    gtk,
    clutter,
    clutter_gtk,
    gee,
    libgnome_games_support,
  ],
  c_args: [
    '-DVERSION="@0@"'.format(meson.project_version()),
    '-DGETTEXT_PACKAGE="gnome-2048"',
    '-DDATA_DIRECTORY="@0@"'.format(pkgdatadir),
    '-DLOCALEDIR="@0@"'.format(localedir),
  ],
  install: true,
)
