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

use crate::grid::{
    Grid, GridPosition, GridSize, MoveRequest, Tile, max_merge, restore_size, save_size,
};
use gettextrs::gettext;
use gtk::{
    gio::{self, prelude::*},
    glib::{self},
};
use std::error::Error;

pub fn play_cli(
    cli: &str,
    settings: &gio::Settings,
    size: Option<GridSize>,
) -> Result<(), Box<dyn Error>> {
    let save_path = glib::user_data_dir().join("gnome-2048").join("saved");

    let (mut grid, new_game) = match (cli, size) {
        ("new", Some(size)) => {
            save_size(&settings, size)?;
            (Grid::new(size), true)
        }
        ("new", None) => (Grid::new(restore_size(settings)?), true),
        (_, Some(_size)) => {
            return Err(gettext("Size can only be given for new games.").into());
        }
        (_, None) => {
            if let Ok(grid) = Grid::restore_game(&save_path) {
                (grid, false)
            } else {
                (Grid::new(restore_size(settings)?), false)
            }
        }
    };

    if new_game {
        let _ = grid.new_tile(); // TODO clean that
    }

    let max_shown = match cli {
        "" | "show" | "status" => {
            if !new_game {
                print_board(&grid, None, true, None);
                return Ok(());
            }
            None
        }
        "l" | "left" => request_move(&mut grid, MoveRequest::Left)?,
        "r" | "right" => request_move(&mut grid, MoveRequest::Right)?,
        "u" | "up" => request_move(&mut grid, MoveRequest::Up)?,
        "d" | "down" => request_move(&mut grid, MoveRequest::Down)?,
        _ => {
            return Err(gettext("Cannot parse \"--cli\" command, aborting.").into());
        }
    };

    let mut new_tile = None;
    if !grid.is_finished() {
        new_tile = grid.new_tile();
        if cli == "new" {
            new_tile = None;
        }
    }

    let do_congrat = settings.boolean("do-congrat");
    let target_value = settings.int("target-value") as u64;
    let congrats = max_shown.filter(|v| do_congrat && *v > target_value);
    if congrats.is_some() {
        settings.set_boolean("do-congrat", false)?;
    }

    print_board(&grid, congrats, false, new_tile);

    // one more tile since previously
    if !grid.is_finished() || !grid.size().is_predefined() {
        grid.save_game(&save_path)?;
    }

    Ok(())
}

fn request_move(grid: &mut Grid, request: MoveRequest) -> Result<Option<u64>, Box<dyn Error>> {
    if grid.is_finished() {
        return Err(gettext("Grid is finished, impossible to move.").into());
    }
    let moves = grid.move_(request);
    if moves.is_empty() {
        return Err(gettext("Impossible to move in that direction.").into());
    }
    Ok(max_merge(&moves))
}

fn print_board(grid: &Grid, congrats: Option<u64>, print_score: bool, new_tile: Option<Tile>) {
    let size = grid.size();
    let cols = size.cols();
    let rows = size.rows();

    let mut board = String::new();

    board.push_str("\n ┏");
    for _ in 0..=(7 * cols) {
        board.push('━');
    }
    board.push_str("┓\n");

    for y in 0..rows {
        board.push_str(" ┃");
        for x in 0..cols {
            if grid.at(GridPosition { row: y, col: x }) == 0 {
                board.push_str("       ");
            } else {
                board.push_str(" ╭────╮");
            }
        }
        board.push_str(" ┃\n ┃");
        for x in 0..cols {
            let pos = GridPosition { row: y, col: x };
            let tile_value = grid.at(pos);
            if tile_value == 0 {
                board.push_str("       ");
            } else if tile_value == 1
                && let Some(tile) = new_tile
                && tile.pos == pos
            {
                board.push_str(" │ +1 │");
            } else {
                board.push_str(&format!(" │ {:2} │", tile_value));
            }
        }
        board.push_str(" ┃\n ┃");
        for x in 0..cols {
            if grid.at(GridPosition { row: y, col: x }) == 0 {
                board.push_str("       ");
            } else {
                board.push_str(" ╰────╯");
            }
        }
        board.push_str(" ┃\n");
    }

    board.push_str(" ┗");
    for _ in 0..=(7 * cols) {
        board.push('━');
    }
    board.push_str("┛\n\n");

    if let Some(target_value) = congrats {
        // try to keep string as in game-window.rs
        board.push(' ');
        board.push_str(
            &gettext("You have obtained the %u tile for the first time!")
                .replace("%u", &target_value.to_string()),
        );
        board.push('\n');
        board.push('\n');
    }

    if grid.is_finished() {
        board.push(' ');
        if print_score || !size.is_predefined() {
            board.push_str(
                &gettext("Game is finished! Your score is {score}.")
                    .replace("{score}", &grid.score().to_string()),
            );
        } else {
            // game was just finished and score can be saved
            board.push_str(
                &gettext(
                    "Game is finished! Your score is {score}. (If you want to save it, use GNOME \
                     2048 graphical interface.)",
                )
                .replace("{score}", &grid.score().to_string()),
            );
            // TODO save score
        }
    } else if print_score {
        board.push(' ');
        board.push_str(
            &gettext("Your score is {score}.").replace("{score}", &grid.score().to_string()),
        );
    }

    println!("{}\n", board);
}
