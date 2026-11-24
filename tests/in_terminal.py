import os
from pathlib import Path
import pty
import select
import signal
import subprocess
import sys
import time


def run(frames, command):
    master, slave = pty.openpty()
    output = bytearray()
    process = subprocess.Popen(command, stdin=subprocess.DEVNULL, stdout=slave, stderr=slave, start_new_session=True)
    os.close(slave)
    deadline = time.monotonic() + 30
    while output.count(b"\x1b[H") < frames and time.monotonic() < deadline:
        if select.select([master], [], [], 0.05)[0]:
            try:
                output += os.read(master, 65536)
            except OSError:
                break
    os.killpg(process.pid, signal.SIGTERM)
    process.wait()
    os.close(master)
    (Path(os.environ["GW_TEST_DIR"]) / "terminal").write_bytes(bytes(output))
    return process.returncode


if __name__ == "__main__":
    sys.exit(run(int(sys.argv[1]), sys.argv[2:]))
