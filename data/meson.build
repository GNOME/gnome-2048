install_data(
  join_paths('icons', 'org.gnome.TwentyFortyEight.svg'),
  install_dir: join_paths(icondir, 'scalable', 'apps'),
)

install_data(
  join_paths('icons', 'org.gnome.TwentyFortyEight-symbolic.svg'),
  install_dir: join_paths(icondir, 'symbolic', 'apps'),
)

install_data(
  'org.gnome.TwentyFortyEight.gschema.xml',
  install_dir: schemadir,
)

desktop_file = i18n.merge_file(
  'desktop-file',
  input: 'org.gnome.TwentyFortyEight.desktop.in',
  output: 'org.gnome.TwentyFortyEight.desktop',
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
  input: 'org.gnome.TwentyFortyEight.appdata.xml.in',
  output: 'org.gnome.TwentyFortyEight.appdata.xml',
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
