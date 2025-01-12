# SPDX-FileCopyrightText: © 2025 Joan Farres Garcia
#
# SPDX-License-Identifier: BSD-3-Clause


from cocotb_bus.bus import Bus
from abc import abstractmethod

from cocotb.triggers import RisingEdge, ReadOnly


class FalafelValRdyBus(Bus):
    _signalNames = ["val", "rdy", "data"]

    def __init__(self, entity, name, signals):
        for signal in self._signalNames:
            if not signal in signals:
                raise AttributeError(
                    f"signals doesn't contain a value for key" f"{name}")

        super().__init__(entity, name, signals)


class FalafelLsuRequestBus(Bus):
    _signalNames = ["val", "rdy", "op", "addr",
                    "word", "lock_id", "block_size", "block_next_ptr"]

    def __init__(self, entity, name, signals):
        for signal in self._signalNames:
            if not signal in signals:
                raise AttributeError(
                    f"signals doesn't contain a value for key" f"{name}")

        super().__init__(entity, name, signals)


class FalafelLsuResponseBus(Bus):
    _signalNames = ["val", "rdy", "word", "block_size", "block_next_ptr"]

    def __init__(self, entity, name, signals):
        for signal in self._signalNames:
            if not signal in signals:
                raise AttributeError(
                    f"signals doesn't contain a value for key" f"{name}")

        super().__init__(entity, name, signals)


class FalafelMemRequestBus(Bus):
    _signalNames = ["val", "rdy", "is_write", "is_cas", "addr", "data", "cas_exp"]

    def __init__(self, entity, name, signals):
        for signal in self._signalNames:
            if not signal in signals:
                raise AttributeError(
                    f"signals doesn't contain a value for key" f"{name}")

        super().__init__(entity, name, signals)


class FalafelMemResponseBus(Bus):
    _signalNames = ["val", "rdy", "data"]

    def __init__(self, entity, name, signals):
        for signal in self._signalNames:
            if not signal in signals:
                raise AttributeError(
                    f"signals doesn't contain a value for key" f"{name}")

        super().__init__(entity, name, signals)


class FalafelFifoWriteBus(Bus):
    _signalNames = ["write", "din", "full"]

    def __init__(self, entity, name, signals):
        for signal in self._signalNames:
            if not signal in signals:
                raise AttributeError(
                    f"signals doesn't contain a value for key" f"{name}")

        super().__init__(entity, name, signals)


class FalafelFifoReadBus(Bus):
    _signalNames = ["read", "dout", "empty"]

    def __init__(self, entity, name, signals):
        for signal in self._signalNames:
            if not signal in signals:
                raise AttributeError(
                    f"signals doesn't contain a value for key" f"{name}")

        super().__init__(entity, name, signals)


class FalafelValRdyMonitor:
    def __init__(self, bus, clk):
        self.clk = clk
        self.bus = bus

    async def recv(self):
        await RisingEdge(self.clk)
        self.bus.rdy.value = 1

        await ReadOnly()

        while not self.bus.val.value:
            await RisingEdge(self.clk)
            await ReadOnly()

        data = int(self.bus.data)

        await RisingEdge(self.clk)
        self.bus.rdy.value = 0

        return data

    async def recvi(self, index):
        await RisingEdge(self.clk)
        self.bus.rdy[index].value = 1

        await ReadOnly()

        while not self.bus.val.value:
            await RisingEdge(self.clk)
            await ReadOnly()

        data = int(self.bus.data[index].value)

        await RisingEdge(self.clk)
        self.bus.rdy[index].value = 0

        return data


class FalafelValRdyDriver:
    def __init__(self, bus, clk):
        self.clk = clk
        self.bus = bus

    async def send(self, data):
        await RisingEdge(self.clk)
        self.bus.val.value = 1
        self.bus.data.value = data

        await ReadOnly()

        while not self.bus.rdy.value:
            await RisingEdge(self.clk)
            await ReadOnly()

        await RisingEdge(self.clk)
        self.bus.val.value = 0


    async def sendi(self, index, data):
        await RisingEdge(self.clk)
        self.bus.val[index].value = 1
        self.bus.data[index].value = data

        await ReadOnly()

        while not self.bus.rdy[index].value:
            await RisingEdge(self.clk)
            await ReadOnly()

        await RisingEdge(self.clk)
        self.bus.val[index].value = 0


class FalafelLsuRequestDriver:
    def __init__(self, bus, clk):
        self.clk = clk
        self.bus = bus

    LSU_OP_STORE_WORD = 0
    LSU_OP_LOAD_WORD = 1
    LSU_OP_STORE_BLOCK = 2
    LSU_OP_LOAD_BLOCK = 3
    LSU_OP_LOCK = 4
    LSU_OP_UNLOCK = 5

    async def load_word(self, addr):
        await self._send(self.LSU_OP_LOAD_WORD, addr, 0, 0, (0, 0))

    async def store_word(self, addr, word):
        await self._send(self.LSU_OP_STORE_WORD, addr, word, 0, (0, 0))

    async def load_block(self, addr):
        await self._send(self.LSU_OP_LOAD_BLOCK, addr, 0, 0, (0, 0))

    async def store_block(self, addr, block):
        await self._send(self.LSU_OP_STORE_BLOCK, addr, 0, 0, block)

    async def lock(self, addr, lock_id):
        await self._send(self.LSU_OP_LOCK, addr, 0, lock_id, (0, 0))

    async def unlock(self, addr):
        await self._send(self.LSU_OP_UNLOCK, addr, 0, 0, (0, 0))

    async def _send(self, op, addr, word, lock_id, block):
        (block_size, block_next_ptr) = block

        await RisingEdge(self.clk)
        self.bus.val.value = 1
        self.bus.op.value = op
        self.bus.addr.value = addr
        self.bus.word.value = word
        self.bus.lock_id.value = lock_id
        self.bus.block_size.value = block_size
        self.bus.block_next_ptr.value = block_next_ptr

        await ReadOnly()

        while not self.bus.rdy.value:
            await RisingEdge(self.clk)
            await ReadOnly()

        await RisingEdge(self.clk)
        self.bus.val.value = 0


class FalafelLsuResponseMonitor:
    def __init__(self, bus, clk):
        self.clk = clk
        self.bus = bus

    async def recv(self):
        await RisingEdge(self.clk)
        self.bus.rdy.value = 1

        await ReadOnly()

        while not self.bus.val.value:
            await RisingEdge(self.clk)
            await ReadOnly()

        word = int(self.bus.word)
        block = (int(self.bus.block_size), int(self.bus.block_next_ptr))

        await RisingEdge(self.clk)
        self.bus.rdy.value = 0

        # print('lsu resp recv: (word, block):', (word, block))
        return (word, block)


class FalafelMemRequestMonitor:
    def __init__(self, bus, clk):
        self.clk = clk
        self.bus = bus

    async def recv(self):
        await RisingEdge(self.clk)
        self.bus.rdy.value = 1

        await ReadOnly()

        while not self.bus.val.value:
            await RisingEdge(self.clk)
            await ReadOnly()

        is_write = int(self.bus.is_write)
        is_cas = int(self.bus.is_cas)
        addr = int(self.bus.addr)
        data = int(self.bus.data)
        cas_exp = int(self.bus.cas_exp)

        await RisingEdge(self.clk)
        self.bus.rdy.value = 0

        # print('mem req recv: (is_write, addr, data):', (is_write, addr, data))
        return (is_write, is_cas, addr, data, cas_exp)


class FalafelMemResponseDriver:
    def __init__(self, bus, clk):
        self.clk = clk
        self.bus = bus

    async def send(self, data):
        await RisingEdge(self.clk)
        self.bus.val.value = 1
        self.bus.data.value = data

        await ReadOnly()

        while not self.bus.rdy.value:
            await RisingEdge(self.clk)
            await ReadOnly()

        await RisingEdge(self.clk)
        self.bus.val.value = 0


class FalafelFifoReadSlave:
    def __init__(self, bus, clk):
        self.clk = clk
        self.bus = bus
        self.queue = []

        self.bus.empty.value = 1
        self.bus.dout.value = 0

    async def push(self, data):
        self.queue.append(data)

    async def monitor(self):
        await RisingEdge(self.clk)
        self.bus.empty.value = 1
        self.bus.dout.value = 0

        await RisingEdge(self.clk)

        while True:
            if len(self.queue) == 0:
                await RisingEdge(self.clk)
                continue

            self.bus.empty.value = 0
            self.bus.dout.value = self.queue.pop(0)

            await ReadOnly()

            while not self.bus.read.value:
                await RisingEdge(self.clk)
                await ReadOnly()

            await RisingEdge(self.clk)
            self.bus.empty.value = 1


class FalafelFifoWriteSlave:
    def __init__(self, bus, clk):
        self.clk = clk
        self.bus = bus
        self.queue = []

        self.bus.full.value = 1

    async def pop(self):
        while len(self.queue) == 0:
            await RisingEdge(self.clk)

        return self.queue.pop(0)

    async def monitor(self):
        await RisingEdge(self.clk)
        self.bus.full.value = 0

        while True:
            await RisingEdge(self.clk)
            await ReadOnly()

            while not self.bus.write.value:
                await RisingEdge(self.clk)
                await ReadOnly()

            self.queue.append(int(self.bus.din.value))
