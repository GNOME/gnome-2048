/*
 * Copyright 2026 Andrey Kutejko <andy128k@gmail.com>
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

pub const PACKAGE: Option<&str> = option_env!("PACKAGE");
pub const VERSION: Option<&str> = option_env!("VERSION");
pub const GETTEXT_PACKAGE: Option<&str> = option_env!("GETTEXT_PACKAGE");
pub const LOCALEDIR: Option<&str> = option_env!("LOCALEDIR");

pub const fn package() -> &'static str {
    PACKAGE.expect("Env variable is PACKAGE")
}

pub const fn version() -> &'static str {
    VERSION.expect("Env variable is VERSION")
}

pub const fn gettext_package() -> &'static str {
    GETTEXT_PACKAGE.expect("Env variable is GETTEXT_PACKAGE")
}

pub const fn localedir() -> &'static str {
    LOCALEDIR.expect("Env variable is LOCALEDIR")
}
