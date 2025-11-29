/*
 * Copyright 2025 Andrey Kutejko <andy128k@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, see <http://www.gnu.org/licenses/>.
 *
 * For more details see the file COPYING.
 */

mod about;
mod application;
mod cli;
mod colors;
mod config;
mod game;
mod game_window;
mod grid;
mod scores;
mod shift;

use crate::{
    application::TwentyFortyEight,
    config::{GETTEXT_PACKAGE, LOCALEDIR},
};
use gtk::{glib, prelude::*};
use std::{error::Error, process::Termination};

fn main() -> Result<impl Termination, Box<dyn Error>> {
    if let Some(mismatch) = glib::check_version(2, 80, 0) {
        eprintln!("GLib version mismatch: {mismatch}");
        std::process::exit(1);
    }
    if let Some(mismatch) = gtk::check_version(4, 16, 0) {
        eprintln!("GTK version mismatch: {mismatch}");
        std::process::exit(1);
    }

    gettextrs::setlocale(gettextrs::LocaleCategory::LcAll, "");
    gettextrs::bindtextdomain(GETTEXT_PACKAGE, LOCALEDIR)?;
    gettextrs::bind_textdomain_codeset(GETTEXT_PACKAGE, "UTF-8")?;
    gettextrs::textdomain(GETTEXT_PACKAGE)?;

    gtk::init()?;

    let application_name = "org.gnome.TwentyFortyEight";
    glib::set_application_name(application_name);
    glib::set_prgname(Some("org.gnome.TwentyFortyEight"));
    gtk::Window::set_default_icon_name("org.gnome.TwentyFortyEight");

    let app = TwentyFortyEight::default();
    let exis_code = app.run();
    Ok(exis_code)
}
