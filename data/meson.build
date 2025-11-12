# Install icons
install_data(
  join_paths('icons', 'org.gnome.TwentyFortyEight.svg'),
  install_dir: join_paths(icondir, 'scalable', 'apps'),
)

install_data(
  join_paths('icons', 'org.gnome.TwentyFortyEight-symbolic.svg'),
  install_dir: join_paths(icondir, 'symbolic', 'apps'),
)

# Install gschema
install_data(
  'org.gnome.TwentyFortyEight.gschema.xml',
  install_dir: schemadir,
)

# Desktop file
desktop_file = i18n.merge_file(
  input: 'org.gnome.TwentyFortyEight.desktop.in',
  output: 'org.gnome.TwentyFortyEight.desktop',
  install: true,
  install_dir: join_paths(datadir, 'applications'),
  po_dir: podir,
  type: 'desktop',
)

# Validate desktop file
if desktop_file_validate.found()
  test(
    'Validate desktop file',
    desktop_file_validate,
    args: [desktop_file],
  )
endif

# Metainfo file
metainfo_file = i18n.merge_file(
  input: 'org.gnome.TwentyFortyEight.metainfo.xml.in',
  output: 'org.gnome.TwentyFortyEight.metainfo.xml',
  install: true,
  install_dir: join_paths(datadir, 'metainfo'),
  po_dir: podir,
)

# Validate Metainfo file
if appstreamcli.found()
  test(
    'Validating Metainfo',
    appstreamcli,
    depends: metainfo_file,
    args: ['validate', '--no-net', '--explain', metainfo_file],
  )
endif

# Install man page
install_man('@0@.6'.format(meson.project_name()))
