#!/bin/sh
"exec" "`dirname $0`/py3-cmd" "$0" "-c" "`dirname $0`/config.json" "$@"

import qemu

if __name__ == "__main__":
    qemu.main()
