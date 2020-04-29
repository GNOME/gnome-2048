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

private class RoundedRectangle : Gtk.DrawingArea
{
    [CCode (notify = false)] public float x      { internal get; protected construct set; }
    [CCode (notify = false)] public float y      { internal get; protected construct set; }
    [CCode (notify = false)] public float width  { internal get; protected construct set; }
    [CCode (notify = false)] public float height { internal get; protected construct set; }

    construct
    {
        set_draw_func (_draw);
        idle_resize ();
    }

    internal RoundedRectangle (float x, float y, float width, float height)
    {
        Object (x: x, y: y, width: width, height: height, color: 0);
    }

    internal void resize (float _x, float _y, float _width, float _height)
    {
        x = _x;
        y = _y;
        width = _width;
        height = _height;
    }

    internal void idle_resize ()
    {
//        if (!canvas.set_size ((int) Math.ceilf (actor.width), (int) Math.ceilf (actor.height)))
//            canvas.invalidate ();
    }

    private const double HALF_PI = Math.PI / 2.0;
    protected virtual void _draw (Gtk.DrawingArea _this, Cairo.Context ctx, int width, int height)
    {
        double radius = (height > width) ? (height / 20.0) : (width / 20.0);

        ctx.save ();
        ctx.set_operator (Cairo.Operator.CLEAR);
        ctx.paint ();
        ctx.restore ();

        ctx.new_sub_path ();
        ctx.arc (radius,         radius,          radius,  Math.PI, -HALF_PI);
        ctx.arc (width - radius, radius,          radius, -HALF_PI,        0);
        ctx.arc (width - radius, height - radius, radius,        0,  HALF_PI);
        ctx.arc (radius,         height - radius, radius,  HALF_PI,  Math.PI);
        ctx.close_path ();

        Gdk.cairo_set_source_rgba (ctx, _color);
        ctx.fill ();
    }

    /*\
    * * color
    \*/

    private static HashTable<int, Gdk.RGBA?> colors
             = new HashTable<int, Gdk.RGBA?> (direct_hash, direct_equal);
    static construct
    {
        bool success;
        Gdk.RGBA color;
        if (color.parse ("#ffffff")) colors.insert (/* empty */  0, color); else assert_not_reached ();  // White
        if (color.parse ("#fce94f")) colors.insert (/*     2 */  1, color); else assert_not_reached ();  // Butter 1
        if (color.parse ("#8ae234")) colors.insert (/*     4 */  2, color); else assert_not_reached ();  // Chameleon 1
        if (color.parse ("#fcaf3e")) colors.insert (/*     8 */  3, color); else assert_not_reached ();  // Orange 1
        if (color.parse ("#729fcf")) colors.insert (/*    16 */  4, color); else assert_not_reached ();  // Sky blue 1
        if (color.parse ("#ad7fa8")) colors.insert (/*    32 */  5, color); else assert_not_reached ();  // Plum 1
        if (color.parse ("#c17d11")) colors.insert (/*    64 */  6, color); else assert_not_reached ();  // Chocolate 2
        if (color.parse ("#ef2929")) colors.insert (/*   128 */  7, color); else assert_not_reached ();  // Scarlet red 1
        if (color.parse ("#c4a000")) colors.insert (/*   256 */  8, color); else assert_not_reached ();  // Butter 3
        if (color.parse ("#4e9a06")) colors.insert (/*   512 */  9, color); else assert_not_reached ();  // Chameleon 3
        if (color.parse ("#ce5c00")) colors.insert (/*  1024 */ 10, color); else assert_not_reached ();  // Orange 3
        if (color.parse ("#204a87")) colors.insert (/*  2048 */ 11, color); else assert_not_reached ();  // Sky blue 3
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

    private static void _new_color (uint8 tile_value, out Gdk.RGBA color)
        requires (tile_value >= 12)
        requires (tile_value <= 81)
    {
        Gdk.RGBA? nullable_color = colors.lookup ((int) ((tile_value - 1) % 11 + 1));
        if (nullable_color == null)
            assert_not_reached ();
        color = (!) nullable_color;

        uint8 sbits = (uint8) (Math.pow (2, tile_value) % 7);
        color.red   = (float) ((uint8) (color.red   * 255.0f) << sbits) / 255.0f;
        color.green = (float) ((uint8) (color.green * 255.0f) << sbits) / 255.0f;
        color.blue  = (float) ((uint8) (color.blue  * 255.0f) << sbits) / 255.0f;

        colors.insert ((int) tile_value, color);
    }
}

private class TileView : RoundedRectangle
{
    internal TileView (float x, float y, float width, float height, uint8 val)
    {
        Object (x: x, y: y, width: width, height: height, color: val);
    }

    protected override void _draw (Gtk.DrawingArea _this, Cairo.Context ctx, int width, int height)
    {
        base._draw (_this, ctx, width, height);

        ctx.set_source_rgb (255.0, 255.0, 255.0);

        Pango.Layout layout = Pango.cairo_create_layout (ctx);
        Pango.FontDescription font_desc = Pango.FontDescription.from_string ("Sans Bold %dpx".printf (height / 4));
        layout.set_font_description (font_desc);

        layout.set_text (Math.pow (2, /* tile value */ color).to_string (), -1);

        Pango.Rectangle logical_rect;
        layout.get_extents (null, out logical_rect);
        ctx.move_to ((width  / 2) - (logical_rect.width  / 2 / Pango.SCALE),
                     (height / 2) - (logical_rect.height / 2 / Pango.SCALE));
        Pango.cairo_show_layout (ctx, layout);
    }
}
