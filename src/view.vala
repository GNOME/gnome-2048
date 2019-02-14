/* Copyright (C) 2014-2015 Juan R. García Blanco <juanrgar@gmail.com>
 * Copyright (C) 2016-2019 Arnaud Bonatti <arnaud.bonatti@gmail.com>
 *
 * This file is part of GNOME 2048.
 *
 * GNOME 2048 is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * GNOME 2048 is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with GNOME 2048; if not, see <http://www.gnu.org/licenses/>.
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

    internal RoundedRectangle (float x, float y, float width, float height, string color)
    {
        Object (x: x, y: y, width: width, height: height, color: color);
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

    private static HashTable<string, Clutter.Color?> colors
             = new HashTable<string, Clutter.Color?> (str_hash, str_equal);

    private Clutter.Color _color;
    [CCode (notify = false)] public string color {
        internal construct {
            Clutter.Color? color = colors.lookup (value);
            if (color == null)
            {
                _color = Clutter.Color.from_string (value);

                HashTable<string, Clutter.Color?> _colors = colors;
                _colors.insert (value, _color);
                colors = _colors;
            }
            else
                _color = (!) color;
        }
    }
}

private class TileView : RoundedRectangle
{
    [CCode (notify = false)] public uint8 tile_value { internal get; protected construct; }

    internal TileView (float x, float y, float width, float height, uint8 val)
    {
        Object (x: x, y: y, width: width, height: height, color: _pick_color (val), tile_value: val);
    }

    protected override bool _draw (Cairo.Context ctx, int width, int height)
    {
        Pango.Rectangle logical_rect;
        Pango.Layout layout;
        Pango.FontDescription font_desc;

        base._draw (ctx, width, height);

        ctx.set_source_rgb (255, 255, 255);

        layout = Pango.cairo_create_layout (ctx);
        font_desc = Pango.FontDescription.from_string ("Sans Bold %dpx".printf (height / 4));
        layout.set_font_description (font_desc);

        layout.set_text (Math.pow (2, tile_value).to_string (), -1);

        layout.get_extents (null, out logical_rect);
        ctx.move_to ((width / 2) - (logical_rect.width / 2 / Pango.SCALE),
                     (height / 2) - (logical_rect.height / 2 / Pango.SCALE));
        Pango.cairo_show_layout (ctx, layout);

        return false;
    }

    /*\
    * * color
    \*/

    private static string _pick_color (uint8 tile_value)
        requires (tile_value != 0)
    {
        if (tile_value > 11)
            return _calculate_color (tile_value);
        else
            return _pick_palette_color (tile_value);
    }

    private static string _calculate_color (uint8 tile_value)
        requires (tile_value != 0)
    {
        Clutter.Color color = Clutter.Color.from_string (_pick_palette_color ((tile_value - 1) % 11 + 1));

        uint8 sbits = (uint8) (Math.pow (2, tile_value) % 7);
        color.red   <<= sbits;
        color.green <<= sbits;
        color.blue  <<= sbits;

        return color.to_string ();
    }

    private static string _pick_palette_color (uint8 tile_value)
        requires (tile_value != 0)
        requires (tile_value <= 11)
    {
        switch (tile_value)
        {
            case 1:  return "#fce94f";  // Butter 1
            case 2:  return "#8ae234";  // Chameleon 1
            case 3:  return "#fcaf3e";  // Orange 1
            case 4:  return "#729fcf";  // Sky blue 1
            case 5:  return "#ad7fa8";  // Plum 1
            case 6:  return "#c17d11";  // Chocolate 2
            case 7:  return "#ef2929";  // Scarlet red 1
            case 8:  return "#c4a000";  // Butter 3
            case 9:  return "#4e9a06";  // Chameleon 3
            case 10: return "#ce5c00";  // Orange 3
            case 11: return "#204a87";  // Sky blue 3
            default: assert_not_reached ();
        }
    }
}
