#!/bin/sh
"exec" "`dirname $0`/py3-cmd" "$0" "-c" "`dirname $0`/config.json" "$@"

import os
from typing import List, Optional

import qemu
import qemu_error

__all__ = ["init", "run_test", "shutdown"]


TRUSTY_PROJECT_FOLDER = os.path.dirname(os.path.realpath(__file__))


def init(*, android=None, disable_rpmb=False, verbose=False,
         debug_on_error=False) -> qemu.Runner:

    with open(f"{TRUSTY_PROJECT_FOLDER}/config.json", encoding="utf-8") as json:
        config = qemu.Config(json)

    if android:
        config.android = qemu.find_android_build_dir(android)

    runner = qemu.Runner(config,
                         interactive=False,
                         verbose=verbose,
                         rpmb=not disable_rpmb,
                         debug=False,
                         debug_on_error=debug_on_error)
    return runner


def _check_args(args):
    """Validate arguments passed to run_test."""
    assert args.headless, args
    assert not args.linux, args
    assert not args.atf, args
    assert not args.qemu, args
    assert not args.arch, args
    assert not args.debug, args
    assert not args.extra_qemu_flags, args
    assert not args.disable_rpmb, args


def run_test(runner: qemu.Runner, cmd: List[str]) -> int:
    args = qemu.build_argparser().parse_args(cmd)
    _check_args(args)

    # make sure runner was started with rpmb in the state needed for test
    assert args.disable_rpmb == (not runner.use_rpmb)

    timeout = args.timeout if args.timeout else runner.default_timeout
    if args.boot_test:
        runner.launch(boot_test_only=True)
        return runner.boottest_run(args.boot_test, timeout)
    elif args.shell_command:
        runner.launch(boot_test_only=False)
        return runner.androidtest_run(args.shell_command, timeout)
    else:
        raise qemu_error.ConfigError(
            "Command must request exactly one Android or boot test to run")


def shutdown(runner: Optional[qemu.Runner]):
    if runner:
        runner.shutdown()


if __name__ == "__main__":
    qemu.main()
