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
    Grid, GridPosition, GridSize, MoveRequest, SpawnStrategy, max_merge, restore_size, save_size,
};
use gettextrs::gettext;
use gtk::{
    gio::{self, prelude::*},
    glib,
};
use std::{error::Error, fmt};

pub fn play_cli(
    command: &str,
    size: Option<GridSize>,
    settings: &gio::Settings,
) -> Result<(), Box<dyn Error>> {
    let command = command.to_lowercase();
    let save_path = glib::user_data_dir().join("gnome-2048").join("saved");

    let spawn_strategy =
        SpawnStrategy::from_variant(&settings.value("spawn-strategy")).unwrap_or_default();

    let mut grid = match (command.as_str(), size) {
        ("help", None) => {
            // TODO: translate
            println!(
                r#"
To play GNOME 2048 in command-line:
  --cli         Display current game. Alias: "status" or "show".
  --cli new     Start a new game; for changing size, use --size.

  --cli up      Move tiles up.    Alias: "u".
  --cli down    Move tiles down.  Alias: "d".
  --cli left    Move tiles left.  Alias: "l".
  --cli right   Move tiles right. Alias: "r".

"#
            );
            return Ok(());
        }
        ("new", Some(size)) => {
            save_size(settings, size)?;
            let mut grid = Grid::new(size);
            let _ = grid.new_tile(spawn_strategy); // first tile
            grid
        }
        ("new", None) => {
            let mut grid = Grid::new(restore_size(settings)?);
            let _ = grid.new_tile(spawn_strategy); // first tile
            grid
        }
        (_, Some(_size)) => {
            return Err(gettext("Size can only be given for new games.").into());
        }
        (_, None) => {
            if let Ok(grid) = Grid::restore_game(&save_path) {
                grid
            } else {
                Grid::new(restore_size(settings)?)
            }
        }
    };

    let max_shown = match command.as_str() {
        "" | "show" | "status" => {
            print_board(&grid, None, None)?;
            return Ok(());
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
        new_tile = grid.new_tile(spawn_strategy);
        if command == "new" {
            new_tile = None;
        }
    }

    let do_congrat = settings.boolean("do-congrat");
    let target_value = settings.int("target-value") as u64;
    let congrats = max_shown.filter(|v| do_congrat && *v > target_value);
    if congrats.is_some() {
        settings.set_boolean("do-congrat", false)?;
    }

    print_board(&grid, congrats, new_tile.map(|t| t.pos))?;

    if grid.is_finished() && grid.size().is_predefined() {
        // TODO save score
    } else {
        // one more tile since previously
        grid.save_game(&save_path)?;
    }

    Ok(())
}

fn request_move(grid: &mut Grid, request: MoveRequest) -> Result<Option<u64>, Box<dyn Error>> {
    if grid.is_finished() {
        return Err(gettext("Game is finished, impossible to move.").into());
    }
    let moves = grid.move_(request);
    if moves.is_empty() {
        return Err(gettext("Impossible to move in that direction.").into());
    }
    Ok(max_merge(&moves))
}

struct GridDisplay<'g> {
    grid: &'g Grid,
    new_tile: Option<GridPosition>,
}

impl<'g> fmt::Display for GridDisplay<'g> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let size = self.grid.size();
        let cols = size.cols();
        let rows = size.rows();

        write!(f, "┏")?;
        for _ in 0..=(7 * cols) {
            write!(f, "━")?;
        }
        writeln!(f, "┓")?;

        for row in 0..rows {
            write!(f, "┃")?;
            for col in 0..cols {
                if self.grid.at(GridPosition { row, col }) == 0 {
                    write!(f, "       ")?;
                } else {
                    write!(f, " ╭────╮")?;
                }
            }
            writeln!(f, " ┃")?;

            write!(f, "┃")?;
            for col in 0..cols {
                let pos = GridPosition { row, col };
                let tile_value = self.grid.at(pos);
                if tile_value == 0 {
                    write!(f, "       ")?;
                } else if self.new_tile == Some(pos) {
                    write!(f, " │{:^+4}│", tile_value)?;
                } else {
                    write!(f, " │{:^4}│", tile_value)?;
                }
            }
            writeln!(f, " ┃")?;

            write!(f, "┃")?;
            for col in 0..cols {
                if self.grid.at(GridPosition { row, col }) == 0 {
                    write!(f, "       ")?;
                } else {
                    write!(f, " ╰────╯")?;
                }
            }
            writeln!(f, " ┃")?;
        }

        write!(f, "┗")?;
        for _ in 0..=(7 * cols) {
            write!(f, "━")?;
        }
        writeln!(f, "┛")?;

        Ok(())
    }
}

fn print_board(grid: &Grid, congrats: Option<u64>, new_tile: Option<GridPosition>) -> fmt::Result {
    println!("\n{}\n", GridDisplay { grid, new_tile });
    if let Some(score) = congrats {
        println!(
            "{}",
            gettext("You have obtained the {score} tile for the first time!")
                .replace("{score}", &score.to_string()),
        );
    }
    if grid.is_finished() {
        println!("{}", gettext("Game is finished!"));
    }
    println!(
        "{}",
        gettext("Your score is {score}.").replace("{score}", &grid.score().to_string()),
    );
    Ok(())
}
