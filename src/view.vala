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
    [CCode (notify = false)] internal Clutter.Actor  actor  { internal get; default = new Clutter.Actor (); }
    [CCode (notify = false)] internal Clutter.Canvas canvas { internal get; default = new Clutter.Canvas (); }

    [CCode (notify = false)] public float x      { protected construct { actor.x      = value; }}
    [CCode (notify = false)] public float y      { protected construct { actor.y      = value; }}
    [CCode (notify = false)] public float width  { protected construct { actor.width  = value; }}
    [CCode (notify = false)] public float height { protected construct { actor.height = value; }}

    construct
    {
        actor.set_content (canvas);
        actor.set_pivot_point (0.5f, 0.5f);

        canvas.draw.connect (_draw);
        idle_resize ();
    }

    internal RoundedRectangle (float x, float y, float width, float height)
    {
        Object (x: x, y: y, width: width, height: height, color: 0);
    }

    internal void resize (float x, float y, float width, float height)
    {
        actor.x = x;
        actor.y = y;
        actor.width = width;
        actor.height = height;
    }

    internal void idle_resize ()
    {
        if (!canvas.set_size ((int) Math.ceilf (actor.width), (int) Math.ceilf (actor.height)))
            canvas.invalidate ();
    }

    private const double HALF_PI = Math.PI / 2.0;
    protected virtual bool _draw (Cairo.Context ctx, int width, int height)
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

        Clutter.cairo_set_source_color (ctx, _color);
        ctx.fill ();

        return false;
    }

    /*\
    * * color
    \*/

    private static HashTable<int, Clutter.Color?> colors
             = new HashTable<int, Clutter.Color?> (direct_hash, direct_equal);
    static construct
    {
        colors.insert (/* empty */ 0,  Clutter.Color.from_string ("#ffffff"));  // White
        colors.insert (/*     2 */ 1,  Clutter.Color.from_string ("#fce94f"));  // Butter 1
        colors.insert (/*     4 */ 2,  Clutter.Color.from_string ("#8ae234"));  // Chameleon 1
        colors.insert (/*     8 */ 3,  Clutter.Color.from_string ("#fcaf3e"));  // Orange 1
        colors.insert (/*    16 */ 4,  Clutter.Color.from_string ("#729fcf"));  // Sky blue 1
        colors.insert (/*    32 */ 5,  Clutter.Color.from_string ("#ad7fa8"));  // Plum 1
        colors.insert (/*    64 */ 6,  Clutter.Color.from_string ("#c17d11"));  // Chocolate 2
        colors.insert (/*   128 */ 7,  Clutter.Color.from_string ("#ef2929"));  // Scarlet red 1
        colors.insert (/*   256 */ 8,  Clutter.Color.from_string ("#c4a000"));  // Butter 3
        colors.insert (/*   512 */ 9,  Clutter.Color.from_string ("#4e9a06"));  // Chameleon 3
        colors.insert (/*  1024 */ 10, Clutter.Color.from_string ("#ce5c00"));  // Orange 3
        colors.insert (/*  2048 */ 11, Clutter.Color.from_string ("#204a87"));  // Sky blue 3
    }

    private Clutter.Color _color;
    private uint8 _color_index;
    [CCode (notify = false)] public uint8 color {
        internal get { return _color_index; }   // protected for TileView, internal for debug
        internal construct {
            _color_index = value;
            Clutter.Color? color = colors.lookup ((int) value);
            if (color == null)
                _new_color (value, out _color);
            else
                _color = (!) color;
        }
    }

    private static void _new_color (uint8 tile_value, out Clutter.Color color)
        requires (tile_value >= 12)
        requires (tile_value <= 81)
    {
        Clutter.Color? nullable_color = colors.lookup ((int) ((tile_value - 1) % 11 + 1));
        if (nullable_color == null)
            assert_not_reached ();
        color = (!) nullable_color;

        uint8 sbits = (uint8) (Math.pow (2, tile_value) % 7);
        color.red   <<= sbits;
        color.green <<= sbits;
        color.blue  <<= sbits;

        colors.insert ((int) tile_value, color);
    }
}

private class TileView : RoundedRectangle
{
    internal TileView (float x, float y, float width, float height, uint8 val)
    {
        Object (x: x, y: y, width: width, height: height, color: val);
    }

    protected override bool _draw (Cairo.Context ctx, int width, int height)
    {
        base._draw (ctx, width, height);

        ctx.set_source_rgb (255, 255, 255);

        Pango.Layout layout = Pango.cairo_create_layout (ctx);
        Pango.FontDescription font_desc = Pango.FontDescription.from_string ("Sans Bold %dpx".printf (height / 4));
        layout.set_font_description (font_desc);

        layout.set_text (Math.pow (2, /* tile value */ color).to_string (), -1);

        Pango.Rectangle logical_rect;
        layout.get_extents (null, out logical_rect);
        ctx.move_to ((width  / 2) - (logical_rect.width  / 2 / Pango.SCALE),
                     (height / 2) - (logical_rect.height / 2 / Pango.SCALE));
        Pango.cairo_show_layout (ctx, layout);

        return false;
    }
}
