#!/usr/bin/env python3

import os
import subprocess
import sys


if len(sys.argv) < 3:
  sys.exit("usage: meson_post_install.py <icondir> <schemadir>")

icon_cache_dir = sys.argv[1]
schemadir = sys.argv[2]

if not os.environ.get('DESTDIR'):
  print('Updating icon cache...')
  if not os.path.exists(icon_cache_dir):
    os.makedirs(icon_cache_dir)
  subprocess.call(['gtk-update-icon-cache',
                   '--quiet', '--force', '--ignore-theme-index',
                   icon_cache_dir])

  print('Compiling GSettings schemas...')
  if not os.path.exists(schemadir):
    os.makedirs(schemadir)
  subprocess.call(['glib-compile-schemas', schemadir])
