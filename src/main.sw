library;

// use perlin::compute_perlin;
use sway_libs::signed_integers::i16::*;
use sway_libs::signed_integers::common::WrappingNeg;


const P: [u8;257] = [
    151, 160, 137,  91,  90,  15, 131,  13, 201,  95,  96,  53, 194, 233,   7, 225,
    140,  36, 103,  30,  69, 142,   8,  99,  37, 240,  21,  10,  23, 190,   6, 148,
    247, 120, 234,  75,   0,  26, 197,  62,  94, 252, 219, 203, 117,  35,  11,  32,
     57, 177,  33,  88, 237, 149,  56,  87, 174,  20, 125, 136, 171, 168,  68, 175,
     74, 165,  71, 134, 139,  48,  27, 166,  77, 146, 158, 231,  83, 111, 229, 122,
     60, 211, 133, 230, 220, 105,  92,  41,  55,  46, 245,  40, 244, 102, 143,  54,
     65,  25,  63, 161,   1, 216,  80,  73, 209,  76, 132, 187, 208,  89,  18, 169,
    200, 196, 135, 130, 116, 188, 159,  86, 164, 100, 109, 198, 173, 186,   3,  64,
     52, 217, 226, 250, 124, 123,   5, 202,  38, 147, 118, 126, 255,  82,  85, 212,
    207, 206,  59, 227,  47,  16,  58,  17, 182, 189,  28,  42, 223, 183, 170, 213,
    119, 248, 152,   2,  44, 154, 163,  70, 221, 153, 101, 155, 167,  43, 172,   9,
    129,  22,  39, 253,  19,  98, 108, 110,  79, 113, 224, 232, 178, 185, 112, 104,
    218, 246,  97, 228, 251,  34, 242, 193, 238, 210, 144,  12, 191, 179, 162, 241,
     81,  51, 145, 235, 249,  14, 239, 107,  49, 192, 214,  31, 181, 199, 106, 157,
    184,  84, 204, 176, 115, 121,  50,  45, 127,   4, 150, 254, 138, 236, 205,  93,
    222, 114,  67,  29,  24,  72, 243, 141, 128, 195,  78,  66, 215,  61, 156, 180,
    151];


fn avg15(i: I16, j: I16) -> I16 {
    return (i/I16::try_from(2).unwrap() ) + (j/I16::try_from(2).unwrap()) + I16::try_from(i.underlying() & 0x1).unwrap();
}

fn grad16(hash: u8, x: I16, y: I16) -> I16 {
    let mut hash = hash & 7;
    let mut u = I16::zero();
    let mut v = I16::zero();
    if(hash < 4) { u = x; v = y; } else { u = y; v = x; }
    if(hash&1!=0) { u = u.wrapping_neg(); }
    if(hash&2!=0) { v = v.wrapping_neg(); }
 
    return avg15(u,v);
}


fn lerp15by16( a: I16, b: I16, frac: u16) -> I16
{
    let mut result = I16::zero();
    if b > a {
        let delta = u16::try_from(u32::from((b - a).underlying()) - u32::from(I16::indent())).unwrap();
        let scaled = scale16( delta, frac);
        result = a + I16::try_from(scaled).unwrap();

    } else {
        let delta = u16::try_from(u32::from((a - b).underlying()) - u32::from(I16::indent())).unwrap();
        let scaled = scale16( delta, frac);
        result = a - I16::try_from(scaled).unwrap();
    }
    return result;
}

fn scale16(i: u16, scale: u16) -> u16 {
    u16::try_from((u32::from(i) * u32::from(scale)) / 65536).unwrap()
}

fn ease_16(i: u16) -> u16 {
    let mut j = i;
    if (j & 0x8000) != 0  {
        j = 65535u16 - j;
    }
    let jj = scale16( j, j);
    let mut jj2 = jj << 1;
    if( i & 0x8000 != 0 ) {
        jj2 = 65535u16 - jj2;
    }
    return jj2;
}

fn inoise(x: u32, y: u32) -> I16 {
    // Find the unit cube containing the point
    let X = u64::from(x>>16);
    let Y = u64::from(y>>16);
 
    // Hash cube corner coordinates
    let A = u64::from(P[X])+Y;
    let AA = u64::from(P[A]);
    let AB = u64::from(P[A+1]);
    let B =  u64::from(P[X+1])+Y;
    let BA = u64::from(P[B]);
    let BB = u64::from(P[B+1]);
 
    // Get the relative position of the point in the cube
    let mut u = u16::try_from(x & 0xFFFF).unwrap();
    let mut v = u16::try_from(y & 0xFFFF).unwrap();
 
    // Get a signed version of the above for the grad function
    let xx = I16::try_from((u >> 1) & 0x7FFF).unwrap();
    let yy = I16::try_from((v >> 1) & 0x7FFF).unwrap();
    let N = I16::max(); //FIXME: should be 0x8000
 
    u = ease_16(u); v = ease_16(v);
 
    let grad1 = grad16(P[AA], xx, yy);
    let grad2 = grad16(P[BA], xx - N, yy);
    let X1 = lerp15by16(grad1, grad2, u);
    let grad3 = grad16(P[AB], xx, yy-N);
    let grad4 = grad16(P[BB], xx - N, yy - N);
    let X2 = lerp15by16(grad3, grad4, u);
 
    let ans = lerp15by16(X1,X2,v);
 
    return ans;
}

fn noise(x: u32, y: u32) -> u16{
    let mut  ans = inoise(x,y);
    ans = ans + I16::try_from(17308).unwrap();
    let mut pan = u32::from(ans.underlying())- u32::from(I16::indent());
    // pan = (ans * 242L) >> 7.  That's the same as:
    // pan = (ans * 484L) >> 8.  And this way avoids a 7X four-byte shift-loop on AVR.
    // Identical math, except for the highest bit, which we don't care about anyway,
    // since we're returning the 'middle' 16 out of a 32-bit value anyway.
    pan *= 484;
    u16::try_from(pan>>8).unwrap()
}

#[test]
fn run_test() {
    noise(1, 1);
    noise(2, 1);
    noise(2, 42);
}
 
