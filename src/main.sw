library;

// use perlin::compute_perlin;
use sway_libs::signed_integers::i16::*;
use sway_libs::signed_integers::i8::*;
use sway_libs::signed_integers::common::WrappingNeg;


const P: [u8;256] = [
151,160,137,91,90,15,
   131,13,201,95,96,53,194,233,7,225,140,36,103,30,69,142,8,99,37,240,21,10,23,
   190, 6,148,247,120,234,75,0,26,197,62,94,252,219,203,117,35,11,32,57,177,33,
   88,237,149,56,87,174,20,125,136,171,168, 68,175,74,165,71,134,139,48,27,166,
   77,146,158,231,83,111,229,122,60,211,133,230,220,105,92,41,55,46,245,40,244,
   102,143,54, 65,25,63,161, 1,216,80,73,209,76,132,187,208, 89,18,169,200,196,
   135,130,116,188,159,86,164,100,109,198,173,186, 3,64,52,217,226,250,124,123,
   5,202,38,147,118,126,255,82,85,212,207,206,59,227,47,16,58,17,182,189,28,42,
   223,183,170,213,119,248,152, 2,44,154,163, 70,221,153,101,155,167, 43,172,9,
   129,22,39,253, 19,98,108,110,79,113,224,232,178,185, 112,104,218,246,97,228,
   251,34,242,193,238,210,144,12,191,179,162,241, 81,51,145,235,249,14,239,107,
   49,192,214, 31,181,199,106,157,184, 84,204,176,115,121,50,45,127, 4,150,254,
   138,236,205,93,222,114,67,29,24,72,243,141,128,195,78,66,215,61,156,180 ];

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

fn inoise16_raw(x: u32, y: u32) -> I16 {
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


fn avg7(i: I8, j: I8) -> I8 {
    return (i/I8::try_from(2).unwrap() ) + (j/I8::try_from(2).unwrap()) + I8::try_from(i.underlying() & 0x1).unwrap();
}

fn grad8(hash: u8, x: I8, y: I8) -> I8
{
    // since the tests below can be done bit-wise on the bottom
    // three bits, there's no need to mask off the higher bits
    //  hash = hash & 7;
 
    let mut u = I8::zero();
    let mut v = I8::zero();
    if( hash & 4 != 0) {
        u = y; v = x;
    } else {
        u = x; v = y;
    }
 
    if(hash&1 != 0) { u = u.wrapping_neg(); }
    if(hash&2 != 0) { v = v.wrapping_neg(); }
 
    return avg7(u,v);
}

fn lerp7by8(a: I8, b: I8, frac: u8) -> I8
{
    // int8_t delta = b - a;
    // int16_t prod = (uint16_t)delta * (uint16_t)frac;
    // int8_t scaled = prod >> 8;
    // int8_t result = a + scaled;
    // return result;
    let mut result = I8::zero();
    if( b > a) {
        let delta = u8::try_from(u16::from((b - a).underlying()) - u16::from(I8::indent())).unwrap();
        let scaled = scale8( delta, frac);
        result = a + I8::try_from(scaled).unwrap();
    } else {
        let delta = u8::try_from(u16::from((a - b).underlying()) - u16::from(I8::indent())).unwrap();
        let scaled = scale8( delta, frac);
        result = a - I8::try_from(scaled).unwrap();
    }
    return result;
}

fn scale8(i: u8, scale: u8) -> u8 {
return u8::try_from((u16::from(i) * u16::from(scale)) >> 8).unwrap();
}

fn ease8(i: u8) -> u8 {
    let mut j = i;
    if( j & 0x80 !=0) {
        j = 255u8 - j;
    }
    let jj  = scale8(  j, j);
    let mut jj2 = jj << 1;
    if( i & 0x80 !=0) {
        jj2 = 255u8 - jj2;
    }
    return jj2;
}

fn inoise8_raw(x: u16, y: u16) -> I8
{
    // Find the unit cube containing the point
    let X = u64::from(x>>8);
    let Y = u64::from(y>>8);
 
    // Hash cube corner coordinates
    let A =  u64::from(P[X])+Y;
    let AA = u64::from(P[A]);
    let AB = u64::from(P[A+1]);
    let B =  u64::from(P[X+1])+Y;
    let BA = u64::from(P[B]);
    let BB = u64::from(P[B+1]);
 
    // Get the relative position of the point in the cube
    let mut u = u8::try_from(x & 0xFF).unwrap();
    let mut v = u8::try_from(y & 0xFF).unwrap();
 
    // Get a signed version of the above for the grad function
    let xx = I8::try_from(u8::try_from(x>>1 & 0x7F).unwrap()).unwrap();
    let yy = I8::try_from(u8::try_from(y>>1 & 0x7F).unwrap()).unwrap();
    let N = I8::max();// FIXME should be 0x80u8;
 
    u = ease8(u); v = ease8(v);
 
    let X1 = lerp7by8(grad8(P[AA], xx, yy), grad8(P[BA], xx - N, yy), u);
    let X2 = lerp7by8(grad8(P[AB], xx, yy-N), grad8(P[BB], xx - N, yy - N), u);
 
    let ans = lerp7by8(X1,X2,v);
 
    return ans;
    // return scale8((70+(ans)),234)<<1;
}


fn qadd8(i: u8, j: u8) -> u8 {
    let mut t = u16::from(i) + u16::from(j);
    if t > 255 {
        t = 255;
    }
    return u8::try_from(t).unwrap();
}

pub fn inoise8(x: u16, y: u16) -> u8 {
  //return scale8(69+inoise8_raw(x,y),237)<<1;
    let mut n = inoise8_raw(x, y);  // -64..+64
    n+= I8::try_from(64).unwrap(); //   0..128
    let n = n.underlying() - I8::indent();
    let ans = qadd8(n, n);     //   0..255
    return ans;
}    

#[test]
fn run_test() {
    inoise8(1, 1);
    inoise8(2, 1);
    inoise8(2, 42);
}
 
