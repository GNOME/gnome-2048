install_data(
  join_paths('icons', 'hicolor', size, 'org.gnome.gnome-2048-symbolic.svg'),
  install_dir: join_paths(datadir, 'icons', 'hicolor', 'scalable', 'apps'),
)

install_data(
  join_paths('icons', 'hicolor', 'symbolic', 'org.gnome.gnome-2048-symbolic.svg'),
  install_dir: join_paths(datadir, 'icons', 'hicolor', 'symbolic', 'apps'),
)

install_data(
  'org.gnome.2048.gschema.xml',
  install_dir: schemadir,
)
meson.add_install_script('glib-compile-schemas', schemadir)

desktop_file = i18n.merge_file(
  'desktop-file',
  input: 'org.gnome.gnome-2048.desktop.in',
  output: 'org.gnome.gnome-2048.desktop',
  install: true,
  install_dir: join_paths(datadir, 'applications'),
  po_dir: podir,
  type: 'desktop',
)
if desktop_file_validate.found()
  test(
    'Validating @0@'.format(desktop_file),
    desktop_file_validate,
    args: [desktop_file],
  )
endif

appdata_file = i18n.merge_file(
  'appdata-file',
  input: 'org.gnome.gnome-2048.appdata.xml.in',
  output: 'org.gnome.gnome-2048.appdata.xml',
  install: true,
  install_dir: join_paths(datadir, 'metainfo'),
  po_dir: podir,
)
if appstream_util.found()
  test(
    'Validating @0@'.format(appdata_file),
    appstream_util,
    args: ['validate', '--nonet', appdata_file],
  )
endif
