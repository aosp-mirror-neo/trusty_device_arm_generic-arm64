"""Generate QEMU options for Trusty test framework"""

import logging
import os
import pathlib
import shutil
import subprocess
import tempfile

from qemu_error import RunnerGenericError

logger = logging.getLogger(__name__)

def _find_dtc():
    for search_dir in ["out/host/linux-x86/bin", "prebuilts/misc/linux-x86/dtc", "bin", "linux-build/scripts/dtc"]:
        path = os.path.join(search_dir, "dtc")
        if os.path.exists(path):
            return path
    return None


class QemuDrive:
    def __init__(
        self,
        name: str,
        index: int,
        dir_name: str,
        read_only: bool = True,
        persistent: bool = False,
        ext: str = ".img",
    ):
        self.name = name
        self.index = index
        self.read_only = read_only
        self.persistent = persistent
        self.ext = ext
        self.img_path = self.path(pathlib.Path(dir_name))
        if not os.path.exists(self.img_path):
            raise RunnerGenericError(
                f"image cannot be found at {self.img_path}"
            )

    def index_letter(self):
        return chr(ord('a') + self.index)

    def path(self, directory: os.PathLike):
        return os.path.join(directory,f"{self.name}{self.ext}")

    def ensure_image_exists(self, instance_dir: os.PathLike):
        if self.read_only:
            return

        path = self.path(instance_dir)
        if not os.path.exists(path):
            shutil.copy(self.img_path, path)

    def delete_image_changes(self, instance_dir: os.PathLike, full_wipe: bool):
        if self.read_only:
            return

        if self.persistent and not full_wipe:
            return

        try:
            os.remove(self.path(instance_dir))
        except FileNotFoundError:
            pass

    def args(self, image_dir: os.PathLike, instance_dir: os.PathLike):
        path = self.path(image_dir if self.read_only else instance_dir)
        snapshot = "on" if self.read_only else "off"
        return [
            "-drive",
            (f"file={path},index={self.index},if=none,"
             + f"id=hd{self.index_letter()},format=raw,snapshot={snapshot}"),
            "-device",
            f"virtio-blk-device,drive=hd{self.index_letter()}"
        ]

class QemuArm64Options(object):

    MACHINE = "virt,secure=on,virtualization=on"

    # -no-reboot is to avoid the logs of trusty starting again when the system
    # exists uncleanly, e.g., due to a boot or test failure.
    BASIC_ARGS = [
        "-nographic", "-no-reboot",
        "-cpu", "max,sve=off,pauth=off",
        "-smp", "4",
        "-m", "1024",
        "-d", "unimp",
        "-semihosting-config", "enable=on,target=native",
        "-machine", "acpi=off",
    ]

    LINUX_ARGS = (
        "earlyprintk console=ttyAMA0,38400 keep_bootcon "
        "root=/dev/ram0 init=/init androidboot.hardware=qemu_trusty "
        "androidboot.hypervisor.version=1.0.0 "
        "androidboot.hypervisor.vm.supported=1 "
        "androidboot.hypervisor.protected_vm.supported=1 "
        "trusty-log.log_ratelimit_interval=0 trusty-log.log_to_dmesg=always")

    def __init__(self, config, instance_dir):
        self.args = []
        self.config = config
        self.instance_dir = instance_dir

    def create_rpmb_data(self):
        """If no rpmb data image exists, copy the snapshot to create new one."""
        os.makedirs(self.instance_dir, exist_ok=True)
        path = self.rpmb_data_path()
        if not os.path.exists(path):
            shutil.copy(self.rpmb_data_snapshot_path(), path)

    def delete_rpmb_data(self):
        try:
            os.remove(self.rpmb_data_path())
        except FileNotFoundError:
            pass

    def rpmb_data_snapshot_path(self):
        return f"{self.config.atf}/RPMB_DATA"

    def rpmb_data_path(self):
        return f"{self.instance_dir}/RPMB_DATA"

    def rpmb_options(self, sock):
        return [
            "-device", "virtio-serial",
            "-device", "virtserialport,chardev=rpmb0,name=rpmb0",
            "-chardev", f"socket,id=rpmb0,path={sock}"]

    def get_initrd_filename(self):
        if self.config.initrd and pathlib.Path(self.config.initrd).is_file():
            return self.config.initrd
        return self.config.android_image_dir + "/ramdisk.img"

    def get_linux_args(self):
        # The vport device names in linux change depending on how many virtio
        # block devices we have. Pass a bootparamter to linux with a computed
        # name so we can add drives without updating the android side at the
        # same time.
        # We only pass the base name here, not each vport, since the selinux
        # rules still assign labels to the vport based on a hardcoded suffix.
        vport_num = len(self.drives())

        return self.LINUX_ARGS + f" androidboot.qemu.vport=vport{vport_num}"

    def initrd_dts(self):
        file_stats = os.stat(self.get_initrd_filename())
        start_addr = 0x48000000
        end_addr = start_addr + file_stats.st_size

        return f"""/ {{
        chosen {{
            linux,initrd-start = <0x0 0x{start_addr:08x}>;
            linux,initrd-end = <0x0 0x{end_addr:08x}>;
        }};
    }};
        """

    def gen_dtb(self, args, dtb_tmp_file):
        """Computes a trusty device tree, returning a file for it"""
        dtc = _find_dtc()
        if dtc is None:
            raise RunnerGenericError("Could not find dtc tool")
        with tempfile.NamedTemporaryFile() as dtb_gen:
            dump_dtb_cmd = [
                self.config.qemu, "-machine",
                f"{self.MACHINE},dumpdtb={dtb_gen.name}"
            ] + [arg for arg in args if arg != "-S"]
            logger.info("dump dtb command: %s", " ".join(dump_dtb_cmd))
            returncode = subprocess.call(dump_dtb_cmd)
            if returncode != 0:
                raise RunnerGenericError(
                    f"dumping dtb failed with {returncode}")
            dtb_to_dts_cmd = [dtc, "-q", "-O", "dts", dtb_gen.name]
            logger.info("dtb to dts command: %s", " ".join(dtb_to_dts_cmd))
            # pylint: disable=consider-using-with
            with subprocess.Popen(dtb_to_dts_cmd,
                                  stdout=subprocess.PIPE,
                                  universal_newlines=True) as dtb_to_dts:
                dts = dtb_to_dts.communicate()[0]
                if dtb_to_dts.returncode != 0:
                    raise RunnerGenericError(
                        f"dtb_to_dts failed with {dtb_to_dts.returncode}")

        dts += self.initrd_dts()

        # Subprocess closes dtb, so we can't allow it to autodelete
        dtb = dtb_tmp_file
        dts_to_dtb_cmd = [dtc, "-q", "-O", "dtb"]
        with subprocess.Popen(dts_to_dtb_cmd,
                              stdin=subprocess.PIPE,
                              stdout=dtb,
                              universal_newlines=True) as dts_to_dtb:
            dts_to_dtb.communicate(dts)
            dts_to_dtb_ret = dts_to_dtb.wait()

        if dts_to_dtb_ret:
            raise RunnerGenericError(f"dts_to_dtb failed with {dts_to_dtb_ret}")
        return ["-dtb", dtb.name]

    def drives(self) -> list[QemuDrive]:
        return [
            QemuDrive("trusty_userdata", 6, self.config.atf, read_only=False),
            QemuDrive("trusty_persist", 5, self.config.atf, read_only=False, persistent=True),
            QemuDrive("goldfish_reserved", 4, self.config.atf, read_only=False),
            QemuDrive("metadata", 3, self.config.atf, read_only=False),
            QemuDrive(
                "userdata", 2, self.config.android_image_dir, read_only=False
            ),
            QemuDrive("vendor", 1, self.config.android_image_dir),
            QemuDrive("system", 0, self.config.android_image_dir),
        ]

    def create_drives_data(self):
        """If drives images don't exist, create some from their snapshots."""
        os.makedirs(self.instance_dir, exist_ok=True)
        for drive in self.drives():
            drive.ensure_image_exists(self.instance_dir)

    def delete_drives_data(self, full_wipe: bool):
        for drive in self.drives():
            drive.delete_image_changes(self.instance_dir, full_wipe)

    def android_drives_args(self):
        """Generates arguments for mapping all default drives"""
        args = []
        # This is order sensitive due to using e.g. root=/dev/vda
        for drive in self.drives():
            args += drive.args(self.config.android_image_dir, self.instance_dir)
        return args

    def machine_options(self):
        return ["-machine", self.MACHINE]

    def basic_options(self):
        return list(self.BASIC_ARGS)

    def bios_options(self):
        return ["-bios", f"{self.config.atf}/bl1.bin"]

    def find_kernel_image(self):
        if pathlib.Path(self.config.linux).is_file():
            return self.config.linux
        image = f"{self.config.linux}/arch/{self.config.linux_arch}/boot/Image"
        if os.path.exists(image):
            return image
        return None

    def linux_options(self):
        kernel = self.find_kernel_image()
        if kernel is None:
            raise RunnerGenericError("Could not find kernel image")
        return [
            "-kernel",
            kernel,
            "-initrd",
            self.get_initrd_filename(),
            "-append", self.get_linux_args()
        ]

    def android_trusty_user_data(self):
        return os.path.join(self.config.android_image_dir, "data")
