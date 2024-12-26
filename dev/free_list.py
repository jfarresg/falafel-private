class Node:
    def __init__(self, addr, size, next_addr=None):
        self.addr = addr
        self.size = size
        self.next_addr = next_addr

    def __str__(self):
        return f"Node(addr={self.addr}, size={self.size}, next_addr={self.next_addr})"  # noqa


class LinkedList:
    def __init__(self):
        self.nodes = {}

    def add_node(self, addr, size, next_addr=None):
        node = Node(addr, size, next_addr)
        self.nodes[addr] = node

    def update_size(self, addr, size):
        if addr in self.nodes:
            self.nodes[addr].size = size
        else:
            print(f"Node with address {addr} does not exist.")

    def update_next_addr(self, addr, next_addr):
        if addr in self.nodes:
            self.nodes[addr].next_addr = next_addr
        else:
            print(f"Node with address {addr} does not exist.")

    def get_node(self, addr):
        if addr in self.nodes:
            node = self.nodes[addr]
            return node.size, node.next_addr
        else:
            return None, None

    def print_list(self):
        print("LinkedList contents:")
        for addr, node in sorted(self.nodes.items()):
            print(
                f"Addr: {addr}, Size: {node.size}, Next Addr: {node.next_addr}"
            )  # noqa