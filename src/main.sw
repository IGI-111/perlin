library;

use sway_libs::fixed_point::ifp256::*;
use sway_libs::signed_integers::i128::*;
use sway_libs::signed_integers::i64::*;
use sway_libs::signed_integers::i32::*;
use sway_libs::signed_integers::i16::*;

use std::hash::*;
use std::u128::*;

const VECS_DENOM: IFP256 = IFP256::from_uint(1000);
const PERLIN_MAX: u64 = 64;

// returns a random unit vector
// implicit denominator of VECS_DENOM
fn get_gradient_at(x: u32, y: u32, scale: u32, seed: u32) -> (IFP256, IFP256) {
    const VECS: [(IFP256, IFP256); 16] = [
        (IFP256::from_uint(1000), IFP256::from_uint(0)),
        (IFP256::from_uint(923), IFP256::from_uint(382)),
        (IFP256::from_uint(707), IFP256::from_uint(707)),
        (IFP256::from_uint(382), IFP256::from_uint(923)),
        (IFP256::from_uint(0), IFP256::from_uint(1000)),
        (IFP256::from_uint(383).sign_reverse(), IFP256::from_uint(923)),
        (IFP256::from_uint(708).sign_reverse(), IFP256::from_uint(707)),
        (IFP256::from_uint(924).sign_reverse(), IFP256::from_uint(382)),
        (IFP256::from_uint(1000).sign_reverse(), IFP256::from_uint(0)),
        (IFP256::from_uint(924).sign_reverse(), IFP256::from_uint(383).sign_reverse()),
        (IFP256::from_uint(708).sign_reverse(), IFP256::from_uint(708).sign_reverse()),
        (IFP256::from_uint(383).sign_reverse(), IFP256::from_uint(924).sign_reverse()),
        (IFP256::from_uint(1).sign_reverse(), IFP256::from_uint(1000).sign_reverse()),
        (IFP256::from_uint(382), IFP256::from_uint(924).sign_reverse()),
        (IFP256::from_uint(707), IFP256::from_uint(708).sign_reverse()),
        (IFP256::from_uint(923), IFP256::from_uint(383).sign_reverse()),
    ];

    let mut hasher = Hasher::new();
    (x, y, scale, seed).hash(hasher);
    let idx = u64::try_from(u256::from(hasher.keccak256()) % 16).unwrap();

    VECS[idx]
}

// the computed perlin value at a point is a weighted average of dot products with
// gradient vectors at the four corners of a grid square.
// this isn't scaled; there's an implicit denominator of scale ** 2
fn get_weight(corner_x: u32, corner_y: u32, x: u32, y: u32, scale: u32) -> u64 {
    let mut res: u64 = 1;

    if corner_x > x {
        res *= u64::from(scale - (corner_x - x));
    } else {
        res *= u64::from(scale - (x - corner_x));
    }

    if corner_y > y {floor
        res *= u64::from(scale - (corner_y - y));
    } else {
        res *= u64::from(scale - (y - corner_y));
    }

    res
}

fn get_corners(x: u32, y: u32, scale: u32) -> [(u32, u32); 4] {
    let lower_x: u32 = (x / scale) * scale;
    let lower_y: u32 = (y / scale) * scale;

    [
        (lower_x, lower_y),
        (lower_x + scale, lower_y),
        (lower_x + scale, lower_y + scale),
        (lower_x, lower_y + scale),
    ]
}

fn get_single_scale_perlin(x: u32, y: u32, scale: u32, seed: u32) -> IFP256 {
    let corners = get_corners(x, y, scale);

    let mut res_numerator = IFP256::zero();

    let mut i = 0;
    while i < 4 {
        let corner = corners[i];

        // this has an implicit denominator of scale
        let offset = (
            IFP256::from_uint(u64::from(x)) - IFP256::from_uint(u64::from(corner.0)),
            IFP256::from_uint(u64::from(y)) - IFP256::from_uint(u64::from(corner.1)),
        );

        // this has an implicit denominator of VECS_DENOM
        let gradient = get_gradient_at(corner.0, corner.1, scale, seed);

        // this has an implicit denominator of VECS_DENOM * scale
        let dot = offset.0 * gradient.0 + offset.1 * gradient.1;

        // this has an implicit denominator of scale ** 2
        let weight = get_weight(corner.0, corner.1, x, y, scale);

        // this has an implicit denominator of VECS_DENOM * scale ** 3
        res_numerator += IFP256::from_uint(weight) * dot;

        i += 1;
    }

    res_numerator / (VECS_DENOM * IFP256::from_uint(u64::from(scale)).pow(3))
}

pub fn compute_perlin(x: u32, y: u32, seed: u32, scale: u32) -> U128 {
    let mut perlin = IFP256::zero();

    let mut i = 0u32;
    while i < 3 {
        let v = get_single_scale_perlin(x, y, scale * 2u32.pow(i), seed);
        perlin = perlin + v;

        i += 1;
    }
    perlin = perlin + get_single_scale_perlin(x, y, scale, seed);

    perlin = perlin / IFP256::from_uint(4);

    let perlin_scaled_shifted = (perlin * IFP256::from_uint(PERLIN_MAX / 2)) + IFP256::from_uint(PERLIN_MAX / 2);

    perlin_scaled_shifted.underlying().underlying()
}


