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
use std::num::NonZeroU8;

#[inline]
const fn rgb(rgb: u32) -> gdk::RGBA {
    gdk::RGBA::new(
        ((rgb >> 16) & 255) as f32 / 255_f32,
        ((rgb >> 8) & 255) as f32 / 255_f32,
        (rgb & 255) as f32 / 255_f32,
        1_f32,
    )
}

#[derive(Clone, Copy, Default, PartialEq, Eq, glib::Enum, glib::Variant)]
#[enum_type(name = "Theme")]
pub enum Theme {
    #[default]
    Adwaita = 0,
    Tango,
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

pub struct AdwaitaColorTheme {}

impl ColorTheme for AdwaitaColorTheme {
    fn background_color(&self) -> gdk::RGBA {
        const { rgb(0x_deddda) } /* Light 3 */
    }

    fn empty_tile_color(&self) -> gdk::RGBA {
        const { rgb(0x_f6f5f4) } /* Light 2 */
    }

    fn tile_color(&self, tile: NonZeroU8) -> TileColors {
        const TILE_COLORS: &[TileColors] = &[
            TileColors {
                fg: gdk::RGBA::WHITE,
                bg: rgb(0x_ff7800), /* Orange 3 */
            },
            TileColors {
                fg: gdk::RGBA::WHITE,
                bg: rgb(0x_33d17a), /* Green 3 */
            },
            TileColors {
                fg: gdk::RGBA::WHITE,
                bg: rgb(0x_3584e4), /* Blue 3 */
            },
            TileColors {
                fg: gdk::RGBA::WHITE,
                bg: rgb(0x_f6d32d), /* Yellow 3 */
            },
            TileColors {
                fg: gdk::RGBA::WHITE,
                bg: rgb(0x_9141ac), /* Purple 3 */
            },
            TileColors {
                fg: gdk::RGBA::WHITE,
                bg: rgb(0x_b5835a), /* Brown 2 */
            },
            TileColors {
                fg: gdk::RGBA::WHITE,
                bg: rgb(0x_e01b24), /* Red 3 */
            },
            TileColors {
                fg: gdk::RGBA::WHITE,
                bg: rgb(0x_c64600), /* Orange 5 */
            },
            TileColors {
                fg: gdk::RGBA::WHITE,
                bg: rgb(0x_26a269), /* Green 5 */
            },
            TileColors {
                fg: gdk::RGBA::WHITE,
                bg: rgb(0x_1a5fb4), /* Blue 5 */
            },
            TileColors {
                fg: gdk::RGBA::WHITE,
                bg: rgb(0x_e5a50a), /* Yellow 5 */
            },
        ];

        let index = (tile.get() as usize - 1).min(TILE_COLORS.len() - 1);
        TILE_COLORS[index]
    }
}

pub const ADWAITA_THEME: AdwaitaColorTheme = AdwaitaColorTheme {};

pub struct TangoColorTheme {}

impl ColorTheme for TangoColorTheme {
    fn background_color(&self) -> gdk::RGBA {
        const { rgb(0x_babdb6) }
    }

    fn empty_tile_color(&self) -> gdk::RGBA {
        gdk::RGBA::WHITE
    }

    fn tile_color(&self, tile: NonZeroU8) -> TileColors {
        const TILE_COLORS: &[TileColors] = &[
            TileColors {
                fg: gdk::RGBA::WHITE,
                bg: rgb(0x_fce94f), /* Butter 1 */
            },
            TileColors {
                fg: gdk::RGBA::WHITE,
                bg: rgb(0x_8ae234), /* Chameleon 1 */
            },
            TileColors {
                fg: gdk::RGBA::WHITE,
                bg: rgb(0x_fcaf3e), /* Orange 1 */
            },
            TileColors {
                fg: gdk::RGBA::WHITE,
                bg: rgb(0x_729fcf), /* Sky blue 1 */
            },
            TileColors {
                fg: gdk::RGBA::WHITE,
                bg: rgb(0x_ad7fa8), /* Plum 1 */
            },
            TileColors {
                fg: gdk::RGBA::WHITE,
                bg: rgb(0x_c17d11), /* Chocolate 2 */
            },
            TileColors {
                fg: gdk::RGBA::WHITE,
                bg: rgb(0x_ef2929), /* Scarlet red 1 */
            },
            TileColors {
                fg: gdk::RGBA::WHITE,
                bg: rgb(0x_c4a000), /* Butter 3 */
            },
            TileColors {
                fg: gdk::RGBA::WHITE,
                bg: rgb(0x_4e9a06), /* Chameleon 3 */
            },
            TileColors {
                fg: gdk::RGBA::WHITE,
                bg: rgb(0x_ce5c00), /* Orange 3 */
            },
            TileColors {
                fg: gdk::RGBA::WHITE,
                bg: rgb(0x_204a87), /* Sky blue 3 */
            },
        ];

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
        const { rgb(0x_756452) }
    }

    fn empty_tile_color(&self) -> gdk::RGBA {
        const { rgb(0x_baac9a) }
    }

    fn tile_color(&self, tile: NonZeroU8) -> TileColors {
        const DARK_FG: gdk::RGBA = rgb(0x_776e65);
        const LIGHT_FG: gdk::RGBA = rgb(0x_f9f6f2);
        const TILE_COLORS: &[TileColors] = &[
            TileColors {
                fg: DARK_FG,
                bg: rgb(0x_eee4da),
            },
            TileColors {
                fg: DARK_FG,
                bg: rgb(0x_ede0c8),
            },
            TileColors {
                fg: LIGHT_FG,
                bg: rgb(0x_f2b179),
            },
            TileColors {
                fg: LIGHT_FG,
                bg: rgb(0x_f59563),
            },
            TileColors {
                fg: LIGHT_FG,
                bg: rgb(0x_f67c5f),
            },
            TileColors {
                fg: LIGHT_FG,
                bg: rgb(0x_f65e3b),
            },
            TileColors {
                fg: LIGHT_FG,
                bg: rgb(0x_edcf72),
            },
            TileColors {
                fg: LIGHT_FG,
                bg: rgb(0x_edcc61),
            },
            TileColors {
                fg: LIGHT_FG,
                bg: rgb(0x_edc850),
            },
            TileColors {
                fg: LIGHT_FG,
                bg: rgb(0x_edc53f),
            },
            TileColors {
                fg: LIGHT_FG,
                bg: rgb(0x_edc22e),
            },
            TileColors {
                fg: LIGHT_FG,
                bg: rgb(0x_3c3a32),
            },
        ];

        let index = (tile.get() as usize - 1).min(TILE_COLORS.len() - 1);
        TILE_COLORS[index]
    }
}

pub const CLASSIC_THEME: ClassicColorTheme = ClassicColorTheme {};
