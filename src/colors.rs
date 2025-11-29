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

use gtk::{gdk, glib};
use std::{num::NonZeroU8, sync::LazyLock};

#[derive(Clone, Copy, Default, PartialEq, Eq, glib::Enum, glib::Variant)]
#[enum_type(name = "Theme")]
pub enum Theme {
    #[default]
    Tango = 0,
    Classic,
}

#[derive(Clone, Copy)]
pub struct TileColors {
    pub fg: gdk::RGBA,
    pub bg: gdk::RGBA,
}

pub trait ColorTheme {
    fn background_color(&self) -> gdk::RGBA;
    fn empty_tile_color(&self) -> gdk::RGBA;
    fn tile_color(&self, tile: NonZeroU8) -> TileColors;
}

pub struct TangoColorTheme {}

impl ColorTheme for TangoColorTheme {
    fn background_color(&self) -> gdk::RGBA {
        static COLOR: LazyLock<gdk::RGBA> = LazyLock::new(|| gdk::RGBA::parse("#babdb6").unwrap());
        *COLOR
    }

    fn empty_tile_color(&self) -> gdk::RGBA {
        gdk::RGBA::WHITE
    }

    fn tile_color(&self, tile: NonZeroU8) -> TileColors {
        static TILE_COLORS: LazyLock<Vec<TileColors>> = LazyLock::new(|| {
            vec![
                TileColors {
                    fg: gdk::RGBA::WHITE,
                    bg: gdk::RGBA::parse("#fce94f").unwrap(), /* Butter 1 */
                },
                TileColors {
                    fg: gdk::RGBA::WHITE,
                    bg: gdk::RGBA::parse("#8ae234").unwrap(), /* Chameleon 1 */
                },
                TileColors {
                    fg: gdk::RGBA::WHITE,
                    bg: gdk::RGBA::parse("#fcaf3e").unwrap(), /* Orange 1 */
                },
                TileColors {
                    fg: gdk::RGBA::WHITE,
                    bg: gdk::RGBA::parse("#729fcf").unwrap(), /* Sky blue 1 */
                },
                TileColors {
                    fg: gdk::RGBA::WHITE,
                    bg: gdk::RGBA::parse("#ad7fa8").unwrap(), /* Plum 1 */
                },
                TileColors {
                    fg: gdk::RGBA::WHITE,
                    bg: gdk::RGBA::parse("#c17d11").unwrap(), /* Chocolate 2 */
                },
                TileColors {
                    fg: gdk::RGBA::WHITE,
                    bg: gdk::RGBA::parse("#ef2929").unwrap(), /* Scarlet red 1 */
                },
                TileColors {
                    fg: gdk::RGBA::WHITE,
                    bg: gdk::RGBA::parse("#c4a000").unwrap(), /* Butter 3 */
                },
                TileColors {
                    fg: gdk::RGBA::WHITE,
                    bg: gdk::RGBA::parse("#4e9a06").unwrap(), /* Chameleon 3 */
                },
                TileColors {
                    fg: gdk::RGBA::WHITE,
                    bg: gdk::RGBA::parse("#ce5c00").unwrap(), /* Orange 3 */
                },
                TileColors {
                    fg: gdk::RGBA::WHITE,
                    bg: gdk::RGBA::parse("#204a87").unwrap(), /* Sky blue 3 */
                },
            ]
        });

        fn shift(c: f32, bits: u64) -> f32 {
            ((((c * 255_f32) as u8) << bits) as f32) / 255_f32
        }

        let index = tile.get() as usize - 1;
        TILE_COLORS.get(index).cloned().unwrap_or_else(|| {
            let colors = &TILE_COLORS[index % TILE_COLORS.len()];
            let shift_bits = 2_u64.pow(tile.get() as u32) % 7;
            TileColors {
                fg: colors.fg,
                bg: gdk::RGBA::new(
                    shift(colors.bg.red(), shift_bits),
                    shift(colors.bg.green(), shift_bits),
                    shift(colors.bg.blue(), shift_bits),
                    colors.bg.alpha(),
                ),
            }
        })
    }
}

pub const TANGO_THEME: TangoColorTheme = TangoColorTheme {};

pub struct ClassicColorTheme {}

impl ColorTheme for ClassicColorTheme {
    fn background_color(&self) -> gdk::RGBA {
        static COLOR: LazyLock<gdk::RGBA> = LazyLock::new(|| gdk::RGBA::parse("#756452").unwrap());
        *COLOR
    }

    fn empty_tile_color(&self) -> gdk::RGBA {
        static COLOR: LazyLock<gdk::RGBA> = LazyLock::new(|| gdk::RGBA::parse("#baac9a").unwrap());
        *COLOR
    }

    fn tile_color(&self, tile: NonZeroU8) -> TileColors {
        static TILE_COLORS: LazyLock<Vec<TileColors>> = LazyLock::new(|| {
            let dark_fg = gdk::RGBA::parse("#776e65").unwrap();
            let light_fg = gdk::RGBA::parse("#f9f6f2").unwrap();
            vec![
                TileColors {
                    fg: dark_fg,
                    bg: gdk::RGBA::parse("#eee4da").unwrap(),
                },
                TileColors {
                    fg: dark_fg,
                    bg: gdk::RGBA::parse("#ede0c8").unwrap(),
                },
                TileColors {
                    fg: light_fg,
                    bg: gdk::RGBA::parse("#f2b179").unwrap(),
                },
                TileColors {
                    fg: light_fg,
                    bg: gdk::RGBA::parse("#f59563").unwrap(),
                },
                TileColors {
                    fg: light_fg,
                    bg: gdk::RGBA::parse("#f67c5f").unwrap(),
                },
                TileColors {
                    fg: light_fg,
                    bg: gdk::RGBA::parse("#f65e3b").unwrap(),
                },
                TileColors {
                    fg: light_fg,
                    bg: gdk::RGBA::parse("#edcf72").unwrap(),
                },
                TileColors {
                    fg: light_fg,
                    bg: gdk::RGBA::parse("#edcc61").unwrap(),
                },
                TileColors {
                    fg: light_fg,
                    bg: gdk::RGBA::parse("#edc850").unwrap(),
                },
                TileColors {
                    fg: light_fg,
                    bg: gdk::RGBA::parse("#edc53f").unwrap(),
                },
                TileColors {
                    fg: light_fg,
                    bg: gdk::RGBA::parse("#edc22e").unwrap(),
                },
                TileColors {
                    fg: light_fg,
                    bg: gdk::RGBA::parse("#3c3a32").unwrap(),
                },
            ]
        });

        let index = tile.get() as usize - 1;

        TILE_COLORS
            .get(index)
            .cloned()
            .unwrap_or_else(|| *TILE_COLORS.last().unwrap())
    }
}

pub const CLASSIC_THEME: ClassicColorTheme = ClassicColorTheme {};
