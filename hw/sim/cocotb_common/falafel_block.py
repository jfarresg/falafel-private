# SPDX-FileCopyrightText: © 2025 Joan Farres Garcia
#
# SPDX-License-Identifier: BSD-3-Clause


from dataclasses import dataclass
from falafel_pkg import WORD_SIZE


@dataclass
class Block:
    """Represents a block"""
    base_addr: int
    size: int


def print_list(blocks):
    if len(blocks) == 0:
        return

    for block in blocks:
        print((block.base_addr, block.size), '-->', end=' ')

    print('NULL_PTR')


def list_to_mem(base_addr: int, blocks: list[Block], mem):
    def store_block(addr, size, next_ptr):
        addr = addr//WORD_SIZE
        mem[addr] = size
        mem[addr+1] = next_ptr

    def store_word(addr, word):
        addr = addr//WORD_SIZE
        mem[addr] = word

    NULL_PTR = 0

    last_block = Block(NULL_PTR, 0)
    blocks.append(last_block)

    store_word(base_addr, blocks[0].base_addr)

    for i in range(len(blocks)-1):
        base_addr = blocks[i].base_addr
        size = blocks[i].size
        next_ptr = blocks[i+1].base_addr

        store_block(base_addr, size, next_ptr)


def mem_to_list(base_addr: int, mem) -> list[Block]:
    def load_block(addr):
        addr = addr//WORD_SIZE
        assert addr in mem, "addr {} in mem".format(addr)
        assert addr+1 in mem, "addr {} in mem".format(addr+1)

        size = mem[addr]
        next_ptr = mem[addr+1]

        return (Block(addr*WORD_SIZE, size), next_ptr)

    def load_word(addr):
        addr = addr//WORD_SIZE
        assert addr in mem, "addr {} in mem".format(addr)

        return mem[addr]

    NULL_PTR = 0

    blocks = []

    n = base_addr
    n = load_word(n)

    while n != NULL_PTR:
        (b, n) = load_block(n)
        blocks.append(b)

    return blocks
