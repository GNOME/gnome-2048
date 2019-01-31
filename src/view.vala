/* Copyright (C) 2014-2015 Juan R. García Blanco <juanrgar@gmail.com>
 * Copyright (C) 2016 Arnaud Bonatti <arnaud.bonatti@gmail.com>
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
    internal Clutter.Actor  actor   { internal get; private set; default = new Clutter.Actor (); }
    internal Clutter.Canvas canvas  { internal get; private set; default = new Clutter.Canvas (); }

    private Clutter.Color _color;
    public Clutter.Color color {
        get { return _color; }
        construct {
            _color = value;
            canvas.invalidate ();
        }
    }

    internal RoundedRectangle (float x, float y, float width, float height, Clutter.Color color)
    {
        Object (color: color);

        canvas.set_size ((int)Math.ceilf (width), (int)Math.ceilf (height));

        actor.set_size (width, height);
        actor.set_content (canvas);
        actor.x = x;
        actor.y = y;
        actor.set_pivot_point (0.5f, 0.5f);

        canvas.draw.connect (_draw);
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
        if (!canvas.set_size ((int)Math.ceilf (actor.width), (int)Math.ceilf (actor.height)))
            canvas.invalidate ();
    }

    protected virtual bool _draw (Cairo.Context ctx, int width, int height)
    {
        double radius = height / 20.0;
        double degrees = Math.PI / 180.0;

        ctx.save ();
        ctx.set_operator (Cairo.Operator.CLEAR);
        ctx.paint ();
        ctx.restore ();

        ctx.new_sub_path ();
        ctx.arc (width - radius, radius, radius, -90 * degrees, 0 * degrees);
        ctx.arc (width - radius, height - radius, radius, 0 * degrees, 90 * degrees);
        ctx.arc (radius, height - radius, radius, 90 * degrees, 180 * degrees);
        ctx.arc (radius, radius, radius, 180 * degrees, 270 * degrees);
        ctx.close_path ();

        Clutter.cairo_set_source_color (ctx, (!) _color);
        ctx.fill ();

        return false;
    }
}

private class TileView : RoundedRectangle
{
    internal uint tile_value { internal get; private set; default = 2; }

    internal TileView (float x, float y, float width, float height, uint val)
    {
        base (x, y, width, height, _pick_color (val));
        tile_value = val;
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

        layout.set_text (tile_value.to_string (), -1);

        layout.get_extents (null, out logical_rect);
        ctx.move_to ((width / 2) - (logical_rect.width / 2 / Pango.SCALE),
                     (height / 2) - (logical_rect.height / 2 / Pango.SCALE));
        Pango.cairo_show_layout (ctx, layout);

        return false;
    }

    /*\
    * * color
    \*/

    private static Clutter.Color _pick_color (uint tile_value)
    {
        if (tile_value <= 2048)
            return _pick_palette_color (tile_value);
        else
            return _calculate_color (tile_value);
    }

    private static Clutter.Color _pick_palette_color (uint tile_value)
    {
        switch (tile_value)
        {
            case 2:    return Clutter.Color.from_string ("#fce94f"); // Butter 1
            case 4:    return Clutter.Color.from_string ("#8ae234"); // Chameleon 1
            case 8:    return Clutter.Color.from_string ("#fcaf3e"); // Orange 1
            case 16:   return Clutter.Color.from_string ("#729fcf"); // Sky blue 1
            case 32:   return Clutter.Color.from_string ("#ad7fa8"); // Plum 1
            case 64:   return Clutter.Color.from_string ("#c17d11"); // Chocolate 2
            case 128:  return Clutter.Color.from_string ("#ef2929"); // Scarlet red 1
            case 256:  return Clutter.Color.from_string ("#c4a000"); // Butter 3
            case 512:  return Clutter.Color.from_string ("#4e9a06"); // Chameleon 3
            case 1024: return Clutter.Color.from_string ("#ce5c00"); // Orange 3
            case 2048: return Clutter.Color.from_string ("#204a87"); // Sky blue 3
            default:   assert_not_reached ();
        }
    }

    private static Clutter.Color _calculate_color (uint tile_value)
    {
        uint norm_val = tile_value / 2048;
        Clutter.Color? nullable_color = _pick_palette_color (norm_val);
        if (nullable_color == null)
            assert_not_reached ();
        Clutter.Color color = (!) nullable_color;

        uint8 sbits = (uint8) (tile_value % 7);
        color.red   <<= sbits;
        color.green <<= sbits;
        color.blue  <<= sbits;

        return color;
    }
}
