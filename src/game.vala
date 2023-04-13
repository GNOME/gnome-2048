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

private class Game : Object
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

    private RoundedRectangle [,] _background;
    private bool _background_init_done = false;
    private TileView? [,] _foreground_cur;
    private TileView? [,] _foreground_nxt;

    private Gee.LinkedList<TileMovement?> _to_move = new Gee.LinkedList<TileMovement?> ();
    private Gee.LinkedList<TileMovement?> _to_hide = new Gee.LinkedList<TileMovement?> ();
    private Gee.LinkedList<Tile?>         _to_show = new Gee.LinkedList<Tile?> ();

    private GameState _state = GameState.STOPPED;
    private Clutter.TransitionGroup _show_hide_trans;
    private Clutter.TransitionGroup _move_trans;
    private int _animations_duration;

    private string _saved_path = Path.build_filename (Environment.get_user_data_dir (), "gnome-2048", "saved");

    private uint _resize_view_id;

    internal Game (ref GLib.Settings settings)
    {
        uint8 cols = (uint8) settings.get_int ("cols");  // schema ranges cols
        uint8 rows = (uint8) settings.get_int ("rows"); // and rows from 1 to 9
        _init_grid (rows, cols, out _grid, ref settings);
    }

    private static void _init_grid (uint8 rows, uint8 cols, out Grid grid, ref GLib.Settings settings)
    {
        grid = new Grid (rows, cols);
        settings.bind ("target-value", grid, "target-value", GLib.SettingsBindFlags.DEFAULT | GLib.SettingsBindFlags.NO_SENSITIVITY);
    }

    /*\
    * * view
    \*/

    private Clutter.Actor _view;
    private Clutter.Actor _view_background;
    private Clutter.Actor _view_foreground;

    [CCode (notify = false)] internal Clutter.Actor view {
        internal get { return _view; }
        internal set {
            _view = value;
            _view.allocation_changed.connect (_on_allocation_changed);

            _view_background = new Clutter.Actor ();
            _view_foreground = new Clutter.Actor ();
            _view_background.show ();
            _view_foreground.show ();
            _view.add_child (_view_background);
            _view.add_child (_view_foreground);
        }
    }

    private void _on_allocation_changed (Clutter.ActorBox box, Clutter.AllocationFlags flags)
    {
        if (_background_init_done)
            _resize_view ();
        else
            _init_background ();
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
            _clear_foreground ();
            _clear_background ();

            _init_grid (rows, cols, out _grid, ref settings);

            _init_background ();
        }
        else if (_background_init_done)
            _clear_foreground ();
        else // new_game could be called without an existing game
            _init_background ();

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

        if (_background_init_done)
            _clear_background ();
        _init_background ();
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

    private void _init_background ()
    {
        uint8 rows = _grid.rows;
        uint8 cols = _grid.cols;
        Clutter.Color background_color = Clutter.Color.from_string ("#babdb6");
        _view.set_background_color (background_color);

        _background     = new RoundedRectangle [rows, cols];
        _foreground_cur = new TileView? [rows, cols];
        _foreground_nxt = new TileView? [rows, cols];

        float canvas_width  = _view.width;
        float canvas_height = _view.height;

        canvas_width  -= (cols + 1) * BLANK_COL_WIDTH;
        canvas_height -= (rows + 1) * BLANK_ROW_HEIGHT;

        float tile_width  = canvas_width  / cols;
        float tile_height = canvas_height / rows;

        for (uint8 i = 0; i < rows; i++)
        {
            for (uint8 j = 0; j < cols; j++)
            {
                float x = j * tile_width  + (j + 1) * BLANK_COL_WIDTH;
                float y = i * tile_height + (i + 1) * BLANK_ROW_HEIGHT;

                RoundedRectangle rect = new RoundedRectangle (x, y, tile_width, tile_height);

                _view_background.add_child (rect.actor);
                rect.canvas.invalidate ();
                rect.actor.show ();

                _background     [i, j] = rect;
                _foreground_cur [i, j] = null;
                _foreground_nxt [i, j] = null;
            }
        }
        _background_init_done = true;
    }

    private void _resize_view ()
    {
        uint8 rows = _grid.rows;
        uint8 cols = _grid.cols;
        float canvas_width  = _view.width;
        float canvas_height = _view.height;

        canvas_width  -= (cols + 1) * BLANK_COL_WIDTH;
        canvas_height -= (rows + 1) * BLANK_ROW_HEIGHT;

        float tile_width  = canvas_width  / cols;
        float tile_height = canvas_height / rows;

        for (uint8 i = 0; i < rows; i++)
        {
            for (uint8 j = 0; j < cols; j++)
            {
                float x = j * tile_width  + (j + 1) * BLANK_COL_WIDTH;
                float y = i * tile_height + (i + 1) * BLANK_ROW_HEIGHT;

                _background [i, j].resize (x, y, tile_width, tile_height);

                if (_foreground_cur [i, j] != null)
                    ((!) _foreground_cur [i, j]).resize (x, y, tile_width, tile_height);

                if (_foreground_nxt [i, j] != null)
                    ((!) _foreground_nxt [i, j]).resize (x, y, tile_width, tile_height);
            }
        }

        if (_resize_view_id == 0)
            _resize_view_id = Clutter.Threads.Timeout.add (1000, _idle_resize_view);
    }

    private bool _idle_resize_view ()
    {
        uint8 rows = _grid.rows;
        uint8 cols = _grid.cols;
        for (uint8 i = 0; i < rows; i++)
        {
            for (uint8 j = 0; j < cols; j++)
            {
                _background [i, j].idle_resize ();

                if (_foreground_cur [i, j] != null)
                    ((!) _foreground_cur [i, j]).idle_resize ();

                if (_foreground_nxt [i, j] != null)
                    ((!) _foreground_nxt [i, j]).idle_resize ();
            }
        }

        _resize_view_id = 0;
        return false;
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
        _show_hide_trans.start ();
    }

    private void _create_tile (Tile tile)
    {
        GridPosition pos = tile.pos;
        assert (_foreground_nxt [pos.row, pos.col] == null);

        Clutter.Actor actor = _background [pos.row, pos.col].actor;
        _foreground_nxt [pos.row, pos.col] = new TileView (actor.x,
                                                           actor.y,
                                                           actor.width,
                                                           actor.height,
                                                           tile.val);
    }

    private void _show_tile (GridPosition pos)
    {
        debug (@"show tile pos $pos");

        Clutter.PropertyTransition trans;

        TileView? tile_view = _foreground_nxt [pos.row, pos.col];
        if (tile_view == null)
            assert_not_reached ();
        Clutter.Actor actor = ((!) tile_view).actor;

        ((!) tile_view).canvas.invalidate ();
        actor.set_opacity (0);
        actor.show ();
        _view_foreground.add_child (actor);

        trans = new Clutter.PropertyTransition ("scale-x");
        trans.set_from_value (1.0);
        trans.set_to_value (1.1);
        trans.set_duration (_animations_duration);
        trans.set_animatable (actor);
        _show_hide_trans.add_transition (trans);

        trans = new Clutter.PropertyTransition ("scale-y");
        trans.set_from_value (1.0);
        trans.set_to_value (1.1);
        trans.set_duration (_animations_duration);
        trans.set_animatable (actor);
        _show_hide_trans.add_transition (trans);

        trans = new Clutter.PropertyTransition ("opacity");
        trans.set_from_value (0);
        trans.set_to_value (255);
        trans.set_remove_on_complete (true);
        trans.set_duration (_animations_duration / 2);
        actor.add_transition ("show", trans);
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

        bool row_move = (from.col == to.col);

        RoundedRectangle rect_from = _background [from.row, from.col];
        RoundedRectangle rect_to   = _background [  to.row,   to.col];

        TileView? tile_view = _foreground_cur [from.row, from.col];
        if (tile_view == null)
            assert_not_reached ();

        Clutter.PropertyTransition trans = new Clutter.PropertyTransition (row_move ? "y" : "x");
        trans.set_from_value (row_move ? rect_from.actor.y : rect_from.actor.x);
        trans.set_to_value (row_move ? rect_to.actor.y : rect_to.actor.x);
        trans.set_duration (_animations_duration);
        trans.set_animatable (((!) tile_view).actor);
        _move_trans.add_transition (trans);
    }

    private void _dim_tile (GridPosition pos)
    {
        TileView? tile_view = _foreground_cur [pos.row, pos.col];
        if (tile_view == null)
            assert_not_reached ();
        debug (@"diming tile at $pos " + ((!) tile_view).color.to_string ());

        Clutter.Actor actor;
        Clutter.PropertyTransition trans;

        actor = ((!) tile_view).actor;

        trans = new Clutter.PropertyTransition ("opacity");
        trans.set_from_value (actor.opacity);
        trans.set_to_value (0);
        trans.set_duration (_animations_duration);
        trans.set_animatable (actor);

        _show_hide_trans.add_transition (trans);
    }

    private void _clear_background ()
    {
        _view_background.remove_all_children ();
    }

    private void _clear_foreground ()
    {
        uint8 rows = _grid.rows;
        uint8 cols = _grid.cols;
        _view_foreground.remove_all_children ();
        for (uint8 i = 0; i < rows; i++)
        {
            for (uint8 j = 0; j < cols; j++)
            {
                if (_foreground_cur [i, j] != null)
                    _foreground_cur [i, j] = null;
                if (_foreground_nxt [i, j] != null)
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
            _show_hide_trans.start ();
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

        _move_trans = new Clutter.TransitionGroup ();
        _move_trans.stopped.connect (_on_move_trans_stopped);
        _move_trans.set_duration (_animations_duration);

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
            _move_trans.start ();
            _store_movement (clone);
        }

        _just_restored = false;
    }

    private void _on_move_trans_stopped (Clutter.Timeline trans, bool is_finished)
    {
        debug (@"move animation stopped\n$_grid");

        ((Clutter.TransitionGroup) trans).remove_all ();

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
        _show_hide_trans = new Clutter.TransitionGroup ();
        _show_hide_trans.stopped.connect (_on_show_hide_trans_stopped);
        /* _show_hide_trans should be finished two times (forward and backward) before
           one _move_trans is done, so at least animation time should be strictly half */
        _show_hide_trans.set_duration (animate ? _animations_duration / 3 : 10);
    }

    private void _on_show_hide_trans_stopped (Clutter.Timeline trans, bool is_finished)
    {
        debug ("show/hide animation stopped");

        if (trans.direction == Clutter.TimelineDirection.FORWARD)
        {
            trans.direction = Clutter.TimelineDirection.BACKWARD;
            trans.start ();
            return;
        }

        ((Clutter.TransitionGroup) trans).remove_all ();
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
            ((!) tile_view).actor.hide ();
            debug (@"remove child " + ((!) tile_view).color.to_string ());
            _view_foreground.remove_child (((!) tile_view).actor);

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
