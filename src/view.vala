/*
   This file is part of GNOME 2048.

   Copyright (C) 2014-2015 Juan R. García Blanco <juanrgar@gmail.com>
   Copyright (C) 2016-2019 Arnaud Bonatti <arnaud.bonatti@gmail.com>

   GNOME 2048 is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   GNOME 2048 is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with GNOME 2048.  If not, see <https://www.gnu.org/licenses/>.
*/

private class RoundedRectangle : Object
{
    internal RoundedRectangle ()
    {
        Object (color: 0);
    }

    /*\
    * * color
    \*/

    private static Gdk.RGBA color_from_string (string color)
    {
        Gdk.RGBA c = Gdk.RGBA ();
        c.parse (color);
        return c;
    }

    private static HashTable<int, Gdk.RGBA?> colors
             = new HashTable<int, Gdk.RGBA?> (direct_hash, direct_equal);
    static construct
    {
        colors.insert (/* empty */ 0,  color_from_string ("#ffffff"));  // White
        colors.insert (/*     2 */ 1,  color_from_string ("#fce94f"));  // Butter 1
        colors.insert (/*     4 */ 2,  color_from_string ("#8ae234"));  // Chameleon 1
        colors.insert (/*     8 */ 3,  color_from_string ("#fcaf3e"));  // Orange 1
        colors.insert (/*    16 */ 4,  color_from_string ("#729fcf"));  // Sky blue 1
        colors.insert (/*    32 */ 5,  color_from_string ("#ad7fa8"));  // Plum 1
        colors.insert (/*    64 */ 6,  color_from_string ("#c17d11"));  // Chocolate 2
        colors.insert (/*   128 */ 7,  color_from_string ("#ef2929"));  // Scarlet red 1
        colors.insert (/*   256 */ 8,  color_from_string ("#c4a000"));  // Butter 3
        colors.insert (/*   512 */ 9,  color_from_string ("#4e9a06"));  // Chameleon 3
        colors.insert (/*  1024 */ 10, color_from_string ("#ce5c00"));  // Orange 3
        colors.insert (/*  2048 */ 11, color_from_string ("#204a87"));  // Sky blue 3
    }

    private Gdk.RGBA _color;
    private uint8 _color_index;
    [CCode (notify = false)] public uint8 color {
        internal get { return _color_index; }   // protected for TileView, internal for debug
        internal construct {
            _color_index = value;
            Gdk.RGBA? color = colors.lookup ((int) value);
            if (color == null)
                _new_color (value, out _color);
            else
                _color = (!) color;
        }
    }

    public Gdk.RGBA color_rgba ()
    {
        return _color;
    }

    private static void _new_color (uint8 tile_value, out Gdk.RGBA color)
        requires (tile_value >= 12)
        requires (tile_value <= 81)
    {
        Gdk.RGBA? nullable_color = colors.lookup ((int) ((tile_value - 1) % 11 + 1));
        if (nullable_color == null)
            assert_not_reached ();
        color = (!) nullable_color;

        uint8 sbits = (uint8) (Math.pow (2, tile_value) % 7);
        color.red   = (float) (((uint8) (color.red   * 255)) << sbits) / 255;
        color.green = (float) (((uint8) (color.green * 255)) << sbits) / 255;
        color.blue  = (float) (((uint8) (color.blue  * 255)) << sbits) / 255;

        colors.insert ((int) tile_value, color);
    }
}

private class TileView : RoundedRectangle
{
    internal TileView (uint8 val)
    {
        Object (color: val);
    }
}
