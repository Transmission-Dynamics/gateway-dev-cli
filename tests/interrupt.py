import errno
import os
from pathlib import Path
import pty
import select
import signal
import subprocess
import sys
import time


def read_terminal(master, output):
    if select.select([master], [], [], 0.05)[0]:
        try:
            data = os.read(master, 65536)
            output.write(data)
            return bool(data)
        except OSError as error:
            if error.errno != errno.EIO:
                raise
            return False
    return True


def interrupt(command):
    sandbox = Path(os.environ["GW_TEST_DIR"])
    master, slave = pty.openpty()
    process = None
    try:
        with (sandbox / "stdout").open("wb") as stdout, (sandbox / "stderr").open("wb") as stderr:
            process = subprocess.Popen(
                command,
                stdin=subprocess.DEVNULL,
                stdout=stdout,
                stderr=slave,
                start_new_session=True,
            )
            os.close(slave)
            slave = None
            deadline = time.monotonic() + 10
            while not (sandbox / "npm-paused").exists():
                read_terminal(master, stderr)
                if process.poll() is not None or time.monotonic() >= deadline:
                    raise RuntimeError("Deploy did not reach the paused npm step")

            os.killpg(process.pid, signal.SIGINT)
            deadline = time.monotonic() + 10
            while process.poll() is None:
                read_terminal(master, stderr)
                if time.monotonic() >= deadline:
                    raise RuntimeError("Deploy did not exit after Ctrl+C")

            deadline = time.monotonic() + 2
            while read_terminal(master, stderr):
                if time.monotonic() >= deadline:
                    raise RuntimeError("Deploy left its terminal open after Ctrl+C")
            if not (sandbox / "npm-stopped").exists():
                raise RuntimeError("npm did not stop after Ctrl+C")
            return process.returncode
    finally:
        if process is not None:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except (ProcessLookupError, PermissionError):
                pass
            process.wait()
        os.close(master)
        if slave is not None:
            os.close(slave)


if __name__ == "__main__":
    sys.exit(interrupt(sys.argv[1:]))
