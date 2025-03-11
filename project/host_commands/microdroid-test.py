#!/bin/sh
"exec" "`dirname $0`/../py3-cmd" "$0" "$@"

import os
import queue
import re
import subprocess
import sys
import threading
import time

try:
    trusty_adb_port = os.environ["ADB_PORT"]
    project_root = os.environ["PROJECT_ROOT"]
except KeyError:
    print("ADB_PORT and PROJECT_ROOT environment variables required.")
    sys.exit(64)  # EX_USAGE

sys.path.append(project_root)
import alloc_adb_ports
import qemu


MIN_MICRODROID_PORT = 8000
START_MICRODROID_COMMAND = (
    "/apex/com.android.virt/bin/vm run-microdroid"
    " --debug full --protected --enable-earlycon"
    " --os microdroid_gki-android16-6.12"
    " --vendor /vendor/etc/avf/microdroid/microdroid_vendor.img"
)


class Adb(object):
    """Manage adb."""

    def __init__(self, adb_bin, port=None):

        self.adb_bin = adb_bin

        self.port = (
            port
            if port
            else alloc_adb_ports.alloc_adb_ports(
                min_port=MIN_MICRODROID_PORT, num_ports=1
            )[0]
        )

    def run(self, args, timeout=60, stdout=None, stderr=None):
        """Run an adb command."""

        args = [self.adb_bin, "-s", f"localhost:{self.port}"] + args

        status = subprocess.run(args, stdout=stdout, stderr=stderr, timeout=timeout)

        return status

    def run_background(self, args):
        """Run an adb command in the background."""
        args = [self.adb_bin, "-s", f"localhost:{self.port}"] + args

        adb_proc = subprocess.Popen(args, stdout=subprocess.PIPE)

        return adb_proc

    def connect(self, host):
        """Connect to adbd."""
        return self.run(
            ["connect", host], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )

    def disconnect(self, host):
        """Disonnect from adbd."""
        return self.run(
            ["disconnect", host], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )

    def is_connected(self, host):
        """Check adb connection."""
        out = self.run(["devices"], stdout=subprocess.PIPE)

        m = re.search(f"{host}.*device", out.stdout.decode("UTF-8"))
        if m:
            return True
        else:
            return False

    def forward(self, local_port, cid):
        """Forward adb connection."""
        return self.run(
            ["forward", f"tcp:{local_port}", f"vsock:{cid}:{self.port}"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

    def unforward(self, local_port):
        """Remove forwarded adb connection."""
        return self.run(
            ["forward", "--remove" f"tcp:{local_port}"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )


class Microdroid(object):
    """Manage Microdroid VM."""

    def __init__(self, adb):
        self.adb = adb
        self.stop_thread = False
        self.cid = None
        self.cid_queue = queue.Queue()

    def process_output(self, pipe):
        """Filters stdout, searching for Microdroid's CID"""
        # this terminates when microdroid does
        p = re.compile(
            r"Created debuggable VM from.*with CID\s+(\d+), state is STARTING."
        )
        cid = None
        for line in pipe:
            decoded_line = line.decode("UTF-8")
            print(decoded_line, end="")

            if cid == None:
                if m := p.search(decoded_line):
                    cid = m.group(1)
                    self.cid_queue.put(cid)

    def start(self, command):
        """Start Microdroid."""
        self.microdroid_proc = self.adb.run_background(["shell"] + command.split(" "))
        self.microdroid_output_thread = threading.Thread(
            target=self.process_output, args=[self.microdroid_proc.stdout],
            daemon=1
        )

        self.microdroid_output_thread.start()

        self.cid = self.cid_queue.get()

        return self.cid

    def stop(self):
        """Stop Microdroid."""
        self.adb.run(
            [
                "shell",
                "/apex/com.android.virt/bin/crosvm",
                "stop",
                f"/data/misc/virtualizationservice/{self.cid}/crosvm.sock",
            ]
        )

        try:
            self.microdroid_proc.kill()
        except OSError:
            pass


def main():
    status = 1
    microdroid = None
    microdroid_adb = None
    try:
        with open(f"{project_root}/config.json", encoding="utf-8") as json:
            config = qemu.Config(json)

        trusty_adb = Adb(config.adb, trusty_adb_port)

        trusty_adb.run(["shell", "setprop hypervisor.pvmfw.path none"])

        microdroid = Microdroid(trusty_adb)
        microdroid.start(START_MICRODROID_COMMAND)

        print("Microdroid started")
        microdroid_adb = Adb(config.adb)

        trusty_adb.forward(microdroid_adb.port, microdroid.cid)

        # Wait for microdroid to finish booting
        while not trusty_adb.is_connected(f"localhost:{microdroid_adb.port}"):
            trusty_adb.disconnect(f"localhost:{microdroid_adb.port}")
            trusty_adb.connect(f"localhost:{microdroid_adb.port}")
            time.sleep(1)

        microdroid_adb.run(["wait-for-device", "root"])

        print("Starting microdroid test: " + " ".join(sys.argv[1:]))
        st = microdroid_adb.run(["shell"] + sys.argv[1:])
        status = st.returncode
        print("Starting microdroid completed")

    finally:
        if microdroid:
            microdroid.stop()

        if microdroid_adb:
            trusty_adb.unforward(microdroid_adb.port)

    sys.exit(status)


if __name__ == "__main__":
    main()
