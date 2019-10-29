# Tests
tw12ht_tests = executable(
    'tw12ht_tests',
    [
        'grid.vala',
        'test-tw12ht.vala'
    ],
    dependencies : [
        gee_dependency,
        gio_dependency,
        glib_dependency,
        libm_dependency
    ]
)
test('tw12ht-tests', tw12ht_tests)

# Application
resources = gnome.compile_resources(
  'resources',
  'org.gnome.TwentyFortyEight.gresource.xml',
  c_name: 'resources',
)

gnome_2048_sources = [
  'application.vala',
  'cli.vala',
  'config.vapi',
  'game.vala',
  'game-headerbar.vala',
  'game-window.vala',
  'grid.vala',
  'view.vala',
] + resources

gnome_2048 = executable(
  'gnome-2048',
  gnome_2048_sources,
  dependencies: [
    posix_dependency,
    libm_dependency,
    gtk_dependency,
    clutter_dependency,
    clutter_gtk_dependency,
    gee_dependency,
    libgnome_games_support_dependency,
  ],
  c_args: [
    '-DVERSION="@0@"'.format(meson.project_version()),
    '-DGETTEXT_PACKAGE="gnome-2048"',
    '-DDATA_DIRECTORY="@0@"'.format(pkgdatadir),
    '-DLOCALEDIR="@0@"'.format(localedir),
  ],
  vala_args: [
    '--enable-experimental-non-null'
  ],
  install: true,
)
