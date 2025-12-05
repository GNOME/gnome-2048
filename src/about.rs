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

use crate::config::VERSION;
use adw::prelude::*;
use gettextrs::pgettext;

pub fn about(parent: Option<&gtk::Widget>) {
    adw::AboutDialog::builder()
        .application_name(pgettext("about dialog text; the program name", "2048"))
        .application_icon("org.gnome.TwentyFortyEight")
        .version(VERSION)
        .comments(pgettext(
            "about dialog text; a introduction to the game",
            "A clone of 2048 for GNOME",
        ))
        .license_type(gtk::License::Gpl30)
        .copyright(
            String::new()
                + &pgettext(
                    "text crediting a maintainer, seen in the About dialog",
                    "Copyright \u{a9} 2014-2015 – Juan R. García Blanco",
                )
                + "\n"
                + &pgettext(
                    "text crediting a maintainer, seen in the About dialog",
                    "Copyright \u{a9} 2016-2020 – Arnaud Bonatti",
                )
                + "\n"
                + &pgettext(
                    "text crediting a maintainer, seen in the About dialog",
                    "Copyright \u{a9} 2025 – Andrey Kutejko",
                ),
        )
        .developers(["Juan R. García Blanco", "Arnaud Bonatti", "Andrey Kutejko"])
        .translator_credits(pgettext(
            "about dialog text; this string should be replaced by a text crediting yourselves and your translation team, or should be left empty. Do not translate literally!",
            "translator-credits",
        ))
        .website("https://gitlab.gnome.org/GNOME/gnome-2048/")
        .build()
        .present(parent);
}
