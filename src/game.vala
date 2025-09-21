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

private class Game : Gtk.Widget
{
    private enum GameState {
        STOPPED,
        IDLE,
        MOVING,
        SHOWING_FIRST_TILE,
        SHOWING_NEW_TILE,
        RESTORING_TILES;

        internal static string to_string (GameState state)
        {
            switch (state)
            {
                case GameState.STOPPED:             return "stopped";
                case GameState.IDLE:                return "idle";
                case GameState.MOVING:              return "moving";
                case GameState.SHOWING_FIRST_TILE:  return "showing first tile";
                case GameState.SHOWING_NEW_TILE:    return "showing new tile";
                case GameState.RESTORING_TILES:     return "restoring tiles";
                default: assert_not_reached ();
            }
        }
    }

    private int BLANK_COL_WIDTH  = 10;
    private int BLANK_ROW_HEIGHT = 10;

    private Grid _grid;

    private TileView? [,] _foreground_cur;
    private TileView? [,] _foreground_nxt;

    private Gee.LinkedList<TileMovement?> _to_move = new Gee.LinkedList<TileMovement?> ();
    private Gee.LinkedList<TileMovement?> _to_hide = new Gee.LinkedList<TileMovement?> ();
    private Gee.LinkedList<Tile?>         _to_show = new Gee.LinkedList<Tile?> ();

    private GameState _state = GameState.STOPPED;
    private Adw.Animation _show_hide_trans;
    private Gee.ArrayList<GridPosition?> _show_trans_tiles = new Gee.ArrayList<GridPosition?> ();
    private Gee.ArrayList<GridPosition?> _hide_trans_tiles = new Gee.ArrayList<GridPosition?> ();
    private double _show_hide_trans_value = -1;
    private Adw.Animation _move_trans;
    private double _move_trans_value = -1;
    private Gee.ArrayList<TileMovement?> _move_trans_tiles = new Gee.ArrayList<TileMovement?> ();
    private int _animations_duration;

    private string _saved_path = Path.build_filename (Environment.get_user_data_dir (), "gnome-2048", "saved");

    public GLib.Settings settings;

    private void _init_grid (uint8 rows, uint8 cols)
    {
        _grid = new Grid (rows, cols);
        settings.bind ("target-value", _grid, "target-value", GLib.SettingsBindFlags.DEFAULT | GLib.SettingsBindFlags.NO_SENSITIVITY);
    }

    private Gdk.RGBA _background_color;
    private Gdk.RGBA _empty_tile_color;
    private Gdk.RGBA _text_color;

    construct {
        settings = new GLib.Settings ("org.gnome.TwentyFortyEight");

        _background_color.parse ("#babdb6");
        _empty_tile_color.parse ("#ffffff");
        _text_color.parse ("#ffffff");

        width_request = 350;
        height_request = 350;
        focusable = true;

        uint8 cols = (uint8) settings.get_int ("cols"); // schema ranges cols
        uint8 rows = (uint8) settings.get_int ("rows"); // and rows from 1 to 9
        _init_grid (rows, cols);

        var key_controller = new Gtk.EventControllerKey ();
        key_controller.key_pressed.connect (on_key_pressed);
        add_controller (key_controller);

        var gesture_swipe = new Gtk.GestureSwipe ();
        gesture_swipe.set_propagation_phase (Gtk.PropagationPhase.CAPTURE);
        gesture_swipe.set_button (/* all buttons */ 0);
        gesture_swipe.swipe.connect (_on_swipe);
        add_controller (gesture_swipe);
    }

    /*\
    * * keyboard user actions
    \*/

    private const uint16 KEYCODE_W = 25;
    private const uint16 KEYCODE_A = 38;
    private const uint16 KEYCODE_S = 39;
    private const uint16 KEYCODE_D = 40;

    private inline bool on_key_pressed (Gtk.EventControllerKey _key_controller, uint keyval, uint keycode, Gdk.ModifierType state)
    {
        if (cannot_move ())
            return false;

        switch (keycode)
        {
            case KEYCODE_W:     move (MoveRequest.UP);      return true;
            case KEYCODE_A:     move (MoveRequest.LEFT);    return true;
            case KEYCODE_S:     move (MoveRequest.DOWN);    return true;
            case KEYCODE_D:     move (MoveRequest.RIGHT);   return true;
        }
        switch (_upper_key (keyval))
        {
            case Gdk.Key.Up:    move (MoveRequest.UP);      return true;
            case Gdk.Key.Left:  move (MoveRequest.LEFT);    return true;
            case Gdk.Key.Down:  move (MoveRequest.DOWN);    return true;
            case Gdk.Key.Right: move (MoveRequest.RIGHT);   return true;
        }
        return false;
    }

    private static inline uint _upper_key (uint keyval)
    {
        return (keyval > 255) ? keyval : ((char) keyval).toupper ();
    }

    /*\
    * * gestures
    \*/

    private inline void _on_swipe (Gtk.GestureSwipe _gesture_swipe, double velocity_x, double velocity_y)
    {
        uint button = _gesture_swipe.get_current_button ();
        if (button != Gdk.BUTTON_PRIMARY && button != Gdk.BUTTON_SECONDARY)
            return;

        if (cannot_move ())
            return;

        double abs_x = velocity_x.abs ();
        double abs_y = velocity_y.abs ();
        if (abs_x * abs_x + abs_y * abs_y < 400.0)
            return;
        bool left_or_right = abs_y * 4.0 < abs_x;
        bool up_or_down = abs_x * 4.0 < abs_y;
        if (left_or_right)
        {
            if (velocity_x < -10.0)
                move (MoveRequest.LEFT);
            else if (velocity_x > 10.0)
                move (MoveRequest.RIGHT);
        }
        else if (up_or_down)
        {
            if (velocity_y < -10.0)
                move (MoveRequest.UP);
            else if (velocity_y > 10.0)
                move (MoveRequest.DOWN);
        }
    }

    protected override void snapshot (Gtk.Snapshot snapshot)
    {
        var width = get_width ();
        var height = get_height ();

        Graphene.Rect rect = Graphene.Rect () {
            origin = { x: 0, y: 0 },
            size = { width: width, height: height }
        };

        snapshot.append_color (_background_color, rect);

        uint8 rows = _grid.rows;
        uint8 cols = _grid.cols;

        float tile_width  = (width  - (cols + 1) * BLANK_COL_WIDTH)  / cols;
        float tile_height = (height - (rows + 1) * BLANK_ROW_HEIGHT) / rows;

        Graphene.Rect tile_rect = Graphene.Rect () {
            origin = { x: 0, y: 0 },
            size = { width: tile_width, height: tile_height }
        };

        float radius = (tile_height > tile_width) ? (tile_height / 20.0f) : (tile_width / 20.0f);
        Graphene.Size rounded_corner = Graphene.Size () {
            height = radius,
            width = radius
        };

        Pango.Layout layout = new Pango.Layout (get_pango_context());
        Pango.FontDescription font_desc = Pango.FontDescription.from_string ("Sans Bold %dpx".printf ((int) tile_height / 4));
        layout.set_font_description (font_desc);

        for (uint8 i = 0; i < rows; i++)
        {
            for (uint8 j = 0; j < cols; j++)
            {
                float x = j * tile_width  + (j + 1) * BLANK_COL_WIDTH  + tile_width / 2;
                float y = i * tile_height + (i + 1) * BLANK_ROW_HEIGHT + tile_height / 2;

                snapshot.save ();
                snapshot.translate (Graphene.Point () { x = x, y = y });
                draw_tile(snapshot, tile_width, tile_height, null, 1.0f, layout);
                snapshot.restore ();
            }
        }

        for (uint8 i = 0; i < rows; i++)
        {
            for (uint8 j = 0; j < cols; j++)
            {
                TileView?[] tiles = { _foreground_cur [i, j], _foreground_nxt [i, j] };

                foreach (var tile in tiles) if (tile != null)
                {
                    GridPosition pos = { (int8) i, (int8) j };

                    float x = j * tile_width  + (j + 1) * BLANK_COL_WIDTH  + tile_width / 2;
                    float y = i * tile_height + (i + 1) * BLANK_ROW_HEIGHT + tile_height / 2;

                    snapshot.save ();
                    snapshot.translate (Graphene.Point () { x = x, y = y });

                    TileMovement? move_anim = null;

                    if (_is_tile_animating_hide (pos))
                    {
                        var opacity = 1.0f - (float) _show_hide_trans_value;

                        draw_tile(snapshot, tile_width, tile_height, tile, opacity, layout);
                    }
                    else if (_is_tile_animating_show (pos))
                    {
                        var factor = 1.0f - 2.0f * ((float) _show_hide_trans_value - 0.5f).abs ();
                        factor = 1.0f + 0.1f * factor;

                        var opacity = (float) _show_hide_trans_value;

                        draw_tile(snapshot, factor * tile_width, factor * tile_height, tile, opacity, layout);
                    }
                    else if ((move_anim = _is_tile_animating_move (pos)) != null)
                    {
                        float from_j = ((!) move_anim).from.col;
                        float from_i = ((!) move_anim).from.row;

                        float from_x = from_j * tile_width  + (from_j + 1) * BLANK_COL_WIDTH  + tile_width / 2;
                        float from_y = from_i * tile_height + (from_i + 1) * BLANK_ROW_HEIGHT + tile_height / 2;

                        float offset_x = (1.0f - (float) _move_trans_value) * (from_x - x);
                        float offset_y = (1.0f - (float) _move_trans_value) * (from_y - y);

                        snapshot.save ();
                        snapshot.translate (Graphene.Point () { x = offset_x, y = offset_y });
                        draw_tile(snapshot, tile_width, tile_height, tile, 1.0f, layout);
                        snapshot.restore ();
                    }
                    else
                    {
                        draw_tile(snapshot, tile_width, tile_height, tile, 1.0f, layout);
                    }

                    snapshot.restore ();
                }
            }
        }
    }

    private inline bool _is_tile_animating_show (GridPosition pos)
    {
        if (_show_hide_trans_value < 0.0)
            return false;
        return _show_trans_tiles.any_match ((p) =>
            ((!) p).row == pos.row &&
            ((!) p).col == pos.col
        );
    }

    private inline bool _is_tile_animating_hide (GridPosition pos)
    {
        if (_show_hide_trans_value < 0.0)
            return false;
        return _hide_trans_tiles.any_match ((p) =>
            ((!) p).row == pos.row &&
            ((!) p).col == pos.col
        );
    }

    private inline TileMovement? _is_tile_animating_move (GridPosition pos)
    {
        if (_move_trans_value < 0.0)
            return null;
        return _move_trans_tiles.first_match ((p) =>
            ((!) p).to.row == pos.row &&
            ((!) p).to.col == pos.col
        );
    }

    private void draw_tile(Gtk.Snapshot snapshot, float tile_width, float tile_height, TileView? tile, float opacity, Pango.Layout layout)
    {
        Graphene.Rect tile_rect = Graphene.Rect () {
            origin = { x: 0, y: 0 },
            size = { width: tile_width, height: tile_height }
        };

        float radius = (tile_height > tile_width) ? (tile_height / 20.0f) : (tile_width / 20.0f);
        Graphene.Size rounded_corner = Graphene.Size () {
            height = radius,
            width = radius
        };

        snapshot.save ();
        snapshot.translate (Graphene.Point () { x = - tile_width / 2, y = - tile_height / 2 });

        snapshot.push_rounded_clip ((!) Gsk.RoundedRect ().init (tile_rect, rounded_corner, rounded_corner, rounded_corner, rounded_corner));

        if (tile != null)
        {
            var color = ((!) tile).color_rgba ();
            color.alpha = opacity;
            snapshot.append_color (color, tile_rect);

            layout.set_text (Math.pow (2, ((!) tile).color).to_string (), -1);

            Pango.Rectangle logical_rect;
            layout.get_extents (null, out logical_rect);

            snapshot.save ();
            snapshot.translate (Graphene.Point () {
                x = (tile_width  / 2) - (logical_rect.width  / 2 / Pango.SCALE),
                y = (tile_height / 2) - (logical_rect.height / 2 / Pango.SCALE)
            });
            snapshot.append_layout (layout, _text_color);
            snapshot.restore ();
        }
        else
        {
            snapshot.append_color (_empty_tile_color, tile_rect);
        }

        snapshot.pop ();

        snapshot.restore ();
    }

    /*\
    * * others
    \*/

    private bool _just_restored = true;

    [CCode (notify = true)] internal long score { internal get; private set; default = 0; }

    internal void new_game (ref GLib.Settings settings)
    {
        if (_state != GameState.IDLE && _state != GameState.STOPPED)
            return;

        _clean_finish_move_animation ();
        _grid.clear ();
        _clear_history ();

        uint8 cols = (uint8) settings.get_int ("cols");  // schema ranges cols
        uint8 rows = (uint8) settings.get_int ("rows"); // and rows from 1 to 9

        if ((rows != _grid.rows) || (cols != _grid.cols))
        {
            _init_grid (rows, cols);
        }
        _init_foreground ();

        score = 0;
        _state = GameState.SHOWING_FIRST_TILE;
        _create_random_tile ();
        undo_disabled ();

        _just_restored = false;
    }

    internal void save_game ()
    {
        _grid.save_game (_saved_path);
    }

    internal bool restore_game (ref GLib.Settings settings)
    {
        if (!_grid.restore_game (_saved_path))
            return false;

        score = _grid.get_score ();

        _init_foreground ();
        _restore_foreground (true);

        uint8 rows = _grid.rows;
        uint8 cols = _grid.cols;
        if ((rows == 3 && cols != 3)
         || (rows == 4 && cols != 4)
         || (rows == 5 && cols != 5)
         || (rows != 3 && rows != 4 && rows != 5))
        {
            settings.delay ();
            settings.set_int ("rows", rows);
            settings.set_int ("cols", cols);
            settings.apply ();
        }

        _just_restored = true;

        debug ("game restored successfully");
        return true;
    }

    internal bool cannot_move ()
    {
        return _state != GameState.IDLE
            && _state != GameState.SHOWING_NEW_TILE;
    }

    internal void load_settings (ref GLib.Settings settings)
    {
        _animations_duration = (int) settings.get_double ("animations-speed");
        _load_undo_settings (ref settings);
    }

    private void _init_foreground ()
    {
        uint8 rows = _grid.rows;
        uint8 cols = _grid.cols;

        _foreground_cur = new TileView? [rows, cols];
        _foreground_nxt = new TileView? [rows, cols];

        for (uint8 i = 0; i < rows; i++)
        {
            for (uint8 j = 0; j < cols; j++)
            {
                _foreground_cur [i, j] = null;
                _foreground_nxt [i, j] = null;
            }
        }
    }

    private void _create_random_tile ()
    {
        Tile tile;
        _grid.new_tile (out tile);

        if (_state == GameState.SHOWING_FIRST_TILE)
            _update_handled = true;
        else
        {
            _update_handled = false;
            _state = GameState.SHOWING_NEW_TILE;
        }
        _create_show_hide_transition (true);

        _create_tile (tile);
        _to_show.add (tile);
        _show_tile (tile.pos);
        _show_hide_trans.play ();
    }

    private void _create_tile (Tile tile)
    {
        GridPosition pos = tile.pos;
        assert (_foreground_nxt [pos.row, pos.col] == null);

        _foreground_nxt [pos.row, pos.col] = new TileView (tile.val);
    }

    private void _show_tile (GridPosition pos)
    {
        debug (@"show tile pos $pos");

        TileView? tile_view = _foreground_nxt [pos.row, pos.col];
        if (tile_view == null)
            assert_not_reached ();

        _show_trans_tiles.add (pos);
    }

    private void _move_tile (GridPosition from, GridPosition to)
    {
        debug (@"move tile from $from to $to");

        _prepare_move_tile (from, to);

        _foreground_nxt [  to.row,   to.col] = _foreground_cur [from.row, from.col];
        _foreground_cur [from.row, from.col] = null;
    }

    private void _prepare_move_tile (GridPosition from, GridPosition to)
    {
        debug (@"prepare move tile from $from to $to");

        TileView? tile_view = _foreground_cur [from.row, from.col];
        if (tile_view == null)
            assert_not_reached ();

        _move_trans_tiles.add (TileMovement () { to = to, from = from });
    }

    private void _dim_tile (GridPosition pos)
    {
        TileView? tile_view = _foreground_cur [pos.row, pos.col];
        if (tile_view == null)
            assert_not_reached ();
        debug (@"diming tile at $pos " + ((!) tile_view).color.to_string ());

        _hide_trans_tiles.add (pos);
    }

    private void _clear_foreground ()
    {
        uint8 rows = _grid.rows;
        uint8 cols = _grid.cols;
        for (uint8 i = 0; i < rows; i++)
        {
            for (uint8 j = 0; j < cols; j++)
            {
                _foreground_cur [i, j] = null;
                _foreground_nxt [i, j] = null;
            }
        }
    }

    private void _restore_foreground (bool animate)
    {
        uint8 rows = _grid.rows;
        uint8 cols = _grid.cols;

        _create_show_hide_transition (animate);

        for (uint8 i = 0; i < rows; i++)
        {
            for (uint8 j = 0; j < cols; j++)
            {
                uint8 val = _grid [i, j];
                if (val != 0)
                {
                    GridPosition pos = { (int8) i, (int8) j };
                    Tile tile = { pos, val };
                    _create_tile (tile);
                    _to_show.add (tile);
                    _show_tile (pos);
                }
            }
        }

        if (_to_show.size > 0)
        {
            _state = GameState.RESTORING_TILES;
            _show_hide_trans.play ();
        }
    }

    /*\
    * * move animation
    \*/

    internal void move (MoveRequest request)
    {
        if (_state == GameState.SHOWING_NEW_TILE)
            _apply_move ();
        else if (_state != GameState.IDLE)
            assert_not_reached ();

        debug (MoveRequest.debug_string (request));

        Grid clone = _grid.clone ();

        _move_trans = new Adw.TimedAnimation (this, 0.0d, 1.0d, _animations_duration,
            new Adw.CallbackAnimationTarget ((value) => {
                _move_trans_value = value;
                queue_draw ();
            })
        );
        _move_trans.done.connect (_on_move_trans_stopped);

        _grid.move (request, ref _to_move, ref _to_hide, ref _to_show);

        foreach (TileMovement? e in _to_move)
        {
            if (e == null)
                assert_not_reached ();
            _move_tile (((!) e).from, ((!) e).to);
        }
        foreach (TileMovement? e in _to_hide)
        {
            if (e == null)
                assert_not_reached ();
            _prepare_move_tile (((!) e).from, ((!) e).to);
        }

        if ((_to_move.size > 0) || (_to_hide.size > 0) || (_to_show.size > 0))
        {
            _state = GameState.MOVING;
            _move_trans.play ();
            _store_movement (clone);
        }

        _just_restored = false;
    }

    private void _on_move_trans_stopped ()
    {
        debug (@"move animation stopped\n$_grid");

        _move_trans_value = -1;
        _move_trans_tiles.clear ();

        foreach (TileMovement? e in _to_hide)
        {
            if (e == null)
                assert_not_reached ();
            _dim_tile (((!) e).from);
        }

        long delta_score = 0;   // do not notify["score"] multiple times
        foreach (Tile? e in _to_show)
        {
            if (e == null)
                assert_not_reached ();
            _create_tile ((!) e);
            _show_tile (((!) e).pos);
            delta_score += (long) Math.pow (2, ((!) e).val);
        }
        score += delta_score;

        _create_random_tile ();
    }

    /*\
    * * new tile animation
    \*/

    internal signal void finished (bool show_scores);
    internal signal void target_value_reached (uint val);

    private uint _finish_move_id = 0;
    private bool _update_handled = false;

    private void _create_show_hide_transition (bool animate)
    {
        /* _show_hide_trans should be finished two times (forward and backward) before
           one _move_trans is done, so at least animation time should be strictly half */
        _show_hide_trans = new Adw.TimedAnimation (this,
            0.0d,
            1.0d,
            animate ? _animations_duration : 10,
            new Adw.CallbackAnimationTarget ((value) => {
                _show_hide_trans_value = value;
                queue_draw ();
            })
        );
        _show_hide_trans.done.connect (_on_show_hide_trans_stopped);
    }

    private void _on_show_hide_trans_stopped ()
    {
        debug ("show/hide animation stopped");
        _show_hide_trans_value = -1;
        _show_trans_tiles.clear ();
        _hide_trans_tiles.clear ();
        _apply_move ();
    }

    private void _apply_move ()
    {
        debug (@"$_grid");

        if (_update_handled && _state != GameState.SHOWING_FIRST_TILE)
            return;
        _update_handled = true;

        foreach (TileMovement? e in _to_hide)
        {
            if (e == null)
                assert_not_reached ();
            GridPosition pos = ((!) e).from;
            TileView? tile_view = _foreground_cur [pos.row, pos.col];
            if (tile_view == null)
                assert_not_reached ();
            //  ((!) tile_view).hide ();
            debug (@"remove child " + ((!) tile_view).color.to_string ());
            //  _view_foreground.remove_child (((!) tile_view).actor);

            _foreground_cur [pos.row, pos.col] = null;
        }

        if (_state == GameState.SHOWING_FIRST_TILE)
        {
            _state = GameState.SHOWING_NEW_TILE;
            debug ("state show second tile");
            _create_random_tile ();
        }
        else if (_state != GameState.IDLE)
        {
            _state = GameState.IDLE;
            debug ("state idle");
        }

        foreach (TileMovement? e in _to_move)
        {
            if (e == null)
                assert_not_reached ();
            GridPosition to = ((!) e).to;
            _foreground_cur [to.row, to.col] = _foreground_nxt [to.row, to.col];
            _foreground_nxt [to.row, to.col] = null;
        }
        foreach (Tile? e in _to_show)
        {
            if (e == null)
                assert_not_reached ();
            GridPosition pos = ((!) e).pos;
            _foreground_cur [pos.row, pos.col] = _foreground_nxt [pos.row, pos.col];
            _foreground_nxt [pos.row, pos.col] = null;
        }

        _to_hide.clear ();
        _to_move.clear ();
        _to_show.clear ();

        if (_grid.target_value_reached)
        {
            target_value_reached (_grid.target_value);
            _grid.target_value_reached = false;
        }

        if (!_just_restored)
            _finish_move_id = GLib.Timeout.add (100, _finish_move);
        else if (_grid.is_finished ())
            finished (/* show scores */ false);
    }

    private bool _finish_move ()
    {
        if (_grid.is_finished ())
            finished (/* show scores */ true);

        _finish_move_id = 0;
        return false;
    }

    private inline void _clean_finish_move_animation ()
    {
        if (_finish_move_id > 0)
            Source.remove (_finish_move_id);
    }

    /*\
    * * history
    \*/

    internal signal void undo_enabled ();
    internal signal void undo_disabled ();

    private bool _allow_undo = false;
    private uint _undo_stack_max_size;
    private Gee.LinkedList<Grid> _undo_stack = new Gee.LinkedList<Grid> ();

    internal void undo ()
        requires (_allow_undo == true)
    {
        if (_state != GameState.IDLE)
            return;

        _clear_foreground ();
        _grid = (!) _undo_stack.poll_head ();
        _restore_foreground (false);
        score = _grid.get_score ();

        if (_undo_stack.size == 0)
            undo_disabled ();
        _update_handled = false;
    }

    private void _load_undo_settings (ref GLib.Settings settings)
    {
        bool allow_undo = settings.get_boolean ("allow-undo");
        if (_allow_undo && !allow_undo)
        {
            _clear_history ();
            undo_disabled ();
        }
        _allow_undo = allow_undo;
        _undo_stack_max_size = settings.get_uint ("allow-undo-max");
    }

    private void _clear_history ()
    {
        _undo_stack.clear ();
    }

    private void _store_movement (Grid clone)
    {
        if (!_allow_undo)
            return;

        if (_undo_stack.size >= _undo_stack_max_size)
            _undo_stack.poll_tail ();
        _undo_stack.offer_head (clone);
        if (_undo_stack.size == 1)
            undo_enabled ();
    }
}
