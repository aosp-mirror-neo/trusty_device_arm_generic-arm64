#!/bin/sh
"exec" "`dirname $0`/py3-cmd" "$0" "-c" "`dirname $0`/config.json" "$@"

import argparse
import logging
import os
from typing import List, Optional
import sys


import qemu
import qemu_error

__all__ = ["init", "run_test", "shutdown"]


TRUSTY_PROJECT_FOLDER = os.path.dirname(os.path.realpath(__file__))


def init(*, android=None, instance_dir: os.PathLike, disable_rpmb=False,
         verbose=False, debug_on_error=False
) -> qemu.Runner:

    with open(f"{TRUSTY_PROJECT_FOLDER}/config.json", encoding="utf-8") as json:
        config = qemu.Config(json)

    if android:
        config.android_image_dir = qemu.find_android_image_dir(android)
        config.adb = qemu.find_adb_path(android)
        config.boot_android = True

    runner = qemu.Runner(config,
                         interactive=False,
                         instance_dir=instance_dir,
                         verbose=verbose,
                         rpmb=not disable_rpmb,
                         debug=False,
                         debug_on_error=debug_on_error)
    return runner


def _check_args(args):
    """Validate arguments passed to run_test."""
    assert args.headless, args
    assert not args.linux, args
    assert not args.initrd, args
    assert not args.atf, args
    assert not args.qemu, args
    assert not args.arch, args
    assert not args.debug, args
    assert not args.extra_linux_args, args
    assert not args.extra_qemu_flags, args
    assert not args.disable_rpmb, args


def _prepare_runner_for_test(runner, args):
    """Check if the runner is in the correct state (BOOTLOADER, ANDROID)
    to run a given test and reboot the emulator if it is not.

    TODO: Remove the unconditional reboot after boot tests once the test harness
          no longers requires it.
    """
    if args.boot_test:
        target_state = qemu.RunnerState.BOOTLOADER
    elif args.shell_command or args.host_command:
        target_state = qemu.RunnerState.ANDROID
    else:
        raise qemu_error.ConfigError(
            "Command must request exactly one Android, boot test, or"
            " host command to run"
        )

    # Due to limitations in the test runner, always reboot between boot tests
    if (runner.state != target_state or
            runner.state == qemu.RunnerState.BOOTLOADER):
        runner.reboot(target_state, factory_reset=True, full_wipe=False)

def run_test(runner: qemu.Runner, cmd: List[str]) -> int:
    args = build_argparser().parse_args(cmd)
    _check_args(args)
    _prepare_runner_for_test(runner, args)

    timeout = args.timeout if args.timeout else runner.default_timeout
    if args.boot_test:
        return runner.boottest_run(args.boot_test, timeout)
    if args.shell_command:
        return runner.androidtest_run(args.shell_command, timeout)
    if args.host_command:
        return runner.hostcommandtest_run(args.host_command[0], timeout)

    raise qemu.RunnerGenericError(
        "Command contained neither a boot test nor an Android test to run")


def shutdown(runner: Optional[qemu.Runner],
             factory_reset: bool = True,
             full_wipe: bool = False):
    if runner:
        runner.shutdown(factory_reset, full_wipe)


def build_argparser():
    argument_parser = argparse.ArgumentParser()
    argument_parser.add_argument("-c", "--config", type=argparse.FileType("r"))
    argument_parser.add_argument("--headless", action="store_true")
    argument_parser.add_argument("-v", "--verbose", action="store_true")
    argument_parser.add_argument("--debug", action="store_true")
    argument_parser.add_argument("--debug-on-error", action="store_true")
    argument_parser.add_argument("--boot-test", action="append")
    argument_parser.add_argument("--shell-command", action="append")
    argument_parser.add_argument("--host-command", action="append")
    argument_parser.add_argument("--android")
    argument_parser.add_argument("--linux")
    argument_parser.add_argument("--initrd")
    argument_parser.add_argument("--instance-dir", type=str,
                                 default="/tmp/trusty-qemu-generic-arm64")
    argument_parser.add_argument("--preserve-instance", action="store_true")
    argument_parser.add_argument("--atf")
    argument_parser.add_argument("--qemu")
    argument_parser.add_argument("--arch")
    argument_parser.add_argument("--disable-rpmb", action="store_true")
    argument_parser.add_argument("--timeout", type=int)
    argument_parser.add_argument('-n', '--extra-linux-args', nargs='+', default=[])
    argument_parser.add_argument("extra_qemu_flags", nargs="*")
    return argument_parser


def main():
    args = build_argparser().parse_args()
    log_level = logging.DEBUG if args.verbose else logging.WARN
    logging.basicConfig(level=log_level)

    config = qemu.Config(args.config)
    if args.android:
        config.android_image_dir = qemu.find_android_image_dir(args.android)
        config.adb = qemu.find_adb_path(args.android)
        config.boot_android = True
    if args.linux:
        config.linux = args.linux
    if args.initrd:
        config.initrd = args.initrd
    if args.atf:
        config.atf = args.atf
    if args.qemu:
        config.qemu = args.qemu
    if args.arch:
        config.arch = args.arch
    if args.extra_linux_args:
        config.extra_linux_args = args.extra_linux_args
    if args.extra_qemu_flags:
        config.extra_qemu_flags += args.extra_qemu_flags

    runner = qemu.Runner(config,
                         interactive=not args.headless,
                         instance_dir=args.instance_dir,
                         preserve_instance=args.preserve_instance,
                         verbose=args.verbose,
                         rpmb=not args.disable_rpmb,
                         debug=args.debug,
                         debug_on_error=args.debug_on_error)

    try:
        results = runner.run(args.boot_test, args.shell_command,
                             args.host_command, args.timeout)
        print("Command results: " + repr(results))

        if any(results):
            sys.exit(1)
        else:
            sys.exit(0)
    except qemu_error.RunnerError as exn:
        print(exn)
        sys.exit(2)


if __name__ == "__main__":
    main()
