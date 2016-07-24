//
//  NSData+Shavite.m
/* $Id: shavite.c 227 2010-06-16 17:28:38Z tp $ */
/*
 * SHAvite-3 implementation.
 *
 * ==========================(LICENSE BEGIN)============================
 *
 * Copyright (c) 2007-2010  Projet RNRT SAPHIR
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 * CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 * TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 * SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 *
 * ===========================(LICENSE END)=============================
 *
 * @author   Thomas Pornin <thomas.pornin@cryptolog.com>
 */

#import "NSData+Shavite.h"
#import "sph_types.h"

@implementation NSData(Shavite)

typedef struct {
#ifndef DOXYGEN_IGNORE
    unsigned char buf[128];    /* first field, for alignment */
    size_t ptr;
    sph_u32 h[16];
    sph_u32 count0, count1, count2, count3;
#endif
} sph_shavite_big_context;

#if SPH_SMALL_FOOTPRINT && !defined SPH_SMALL_FOOTPRINT_SHAVITE
#define SPH_SMALL_FOOTPRINT_SHAVITE   1
#endif

#ifdef _MSC_VER
#pragma warning (disable: 4146)
#endif

#define C32   SPH_C32

/*
 * As of round 2 of the SHA-3 competition, the published reference
 * implementation and test vectors are wrong, because they use
 * big-endian AES tables while the internal decoding uses little-endian.
 * The code below follows the specification. To turn it into a code
 * which follows the reference implementation (the one called "BugFix"
 * on the SHAvite-3 web site, published on Nov 23rd, 2009), comment out
 * the code below (from the '#define AES_BIG_ENDIAN...' to the definition
 * of the AES_ROUND_NOKEY macro) and replace it with the version which
 * is commented out afterwards.
 */

#define AES_BIG_ENDIAN   0
#include "aes_helper.c"

static const sph_u32 IV512[] = {
    C32(0x72FCCDD8), C32(0x79CA4727), C32(0x128A077B), C32(0x40D55AEC),
    C32(0xD1901A06), C32(0x430AE307), C32(0xB29F5CD1), C32(0xDF07FBFC),
    C32(0x8E45D73D), C32(0x681AB538), C32(0xBDE86578), C32(0xDD577E47),
    C32(0xE275EADE), C32(0x502D9FCD), C32(0xB9357178), C32(0x022A4B9A)
};

#define AES_ROUND_NOKEY(x0, x1, x2, x3)   do { \
sph_u32 t0 = (x0); \
sph_u32 t1 = (x1); \
sph_u32 t2 = (x2); \
sph_u32 t3 = (x3); \
AES_ROUND_NOKEY_LE(t0, t1, t2, t3, x0, x1, x2, x3); \
} while (0)

#define KEY_EXPAND_ELT(k0, k1, k2, k3)   do { \
sph_u32 kt; \
AES_ROUND_NOKEY(k1, k2, k3, k0); \
kt = (k0); \
(k0) = (k1); \
(k1) = (k2); \
(k2) = (k3); \
(k3) = kt; \
} while (0)

/*
 * This function assumes that "msg" is aligned for 32-bit access.
 */
static void
c512(sph_shavite_big_context *sc, const void *msg)
{
    sph_u32 p0, p1, p2, p3, p4, p5, p6, p7;
    sph_u32 p8, p9, pA, pB, pC, pD, pE, pF;
    sph_u32 x0, x1, x2, x3;
    sph_u32 rk00, rk01, rk02, rk03, rk04, rk05, rk06, rk07;
    sph_u32 rk08, rk09, rk0A, rk0B, rk0C, rk0D, rk0E, rk0F;
    sph_u32 rk10, rk11, rk12, rk13, rk14, rk15, rk16, rk17;
    sph_u32 rk18, rk19, rk1A, rk1B, rk1C, rk1D, rk1E, rk1F;
    int r;
    
    p0 = sc->h[0x0];
    p1 = sc->h[0x1];
    p2 = sc->h[0x2];
    p3 = sc->h[0x3];
    p4 = sc->h[0x4];
    p5 = sc->h[0x5];
    p6 = sc->h[0x6];
    p7 = sc->h[0x7];
    p8 = sc->h[0x8];
    p9 = sc->h[0x9];
    pA = sc->h[0xA];
    pB = sc->h[0xB];
    pC = sc->h[0xC];
    pD = sc->h[0xD];
    pE = sc->h[0xE];
    pF = sc->h[0xF];
    /* round 0 */
    rk00 = sph_dec32le_aligned((const unsigned char *)msg +   0);
    x0 = p4 ^ rk00;
    rk01 = sph_dec32le_aligned((const unsigned char *)msg +   4);
    x1 = p5 ^ rk01;
    rk02 = sph_dec32le_aligned((const unsigned char *)msg +   8);
    x2 = p6 ^ rk02;
    rk03 = sph_dec32le_aligned((const unsigned char *)msg +  12);
    x3 = p7 ^ rk03;
    AES_ROUND_NOKEY(x0, x1, x2, x3);
    rk04 = sph_dec32le_aligned((const unsigned char *)msg +  16);
    x0 ^= rk04;
    rk05 = sph_dec32le_aligned((const unsigned char *)msg +  20);
    x1 ^= rk05;
    rk06 = sph_dec32le_aligned((const unsigned char *)msg +  24);
    x2 ^= rk06;
    rk07 = sph_dec32le_aligned((const unsigned char *)msg +  28);
    x3 ^= rk07;
    AES_ROUND_NOKEY(x0, x1, x2, x3);
    rk08 = sph_dec32le_aligned((const unsigned char *)msg +  32);
    x0 ^= rk08;
    rk09 = sph_dec32le_aligned((const unsigned char *)msg +  36);
    x1 ^= rk09;
    rk0A = sph_dec32le_aligned((const unsigned char *)msg +  40);
    x2 ^= rk0A;
    rk0B = sph_dec32le_aligned((const unsigned char *)msg +  44);
    x3 ^= rk0B;
    AES_ROUND_NOKEY(x0, x1, x2, x3);
    rk0C = sph_dec32le_aligned((const unsigned char *)msg +  48);
    x0 ^= rk0C;
    rk0D = sph_dec32le_aligned((const unsigned char *)msg +  52);
    x1 ^= rk0D;
    rk0E = sph_dec32le_aligned((const unsigned char *)msg +  56);
    x2 ^= rk0E;
    rk0F = sph_dec32le_aligned((const unsigned char *)msg +  60);
    x3 ^= rk0F;
    AES_ROUND_NOKEY(x0, x1, x2, x3);
    p0 ^= x0;
    p1 ^= x1;
    p2 ^= x2;
    p3 ^= x3;
    rk10 = sph_dec32le_aligned((const unsigned char *)msg +  64);
    x0 = pC ^ rk10;
    rk11 = sph_dec32le_aligned((const unsigned char *)msg +  68);
    x1 = pD ^ rk11;
    rk12 = sph_dec32le_aligned((const unsigned char *)msg +  72);
    x2 = pE ^ rk12;
    rk13 = sph_dec32le_aligned((const unsigned char *)msg +  76);
    x3 = pF ^ rk13;
    AES_ROUND_NOKEY(x0, x1, x2, x3);
    rk14 = sph_dec32le_aligned((const unsigned char *)msg +  80);
    x0 ^= rk14;
    rk15 = sph_dec32le_aligned((const unsigned char *)msg +  84);
    x1 ^= rk15;
    rk16 = sph_dec32le_aligned((const unsigned char *)msg +  88);
    x2 ^= rk16;
    rk17 = sph_dec32le_aligned((const unsigned char *)msg +  92);
    x3 ^= rk17;
    AES_ROUND_NOKEY(x0, x1, x2, x3);
    rk18 = sph_dec32le_aligned((const unsigned char *)msg +  96);
    x0 ^= rk18;
    rk19 = sph_dec32le_aligned((const unsigned char *)msg + 100);
    x1 ^= rk19;
    rk1A = sph_dec32le_aligned((const unsigned char *)msg + 104);
    x2 ^= rk1A;
    rk1B = sph_dec32le_aligned((const unsigned char *)msg + 108);
    x3 ^= rk1B;
    AES_ROUND_NOKEY(x0, x1, x2, x3);
    rk1C = sph_dec32le_aligned((const unsigned char *)msg + 112);
    x0 ^= rk1C;
    rk1D = sph_dec32le_aligned((const unsigned char *)msg + 116);
    x1 ^= rk1D;
    rk1E = sph_dec32le_aligned((const unsigned char *)msg + 120);
    x2 ^= rk1E;
    rk1F = sph_dec32le_aligned((const unsigned char *)msg + 124);
    x3 ^= rk1F;
    AES_ROUND_NOKEY(x0, x1, x2, x3);
    p8 ^= x0;
    p9 ^= x1;
    pA ^= x2;
    pB ^= x3;
    
    for (r = 0; r < 3; r ++) {
        /* round 1, 5, 9 */
        KEY_EXPAND_ELT(rk00, rk01, rk02, rk03);
        rk00 ^= rk1C;
        rk01 ^= rk1D;
        rk02 ^= rk1E;
        rk03 ^= rk1F;
        if (r == 0) {
            rk00 ^= sc->count0;
            rk01 ^= sc->count1;
            rk02 ^= sc->count2;
            rk03 ^= SPH_T32(~sc->count3);
        }
        x0 = p0 ^ rk00;
        x1 = p1 ^ rk01;
        x2 = p2 ^ rk02;
        x3 = p3 ^ rk03;
        AES_ROUND_NOKEY(x0, x1, x2, x3);
        KEY_EXPAND_ELT(rk04, rk05, rk06, rk07);
        rk04 ^= rk00;
        rk05 ^= rk01;
        rk06 ^= rk02;
        rk07 ^= rk03;
        if (r == 1) {
            rk04 ^= sc->count3;
            rk05 ^= sc->count2;
            rk06 ^= sc->count1;
            rk07 ^= SPH_T32(~sc->count0);
        }
        x0 ^= rk04;
        x1 ^= rk05;
        x2 ^= rk06;
        x3 ^= rk07;
        AES_ROUND_NOKEY(x0, x1, x2, x3);
        KEY_EXPAND_ELT(rk08, rk09, rk0A, rk0B);
        rk08 ^= rk04;
        rk09 ^= rk05;
        rk0A ^= rk06;
        rk0B ^= rk07;
        x0 ^= rk08;
        x1 ^= rk09;
        x2 ^= rk0A;
        x3 ^= rk0B;
        AES_ROUND_NOKEY(x0, x1, x2, x3);
        KEY_EXPAND_ELT(rk0C, rk0D, rk0E, rk0F);
        rk0C ^= rk08;
        rk0D ^= rk09;
        rk0E ^= rk0A;
        rk0F ^= rk0B;
        x0 ^= rk0C;
        x1 ^= rk0D;
        x2 ^= rk0E;
        x3 ^= rk0F;
        AES_ROUND_NOKEY(x0, x1, x2, x3);
        pC ^= x0;
        pD ^= x1;
        pE ^= x2;
        pF ^= x3;
        KEY_EXPAND_ELT(rk10, rk11, rk12, rk13);
        rk10 ^= rk0C;
        rk11 ^= rk0D;
        rk12 ^= rk0E;
        rk13 ^= rk0F;
        x0 = p8 ^ rk10;
        x1 = p9 ^ rk11;
        x2 = pA ^ rk12;
        x3 = pB ^ rk13;
        AES_ROUND_NOKEY(x0, x1, x2, x3);
        KEY_EXPAND_ELT(rk14, rk15, rk16, rk17);
        rk14 ^= rk10;
        rk15 ^= rk11;
        rk16 ^= rk12;
        rk17 ^= rk13;
        x0 ^= rk14;
        x1 ^= rk15;
        x2 ^= rk16;
        x3 ^= rk17;
        AES_ROUND_NOKEY(x0, x1, x2, x3);
        KEY_EXPAND_ELT(rk18, rk19, rk1A, rk1B);
        rk18 ^= rk14;
        rk19 ^= rk15;
        rk1A ^= rk16;
        rk1B ^= rk17;
        x0 ^= rk18;
        x1 ^= rk19;
        x2 ^= rk1A;
        x3 ^= rk1B;
        AES_ROUND_NOKEY(x0, x1, x2, x3);
        KEY_EXPAND_ELT(rk1C, rk1D, rk1E, rk1F);
        rk1C ^= rk18;
        rk1D ^= rk19;
        rk1E ^= rk1A;
        rk1F ^= rk1B;
        if (r == 2) {
            rk1C ^= sc->count2;
            rk1D ^= sc->count3;
            rk1E ^= sc->count0;
            rk1F ^= SPH_T32(~sc->count1);
        }
        x0 ^= rk1C;
        x1 ^= rk1D;
        x2 ^= rk1E;
        x3 ^= rk1F;
        AES_ROUND_NOKEY(x0, x1, x2, x3);
        p4 ^= x0;
        p5 ^= x1;
        p6 ^= x2;
        p7 ^= x3;
        /* round 2, 6, 10 */
        rk00 ^= rk19;
        x0 = pC ^ rk00;
        rk01 ^= rk1A;
        x1 = pD ^ rk01;
        rk02 ^= rk1B;
        x2 = pE ^ rk02;
        rk03 ^= rk1C;
        x3 = pF ^ rk03;
        AES_ROUND_NOKEY(x0, x1, x2, x3);
        rk04 ^= rk1D;
        x0 ^= rk04;
        rk05 ^= rk1E;
        x1 ^= rk05;
        rk06 ^= rk1F;
        x2 ^= rk06;
        rk07 ^= rk00;
        x3 ^= rk07;
        AES_ROUND_NOKEY(x0, x1, x2, x3);
        rk08 ^= rk01;
        x0 ^= rk08;
        rk09 ^= rk02;
        x1 ^= rk09;
        rk0A ^= rk03;
        x2 ^= rk0A;
        rk0B ^= rk04;
        x3 ^= rk0B;
        AES_ROUND_NOKEY(x0, x1, x2, x3);
        rk0C ^= rk05;
        x0 ^= rk0C;
        rk0D ^= rk06;
        x1 ^= rk0D;
        rk0E ^= rk07;
        x2 ^= rk0E;
        rk0F ^= rk08;
        x3 ^= rk0F;
        AES_ROUND_NOKEY(x0, x1, x2, x3);
        p8 ^= x0;
        p9 ^= x1;
        pA ^= x2;
        pB ^= x3;
        rk10 ^= rk09;
        x0 = p4 ^ rk10;
        rk11 ^= rk0A;
        x1 = p5 ^ rk11;
        rk12 ^= rk0B;
        x2 = p6 ^ rk12;
        rk13 ^= rk0C;
        x3 = p7 ^ rk13;
        AES_ROUND_NOKEY(x0, x1, x2, x3);
        rk14 ^= rk0D;
        x0 ^= rk14;
        rk15 ^= rk0E;
        x1 ^= rk15;
        rk16 ^= rk0F;
        x2 ^= rk16;
        rk17 ^= rk10;
        x3 ^= rk17;
        AES_ROUND_NOKEY(x0, x1, x2, x3);
        rk18 ^= rk11;
        x0 ^= rk18;
        rk19 ^= rk12;
        x1 ^= rk19;
        rk1A ^= rk13;
        x2 ^= rk1A;
        rk1B ^= rk14;
        x3 ^= rk1B;
        AES_ROUND_NOKEY(x0, x1, x2, x3);
        rk1C ^= rk15;
        x0 ^= rk1C;
        rk1D ^= rk16;
        x1 ^= rk1D;
        rk1E ^= rk17;
        x2 ^= rk1E;
        rk1F ^= rk18;
        x3 ^= rk1F;
        AES_ROUND_NOKEY(x0, x1, x2, x3);
        p0 ^= x0;
        p1 ^= x1;
        p2 ^= x2;
        p3 ^= x3;
        /* round 3, 7, 11 */
        KEY_EXPAND_ELT(rk00, rk01, rk02, rk03);
        rk00 ^= rk1C;
        rk01 ^= rk1D;
        rk02 ^= rk1E;
        rk03 ^= rk1F;
        x0 = p8 ^ rk00;
        x1 = p9 ^ rk01;
        x2 = pA ^ rk02;
        x3 = pB ^ rk03;
        AES_ROUND_NOKEY(x0, x1, x2, x3);
        KEY_EXPAND_ELT(rk04, rk05, rk06, rk07);
        rk04 ^= rk00;
        rk05 ^= rk01;
        rk06 ^= rk02;
        rk07 ^= rk03;
        x0 ^= rk04;
        x1 ^= rk05;
        x2 ^= rk06;
        x3 ^= rk07;
        AES_ROUND_NOKEY(x0, x1, x2, x3);
        KEY_EXPAND_ELT(rk08, rk09, rk0A, rk0B);
        rk08 ^= rk04;
        rk09 ^= rk05;
        rk0A ^= rk06;
        rk0B ^= rk07;
        x0 ^= rk08;
        x1 ^= rk09;
        x2 ^= rk0A;
        x3 ^= rk0B;
        AES_ROUND_NOKEY(x0, x1, x2, x3);
        KEY_EXPAND_ELT(rk0C, rk0D, rk0E, rk0F);
        rk0C ^= rk08;
        rk0D ^= rk09;
        rk0E ^= rk0A;
        rk0F ^= rk0B;
        x0 ^= rk0C;
        x1 ^= rk0D;
        x2 ^= rk0E;
        x3 ^= rk0F;
        AES_ROUND_NOKEY(x0, x1, x2, x3);
        p4 ^= x0;
        p5 ^= x1;
        p6 ^= x2;
        p7 ^= x3;
        KEY_EXPAND_ELT(rk10, rk11, rk12, rk13);
        rk10 ^= rk0C;
        rk11 ^= rk0D;
        rk12 ^= rk0E;
        rk13 ^= rk0F;
        x0 = p0 ^ rk10;
        x1 = p1 ^ rk11;
        x2 = p2 ^ rk12;
        x3 = p3 ^ rk13;
        AES_ROUND_NOKEY(x0, x1, x2, x3);
        KEY_EXPAND_ELT(rk14, rk15, rk16, rk17);
        rk14 ^= rk10;
        rk15 ^= rk11;
        rk16 ^= rk12;
        rk17 ^= rk13;
        x0 ^= rk14;
        x1 ^= rk15;
        x2 ^= rk16;
        x3 ^= rk17;
        AES_ROUND_NOKEY(x0, x1, x2, x3);
        KEY_EXPAND_ELT(rk18, rk19, rk1A, rk1B);
        rk18 ^= rk14;
        rk19 ^= rk15;
        rk1A ^= rk16;
        rk1B ^= rk17;
        x0 ^= rk18;
        x1 ^= rk19;
        x2 ^= rk1A;
        x3 ^= rk1B;
        AES_ROUND_NOKEY(x0, x1, x2, x3);
        KEY_EXPAND_ELT(rk1C, rk1D, rk1E, rk1F);
        rk1C ^= rk18;
        rk1D ^= rk19;
        rk1E ^= rk1A;
        rk1F ^= rk1B;
        x0 ^= rk1C;
        x1 ^= rk1D;
        x2 ^= rk1E;
        x3 ^= rk1F;
        AES_ROUND_NOKEY(x0, x1, x2, x3);
        pC ^= x0;
        pD ^= x1;
        pE ^= x2;
        pF ^= x3;
        /* round 4, 8, 12 */
        rk00 ^= rk19;
        x0 = p4 ^ rk00;
        rk01 ^= rk1A;
        x1 = p5 ^ rk01;
        rk02 ^= rk1B;
        x2 = p6 ^ rk02;
        rk03 ^= rk1C;
        x3 = p7 ^ rk03;
        AES_ROUND_NOKEY(x0, x1, x2, x3);
        rk04 ^= rk1D;
        x0 ^= rk04;
        rk05 ^= rk1E;
        x1 ^= rk05;
        rk06 ^= rk1F;
        x2 ^= rk06;
        rk07 ^= rk00;
        x3 ^= rk07;
        AES_ROUND_NOKEY(x0, x1, x2, x3);
        rk08 ^= rk01;
        x0 ^= rk08;
        rk09 ^= rk02;
        x1 ^= rk09;
        rk0A ^= rk03;
        x2 ^= rk0A;
        rk0B ^= rk04;
        x3 ^= rk0B;
        AES_ROUND_NOKEY(x0, x1, x2, x3);
        rk0C ^= rk05;
        x0 ^= rk0C;
        rk0D ^= rk06;
        x1 ^= rk0D;
        rk0E ^= rk07;
        x2 ^= rk0E;
        rk0F ^= rk08;
        x3 ^= rk0F;
        AES_ROUND_NOKEY(x0, x1, x2, x3);
        p0 ^= x0;
        p1 ^= x1;
        p2 ^= x2;
        p3 ^= x3;
        rk10 ^= rk09;
        x0 = pC ^ rk10;
        rk11 ^= rk0A;
        x1 = pD ^ rk11;
        rk12 ^= rk0B;
        x2 = pE ^ rk12;
        rk13 ^= rk0C;
        x3 = pF ^ rk13;
        AES_ROUND_NOKEY(x0, x1, x2, x3);
        rk14 ^= rk0D;
        x0 ^= rk14;
        rk15 ^= rk0E;
        x1 ^= rk15;
        rk16 ^= rk0F;
        x2 ^= rk16;
        rk17 ^= rk10;
        x3 ^= rk17;
        AES_ROUND_NOKEY(x0, x1, x2, x3);
        rk18 ^= rk11;
        x0 ^= rk18;
        rk19 ^= rk12;
        x1 ^= rk19;
        rk1A ^= rk13;
        x2 ^= rk1A;
        rk1B ^= rk14;
        x3 ^= rk1B;
        AES_ROUND_NOKEY(x0, x1, x2, x3);
        rk1C ^= rk15;
        x0 ^= rk1C;
        rk1D ^= rk16;
        x1 ^= rk1D;
        rk1E ^= rk17;
        x2 ^= rk1E;
        rk1F ^= rk18;
        x3 ^= rk1F;
        AES_ROUND_NOKEY(x0, x1, x2, x3);
        p8 ^= x0;
        p9 ^= x1;
        pA ^= x2;
        pB ^= x3;
    }
    /* round 13 */
    KEY_EXPAND_ELT(rk00, rk01, rk02, rk03);
    rk00 ^= rk1C;
    rk01 ^= rk1D;
    rk02 ^= rk1E;
    rk03 ^= rk1F;
    x0 = p0 ^ rk00;
    x1 = p1 ^ rk01;
    x2 = p2 ^ rk02;
    x3 = p3 ^ rk03;
    AES_ROUND_NOKEY(x0, x1, x2, x3);
    KEY_EXPAND_ELT(rk04, rk05, rk06, rk07);
    rk04 ^= rk00;
    rk05 ^= rk01;
    rk06 ^= rk02;
    rk07 ^= rk03;
    x0 ^= rk04;
    x1 ^= rk05;
    x2 ^= rk06;
    x3 ^= rk07;
    AES_ROUND_NOKEY(x0, x1, x2, x3);
    KEY_EXPAND_ELT(rk08, rk09, rk0A, rk0B);
    rk08 ^= rk04;
    rk09 ^= rk05;
    rk0A ^= rk06;
    rk0B ^= rk07;
    x0 ^= rk08;
    x1 ^= rk09;
    x2 ^= rk0A;
    x3 ^= rk0B;
    AES_ROUND_NOKEY(x0, x1, x2, x3);
    KEY_EXPAND_ELT(rk0C, rk0D, rk0E, rk0F);
    rk0C ^= rk08;
    rk0D ^= rk09;
    rk0E ^= rk0A;
    rk0F ^= rk0B;
    x0 ^= rk0C;
    x1 ^= rk0D;
    x2 ^= rk0E;
    x3 ^= rk0F;
    AES_ROUND_NOKEY(x0, x1, x2, x3);
    pC ^= x0;
    pD ^= x1;
    pE ^= x2;
    pF ^= x3;
    KEY_EXPAND_ELT(rk10, rk11, rk12, rk13);
    rk10 ^= rk0C;
    rk11 ^= rk0D;
    rk12 ^= rk0E;
    rk13 ^= rk0F;
    x0 = p8 ^ rk10;
    x1 = p9 ^ rk11;
    x2 = pA ^ rk12;
    x3 = pB ^ rk13;
    AES_ROUND_NOKEY(x0, x1, x2, x3);
    KEY_EXPAND_ELT(rk14, rk15, rk16, rk17);
    rk14 ^= rk10;
    rk15 ^= rk11;
    rk16 ^= rk12;
    rk17 ^= rk13;
    x0 ^= rk14;
    x1 ^= rk15;
    x2 ^= rk16;
    x3 ^= rk17;
    AES_ROUND_NOKEY(x0, x1, x2, x3);
    KEY_EXPAND_ELT(rk18, rk19, rk1A, rk1B);
    rk18 ^= rk14 ^ sc->count1;
    rk19 ^= rk15 ^ sc->count0;
    rk1A ^= rk16 ^ sc->count3;
    rk1B ^= rk17 ^ SPH_T32(~sc->count2);
    x0 ^= rk18;
    x1 ^= rk19;
    x2 ^= rk1A;
    x3 ^= rk1B;
    AES_ROUND_NOKEY(x0, x1, x2, x3);
    KEY_EXPAND_ELT(rk1C, rk1D, rk1E, rk1F);
    rk1C ^= rk18;
    rk1D ^= rk19;
    rk1E ^= rk1A;
    rk1F ^= rk1B;
    x0 ^= rk1C;
    x1 ^= rk1D;
    x2 ^= rk1E;
    x3 ^= rk1F;
    AES_ROUND_NOKEY(x0, x1, x2, x3);
    p4 ^= x0;
    p5 ^= x1;
    p6 ^= x2;
    p7 ^= x3;
    sc->h[0x0] ^= p8;
    sc->h[0x1] ^= p9;
    sc->h[0x2] ^= pA;
    sc->h[0x3] ^= pB;
    sc->h[0x4] ^= pC;
    sc->h[0x5] ^= pD;
    sc->h[0x6] ^= pE;
    sc->h[0x7] ^= pF;
    sc->h[0x8] ^= p0;
    sc->h[0x9] ^= p1;
    sc->h[0xA] ^= p2;
    sc->h[0xB] ^= p3;
    sc->h[0xC] ^= p4;
    sc->h[0xD] ^= p5;
    sc->h[0xE] ^= p6;
    sc->h[0xF] ^= p7;
}

static void
shavite_big_init(sph_shavite_big_context *sc, const sph_u32 *iv)
{
    memcpy(sc->h, iv, sizeof sc->h);
    sc->ptr = 0;
    sc->count0 = 0;
    sc->count1 = 0;
    sc->count2 = 0;
    sc->count3 = 0;
}

static void
shavite_big_core(sph_shavite_big_context *sc, const void *data, size_t len)
{
    unsigned char *buf;
    size_t ptr;
    
    buf = sc->buf;
    ptr = sc->ptr;
    while (len > 0) {
        size_t clen;
        
        clen = (sizeof sc->buf) - ptr;
        if (clen > len)
            clen = len;
        memcpy(buf + ptr, data, clen);
        data = (const unsigned char *)data + clen;
        ptr += clen;
        len -= clen;
        if (ptr == sizeof sc->buf) {
            if ((sc->count0 = SPH_T32(sc->count0 + 1024)) == 0) {
                sc->count1 = SPH_T32(sc->count1 + 1);
                if (sc->count1 == 0) {
                    sc->count2 = SPH_T32(sc->count2 + 1);
                    if (sc->count2 == 0) {
                        sc->count3 = SPH_T32(
                                             sc->count3 + 1);
                    }
                }
            }
            c512(sc, buf);
            ptr = 0;
        }
    }
    sc->ptr = ptr;
}

static void
shavite_big_close(sph_shavite_big_context *sc,
                  unsigned ub, unsigned n, void *dst, size_t out_size_w32)
{
    unsigned char *buf;
    size_t ptr, u;
    unsigned z;
    sph_u32 count0, count1, count2, count3;
    
    buf = sc->buf;
    ptr = sc->ptr;
    count0 = (sc->count0 += (ptr << 3) + n);
    count1 = sc->count1;
    count2 = sc->count2;
    count3 = sc->count3;
    z = 0x80 >> n;
    z = ((ub & -z) | z) & 0xFF;
    if (ptr == 0 && n == 0) {
        buf[0] = 0x80;
        memset(buf + 1, 0, 109);
        sc->count0 = sc->count1 = sc->count2 = sc->count3 = 0;
    } else if (ptr < 110) {
        buf[ptr ++] = z;
        memset(buf + ptr, 0, 110 - ptr);
    } else {
        buf[ptr ++] = z;
        memset(buf + ptr, 0, 128 - ptr);
        c512(sc, buf);
        memset(buf, 0, 110);
        sc->count0 = sc->count1 = sc->count2 = sc->count3 = 0;
    }
    sph_enc32le(buf + 110, count0);
    sph_enc32le(buf + 114, count1);
    sph_enc32le(buf + 118, count2);
    sph_enc32le(buf + 122, count3);
    buf[126] = out_size_w32 << 5;
    buf[127] = out_size_w32 >> 3;
    c512(sc, buf);
    for (u = 0; u < out_size_w32; u ++)
        sph_enc32le((unsigned char *)dst + (u << 2), sc->h[u]);
}

/* see sph_shavite.h */
void
sph_shavite512_init(void *cc)
{
    shavite_big_init(cc, IV512);
}

/* see sph_shavite.h */
void
sph_shavite512(void *cc, const void *data, size_t len)
{
    shavite_big_core(cc, data, len);
}

/* see sph_shavite.h */
void
sph_shavite512_close(void *cc, void *dst)
{
    shavite_big_close(cc, 0, 0, dst, 16);
    shavite_big_init(cc, IV512);
}

/* see sph_shavite.h */
void
sph_shavite512_addbits_and_close(void *cc, unsigned ub, unsigned n, void *dst)
{
    shavite_big_close(cc, ub, n, dst, 16);
    shavite_big_init(cc, IV512);
}


-(NSData*)shavite512 {
    sph_shavite_big_context ctx_shavite;
    sph_shavite512_init(&ctx_shavite);
    sph_shavite512(&ctx_shavite, self.bytes, self.length);
    void * dest = malloc(64*sizeof(Byte));
    sph_shavite512_close(&ctx_shavite, dest);
    return [NSData dataWithBytes:dest length:64];
}

@end
