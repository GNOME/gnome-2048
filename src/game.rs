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

use crate::grid::{Grid, GridSize};
use adw::{self, prelude::*};
use gtk::{gdk, gio, glib, graphene, gsk, pango, subclass::prelude::*};
use std::fmt;

#[derive(Clone, Copy, PartialEq, Eq)]
pub enum GameState {
    Stopped,
    Idle,
    Moving,
    ShowingNewTile,
    RestoringTiles,
}

impl fmt::Display for GameState {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "{}",
            match *self {
                Self::Stopped => "stopped",
                Self::Idle => "idle",
                Self::Moving => "moving",
                Self::ShowingNewTile => "showing new tile",
                Self::RestoringTiles => "restoring tiles",
            }
        )
    }
}

const BLANK_COL_WIDTH: f32 = 10.0;
const BLANK_ROW_HEIGHT: f32 = 10.0;

mod imp {
    use super::*;
    use crate::{
        colors::{ADWAITA_THEME, CLASSIC_THEME, ColorTheme, TANGO_THEME, Theme, TileColors},
        grid::{
            Grid, GridPosition, GridSize, MoveRequest, SpawnStrategy, Tile, TileMovement, max_merge,
        },
        shift::Movement,
    };
    use std::{
        cell::{Cell, RefCell},
        collections::VecDeque,
        num::NonZeroU8,
        rc::Rc,
        sync::OnceLock,
        time::Duration,
    };

    #[derive(glib::Properties)]
    #[properties(wrapper_type = super::Game)]
    pub struct Game {
        #[property(get, set=Self::set_theme, builder(Theme::default()))]
        pub theme: Cell<Theme>,
        pub color_theme: Cell<&'static dyn ColorTheme>,

        pub grid: RefCell<Grid>,

        pub movements: RefCell<Vec<Movement<GridPosition>>>,

        pub state: Cell<GameState>,

        pub show_transition_value: Rc<Cell<Option<f64>>>,
        pub show_transition_tiles: RefCell<Vec<GridPosition>>,

        pub move_transition_value: Rc<Cell<Option<f64>>>,
        pub move_transition_tiles: RefCell<Vec<TileMovement>>,

        pub just_restored: Cell<bool>,

        #[property(get, set)]
        score: Cell<u64>,

        pub undo_stack: RefCell<VecDeque<Grid>>,

        #[property(get, set)]
        target_value: Cell<i32>,
        #[property(get, set, builder(SpawnStrategy::default()))]
        spawn_strategy: Cell<SpawnStrategy>,

        #[property(get, set)]
        animations_speed: Cell<f64>,
        #[property(get, set=Self::set_allow_undo)]
        allow_undo: Cell<bool>,
        #[property(get, set)]
        allow_undo_max: Cell<u32>,
    }

    #[glib::object_subclass]
    impl ObjectSubclass for Game {
        const NAME: &'static str = "Game";
        type Type = super::Game;
        type ParentType = gtk::Widget;

        fn new() -> Self {
            Self {
                theme: Cell::new(Theme::Tango),
                color_theme: Cell::new(&TANGO_THEME),
                grid: RefCell::new(Grid::new(GridSize::GRID_4_BY_4)),
                movements: Default::default(),
                state: Cell::new(GameState::Stopped),
                show_transition_value: Default::default(),
                show_transition_tiles: Default::default(),
                move_transition_value: Default::default(),
                move_transition_tiles: Default::default(),
                just_restored: Cell::new(true),
                score: Default::default(),
                undo_stack: Default::default(),
                target_value: Cell::new(2048),
                spawn_strategy: Default::default(),
                animations_speed: Cell::new(130.0),
                allow_undo: Default::default(),
                allow_undo_max: Cell::new(10),
            }
        }
    }

    #[glib::derived_properties]
    impl ObjectImpl for Game {
        fn constructed(&self) {
            self.parent_constructed();
            let game = self.obj();

            game.set_width_request(350);
            game.set_height_request(350);
            game.set_focusable(true);

            let key_controller = gtk::EventControllerKey::new();
            key_controller.connect_key_pressed(glib::clone!(
                #[weak(rename_to=imp)]
                self,
                #[upgrade_or]
                glib::Propagation::Proceed,
                move |_, key, _, _| imp.on_key_pressed(key)
            ));
            game.add_controller(key_controller);

            let gesture_swipe = gtk::GestureSwipe::builder()
                .propagation_phase(gtk::PropagationPhase::Capture)
                .button(0)
                .build();
            gesture_swipe.connect_swipe(glib::clone!(
                #[weak(rename_to=imp)]
                self,
                move |g, vx, vy| imp.on_swipe(g.current_button(), vx, vy)
            ));
            game.add_controller(gesture_swipe);
        }

        fn signals() -> &'static [glib::subclass::Signal] {
            static SIGNALS: OnceLock<Vec<glib::subclass::Signal>> = OnceLock::new();
            SIGNALS.get_or_init(|| {
                vec![
                    glib::subclass::Signal::builder("finished")
                        .param_types([bool::static_type()])
                        .build(),
                    glib::subclass::Signal::builder("target-value-reached")
                        .param_types([u64::static_type()])
                        .build(),
                    glib::subclass::Signal::builder("undo-enabled").build(),
                    glib::subclass::Signal::builder("undo-disabled").build(),
                ]
            })
        }
    }

    impl WidgetImpl for Game {
        fn snapshot(&self, snapshot: &gtk::Snapshot) {
            let width = self.obj().width() as f32;
            let height = self.obj().height() as f32;

            let rect = graphene::Rect::new(0.0, 0.0, width, height);

            snapshot.append_color(&self.color_theme.get().background_color(), &rect);

            let grid = self.grid.borrow();

            let rows = grid.size().rows();
            let cols = grid.size().cols();

            let tile_width = (width - (cols as f32 + 1.0) * BLANK_COL_WIDTH) / (cols as f32);
            let tile_height = (height - (rows as f32 + 1.0) * BLANK_ROW_HEIGHT) / (rows as f32);

            let layout = pango::Layout::new(&self.obj().pango_context());
            let font_desc = pango::FontDescription::from_string(&format!(
                "Sans Bold {}px",
                (tile_height as i32) / 4
            ));
            layout.set_font_description(Some(&font_desc));

            for row in 0..rows {
                for col in 0..cols {
                    let x = BLANK_COL_WIDTH
                        + (col as f32) * (tile_width + BLANK_COL_WIDTH)
                        + tile_width / 2.0;
                    let y = BLANK_ROW_HEIGHT
                        + (row as f32) * (tile_height + BLANK_ROW_HEIGHT)
                        + tile_height / 2.0;

                    snapshot.save();
                    snapshot.translate(&graphene::Point::new(x, y));
                    self.draw_tile(snapshot, tile_width, tile_height, 0, 1.0, &layout);
                    snapshot.restore();
                }
            }

            for (pos, tile) in self.grid.borrow().iter() {
                if tile == 0 {
                    continue;
                }

                let x = BLANK_COL_WIDTH
                    + (pos.col as f32) * (tile_width + BLANK_COL_WIDTH)
                    + tile_width / 2.0;
                let y = BLANK_ROW_HEIGHT
                    + (pos.row as f32) * (tile_height + BLANK_ROW_HEIGHT)
                    + tile_height / 2.0;

                snapshot.save();
                snapshot.translate(&graphene::Point::new(x, y));

                if let Some(animation_phase) = self.is_tile_animating_show(pos) {
                    let mut factor = 1.0 - 2.0 * (animation_phase as f32 - 0.5).abs();
                    factor = 1.0 + 0.1 * factor;

                    let opacity = animation_phase;

                    self.draw_tile(
                        snapshot,
                        factor * tile_width,
                        factor * tile_height,
                        tile,
                        opacity as f32,
                        &layout,
                    );
                } else if let Some((animation_phase, tiles)) = self.is_tile_animating_move(pos) {
                    for t in tiles {
                        let from_col = t.pos.col;
                        let from_row = t.pos.row;

                        let from_x = BLANK_COL_WIDTH
                            + (from_col as f32) * (tile_width + BLANK_COL_WIDTH)
                            + tile_width / 2.0;
                        let from_y = BLANK_ROW_HEIGHT
                            + (from_row as f32) * (tile_height + BLANK_ROW_HEIGHT)
                            + tile_height / 2.0;

                        let offset_x = (1.0 - animation_phase as f32) * (from_x - x);
                        let offset_y = (1.0 - animation_phase as f32) * (from_y - y);

                        snapshot.save();
                        snapshot.translate(&graphene::Point::new(offset_x, offset_y));
                        self.draw_tile(snapshot, tile_width, tile_height, tile, 1.0, &layout);
                        snapshot.restore();
                    }
                } else {
                    self.draw_tile(snapshot, tile_width, tile_height, tile, 1.0, &layout);
                }

                snapshot.restore();
            }
        }
    }

    impl Game {
        fn set_theme(&self, theme: Theme) {
            self.theme.replace(theme);
            match theme {
                Theme::Adwaita => self.color_theme.set(&ADWAITA_THEME),
                Theme::Tango => self.color_theme.set(&TANGO_THEME),
                Theme::Classic => self.color_theme.set(&CLASSIC_THEME),
            }
            self.obj().queue_draw();
        }

        fn set_allow_undo(&self, allow_undo: bool) {
            if self.allow_undo.get() && !allow_undo {
                self.clear_history();
                self.emit_undo_disabled();
            }
            self.allow_undo.set(allow_undo);
        }

        fn is_tile_animating_show(&self, pos: GridPosition) -> Option<f64> {
            if let Some(value) = self.show_transition_value.get()
                && self.show_transition_tiles.borrow().contains(&pos)
            {
                Some(value)
            } else {
                None
            }
        }

        fn is_tile_animating_move(&self, pos: GridPosition) -> Option<(f64, Vec<Tile>)> {
            let value = self.move_transition_value.get()?;
            let tiles: Vec<Tile> = self
                .move_transition_tiles
                .borrow()
                .iter()
                .filter(|p| p.to == pos)
                .map(|p| p.tile)
                .collect();
            if tiles.is_empty() {
                None
            } else {
                Some((value, tiles))
            }
        }

        fn draw_tile(
            &self,
            snapshot: &gtk::Snapshot,
            tile_width: f32,
            tile_height: f32,
            tile: u8,
            opacity: f32,
            layout: &pango::Layout,
        ) {
            let tile_rect = graphene::Rect::new(0.0, 0.0, tile_width, tile_height);

            let radius = f32::max(tile_height, tile_width) / 20.0;
            let rounded_corner = graphene::Size::new(radius, radius);

            snapshot.save();
            snapshot.translate(&graphene::Point::new(-tile_width / 2.0, -tile_height / 2.0));

            snapshot.push_rounded_clip(&gsk::RoundedRect::new(
                tile_rect,
                rounded_corner,
                rounded_corner,
                rounded_corner,
                rounded_corner,
            ));

            if let Some(nz_tile) = NonZeroU8::new(tile) {
                let TileColors { mut fg, mut bg } = self.color_theme.get().tile_color(nz_tile);
                fg.set_alpha(opacity);
                bg.set_alpha(opacity);
                snapshot.append_color(&bg, &tile_rect);

                layout.set_text(&2_u32.pow(tile as u32).to_string());

                let (_, logical_rect) = layout.extents();

                snapshot.save();
                snapshot.translate(&graphene::Point::new(
                    (tile_width / 2.0)
                        - ((logical_rect.width() as f32) / 2.0 / (pango::SCALE as f32)),
                    (tile_height / 2.0)
                        - ((logical_rect.height() as f32) / 2.0 / (pango::SCALE as f32)),
                ));
                snapshot.append_layout(layout, &fg);
                snapshot.restore();
            } else {
                snapshot.append_color(&self.color_theme.get().empty_tile_color(), &tile_rect);
            }

            snapshot.pop();

            snapshot.restore();
        }

        fn on_key_pressed(&self, key: gdk::Key) -> glib::Propagation {
            if !self.can_move() {
                return glib::Propagation::Proceed;
            }
            let request = match key {
                gdk::Key::Up
                | gdk::Key::KP_Up
                | gdk::Key::W
                | gdk::Key::w
                | gdk::Key::H
                | gdk::Key::h => MoveRequest::Up,
                gdk::Key::Left
                | gdk::Key::KP_Left
                | gdk::Key::A
                | gdk::Key::a
                | gdk::Key::J
                | gdk::Key::j => MoveRequest::Left,
                gdk::Key::Down
                | gdk::Key::KP_Down
                | gdk::Key::S
                | gdk::Key::s
                | gdk::Key::K
                | gdk::Key::k => MoveRequest::Down,
                gdk::Key::Right
                | gdk::Key::KP_Right
                | gdk::Key::D
                | gdk::Key::d
                | gdk::Key::L
                | gdk::Key::l => MoveRequest::Right,
                _ => return glib::Propagation::Proceed,
            };

            self.move_(request);
            glib::Propagation::Stop
        }

        fn on_swipe(&self, button: u32, velocity_x: f64, velocity_y: f64) {
            if button != gdk::BUTTON_PRIMARY && button != gdk::BUTTON_SECONDARY {
                return;
            }
            if !self.can_move() {
                return;
            }

            let abs_x = velocity_x.abs();
            let abs_y = velocity_y.abs();
            if abs_x * abs_x + abs_y * abs_y < 400.0 {
                return;
            }
            let left_or_right = abs_y * 4.0 < abs_x;
            let up_or_down = abs_x * 4.0 < abs_y;
            let request = if left_or_right {
                if velocity_x < -10.0 {
                    MoveRequest::Left
                } else if velocity_x > 10.0 {
                    MoveRequest::Right
                } else {
                    return;
                }
            } else if up_or_down {
                if velocity_y < -10.0 {
                    MoveRequest::Up
                } else if velocity_y > 10.0 {
                    MoveRequest::Down
                } else {
                    return;
                }
            } else {
                return;
            };

            self.move_(request);
        }

        fn can_move(&self) -> bool {
            match self.state.get() {
                GameState::Stopped
                | GameState::Moving
                | GameState::ShowingNewTile
                | GameState::RestoringTiles => false,
                GameState::Idle => true,
            }
        }

        pub fn create_random_tiles(&self, count: usize) {
            let this = self.obj().clone();
            glib::spawn_future_local(async move {
                this.imp().create_random_tiles_async(count).await;
            });
        }

        pub async fn create_random_tiles_async(&self, count: usize) {
            self.state.set(GameState::ShowingNewTile);

            for _ in 0..count {
                if let Some(tile) = self.grid.borrow_mut().new_tile(self.spawn_strategy.get()) {
                    self.movements.borrow_mut().push(Movement::Appear {
                        to: tile.pos,
                        new_value: tile.val,
                    });
                    self.show_tile(tile.pos);
                }
            }

            self.play_animation(true, &self.show_transition_value).await;
            self.show_transition_tiles.borrow_mut().clear();
            self.apply_move();
        }

        fn show_tile(&self, pos: GridPosition) {
            self.show_transition_tiles.borrow_mut().push(pos);
        }

        fn prepare_move_tile(&self, tile: Tile, to: GridPosition) {
            self.move_transition_tiles
                .borrow_mut()
                .push(TileMovement { tile, to });
        }

        pub fn restore_foreground(&self, animate: bool) {
            let this = self.obj().clone();
            glib::spawn_future_local(async move {
                this.imp().restore_foreground_async(animate).await;
            });
        }

        pub async fn restore_foreground_async(&self, animate: bool) {
            for (pos, val) in self.grid.borrow().iter() {
                if val != 0 {
                    let tile = Tile { pos, val };
                    self.movements.borrow_mut().push(Movement::Appear {
                        to: tile.pos,
                        new_value: tile.val,
                    });
                    self.show_tile(pos);
                }
            }

            if !self.movements.borrow().is_empty() {
                self.state.set(GameState::RestoringTiles);
                self.play_animation(animate, &self.show_transition_value)
                    .await;
                self.show_transition_tiles.borrow_mut().clear();
                self.apply_move();
            }
        }

        fn move_(&self, request: MoveRequest) {
            let this = self.obj().clone();
            glib::spawn_future_local(async move {
                this.imp().move_async(request).await;
            });
        }

        async fn move_async(&self, request: MoveRequest) {
            self.just_restored.set(false);

            let previous_grid = self.grid.borrow().clone();
            let movements = self.grid.borrow_mut().move_(request);
            self.movements.replace(movements);
            if self.movements.borrow().is_empty() {
                return;
            }
            self.store_movement(previous_grid);

            if let Some(max_value) = max_merge(&self.movements.borrow())
                && max_value >= self.obj().target_value() as u64
            {
                self.emit_target_value_reached(max_value);
            }

            for m in self.movements.borrow().iter() {
                match m {
                    Movement::Appear { .. } => {}
                    Movement::Move { from, to, value } => {
                        self.prepare_move_tile(
                            Tile {
                                pos: *from,
                                val: *value,
                            },
                            *to,
                        );
                    }
                    Movement::Merge {
                        from1,
                        from2,
                        to,
                        new_value,
                    } => {
                        self.prepare_move_tile(
                            Tile {
                                pos: *from1,
                                val: new_value - 1,
                            },
                            *to,
                        );
                        self.prepare_move_tile(
                            Tile {
                                pos: *from2,
                                val: new_value - 1,
                            },
                            *to,
                        );
                    }
                }
            }

            self.obj().set_score(self.grid.borrow().score());

            self.state.set(GameState::Moving);
            self.play_animation(true, &self.move_transition_value).await;
            self.move_transition_tiles.borrow_mut().clear();

            self.create_random_tiles_async(1).await;
        }

        fn apply_move(&self) {
            self.state.set(GameState::Idle);
            self.movements.borrow_mut().clear();

            if self.grid.borrow().is_finished() {
                self.emit_finished(!self.just_restored.get());
            }
        }

        pub fn clear_history(&self) {
            self.undo_stack.borrow_mut().clear();
        }

        fn store_movement(&self, clone: Grid) {
            if !self.allow_undo.get() {
                return;
            }

            let enable_undo = self.undo_stack.borrow().is_empty();
            self.undo_stack.borrow_mut().push_front(clone);
            self.undo_stack
                .borrow_mut()
                .truncate(self.allow_undo_max.get() as usize);
            if enable_undo {
                self.emit_undo_enabled();
            }
        }

        pub fn emit_target_value_reached(&self, value: u64) {
            self.obj()
                .emit_by_name::<()>("target-value-reached", &[&value]);
        }

        pub fn emit_finished(&self, show_scores: bool) {
            let obj = self.obj().clone();
            glib::timeout_add_local_once(Duration::from_millis(100), move || {
                obj.emit_by_name::<()>("finished", &[&show_scores]);
            });
        }

        pub fn emit_undo_enabled(&self) {
            self.obj().emit_by_name::<()>("undo-enabled", &[]);
        }

        pub fn emit_undo_disabled(&self) {
            self.obj().emit_by_name::<()>("undo-disabled", &[]);
        }

        async fn play_animation(&self, animate: bool, animation_value: &Rc<Cell<Option<f64>>>) {
            let (sender, receiver) = async_channel::bounded(1);

            let show_hide_trans = adw::TimedAnimation::new(
                &*self.obj(),
                0.0,
                1.0,
                animate
                    .then(|| self.animations_speed.get() as u32)
                    .unwrap_or(10),
                adw::CallbackAnimationTarget::new(glib::clone!(
                    #[weak(rename_to=imp)]
                    self,
                    #[strong]
                    animation_value,
                    move |value| {
                        animation_value.set(Some(value));
                        imp.obj().queue_draw();
                    }
                )),
            );
            show_hide_trans.connect_done(glib::clone!(move |_| {
                if let Err(error) = sender.send_blocking(()) {
                    eprintln!("Animation channel error {error}.");
                }
            }));
            show_hide_trans.play();
            if let Err(error) = receiver.recv().await {
                eprintln!("Animation channel error {error}.");
            }
            animation_value.set(None);
        }
    }
}

glib::wrapper! {
    pub struct Game(ObjectSubclass<imp::Game>)
        @extends gtk::Widget,
        @implements gtk::Accessible, gtk::Buildable, gtk::ConstraintTarget;
}

impl Default for Game {
    fn default() -> Self {
        glib::Object::builder().build()
    }
}

impl Game {
    pub fn new_game(&self, size: Option<GridSize>) {
        let state = self.imp().state.get();
        if state != GameState::Idle && state != GameState::Stopped {
            return;
        }

        self.imp().grid.borrow_mut().clear();
        self.imp().clear_history();

        if let Some(size) = size
            && size != self.imp().grid.borrow().size()
        {
            self.imp().grid.replace(Grid::new(size));
        }

        self.set_score(0);
        self.imp().create_random_tiles(2);
        self.imp().emit_undo_disabled();

        self.imp().just_restored.set(false);
    }

    pub fn grid_size(&self) -> GridSize {
        self.imp().grid.borrow().size()
    }

    pub fn grid(&self) -> Grid {
        self.imp().grid.borrow().clone()
    }

    pub fn set_grid(&self, grid: Grid) {
        self.set_score(grid.score());
        self.imp().grid.replace(grid);

        self.imp().restore_foreground(true);

        self.imp().just_restored.set(true);
    }

    pub fn undo(&self) {
        if !self.allow_undo() {
            return;
        }

        if self.imp().state.get() != GameState::Idle {
            return;
        }

        let prev_grid = self.imp().undo_stack.borrow_mut().pop_front();
        if let Some(grid) = prev_grid {
            self.set_score(grid.score());
            self.imp().grid.replace(grid);
            self.imp().restore_foreground(false);

            if self.imp().undo_stack.borrow().is_empty() {
                self.imp().emit_undo_disabled();
            }
        }
    }

    pub fn bind_settings(&self, settings: &gio::Settings) {
        settings.bind("target-value", self, "target-value").build();
        settings
            .bind("animations-speed", self, "animations-speed")
            .build();
        settings.bind("allow-undo", self, "allow-undo").build();
        settings
            .bind("allow-undo-max", self, "allow-undo-max")
            .build();
    }
}
