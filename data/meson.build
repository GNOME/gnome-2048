icon_sizes = [
  '16x16',
  '22x22',
  '24x24',
  '32x32',
  '48x48',
  '256x256',
  '512x512',
]
foreach size : icon_sizes
  install_data(
    join_paths('icons', 'hicolor', size, 'gnome-2048.png'),
    install_dir: join_paths(icondir, size, 'apps'),
  )
endforeach
install_data(
  join_paths('icons', 'hicolor', 'symbolic', 'gnome-2048-symbolic.svg'),
  install_dir: join_paths(icondir, 'symbolic', 'apps'),
)

install_data(
  'org.gnome.TwentyFortyEight.gschema.xml',
  install_dir: schemadir,
)

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
