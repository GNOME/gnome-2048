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

#[derive(PartialEq, Debug)]
pub enum Movement<P> {
    Appear {
        to: P,
        new_value: u8,
    },
    Move {
        from: P,
        to: P,
        value: u8,
    },
    Merge {
        from1: P,
        from2: P,
        to: P,
        new_value: u8,
    },
}

impl<P> Movement<P> {
    pub fn map<R>(&self, f: impl Fn(&P) -> R) -> Movement<R> {
        match self {
            Self::Appear { to, new_value } => Movement::Appear {
                to: (f)(to),
                new_value: *new_value,
            },
            Self::Move { from, to, value } => Movement::Move {
                from: (f)(from),
                to: (f)(to),
                value: *value,
            },
            Self::Merge {
                from1,
                from2,
                to,
                new_value,
            } => Movement::Merge {
                from1: (f)(from1),
                from2: (f)(from2),
                to: (f)(to),
                new_value: *new_value,
            },
        }
    }
}

pub fn shift_tiles(tiles: &mut [u8]) -> Vec<Movement<usize>> {
    let mut empty = None;
    let mut movements = Vec::new();

    for i in 0..tiles.len() {
        let value = tiles[i];

        if value == 0 {
            if empty.is_none() {
                empty = Some(i);
            }
        } else if let Some(j) = find_match(tiles, i) {
            let to = empty.unwrap_or(i);

            movements.push(Movement::Merge {
                from1: i,
                from2: j,
                to,
                new_value: value + 1,
            });

            tiles[i] = 0;
            tiles[j] = 0;
            tiles[to] = value + 1;

            empty = Some(to + 1);
        } else if let Some(to) = empty {
            movements.push(Movement::Move { from: i, to, value });

            tiles[i] = 0;
            tiles[to] = value;

            empty = Some(to + 1);
        }
    }
    movements
}

fn find_match(tiles: &[u8], i: usize) -> Option<usize> {
    let i_value = tiles[i];
    tiles
        .iter()
        .enumerate()
        .skip(i + 1)
        .find(|(_, value)| **value != 0)
        .filter(|(_, value)| **value == i_value)
        .map(|(position, _)| position)
}

pub fn shift_tiles_rev(tiles: &mut [u8]) -> Vec<Movement<usize>> {
    tiles.reverse();
    let mut movements = shift_tiles(tiles);
    for movement in &mut movements {
        match movement {
            Movement::Appear { to, .. } => {
                *to = tiles.len() - 1 - *to;
            }
            Movement::Move { from, to, .. } => {
                *from = tiles.len() - 1 - *from;
                *to = tiles.len() - 1 - *to;
            }
            Movement::Merge {
                from1, from2, to, ..
            } => {
                *from1 = tiles.len() - 1 - *from1;
                *from2 = tiles.len() - 1 - *from2;
                *to = tiles.len() - 1 - *to;
            }
        }
    }
    tiles.reverse();
    movements
}

#[cfg(test)]
mod tests {
    use super::*;
    use proptest::{collection::vec, proptest};

    #[test]
    fn test_shift_tiles_0() {
        let mut tiles = vec![0, 0, 0];
        let moves = shift_tiles(&mut tiles);
        assert_eq!(tiles, vec![0, 0, 0]);
        assert!(moves.is_empty(),);
    }

    #[test]
    fn test_shift_tiles_0_rev() {
        let mut tiles = vec![0, 0, 0];
        let moves = shift_tiles_rev(&mut tiles);
        assert_eq!(tiles, vec![0, 0, 0]);
        assert!(moves.is_empty(),);
    }

    #[test]
    fn test_shift_tiles_1() {
        let mut tiles = vec![2, 2, 0, 4];
        let moves = shift_tiles(&mut tiles);
        assert_eq!(tiles, vec![3, 4, 0, 0]);
        assert_eq!(
            moves,
            vec![
                Movement::Merge {
                    from1: 0,
                    from2: 1,
                    to: 0,
                    new_value: 3
                },
                Movement::Move {
                    from: 3,
                    to: 1,
                    value: 4
                }
            ]
        );
    }

    #[test]
    fn test_shift_tiles_1_rev() {
        let mut tiles = vec![2, 2, 0, 4];
        let moves = shift_tiles_rev(&mut tiles);
        assert_eq!(tiles, vec![0, 0, 3, 4]);
        assert_eq!(
            moves,
            vec![Movement::Merge {
                from1: 1,
                from2: 0,
                to: 2,
                new_value: 3
            },]
        );
    }

    #[test]
    fn test_shift_tiles_2() {
        let mut tiles = vec![0, 1, 0, 1, 0];
        let moves = shift_tiles(&mut tiles);
        assert_eq!(tiles, vec![2, 0, 0, 0, 0]);
        assert_eq!(
            moves,
            vec![Movement::Merge {
                from1: 1,
                from2: 3,
                to: 0,
                new_value: 2
            },]
        );
    }

    #[test]
    fn test_shift_tiles_2_rev() {
        let mut tiles = vec![0, 1, 0, 1, 0];
        let moves = shift_tiles_rev(&mut tiles);
        assert_eq!(tiles, vec![0, 0, 0, 0, 2]);
        assert_eq!(
            moves,
            vec![Movement::Merge {
                from1: 3,
                from2: 1,
                to: 4,
                new_value: 2
            },]
        );
    }

    fn sum_tiles(tiles: &[u8]) -> u128 {
        tiles
            .iter()
            .filter(|t| **t != 0)
            .map(|t| 2_u128.pow(*t as u32))
            .sum()
    }

    proptest! {
        #[test]
        fn test_sum_matches(mut tiles in vec(0..127_u8, 0..10)) {
            let sum_before = sum_tiles(&tiles);

            let _moves = shift_tiles(&mut tiles);

            let sum_after = sum_tiles(&tiles);
            assert_eq!(sum_before, sum_after);

            assert!(tiles.iter().skip_while(|t| **t != 0).all(|t| *t == 0), "all non-zero tiles are at the front");
        }
    }

    proptest! {
        #[test]
        fn test_sum_matches_rev(mut tiles in vec(0..127_u8, 0..10)) {
            let sum_before = sum_tiles(&tiles);

            let _moves = shift_tiles_rev(&mut tiles);

            let sum_after = sum_tiles(&tiles);
            assert_eq!(sum_before, sum_after);

            assert!(tiles.iter().skip_while(|t| **t == 0).all(|t| *t != 0), "all non-zero tiles are at the back");
        }
    }
}
