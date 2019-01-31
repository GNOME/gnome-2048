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

public class Game : Object
{
    enum GameState {
        STOPPED,
        IDLE,
        MOVING_DOWN,
        MOVING_UP,
        MOVING_RIGHT,
        MOVING_LEFT,
        SHOWING_FIRST_TILE,
        SHOWING_SECOND_TILE,
        RESTORING_TILES
    }

    private int BLANK_ROW_HEIGHT = 10;
    private int BLANK_COL_WIDTH = 10;

    private Grid _grid;

    private uint _finish_move_id = 0;
    private Clutter.Actor _view;
    private Clutter.Actor _view_background;
    private Clutter.Actor _view_foreground;
    private RoundedRectangle [,] _background;
    private bool _background_init_done = false;
    private TileView? [,] _foreground_cur;
    private TileView? [,] _foreground_nxt;

    private Gee.LinkedList<TileMovement?> _to_move = new Gee.LinkedList<TileMovement?> ();
    private Gee.LinkedList<TileMovement?> _to_hide = new Gee.LinkedList<TileMovement?> ();
    private Gee.LinkedList<Tile?>         _to_show = new Gee.LinkedList<Tile?> ();

    private GameState _state;
    private Clutter.TransitionGroup _show_hide_trans;
    private Clutter.TransitionGroup _move_trans;
    private int _animations_duration;

    private bool _allow_undo;
    private uint _undo_stack_max_size;
    private Gee.LinkedList<Grid> _undo_stack       = new Gee.LinkedList<Grid> ();
    private Gee.LinkedList<uint> _undo_score_stack = new Gee.LinkedList<uint> ();

    private GLib.Settings _settings;

    private string _saved_path;

    private uint _resize_view_id;

    public signal void finished ();
    public signal void target_value_reached (uint val);
    public signal void undo_enabled ();
    public signal void undo_disabled ();

    public Game (GLib.Settings settings)
    {
        Object ();

        _settings = settings;

        int rows = _settings.get_int ("rows");
        int cols = _settings.get_int ("cols");
        _grid = new Grid (rows, cols);

        _animations_duration = (int)_settings.get_double ("animations-speed");

        _settings.bind ("target-value", _grid, "target-value", GLib.SettingsBindFlags.DEFAULT);

        _view_background = new Clutter.Actor ();
        _view_foreground = new Clutter.Actor ();
        _view_background.show ();
        _view_foreground.show ();

        _allow_undo = _settings.get_boolean ("allow-undo");
        _undo_stack_max_size = _settings.get_uint ("allow-undo-max");

        _saved_path = Path.build_filename (Environment.get_user_data_dir (), "gnome-2048", "saved");

        _state = GameState.STOPPED;
    }

    public Clutter.Actor view {
        get { return _view; }
        set {
            _view = value;
            _view.allocation_changed.connect (_on_allocation_changed);
            _view.add_child (_view_background);
            _view.add_child (_view_foreground);
        }
    }

    internal uint score { internal get; private set; default = 0; }

    public void new_game ()
    {
        if (_finish_move_id > 0)
            Source.remove (_finish_move_id);
        _grid.clear ();
        _undo_stack.clear ();
        _undo_score_stack.clear ();

        if (_background_init_done)
            _clear_foreground ();
        else // new_game could be called without an existing game
            _init_background ();

        score = 0;
        _state = GameState.SHOWING_FIRST_TILE;
        _create_random_tile ();
        undo_disabled ();
    }

    public void undo ()
    {
        Grid grid = _undo_stack.poll_head ();
        uint delta_score = _undo_score_stack.poll_head ();

        _clear_foreground ();
        _grid = grid;
        _restore_foreground (false);
        score -= delta_score;

        if (_undo_stack.size == 0)
            undo_disabled ();
    }

    public void save_game ()
    {
        string contents = "";

        contents += _grid.save ();
        contents += _score.to_string () + "\n";

        try {
            DirUtils.create_with_parents (Path.get_dirname (_saved_path), 0775);
            FileUtils.set_contents (_saved_path, contents);
            debug ("game saved successfully");
        } catch (FileError e) {
            warning ("Failed to save game: %s", e.message);
        }
    }

    public bool restore_game ()
    {
        string contents;
        string [] lines;

        try {
            FileUtils.get_contents (_saved_path, out contents);
        } catch (FileError e) {
            return false;
        }

        if (!_grid.load (contents))
        {
            warning ("Failed to restore game from saved file");
            return false;
        }

        lines = contents.split ("\n");
        score = (uint) int.parse (lines [lines.length - 2]);

        if (_background_init_done)
            _clear_background ();
        _init_background ();
        _restore_foreground (true);

        debug ("game restored successfully");
        return true;
    }

    internal bool cannot_move ()
    {
        return _state != GameState.IDLE;
    }

    public void reload_settings ()
    {
        int rows, cols;
        bool allow_undo;

        _animations_duration = (int)_settings.get_double ("animations-speed");

        allow_undo = _settings.get_boolean ("allow-undo");
        if (_allow_undo && !allow_undo)
        {
            _undo_stack.clear ();
            _undo_score_stack.clear ();
            undo_disabled ();
        }
        _allow_undo = allow_undo;
        _undo_stack_max_size = _settings.get_uint ("allow-undo-max");

        rows = _settings.get_int ("rows");
        cols = _settings.get_int ("cols");

        if ((rows != _grid.rows) || (cols != _grid.cols))
        {
            _clear_foreground ();
            _clear_background ();

            _grid = new Grid (rows, cols);

            _init_background ();

         // return true;
        }

     // return false;
    }

    private void _on_allocation_changed (Clutter.ActorBox box, Clutter.AllocationFlags flags)
    {
        if (_background_init_done)
            _resize_view ();
        else
            _init_background ();
    }

    private void _init_background ()
    {
        int rows = _grid.rows;
        int cols = _grid.cols;
        Clutter.Color background_color = Clutter.Color.from_string ("#babdb6");
        _view.set_background_color (background_color);

        _background     = new RoundedRectangle [rows, cols];
        _foreground_cur = new TileView? [rows, cols];
        _foreground_nxt = new TileView? [rows, cols];

        float canvas_width = _view.width;
        float canvas_height = _view.height;

        canvas_width -= (cols + 1) * BLANK_COL_WIDTH;
        canvas_height -= (rows + 1) * BLANK_ROW_HEIGHT;

        float tile_width = canvas_width / cols;
        float tile_height = canvas_height / rows;

        Clutter.Color color = Clutter.Color.from_string ("#ffffff");

        for (int i = 0; i < rows; i++)
        {
            for (int j = 0; j < cols; j++)
            {
                float x = j * tile_width + (j+1) * BLANK_COL_WIDTH;
                float y = i * tile_height + (i+1) * BLANK_ROW_HEIGHT;

                RoundedRectangle rect = new RoundedRectangle (x, y, tile_width, tile_height, color);

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
        int rows = _grid.rows;
        int cols = _grid.cols;
        float canvas_width = _view.width;
        float canvas_height = _view.height;

        canvas_width -= (cols + 1) * BLANK_COL_WIDTH;
        canvas_height -= (rows + 1) * BLANK_ROW_HEIGHT;

        float tile_width = canvas_width / cols;
        float tile_height = canvas_height / rows;

        for (int i = 0; i < rows; i++)
        {
            for (int j = 0; j < cols; j++)
            {
                float x = j * tile_width + (j + 1) * BLANK_COL_WIDTH;
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
        int rows = _grid.rows;
        int cols = _grid.cols;
        for (int i = 0; i < rows; i++)
        {
            for (int j = 0; j < cols; j++)
            {
                _background [i, j].idle_resize ();

                if (_foreground_cur [i, j] != null)
                    ((!) _foreground_cur [i, j]).idle_resize ();
            }
        }

        _resize_view_id = 0;
        return false;
    }

    private void _create_random_tile ()
    {
        Tile tile;

        if (_grid.new_tile (out tile))
        {
            _create_show_hide_transition (true);

            _create_tile (tile);
            _to_show.add (tile);
            _show_tile (tile.pos);
            _show_hide_trans.start ();
        }
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

    internal void move_down ()
    {
        debug ("move down");

        Grid clone = _grid.clone ();

        _move_trans = new Clutter.TransitionGroup ();
        _move_trans.stopped.connect (_on_move_trans_stopped);
        _move_trans.set_duration (_animations_duration);

        _grid.move_down (_to_move, _to_hide, _to_show);

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
            _state = GameState.MOVING_DOWN;
            _move_trans.start ();
            _store_movement (clone);
        }
    }

    internal void move_up ()
    {
        debug ("move up");

        Grid clone = _grid.clone ();

        _move_trans = new Clutter.TransitionGroup ();
        _move_trans.stopped.connect (_on_move_trans_stopped);
        _move_trans.set_duration (_animations_duration);

        _grid.move_up (_to_move, _to_hide, _to_show);

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
            _state = GameState.MOVING_UP;
            _move_trans.start ();
            _store_movement (clone);
        }
    }

    internal void move_left ()
    {
        debug ("move left");

        Grid clone = _grid.clone ();

        _move_trans = new Clutter.TransitionGroup ();
        _move_trans.stopped.connect (_on_move_trans_stopped);
        _move_trans.set_duration (_animations_duration);

        _grid.move_left (_to_move, _to_hide, _to_show);

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
            _state = GameState.MOVING_LEFT;
            _move_trans.start ();
            _store_movement (clone);
        }
    }

    internal void move_right ()
    {
        debug ("move right");

        Grid clone = _grid.clone ();

        _move_trans = new Clutter.TransitionGroup ();
        _move_trans.stopped.connect (_on_move_trans_stopped);
        _move_trans.set_duration (_animations_duration);

        _grid.move_right (_to_move, _to_hide, _to_show);

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
            _state = GameState.MOVING_RIGHT;
            _move_trans.start ();
            _store_movement (clone);
        }
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
        debug (@"diming tile at $pos " + ((!) tile_view).@value.to_string ());

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
        int rows = _grid.rows;
        int cols = _grid.cols;
        _view_foreground.remove_all_children ();
        for (int i = 0; i < rows; i++)
        {
            for (int j = 0; j < cols; j++)
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
        uint val;
        GridPosition pos;
        Tile tile;
        int rows = _grid.rows;
        int cols = _grid.cols;

        _create_show_hide_transition (animate);

        for (int i = 0; i < rows; i++)
        {
            for (int j = 0; j < cols; j++)
            {
                val = _grid [i, j];
                if (val != 0)
                {
                    pos = { i, j };
                    tile = { pos, val };
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

    private void _on_move_trans_stopped (bool is_finished)
    {
        debug (@"move animation stopped; finished $is_finished");
        debug (@"$_grid");

        _move_trans.remove_all ();

        _create_show_hide_transition (true);

        foreach (TileMovement? e in _to_hide)
        {
            if (e == null)
                assert_not_reached ();
            _dim_tile (((!) e).from);
        }

        uint delta_score = 0;
        foreach (Tile? e in _to_show)
        {
            if (e == null)
                assert_not_reached ();
            _create_tile ((!) e);
            _show_tile (((!) e).pos);
            delta_score += ((!) e).val;
        }
        score += delta_score;
        _store_score_update (delta_score);

        _create_random_tile ();

        _show_hide_trans.start ();
    }

    private void _on_show_hide_trans_stopped (bool is_finished)
    {
        debug (@"show/hide animation stopped; finished $is_finished");

        if (_show_hide_trans.direction == Clutter.TimelineDirection.FORWARD)
        {
            _show_hide_trans.direction = Clutter.TimelineDirection.BACKWARD;
            _show_hide_trans.start ();
            return;
        }

        debug (@"$_grid");

        _show_hide_trans.remove_all ();

        foreach (TileMovement? e in _to_hide)
        {
            if (e == null)
                assert_not_reached ();
            GridPosition pos = ((!) e).from;
            TileView? tile_view = _foreground_cur [pos.row, pos.col];
            if (tile_view == null)
                assert_not_reached ();
            ((!) tile_view).actor.hide ();
            debug (@"remove child " + ((!) tile_view).@value.to_string ());
            _view_foreground.remove_child (((!) tile_view).actor);

            _foreground_cur [pos.row, pos.col] = null;
        }

        _finish_move_id = GLib.Timeout.add (100, _finish_move);
    }

    private void _create_show_hide_transition (bool animate)
    {
        _show_hide_trans = new Clutter.TransitionGroup ();
        _show_hide_trans.stopped.connect (_on_show_hide_trans_stopped);
        _show_hide_trans.set_duration (animate ? _animations_duration : 10);
    }

    private bool _finish_move ()
    {
        if (_state == GameState.SHOWING_FIRST_TILE)
        {
            _state = GameState.SHOWING_SECOND_TILE;
            debug ("state show second tile");
            _create_random_tile ();
        }
        else if (_state == GameState.SHOWING_SECOND_TILE)
        {
            _state = GameState.IDLE;
            debug ("state idle");
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

        if (_grid.is_finished ())
            finished ();

        _finish_move_id = 0;
        return false;
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

    private void _store_score_update (uint delta_score)
    {
        if (!_allow_undo)
            return;

        if (_undo_score_stack.size >= _undo_stack_max_size)
            _undo_score_stack.poll_tail ();
        _undo_score_stack.offer_head (delta_score);
    }
}
