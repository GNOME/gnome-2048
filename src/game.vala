/* gnome-2048 Copyright (C) 2014 Juan R. García Blanco
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2
 * as published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
 */

public class Game : GLib.Object
{
  enum GameState {
    STOPPED,
    IDLE,
    MOVING_DOWN,
    MOVING_UP,
    MOVING_RIGHT,
    MOVING_LEFT,
    SHOWING_FIRST_TILE,
    SHOWING_SECOND_TILE
  }

  private int BLANK_ROW_HEIGHT = 10;
  private int BLANK_COL_WIDTH = 10;

  private int _n_rows;
  private int _n_cols;

  private Grid _grid;

  private Clutter.Actor _view;
  private RoundedRectangle[,] _background;
  private TileView[,] _foreground_cur;
  private TileView[,] _foreground_nxt;

  private Gee.LinkedList<TileMovement?> _to_move;
  private Gee.LinkedList<TileMovement?> _to_hide;
  private Gee.LinkedList<Tile?> _to_show;

  private GameState _state;
  private Clutter.TransitionGroup _show_hide_trans;
  private Clutter.TransitionGroup _move_trans;

  private GLib.Settings _settings;

  public signal void finished ();

  public Game (GLib.Settings settings)
  {
    Object ();

    _settings = settings;

    _n_rows = _settings.get_int ("rows");
    _n_cols = _settings.get_int ("cols");

    _grid = new Grid (_n_rows, _n_cols);

    _to_move = new Gee.LinkedList<TileMovement?> ();
    _to_hide = new Gee.LinkedList<TileMovement?> ();
    _to_show = new Gee.LinkedList<Tile?> ();

    _state = GameState.STOPPED;
  }

  public Clutter.Actor view {
    get { return _view; }
    set {
      _view = value;
      _view.allocation_changed.connect (_on_allocation_changed);
    }
  }

  public uint score {
    get; set;
  }

  public void new_game ()
  {
    _grid.clear ();
    _clear_foreground ();
    score = 0;
    _state = GameState.SHOWING_FIRST_TILE;
    _create_random_tile ();
  }

  public bool key_pressed (Gdk.EventKey event)
  {
    if (_state != GameState.IDLE) {
      return true;
    }

    uint keyval = _upper_key (event.keyval);

    if (keyval == Gdk.Key.Down) {
      _move_down ();
    } else if (keyval == Gdk.Key.Up) {
      _move_up ();
    } else if (keyval == Gdk.Key.Left) {
      _move_left ();
    } else if (keyval == Gdk.Key.Right) {
      _move_right ();
    }

    return false;
  }

  public void reload_settings ()
  {
    int n_rows = _settings.get_int ("rows");
    int n_cols = _settings.get_int ("cols");

    if ((n_rows != _n_rows) || (n_cols != _n_cols)) {
      _clear_foreground ();
      _clear_background ();

      _n_rows = n_rows;
      _n_cols = n_cols;
      _init_background ();

      _grid = new Grid (_n_rows, _n_cols);
    }
  }

  private uint _upper_key (uint keyval)
  {
    return (keyval > 255) ? keyval : ((char) keyval).toupper ();
  }

  private void _on_allocation_changed (Clutter.ActorBox box, Clutter.AllocationFlags flags)
  {
    if (_background == null) {
      _init_background ();
    } else {
      _resize_view ();
    }
  }

  private void _init_background ()
  {
    Clutter.Color background_color = Clutter.Color.from_string ("#babdb6");
    _view.set_background_color (background_color);

    _background = new RoundedRectangle[_n_rows, _n_cols];
    _foreground_cur = new TileView[_n_rows, _n_cols];
    _foreground_nxt = new TileView[_n_rows, _n_cols];

    float canvas_width = _view.width;
    float canvas_height = _view.height;

    canvas_width -= (_n_cols + 1) * BLANK_COL_WIDTH;
    canvas_height -= (_n_rows + 1) * BLANK_ROW_HEIGHT;

    float tile_width = canvas_width / _n_cols;
    float tile_height = canvas_height / _n_rows;

    Clutter.Color color = Clutter.Color.from_string ("#ffffff");

    for (int row = 0; row < _n_rows; row++) {
      for (int col = 0; col < _n_cols; col++) {
        float x = col * tile_width + (col+1) * BLANK_COL_WIDTH;
        float y = row * tile_height + (row+1) * BLANK_ROW_HEIGHT;

        RoundedRectangle rect = new RoundedRectangle (x, y, tile_width, tile_height, color);

        _view.add_child (rect.actor);
        rect.canvas.invalidate ();
        rect.actor.show ();

        _background[row,col] = rect;
      }
    }
  }

  private void _resize_view ()
  {
    float canvas_width = _view.width;
    float canvas_height = _view.height;

    canvas_width -= (_n_cols + 1) * BLANK_COL_WIDTH;
    canvas_height -= (_n_rows + 1) * BLANK_ROW_HEIGHT;

    float tile_width = canvas_width / _n_rows;
    float tile_height = canvas_height / _n_cols;

    for (int i = 0; i < _n_rows; i++) {
      for (int j = 0; j < _n_cols; j++) {
        float x = j * tile_width + (j+1) * BLANK_COL_WIDTH;
        float y = i * tile_height + (i+1) * BLANK_ROW_HEIGHT;

        _background[i,j].resize (x, y, tile_width, tile_height);

        if (_foreground_cur[i,j] != null) {
          _foreground_cur[i,j].resize (x, y, tile_width, tile_height);
        }
      }
    }
  }

  private void _create_random_tile ()
  {
    Tile tile;

    if (_grid.new_tile (out tile)) {
      _create_show_hide_transition ();

      _create_tile (tile);
      _to_show.add (tile);
      _show_tile (tile.pos);
    }
  }

  private void _create_tile (Tile tile)
  {
    GridPosition pos;
    RoundedRectangle rect;
    TileView view;
    float x;
    float y;
    float width;
    float height;

    pos = tile.pos;
    rect = _background[pos.row,pos.col];
    x = rect.actor.x;
    y = rect.actor.y;
    width = rect.actor.width;
    height = rect.actor.height;

    assert (_foreground_nxt[pos.row,pos.col] == null);
    view = new TileView (x, y, width, height, tile.val);
    _foreground_nxt[pos.row,pos.col] = view;
  }

  private void _move_down ()
  {
    debug ("move down");

    bool has_moved;

    _move_trans = new Clutter.TransitionGroup ();
    _move_trans.stopped.connect (_on_move_trans_stopped);
    _move_trans.set_duration (100);

    _grid.move_down (_to_move, _to_hide, _to_show);

    foreach (var e in _to_move)
      _move_tile (e.from, e.to);

    foreach (var e in _to_hide)
      _prepare_move_tile (e.from, e.to);

    has_moved = (_to_move.size > 0) || (_to_hide.size > 0) || (_to_show.size > 0);

    if (has_moved) {
      _state = GameState.MOVING_DOWN;
      _move_trans.start ();
    }
  }

  private void _move_up ()
  {
    debug ("move up");

    bool has_moved;

    _move_trans = new Clutter.TransitionGroup ();
    _move_trans.stopped.connect (_on_move_trans_stopped);
    _move_trans.set_duration (100);

    _grid.move_up (_to_move, _to_hide, _to_show);

    foreach (var e in _to_move)
      _move_tile (e.from, e.to);

    foreach (var e in _to_hide)
      _prepare_move_tile (e.from, e.to);

    has_moved = (_to_move.size > 0) || (_to_hide.size > 0) || (_to_show.size > 0);

    if (has_moved) {
      _state = GameState.MOVING_UP;
      _move_trans.start ();
    }
  }

  private void _move_left ()
  {
    debug ("move left");

    bool has_moved;

    _move_trans = new Clutter.TransitionGroup ();
    _move_trans.stopped.connect (_on_move_trans_stopped);
    _move_trans.set_duration (100);

    _grid.move_left (_to_move, _to_hide, _to_show);

    foreach (var e in _to_move)
      _move_tile (e.from, e.to);

    foreach (var e in _to_hide)
      _prepare_move_tile (e.from, e.to);

    has_moved = (_to_move.size > 0) || (_to_hide.size > 0) || (_to_show.size > 0);

    if (has_moved) {
      _state = GameState.MOVING_LEFT;
      _move_trans.start ();
    }
  }

  private void _move_right ()
  {
    debug ("move right");

    bool has_moved;

    _move_trans = new Clutter.TransitionGroup ();
    _move_trans.stopped.connect (_on_move_trans_stopped);
    _move_trans.set_duration (100);

    _grid.move_right (_to_move, _to_hide, _to_show);

    foreach (var e in _to_move)
      _move_tile (e.from, e.to);

    foreach (var e in _to_hide)
      _prepare_move_tile (e.from, e.to);

    has_moved = (_to_move.size > 0) || (_to_hide.size > 0) || (_to_show.size > 0);

    if (has_moved) {
      _state = GameState.MOVING_LEFT;
      _move_trans.start ();
    }
  }

  private void _show_tile (GridPosition pos)
  {
    debug (@"show tile pos $pos");

    Clutter.PropertyTransition trans;
    TileView view;

    view = _foreground_nxt[pos.row,pos.col];
    view.canvas.invalidate ();
    view.actor.set_opacity (0);
    view.actor.show ();
    _view.add_child (view.actor);

    trans = new Clutter.PropertyTransition ("scale-x");
    trans.set_from_value (1.0);
    trans.set_to_value (1.1);
    trans.set_duration (100);
    trans.set_animatable (view.actor);
    _show_hide_trans.add_transition (trans);

    trans = new Clutter.PropertyTransition ("scale-y");
    trans.set_from_value (1.0);
    trans.set_to_value (1.1);
    trans.set_duration (100);
    trans.set_animatable (view.actor);
    _show_hide_trans.add_transition (trans);

    trans = new Clutter.PropertyTransition ("opacity");
    trans.set_from_value (0);
    trans.set_to_value (255);
    trans.set_remove_on_complete (true);
    trans.set_duration (50);
    view.actor.add_transition ("show", trans);

    _show_hide_trans.start ();
  }

  private void _move_tile (GridPosition from, GridPosition to)
  {
    debug (@"move tile from $from to $to");

    _prepare_move_tile (from, to);

    _foreground_nxt[to.row,to.col] = _foreground_cur[from.row,from.col];
    _foreground_cur[from.row,from.col] = null;
  }

  private void _prepare_move_tile (GridPosition from, GridPosition to)
  {
    debug (@"prepare move tile from $from to $to");

    bool row_move;
    string trans_name;
    Clutter.PropertyTransition trans;
    RoundedRectangle rect_from;
    RoundedRectangle rect_to;

    row_move = (from.col == to.col);
    trans_name = row_move ? "y" : "x";

    rect_from = _background[from.row,from.col];
    rect_to = _background[to.row,to.col];

    trans = new Clutter.PropertyTransition (trans_name);
    trans.set_from_value (row_move ? rect_from.actor.y : rect_from.actor.x);
    trans.set_to_value (row_move ? rect_to.actor.y : rect_to.actor.x);
    trans.set_duration (100);
    trans.set_animatable (_foreground_cur[from.row,from.col].actor);
    _move_trans.add_transition (trans);
  }

  private void _dim_tile (GridPosition pos)
  {
    debug (@"diming tile at $pos " + _foreground_cur[pos.row,pos.col].value.to_string ());

    Clutter.Actor actor;
    Clutter.PropertyTransition trans;

    actor = _foreground_cur[pos.row,pos.col].actor;

    trans = new Clutter.PropertyTransition ("opacity");
    trans.set_from_value (actor.opacity);
    trans.set_to_value (0);
    trans.set_duration (100);
    trans.set_animatable (actor);

    _show_hide_trans.add_transition (trans);
  }

  private void _clear_background ()
  {
    for (int i = 0; i < _n_rows; i++) {
      for (int j = 0; j < _n_cols; j++) {
        RoundedRectangle rect = _background[i,j];
        rect.actor.hide ();
        _view.remove_child (rect.actor);
      }
    }
  }

  private void _clear_foreground ()
  {
    for (int i = 0; i < _n_rows; i++) {
      for (int j = 0; j < _n_cols; j++) {
        if (_foreground_cur[i,j] != null) {
          TileView tile = _foreground_cur[i,j];
          tile.actor.hide ();
          _view.remove_child (tile.actor);
          _foreground_cur[i,j] = null;
        }
      }
    }
  }

  private void _on_move_trans_stopped (bool is_finished)
  {
    debug ("move animation stopped");
    debug (@"$_grid");

    uint delta_score;

    _move_trans.remove_all ();

    _create_show_hide_transition ();

    foreach (var e in _to_hide) {
      _dim_tile (e.from);
    }

    delta_score = 0;
    foreach (var e in _to_show) {
      _create_tile (e);
      _show_tile (e.pos);
      delta_score += e.val;
    }
    score += delta_score;

    _create_random_tile ();

    _show_hide_trans.start ();
  }

  private void _on_show_hide_trans_stopped (bool is_finished)
  {
    debug ("show/hide animation stopped");
    debug (@"$_grid");

    _show_hide_trans.remove_all ();

    foreach (var e in _to_hide) {
      TileView view = _foreground_cur[e.from.row,e.from.col];
      view.actor.hide ();
      debug (@"remove child " + _foreground_cur[e.from.row,e.from.col].value.to_string ());
      _view.remove_child (view.actor);

      _foreground_cur[e.from.row,e.from.col] = null;
    }

    _finish_move ();

    if (_state == GameState.SHOWING_FIRST_TILE) {
      _state = GameState.SHOWING_SECOND_TILE;
      debug ("state show second tile");
      _create_random_tile ();
    } else if (_state == GameState.SHOWING_SECOND_TILE) {
      _state = GameState.IDLE;
      debug ("state idle");
    } else if (_state != GameState.IDLE) {
      _state = GameState.IDLE;
      debug ("state idle");
    }
  }

  private void _create_show_hide_transition ()
  {
    _show_hide_trans = new Clutter.TransitionGroup ();
    _show_hide_trans.stopped.connect (_on_show_hide_trans_stopped);
    _show_hide_trans.set_duration (100);
    _show_hide_trans.set_auto_reverse (true);
    _show_hide_trans.set_repeat_count (1);
  }

  private void _finish_move ()
  {
    foreach (var e in _to_move) {
      _foreground_cur[e.to.row,e.to.col] = _foreground_nxt[e.to.row,e.to.col];
      _foreground_nxt[e.to.row,e.to.col] = null;
    }
    foreach (var e in _to_show) {
      _foreground_cur[e.pos.row,e.pos.col] = _foreground_nxt[e.pos.row,e.pos.col];
      _foreground_nxt[e.pos.row,e.pos.col] = null;
    }

    _to_hide.clear ();
    _to_move.clear ();
    _to_show.clear ();
  }
}
