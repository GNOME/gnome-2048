/*
 * Copyright 2014-2015 Juan R. García Blanco <juanrgar@gmail.com>
 * Copyright 2016-2019 Arnaud Bonatti <arnaud.bonatti@gmail.com>
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

use crate::shift::{Movement, shift_tiles, shift_tiles_rev};
use gettextrs::gettext;
use gtk::{
    gio::{self, prelude::*},
    glib,
};
use std::{error::Error, path::Path};

#[derive(Clone, Copy, PartialEq, Eq, Debug, glib::Variant)]
pub struct GridSize {
    cols: u8,
    rows: u8,
}

impl GridSize {
    pub const GRID_3_BY_3: GridSize = GridSize { cols: 3, rows: 3 };
    pub const GRID_4_BY_4: GridSize = GridSize { cols: 4, rows: 4 };
    pub const GRID_5_BY_5: GridSize = GridSize { cols: 5, rows: 5 };

    pub fn try_new(cols: u8, rows: u8) -> Result<Self, Box<dyn Error>> {
        if rows <= 9 && cols <= 9 && rows * cols >= 3 {
            Ok(Self { cols, rows })
        } else {
            Err(
                gettext("Grid must have no more than 9 rows and columns and have at least 3 tiles")
                    .into(),
            )
        }
    }

    pub fn rows(self) -> u8 {
        self.rows
    }

    pub fn cols(self) -> u8 {
        self.cols
    }

    pub fn positions(self) -> impl Iterator<Item = GridPosition> {
        (0..self.rows).flat_map(move |row| (0..self.cols).map(move |col| GridPosition { row, col }))
    }

    pub fn is_predefined(self) -> bool {
        self == Self::GRID_3_BY_3 || self == Self::GRID_4_BY_4 || self == Self::GRID_5_BY_5
    }
}

pub fn save_size(settings: &gio::Settings, size: GridSize) -> Result<(), Box<dyn Error>> {
    settings.delay();
    settings.set_int("cols", size.cols() as i32)?;
    settings.set_int("rows", size.rows() as i32)?;
    settings.apply();
    gio::Settings::sync();
    Ok(())
}

pub fn restore_size(settings: &gio::Settings) -> Result<GridSize, Box<dyn Error>> {
    let cols = settings.int("cols").try_into()?;
    let rows = settings.int("rows").try_into()?;
    GridSize::try_new(cols, rows)
}

#[derive(Clone)]
pub struct Grid {
    grid: Vec<u8>,
    size: GridSize,
}

impl Grid {
    pub fn new(size: GridSize) -> Self {
        Self {
            grid: vec![0; size.rows() as usize * size.cols() as usize],
            size,
        }
    }

    pub fn size(&self) -> GridSize {
        self.size
    }

    pub fn new_tile(&mut self) -> Option<Tile> {
        if self.is_full() {
            return None;
        }
        let pos = loop {
            let pos = GridPosition {
                row: glib::random_int_range(0, self.size.rows as i32) as u8,
                col: glib::random_int_range(0, self.size.cols as i32) as u8,
            };
            if self.at(pos) == 0 {
                break pos;
            }
        };
        self.set_at(pos, 1);
        Some(Tile { pos, val: 1 })
    }

    pub fn at(&self, pos: GridPosition) -> u8 {
        self.grid[pos.row as usize * self.size.cols as usize + pos.col as usize]
    }

    pub fn set_at(&mut self, pos: GridPosition, value: u8) {
        self.grid[pos.row as usize * self.size.cols as usize + pos.col as usize] = value;
    }

    fn column(&self, col: u8) -> Vec<u8> {
        (0..self.size.rows)
            .map(|row| self.at(GridPosition { row, col }))
            .collect()
    }

    fn set_column(&mut self, col: u8, values: &[u8]) {
        for row in 0..self.size.rows {
            self.set_at(GridPosition { row, col }, values[row as usize]);
        }
    }

    fn row(&self, row: u8) -> Vec<u8> {
        (0..self.size.rows)
            .map(|col| self.at(GridPosition { row, col }))
            .collect()
    }

    fn set_row(&mut self, row: u8, values: &[u8]) {
        for col in 0..self.size.rows {
            self.set_at(GridPosition { row, col }, values[col as usize]);
        }
    }

    pub fn iter(&self) -> impl Iterator<Item = (GridPosition, u8)> {
        self.size().positions().map(|pos| (pos, self.at(pos)))
    }

    pub fn move_(&mut self, request: MoveRequest) -> Vec<Movement<GridPosition>> {
        match request {
            MoveRequest::Down => self.move_down(),
            MoveRequest::Up => self.move_up(),
            MoveRequest::Left => self.move_left(),
            MoveRequest::Right => self.move_right(),
        }
    }

    fn move_down(&mut self) -> Vec<Movement<GridPosition>> {
        let mut movement = Vec::new();
        for col in 0..self.size.cols {
            let mut tiles = self.column(col);
            let moves = shift_tiles_rev(&mut tiles);
            self.set_column(col, &tiles);

            movement.extend(
                moves
                    .iter()
                    .map(|m| m.map(|r| GridPosition { row: *r as u8, col })),
            );
        }
        movement
    }

    fn move_up(&mut self) -> Vec<Movement<GridPosition>> {
        let mut movement = Vec::new();
        for col in 0..self.size.cols {
            let mut tiles = self.column(col);
            let moves = shift_tiles(&mut tiles);
            self.set_column(col, &tiles);

            movement.extend(
                moves
                    .iter()
                    .map(|m| m.map(|r| GridPosition { row: *r as u8, col })),
            );
        }
        movement
    }

    fn move_left(&mut self) -> Vec<Movement<GridPosition>> {
        let mut movement = Vec::new();
        for row in 0..self.size.rows {
            let mut tiles = self.row(row);
            let moves = shift_tiles(&mut tiles);
            self.set_row(row, &tiles);

            movement.extend(
                moves
                    .iter()
                    .map(|m| m.map(|c| GridPosition { row, col: *c as u8 })),
            );
        }
        movement
    }

    fn move_right(&mut self) -> Vec<Movement<GridPosition>> {
        let mut movement = Vec::new();
        for row in 0..self.size.rows {
            let mut tiles = self.row(row);
            let moves = shift_tiles_rev(&mut tiles);
            self.set_row(row, &tiles);

            movement.extend(
                moves
                    .iter()
                    .map(|m| m.map(|c| GridPosition { row, col: *c as u8 })),
            );
        }
        movement
    }

    pub fn is_finished(&self) -> bool {
        if !self.is_full() {
            return false;
        }

        for row in 0..(self.size.rows - 1) {
            for col in 0..(self.size.cols - 1) {
                let value = self.at(GridPosition { row, col });
                let col_neighbour = self.at(GridPosition { row: row + 1, col });
                let row_neighbour = self.at(GridPosition { row, col: col + 1 });

                if value == col_neighbour || value == row_neighbour {
                    return false;
                }
            }
        }
        true
    }

    fn is_full(&self) -> bool {
        self.grid.iter().all(|c| *c != 0)
    }

    pub fn clear(&mut self) {
        self.grid.iter_mut().for_each(|c| *c = 0);
    }

    pub fn score(&self) -> u64 {
        self.grid
            .iter()
            .map(|tile_value| {
                if *tile_value < 2 {
                    0
                } else {
                    2_u64.pow(*tile_value as u32) * (*tile_value as u64 - 1)
                }
            })
            .sum()
    }

    pub fn save(&self) -> String {
        let mut result = format!("{} {}\n", self.size.rows, self.size.cols);
        for row in 0..self.size.rows {
            let mut first = true;
            for col in 0..self.size.cols {
                if first {
                    first = false;
                } else {
                    result.push(' ');
                }

                let val = self.at(GridPosition { row, col });
                if val == 0 {
                    result.push('0');
                } else {
                    result.push_str(&2_u64.pow(val as u32).to_string());
                }
            }
            result.push('\n');
        }

        // historical, not used when loading
        result.push_str(&self.score().to_string());
        result.push('\n');

        result
    }

    pub fn load(content: &str) -> Result<Self, Box<dyn Error>> {
        let mut lines = content.lines();

        let tokens = lines
            .next()
            .ok_or("EOF")?
            .split(' ')
            .map(|t| t.parse())
            .collect::<Result<Vec<u8>, _>>()?;
        if tokens.len() != 2 {
            return Err("Invalid grid size line".into());
        }
        let size = GridSize::try_new(tokens[1], tokens[0])?;

        let mut grid = Vec::new();
        for row in 0..size.rows() {
            let values = lines
                .next()
                .ok_or("EOF")?
                .split(' ')
                .filter(|t| !t.is_empty())
                .map(|t| {
                    let v: u64 = t.parse()?;
                    if v == 0 {
                        Ok(0_u8)
                    } else if v.count_ones() == 1 {
                        Ok(v.ilog2() as u8)
                    } else {
                        Err(format!("Invalid tile value {v}. It is not a power of 2.").into())
                    }
                })
                .collect::<Result<Vec<u8>, Box<dyn Error>>>()?;
            if values.len() != size.cols() as usize {
                return Err(format!("Invalid number of columns in row {row}").into());
            }
            grid.extend(values);
        }

        Ok(Self { grid, size })
    }

    pub fn save_game(&self, path: &Path) -> Result<(), Box<dyn Error>> {
        let contents = self.save();
        std::fs::create_dir_all(path.parent().ok_or("Invalid path")?)?;
        std::fs::write(path, contents)?;
        Ok(())
    }

    pub fn restore_game(path: &Path) -> Result<Self, Box<dyn Error>> {
        let content = std::fs::read_to_string(path)?;
        let grid = Grid::load(&content)?;
        Ok(grid)
    }
}

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct GridPosition {
    pub row: u8,
    pub col: u8,
}

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct TileMovement {
    pub tile: Tile,
    pub to: GridPosition,
}

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct Tile {
    pub pos: GridPosition,
    pub val: u8,
}

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum MoveRequest {
    Up,
    Right,
    Down,
    Left,
}

pub fn max_merge<T>(movements: &[Movement<T>]) -> Option<u64> {
    movements
        .iter()
        .filter_map(|m| match m {
            Movement::Merge { new_value, .. } => Some(*new_value),
            _ => None,
        })
        .max()
        .map(|v| 2_u64.pow(v as u32))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_full_game() {
        test_full_grid(GridSize::try_new(3, 3).unwrap());
        test_full_grid(GridSize::try_new(4, 4).unwrap());
        test_full_grid(GridSize::try_new(5, 5).unwrap());
        test_full_grid(GridSize::try_new(3, 5).unwrap());
        test_full_grid(GridSize::try_new(4, 3).unwrap());
    }

    fn test_full_grid(size: GridSize) {
        let mut grid = Grid::new(size);
        assert_eq!(grid.size, size);

        for _ in grid.size.positions() {
            let tile = grid.new_tile();

            assert!(tile.unwrap().val == 1);
            assert!(tile.unwrap().pos.row < grid.size.rows);
            assert!(tile.unwrap().pos.col < grid.size.cols);
        }

        assert!(grid.is_full());

        grid.clear();
        assert!(!grid.is_full());
    }

    #[test]
    fn test_load() {
        // correct square game
        let content = "2 2\n0 2\n2 4\n4\n";
        let grid = Grid::load(&content).unwrap();
        assert_eq!(grid.size.rows, 2);
        assert_eq!(grid.size.cols, 2);
        assert_eq!(grid.save(), content);

        // incorrect: inverted rows & cols numbers
        assert!(Grid::load("3 2\n0 2 0\n0 2 4\n-42\n").is_err());

        // correct non-square game
        let content = "3 2\n0 2\n0 4\n4 2\n8\n";
        let grid = Grid::load(&content).unwrap();
        assert_eq!(grid.size.rows, 3);
        assert_eq!(grid.size.cols, 2);
        assert_eq!(grid.save(), content);

        // incorrect: bad tile 3
        assert!(Grid::load("3 2\n0 2\n0 4\n4 3\n-42\n").is_err());

        // incorrect: bad tile -2
        assert!(Grid::load("3 2\n0 2\n0 4\n4 -2\n-42\n").is_err());

        // incorrect: bad rows number 10
        assert!(
            Grid::load("10 2\n0 2\n0 4\n4 2\n0 2\n0 4\n4 2\n0 2\n0 4\n4 2\n0 1\n-42\n").is_err()
        );

        // incorrect: bad cols number 10
        assert!(Grid::load("2 10\n0 2 4 8 2 4 8 2 4 8\n0 4 0 2 0 4 0 2 0 8\n-42\n").is_err());

        // incorrect: second row not matching cols number
        assert!(Grid::load("3 2\n0 2\n0 4 2\n4 2\n-42\n").is_err());

        // incorrect score
        let grid = Grid::load("3 2\n0 2\n0 4\n8 2\n16\n").unwrap();
        assert_eq!(grid.size.rows, 3);
        assert_eq!(grid.size.cols, 2);
        assert_eq!(grid.save(), "3 2\n0 2\n0 4\n8 2\n20\n");
    }
}
