//
//  NSData+Jh.m
/* $Id: jh.c 255 2011-06-07 19:50:20Z tp $ */
/*
 * JH implementation.
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

#import "NSData+Jh.h"
#import "sph_types.h"

@implementation NSData(Jh)

typedef struct {
#ifndef DOXYGEN_IGNORE
    unsigned char buf[64];    /* first field, for alignment */
    size_t ptr;
    union {

        sph_u32 narrow[32];
    } H;

    sph_u32 block_count_high, block_count_low;
#endif
} sph_jh_context;

#ifdef _MSC_VER
#pragma warning (disable: 4146)
#endif

/*
 * The internal bitslice representation may use either big-endian or
 * little-endian (true bitslice operations do not care about the bit
 * ordering, and the bit-swapping linear operations in JH happen to
 * be invariant through endianness-swapping). The constants must be
 * defined according to the chosen endianness; we use some
 * byte-swapping macros for that.
 */

#if SPH_LITTLE_ENDIAN

#define C32e(x)     ((SPH_C32(x) >> 24) \
| ((SPH_C32(x) >>  8) & SPH_C32(0x0000FF00)) \
| ((SPH_C32(x) <<  8) & SPH_C32(0x00FF0000)) \
| ((SPH_C32(x) << 24) & SPH_C32(0xFF000000)))
#define dec32e_aligned   sph_dec32le_aligned
#define enc32e           sph_enc32le

#else

#define C32e(x)     SPH_C32(x)
#define dec32e_aligned   sph_dec32be_aligned
#define enc32e           sph_enc32be
#if SPH_64
#define C64e(x)     SPH_C64(x)
#define dec64e_aligned   sph_dec64be_aligned
#define enc64e           sph_enc64be
#endif

#endif

#define Sb(x0, x1, x2, x3, c)   do { \
x3 = ~x3; \
x0 ^= (c) & ~x2; \
tmp = (c) ^ (x0 & x1); \
x0 ^= x2 & x3; \
x3 ^= ~x1 & x2; \
x1 ^= x0 & x2; \
x2 ^= x0 & ~x3; \
x0 ^= x1 | x3; \
x3 ^= x1 & x2; \
x1 ^= tmp & x0; \
x2 ^= tmp; \
} while (0)

#define Lb(x0, x1, x2, x3, x4, x5, x6, x7)   do { \
x4 ^= x1; \
x5 ^= x2; \
x6 ^= x3 ^ x0; \
x7 ^= x0; \
x0 ^= x5; \
x1 ^= x6; \
x2 ^= x7 ^ x4; \
x3 ^= x4; \
} while (0)

static const sph_u32 C[] = {
    C32e(0x72d5dea2), C32e(0xdf15f867), C32e(0x7b84150a),
    C32e(0xb7231557), C32e(0x81abd690), C32e(0x4d5a87f6),
    C32e(0x4e9f4fc5), C32e(0xc3d12b40), C32e(0xea983ae0),
    C32e(0x5c45fa9c), C32e(0x03c5d299), C32e(0x66b2999a),
    C32e(0x660296b4), C32e(0xf2bb538a), C32e(0xb556141a),
    C32e(0x88dba231), C32e(0x03a35a5c), C32e(0x9a190edb),
    C32e(0x403fb20a), C32e(0x87c14410), C32e(0x1c051980),
    C32e(0x849e951d), C32e(0x6f33ebad), C32e(0x5ee7cddc),
    C32e(0x10ba1392), C32e(0x02bf6b41), C32e(0xdc786515),
    C32e(0xf7bb27d0), C32e(0x0a2c8139), C32e(0x37aa7850),
    C32e(0x3f1abfd2), C32e(0x410091d3), C32e(0x422d5a0d),
    C32e(0xf6cc7e90), C32e(0xdd629f9c), C32e(0x92c097ce),
    C32e(0x185ca70b), C32e(0xc72b44ac), C32e(0xd1df65d6),
    C32e(0x63c6fc23), C32e(0x976e6c03), C32e(0x9ee0b81a),
    C32e(0x2105457e), C32e(0x446ceca8), C32e(0xeef103bb),
    C32e(0x5d8e61fa), C32e(0xfd9697b2), C32e(0x94838197),
    C32e(0x4a8e8537), C32e(0xdb03302f), C32e(0x2a678d2d),
    C32e(0xfb9f6a95), C32e(0x8afe7381), C32e(0xf8b8696c),
    C32e(0x8ac77246), C32e(0xc07f4214), C32e(0xc5f4158f),
    C32e(0xbdc75ec4), C32e(0x75446fa7), C32e(0x8f11bb80),
    C32e(0x52de75b7), C32e(0xaee488bc), C32e(0x82b8001e),
    C32e(0x98a6a3f4), C32e(0x8ef48f33), C32e(0xa9a36315),
    C32e(0xaa5f5624), C32e(0xd5b7f989), C32e(0xb6f1ed20),
    C32e(0x7c5ae0fd), C32e(0x36cae95a), C32e(0x06422c36),
    C32e(0xce293543), C32e(0x4efe983d), C32e(0x533af974),
    C32e(0x739a4ba7), C32e(0xd0f51f59), C32e(0x6f4e8186),
    C32e(0x0e9dad81), C32e(0xafd85a9f), C32e(0xa7050667),
    C32e(0xee34626a), C32e(0x8b0b28be), C32e(0x6eb91727),
    C32e(0x47740726), C32e(0xc680103f), C32e(0xe0a07e6f),
    C32e(0xc67e487b), C32e(0x0d550aa5), C32e(0x4af8a4c0),
    C32e(0x91e3e79f), C32e(0x978ef19e), C32e(0x86767281),
    C32e(0x50608dd4), C32e(0x7e9e5a41), C32e(0xf3e5b062),
    C32e(0xfc9f1fec), C32e(0x4054207a), C32e(0xe3e41a00),
    C32e(0xcef4c984), C32e(0x4fd794f5), C32e(0x9dfa95d8),
    C32e(0x552e7e11), C32e(0x24c354a5), C32e(0x5bdf7228),
    C32e(0xbdfe6e28), C32e(0x78f57fe2), C32e(0x0fa5c4b2),
    C32e(0x05897cef), C32e(0xee49d32e), C32e(0x447e9385),
    C32e(0xeb28597f), C32e(0x705f6937), C32e(0xb324314a),
    C32e(0x5e8628f1), C32e(0x1dd6e465), C32e(0xc71b7704),
    C32e(0x51b920e7), C32e(0x74fe43e8), C32e(0x23d4878a),
    C32e(0x7d29e8a3), C32e(0x927694f2), C32e(0xddcb7a09),
    C32e(0x9b30d9c1), C32e(0x1d1b30fb), C32e(0x5bdc1be0),
    C32e(0xda24494f), C32e(0xf29c82bf), C32e(0xa4e7ba31),
    C32e(0xb470bfff), C32e(0x0d324405), C32e(0xdef8bc48),
    C32e(0x3baefc32), C32e(0x53bbd339), C32e(0x459fc3c1),
    C32e(0xe0298ba0), C32e(0xe5c905fd), C32e(0xf7ae090f),
    C32e(0x94703412), C32e(0x4290f134), C32e(0xa271b701),
    C32e(0xe344ed95), C32e(0xe93b8e36), C32e(0x4f2f984a),
    C32e(0x88401d63), C32e(0xa06cf615), C32e(0x47c1444b),
    C32e(0x8752afff), C32e(0x7ebb4af1), C32e(0xe20ac630),
    C32e(0x4670b6c5), C32e(0xcc6e8ce6), C32e(0xa4d5a456),
    C32e(0xbd4fca00), C32e(0xda9d844b), C32e(0xc83e18ae),
    C32e(0x7357ce45), C32e(0x3064d1ad), C32e(0xe8a6ce68),
    C32e(0x145c2567), C32e(0xa3da8cf2), C32e(0xcb0ee116),
    C32e(0x33e90658), C32e(0x9a94999a), C32e(0x1f60b220),
    C32e(0xc26f847b), C32e(0xd1ceac7f), C32e(0xa0d18518),
    C32e(0x32595ba1), C32e(0x8ddd19d3), C32e(0x509a1cc0),
    C32e(0xaaa5b446), C32e(0x9f3d6367), C32e(0xe4046bba),
    C32e(0xf6ca19ab), C32e(0x0b56ee7e), C32e(0x1fb179ea),
    C32e(0xa9282174), C32e(0xe9bdf735), C32e(0x3b3651ee),
    C32e(0x1d57ac5a), C32e(0x7550d376), C32e(0x3a46c2fe),
    C32e(0xa37d7001), C32e(0xf735c1af), C32e(0x98a4d842),
    C32e(0x78edec20), C32e(0x9e6b6779), C32e(0x41836315),
    C32e(0xea3adba8), C32e(0xfac33b4d), C32e(0x32832c83),
    C32e(0xa7403b1f), C32e(0x1c2747f3), C32e(0x5940f034),
    C32e(0xb72d769a), C32e(0xe73e4e6c), C32e(0xd2214ffd),
    C32e(0xb8fd8d39), C32e(0xdc5759ef), C32e(0x8d9b0c49),
    C32e(0x2b49ebda), C32e(0x5ba2d749), C32e(0x68f3700d),
    C32e(0x7d3baed0), C32e(0x7a8d5584), C32e(0xf5a5e9f0),
    C32e(0xe4f88e65), C32e(0xa0b8a2f4), C32e(0x36103b53),
    C32e(0x0ca8079e), C32e(0x753eec5a), C32e(0x91689492),
    C32e(0x56e8884f), C32e(0x5bb05c55), C32e(0xf8babc4c),
    C32e(0xe3bb3b99), C32e(0xf387947b), C32e(0x75daf4d6),
    C32e(0x726b1c5d), C32e(0x64aeac28), C32e(0xdc34b36d),
    C32e(0x6c34a550), C32e(0xb828db71), C32e(0xf861e2f2),
    C32e(0x108d512a), C32e(0xe3db6433), C32e(0x59dd75fc),
    C32e(0x1cacbcf1), C32e(0x43ce3fa2), C32e(0x67bbd13c),
    C32e(0x02e843b0), C32e(0x330a5bca), C32e(0x8829a175),
    C32e(0x7f34194d), C32e(0xb416535c), C32e(0x923b94c3),
    C32e(0x0e794d1e), C32e(0x797475d7), C32e(0xb6eeaf3f),
    C32e(0xeaa8d4f7), C32e(0xbe1a3921), C32e(0x5cf47e09),
    C32e(0x4c232751), C32e(0x26a32453), C32e(0xba323cd2),
    C32e(0x44a3174a), C32e(0x6da6d5ad), C32e(0xb51d3ea6),
    C32e(0xaff2c908), C32e(0x83593d98), C32e(0x916b3c56),
    C32e(0x4cf87ca1), C32e(0x7286604d), C32e(0x46e23ecc),
    C32e(0x086ec7f6), C32e(0x2f9833b3), C32e(0xb1bc765e),
    C32e(0x2bd666a5), C32e(0xefc4e62a), C32e(0x06f4b6e8),
    C32e(0xbec1d436), C32e(0x74ee8215), C32e(0xbcef2163),
    C32e(0xfdc14e0d), C32e(0xf453c969), C32e(0xa77d5ac4),
    C32e(0x06585826), C32e(0x7ec11416), C32e(0x06e0fa16),
    C32e(0x7e90af3d), C32e(0x28639d3f), C32e(0xd2c9f2e3),
    C32e(0x009bd20c), C32e(0x5faace30), C32e(0xb7d40c30),
    C32e(0x742a5116), C32e(0xf2e03298), C32e(0x0deb30d8),
    C32e(0xe3cef89a), C32e(0x4bc59e7b), C32e(0xb5f17992),
    C32e(0xff51e66e), C32e(0x048668d3), C32e(0x9b234d57),
    C32e(0xe6966731), C32e(0xcce6a6f3), C32e(0x170a7505),
    C32e(0xb17681d9), C32e(0x13326cce), C32e(0x3c175284),
    C32e(0xf805a262), C32e(0xf42bcbb3), C32e(0x78471547),
    C32e(0xff465482), C32e(0x23936a48), C32e(0x38df5807),
    C32e(0x4e5e6565), C32e(0xf2fc7c89), C32e(0xfc86508e),
    C32e(0x31702e44), C32e(0xd00bca86), C32e(0xf04009a2),
    C32e(0x3078474e), C32e(0x65a0ee39), C32e(0xd1f73883),
    C32e(0xf75ee937), C32e(0xe42c3abd), C32e(0x2197b226),
    C32e(0x0113f86f), C32e(0xa344edd1), C32e(0xef9fdee7),
    C32e(0x8ba0df15), C32e(0x762592d9), C32e(0x3c85f7f6),
    C32e(0x12dc42be), C32e(0xd8a7ec7c), C32e(0xab27b07e),
    C32e(0x538d7dda), C32e(0xaa3ea8de), C32e(0xaa25ce93),
    C32e(0xbd0269d8), C32e(0x5af643fd), C32e(0x1a7308f9),
    C32e(0xc05fefda), C32e(0x174a19a5), C32e(0x974d6633),
    C32e(0x4cfd216a), C32e(0x35b49831), C32e(0xdb411570),
    C32e(0xea1e0fbb), C32e(0xedcd549b), C32e(0x9ad063a1),
    C32e(0x51974072), C32e(0xf6759dbf), C32e(0x91476fe2)
};

#define Ceven_w3(r)   (C[((r) << 3) + 0])
#define Ceven_w2(r)   (C[((r) << 3) + 1])
#define Ceven_w1(r)   (C[((r) << 3) + 2])
#define Ceven_w0(r)   (C[((r) << 3) + 3])
#define Codd_w3(r)    (C[((r) << 3) + 4])
#define Codd_w2(r)    (C[((r) << 3) + 5])
#define Codd_w1(r)    (C[((r) << 3) + 6])
#define Codd_w0(r)    (C[((r) << 3) + 7])

#define S(x0, x1, x2, x3, cb, r)   do { \
Sb(x0 ## 3, x1 ## 3, x2 ## 3, x3 ## 3, cb ## w3(r)); \
Sb(x0 ## 2, x1 ## 2, x2 ## 2, x3 ## 2, cb ## w2(r)); \
Sb(x0 ## 1, x1 ## 1, x2 ## 1, x3 ## 1, cb ## w1(r)); \
Sb(x0 ## 0, x1 ## 0, x2 ## 0, x3 ## 0, cb ## w0(r)); \
} while (0)

#define L(x0, x1, x2, x3, x4, x5, x6, x7)   do { \
Lb(x0 ## 3, x1 ## 3, x2 ## 3, x3 ## 3, \
x4 ## 3, x5 ## 3, x6 ## 3, x7 ## 3); \
Lb(x0 ## 2, x1 ## 2, x2 ## 2, x3 ## 2, \
x4 ## 2, x5 ## 2, x6 ## 2, x7 ## 2); \
Lb(x0 ## 1, x1 ## 1, x2 ## 1, x3 ## 1, \
x4 ## 1, x5 ## 1, x6 ## 1, x7 ## 1); \
Lb(x0 ## 0, x1 ## 0, x2 ## 0, x3 ## 0, \
x4 ## 0, x5 ## 0, x6 ## 0, x7 ## 0); \
} while (0)

#define Wz(x, c, n)   do { \
sph_u32 t = (x ## 3 & (c)) << (n); \
x ## 3 = ((x ## 3 >> (n)) & (c)) | t; \
t = (x ## 2 & (c)) << (n); \
x ## 2 = ((x ## 2 >> (n)) & (c)) | t; \
t = (x ## 1 & (c)) << (n); \
x ## 1 = ((x ## 1 >> (n)) & (c)) | t; \
t = (x ## 0 & (c)) << (n); \
x ## 0 = ((x ## 0 >> (n)) & (c)) | t; \
} while (0)

#define W0(x)   Wz(x, SPH_C32(0x55555555),  1)
#define W1(x)   Wz(x, SPH_C32(0x33333333),  2)
#define W2(x)   Wz(x, SPH_C32(0x0F0F0F0F),  4)
#define W3(x)   Wz(x, SPH_C32(0x00FF00FF),  8)
#define W4(x)   Wz(x, SPH_C32(0x0000FFFF), 16)
#define W5(x)   do { \
sph_u32 t = x ## 3; \
x ## 3 = x ## 2; \
x ## 2 = t; \
t = x ## 1; \
x ## 1 = x ## 0; \
x ## 0 = t; \
} while (0)
#define W6(x)   do { \
sph_u32 t = x ## 3; \
x ## 3 = x ## 1; \
x ## 1 = t; \
t = x ## 2; \
x ## 2 = x ## 0; \
x ## 0 = t; \
} while (0)

#define DECL_STATE \
sph_u32 h03, h02, h01, h00, h13, h12, h11, h10; \
sph_u32 h23, h22, h21, h20, h33, h32, h31, h30; \
sph_u32 h43, h42, h41, h40, h53, h52, h51, h50; \
sph_u32 h63, h62, h61, h60, h73, h72, h71, h70; \
sph_u32 tmp;

#define READ_STATE(state)   do { \
h03 = (state)->H.narrow[ 0]; \
h02 = (state)->H.narrow[ 1]; \
h01 = (state)->H.narrow[ 2]; \
h00 = (state)->H.narrow[ 3]; \
h13 = (state)->H.narrow[ 4]; \
h12 = (state)->H.narrow[ 5]; \
h11 = (state)->H.narrow[ 6]; \
h10 = (state)->H.narrow[ 7]; \
h23 = (state)->H.narrow[ 8]; \
h22 = (state)->H.narrow[ 9]; \
h21 = (state)->H.narrow[10]; \
h20 = (state)->H.narrow[11]; \
h33 = (state)->H.narrow[12]; \
h32 = (state)->H.narrow[13]; \
h31 = (state)->H.narrow[14]; \
h30 = (state)->H.narrow[15]; \
h43 = (state)->H.narrow[16]; \
h42 = (state)->H.narrow[17]; \
h41 = (state)->H.narrow[18]; \
h40 = (state)->H.narrow[19]; \
h53 = (state)->H.narrow[20]; \
h52 = (state)->H.narrow[21]; \
h51 = (state)->H.narrow[22]; \
h50 = (state)->H.narrow[23]; \
h63 = (state)->H.narrow[24]; \
h62 = (state)->H.narrow[25]; \
h61 = (state)->H.narrow[26]; \
h60 = (state)->H.narrow[27]; \
h73 = (state)->H.narrow[28]; \
h72 = (state)->H.narrow[29]; \
h71 = (state)->H.narrow[30]; \
h70 = (state)->H.narrow[31]; \
} while (0)

#define WRITE_STATE(state)   do { \
(state)->H.narrow[ 0] = h03; \
(state)->H.narrow[ 1] = h02; \
(state)->H.narrow[ 2] = h01; \
(state)->H.narrow[ 3] = h00; \
(state)->H.narrow[ 4] = h13; \
(state)->H.narrow[ 5] = h12; \
(state)->H.narrow[ 6] = h11; \
(state)->H.narrow[ 7] = h10; \
(state)->H.narrow[ 8] = h23; \
(state)->H.narrow[ 9] = h22; \
(state)->H.narrow[10] = h21; \
(state)->H.narrow[11] = h20; \
(state)->H.narrow[12] = h33; \
(state)->H.narrow[13] = h32; \
(state)->H.narrow[14] = h31; \
(state)->H.narrow[15] = h30; \
(state)->H.narrow[16] = h43; \
(state)->H.narrow[17] = h42; \
(state)->H.narrow[18] = h41; \
(state)->H.narrow[19] = h40; \
(state)->H.narrow[20] = h53; \
(state)->H.narrow[21] = h52; \
(state)->H.narrow[22] = h51; \
(state)->H.narrow[23] = h50; \
(state)->H.narrow[24] = h63; \
(state)->H.narrow[25] = h62; \
(state)->H.narrow[26] = h61; \
(state)->H.narrow[27] = h60; \
(state)->H.narrow[28] = h73; \
(state)->H.narrow[29] = h72; \
(state)->H.narrow[30] = h71; \
(state)->H.narrow[31] = h70; \
} while (0)

#define INPUT_BUF1 \
sph_u32 m03 = dec32e_aligned(buf +  0); \
sph_u32 m02 = dec32e_aligned(buf +  4); \
sph_u32 m01 = dec32e_aligned(buf +  8); \
sph_u32 m00 = dec32e_aligned(buf + 12); \
sph_u32 m13 = dec32e_aligned(buf + 16); \
sph_u32 m12 = dec32e_aligned(buf + 20); \
sph_u32 m11 = dec32e_aligned(buf + 24); \
sph_u32 m10 = dec32e_aligned(buf + 28); \
sph_u32 m23 = dec32e_aligned(buf + 32); \
sph_u32 m22 = dec32e_aligned(buf + 36); \
sph_u32 m21 = dec32e_aligned(buf + 40); \
sph_u32 m20 = dec32e_aligned(buf + 44); \
sph_u32 m33 = dec32e_aligned(buf + 48); \
sph_u32 m32 = dec32e_aligned(buf + 52); \
sph_u32 m31 = dec32e_aligned(buf + 56); \
sph_u32 m30 = dec32e_aligned(buf + 60); \
h03 ^= m03; \
h02 ^= m02; \
h01 ^= m01; \
h00 ^= m00; \
h13 ^= m13; \
h12 ^= m12; \
h11 ^= m11; \
h10 ^= m10; \
h23 ^= m23; \
h22 ^= m22; \
h21 ^= m21; \
h20 ^= m20; \
h33 ^= m33; \
h32 ^= m32; \
h31 ^= m31; \
h30 ^= m30;

#define INPUT_BUF2 \
h43 ^= m03; \
h42 ^= m02; \
h41 ^= m01; \
h40 ^= m00; \
h53 ^= m13; \
h52 ^= m12; \
h51 ^= m11; \
h50 ^= m10; \
h63 ^= m23; \
h62 ^= m22; \
h61 ^= m21; \
h60 ^= m20; \
h73 ^= m33; \
h72 ^= m32; \
h71 ^= m31; \
h70 ^= m30;

static const sph_u32 IV512[] = {
    C32e(0x6fd14b96), C32e(0x3e00aa17), C32e(0x636a2e05), C32e(0x7a15d543),
    C32e(0x8a225e8d), C32e(0x0c97ef0b), C32e(0xe9341259), C32e(0xf2b3c361),
    C32e(0x891da0c1), C32e(0x536f801e), C32e(0x2aa9056b), C32e(0xea2b6d80),
    C32e(0x588eccdb), C32e(0x2075baa6), C32e(0xa90f3a76), C32e(0xbaf83bf7),
    C32e(0x0169e605), C32e(0x41e34a69), C32e(0x46b58a8e), C32e(0x2e6fe65a),
    C32e(0x1047a7d0), C32e(0xc1843c24), C32e(0x3b6e71b1), C32e(0x2d5ac199),
    C32e(0xcf57f6ec), C32e(0x9db1f856), C32e(0xa706887c), C32e(0x5716b156),
    C32e(0xe3c2fcdf), C32e(0xe68517fb), C32e(0x545a4678), C32e(0xcc8cdd4b)
};

#define SL(ro)   SLu(r + ro, ro)

#define SLu(r, ro)   do { \
S(h0, h2, h4, h6, Ceven_, r); \
S(h1, h3, h5, h7, Codd_, r); \
L(h0, h2, h4, h6, h1, h3, h5, h7); \
W ## ro(h1); \
W ## ro(h3); \
W ## ro(h5); \
W ## ro(h7); \
} while (0)

/*
 * We are not aiming at a small footprint, but we are still using a
 * 32-bit implementation. Full loop unrolling would smash the L1
 * cache on some "big" architectures (32 kB L1 cache).
 */

#define E8   do { \
unsigned r; \
for (r = 0; r < 42; r += 7) { \
SL(0); \
SL(1); \
SL(2); \
SL(3); \
SL(4); \
SL(5); \
SL(6); \
} \
} while (0)

static void
jh_init(sph_jh_context *sc, const void *iv)
{
    sc->ptr = 0;

    memcpy(sc->H.narrow, iv, sizeof sc->H.narrow);

    sc->block_count_high = 0;
    sc->block_count_low = 0;
}

static void
jh_core(sph_jh_context *sc, const void *data, size_t len)
{
    unsigned char *buf;
    size_t ptr;
    DECL_STATE
    
    buf = sc->buf;
    ptr = sc->ptr;
    if (len < (sizeof sc->buf) - ptr) {
        memcpy(buf + ptr, data, len);
        ptr += len;
        sc->ptr = ptr;
        return;
    }
    
    READ_STATE(sc);
    while (len > 0) {
        size_t clen;
        
        clen = (sizeof sc->buf) - ptr;
        if (clen > len)
            clen = len;
        memcpy(buf + ptr, data, clen);
        ptr += clen;
        data = (const unsigned char *)data + clen;
        len -= clen;
        if (ptr == sizeof sc->buf) {
            INPUT_BUF1;
            unsigned r;
            for (r = 0; r < 42; r += 7) {
//                sph_u32 ccc = Ceven_w3(r);
//                h63 = ~h63;
//                h03 ^= (ccc) & ~h43;
//                tmp = (ccc) ^ (h03 & h23);
//                h03 ^= h43 & h63;
//                h63 ^= ~h23 & h43;
//                h23 ^= h03 & h43;
//                h43 ^= h03 & ~h63;
//                h03 ^= h23 | h63;
//                h63 ^= h23 & h43;
//                h23 ^= tmp & h03;
//                h43 ^= tmp;
                
                Sb(h03, h23, h43, h63, Ceven_w3(r));
                Sb(h02, h22, h42, h62, Ceven_w2(r));
                Sb(h01, h21, h41, h61, Ceven_w1(r));
                Sb(h00, h20, h40, h60, Ceven_w0(r));
                S(h1, h3, h5, h7, Codd_, r);
                L(h0, h2, h4, h6, h1, h3, h5, h7);
                W0(h1);
                W0(h3);
                W0(h5);
                W0(h7);
                SL(1);
                SL(2);
                SL(3);
                SL(4);
                SL(5);
                SL(6);
            }
            INPUT_BUF2;

            if ((sc->block_count_low = SPH_T32(
                                               sc->block_count_low + 1)) == 0)
                sc->block_count_high ++;
            ptr = 0;
        }
    }
    WRITE_STATE(sc);
    sc->ptr = ptr;
}

static void
jh_close(sph_jh_context *sc, unsigned ub, unsigned n,
         void *dst, size_t out_size_w32, const void *iv)
{
    unsigned z;
    unsigned char buf[128];
    bzero(buf, 128);
    size_t numz, u;
    sph_u32 l0, l1, l2, l3;
    z = 0x80 >> n;
    buf[0] = ((ub & -z) | z) & 0xFF;
    if (sc->ptr == 0 && n == 0) {
        numz = 47;
    } else {
        numz = 111 - sc->ptr;
    }
    memset(buf + 1, 0, numz);
    l0 = SPH_T32(sc->block_count_low << 9) + (sc->ptr << 3) + n;
    l1 = SPH_T32(sc->block_count_low >> 23)
    + SPH_T32(sc->block_count_high << 9);
    l2 = SPH_T32(sc->block_count_high >> 23);
    l3 = 0;
    sph_enc32be(buf + numz +  1, l3);
    sph_enc32be(buf + numz +  5, l2);
    sph_enc32be(buf + numz +  9, l1);
    sph_enc32be(buf + numz + 13, l0);
    jh_core(sc, buf, numz + 17);
    for (u = 0; u < 16; u ++)
        enc32e(buf + (u << 2), sc->H.narrow[u + 16]);
    memcpy(dst, buf + ((16 - out_size_w32) << 2), out_size_w32 << 2);
    jh_init(sc, iv);
}

/* see sph_jh.h */
void
sph_jh512_init(void *cc)
{
    jh_init(cc, IV512);
}

/* see sph_jh.h */
void
sph_jh512(void *cc, const void *data, size_t len)
{
    jh_core(cc, data, len);
}

/* see sph_jh.h */
void
sph_jh512_close(void *cc, void *dst)
{
    jh_close(cc, 0, 0, dst, 16, IV512);
}

/* see sph_jh.h */
void
sph_jh512_addbits_and_close(void *cc, unsigned ub, unsigned n, void *dst)
{
    jh_close(cc, ub, n, dst, 16, IV512);
}

-(NSData*)jh512 {
    sph_jh_context ctx_jh;
    sph_jh512_init(&ctx_jh);
    sph_jh512(&ctx_jh, self.bytes, self.length);
    void * dest = malloc(64*sizeof(Byte));
    sph_jh512_close(&ctx_jh, dest);
    return [NSData dataWithBytes:dest length:64];
}


@end
