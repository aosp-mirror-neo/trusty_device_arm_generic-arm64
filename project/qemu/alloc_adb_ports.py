#!/bin/sh
"exec" "`dirname $0`/py3-cmd" "$0" "$@"

import argparse
import socket

# ADB expects its first console on 5554, and control on 5555
ADB_BASE_PORT = 5554


def alloc_adb_ports(min_port=ADB_BASE_PORT, num_ports=2):
    """Allocates num_ports sequential ports above min_port for adb

    adb normally uses ports in pairs. The exception is when a
    port is needed for forwarding the adb connection, such as when
    using a VM.
    """

    # We can't actually reserve ports atomically for QEMU, but we can at
    # least scan and find two that are not currently in use.
    while True:
        alloced_ports = []
        for port in range(min_port, min_port + num_ports):
            # If the port is already in use, don't hand it out
            try:
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.connect(("localhost", port))
                break
            except IOError:
                alloced_ports += [port]
        if len(alloced_ports) == num_ports:
            return alloced_ports

        # We could increment by only 1, but if we are competing with other
        # adb sessions for ports, this will be more polite
        min_port += num_ports


if __name__ == "__main__":
    argument_parser = argparse.ArgumentParser()
    argument_parser.add_argument("--min-port", required=True, type=int)
    argument_parser.add_argument("--num-ports", required=True, type=int)
    args = argument_parser.parse_args()

    ports = alloc_adb_ports(args.min_port, args.num_ports)
    print(*ports, sep=" ")
