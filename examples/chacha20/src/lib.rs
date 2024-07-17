use core::array::from_fn;
use hax_secret_integers::*;

type State = [U32; 16];  
type Block = [U8; 64];
type ChaChaIV = [U8; 12];
type ChaChaKey = [U8; 32];

#[hax_lib::requires(a < 16 && b < 16 && d < 16)]
fn chacha20_line(a: usize, b: usize, d: usize, s: u32, m: State) -> State {
    let mut state = m;
    state[a] = state[a].wrapping_add(state[b]);
    state[d] = state[d] ^ state[a];
    state[d] = state[d].rotate_left(s);
    state
}

#[hax_lib::requires(a < 16 && b < 16 && c < 16 && d < 16)]
pub fn chacha20_quarter_round(a: usize, b: usize, c: usize, d: usize, state: State) -> State {
    let state = chacha20_line(a, b, d, 16, state);
    let state = chacha20_line(c, d, b, 12, state);
    let state = chacha20_line(a, b, d, 8, state);
    chacha20_line(c, d, b, 7, state)
}

fn chacha20_double_round(state: State) -> State {
    let state = chacha20_quarter_round(
        0,
        4,
        8,
        12,
        state,
    );
    let state = chacha20_quarter_round(
        1,
        5,
        9,
        13,
        state,
    );
    let state = chacha20_quarter_round(
        2,
        6,
        10,
        14,
        state,
    );
    let state = chacha20_quarter_round(
        3,
        7,
        11,
        15,
        state,
    );

    let state = chacha20_quarter_round(
        0,
        5,
        10,
        15,
        state,
    );
    let state = chacha20_quarter_round(
        1,
        6,
        11,
        12,
        state,
    );
    let state = chacha20_quarter_round(
        2,
        7,
        8,
        13,
        state,
    );
    chacha20_quarter_round(
        3,
        4,
        9,
        14,
        state,
    )
}

pub fn chacha20_rounds(state: State) -> State {
    let mut st = state;
    for _i in 0..10 {
        st = chacha20_double_round(st);
    }
    st
}

pub fn chacha20_core(ctr: u32, st0: State) -> State {
    let mut state = st0;
    state[12] = state[12].wrapping_add(ctr);
    let k = chacha20_rounds(state);
    from_fn(|i| state[i] + k[i])
}

pub fn chacha20_init(key: &ChaChaKey, iv: &ChaChaIV, ctr: u32) -> State {
    let key_u32: [U32; 8] = <[U32;8]>::try_from_le_bytes(key).unwrap(); 
    let iv_u32: [U32; 3] = <[U32;3]>::try_from_le_bytes(iv).unwrap(); 
    [
        0x6170_7865.classify(),
        0x3320_646e.classify(),
        0x7962_2d32.classify(),
        0x6b20_6574.classify(),
        key_u32[0],
        key_u32[1],
        key_u32[2],
        key_u32[3],
        key_u32[4],
        key_u32[5],
        key_u32[6],
        key_u32[7],
        ctr.classify(),
        iv_u32[0],
        iv_u32[1],
        iv_u32[2],
    ]
}

pub fn chacha20_key_block(state: State) -> Block {
    let state = chacha20_core(0u32, state);
    state.try_to_le_bytes().unwrap()
}

pub fn chacha20_key_block0(key: &ChaChaKey, iv: &ChaChaIV) -> Block {
    let state = chacha20_init(key, iv, 0u32);
    chacha20_key_block(state)
}

pub fn chacha20_encrypt_block(st0: State, ctr: u32, plain: &Block) -> Block {
    let st = chacha20_core(ctr, st0);
    let pl: State = State::try_from_le_bytes(plain).unwrap();
    let encrypted : State = from_fn(|i| st[i] ^ pl[i]);
    encrypted.try_to_le_bytes().unwrap() 
}

#[hax_lib::requires(plain.len() <= 64)]
pub fn chacha20_encrypt_last(st0: State, ctr: u32, plain: &[U8]) -> Vec<U8> {
    let mut b: Block = [0.classify(); 64];
    b.copy_from_slice(plain);
    b = chacha20_encrypt_block(st0, ctr, &b);
    b[0..plain.len()].to_vec()
}

pub fn chacha20_update(st0: State, m: &[U8]) -> Vec<U8> {
    let mut blocks_out = Vec::new();
    let num_blocks = m.len() / 64;
    let remainder_len = m.len() % 64;
    for i in 0..num_blocks {
        // Full block
        let b =
            chacha20_encrypt_block(st0, i as u32, &m[64 * i..(64 * i + 64)].try_into().unwrap());
        hax_lib::assume!(blocks_out.len() == i * 64);
        blocks_out.extend_from_slice(&b);
    }
    hax_lib::assume!(blocks_out.len() == num_blocks * 64);
    if remainder_len != 0 {
        // Last block 
        let b = chacha20_encrypt_last(st0, num_blocks as u32, &m[64 * num_blocks..m.len()]);
        blocks_out.extend_from_slice(&b);
    }
    blocks_out 
}

pub fn chacha20(m: &[U8], key: &ChaChaKey, iv: &ChaChaIV, ctr: u32) -> Vec<U8> {
    let state = chacha20_init(key, iv, ctr);
    chacha20_update(state, m) 
}
