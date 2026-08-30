"""Load a built voice shim and exercise its complete transport-only ABI."""

from __future__ import annotations

import ctypes
import pathlib
import sys


def byte_pointer(data: bytes) -> tuple[ctypes.Array[ctypes.c_ubyte], object]:
    storage = (ctypes.c_ubyte * len(data)).from_buffer_copy(data)
    return storage, ctypes.cast(storage, ctypes.POINTER(ctypes.c_ubyte))


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: dynamic_smoke.py <shared-library>")
    library_path = pathlib.Path(sys.argv[1]).resolve(strict=True)
    library = ctypes.CDLL(str(library_path))

    library.vs_abi_version.argtypes = []
    library.vs_abi_version.restype = ctypes.c_uint16
    library.vs_free.argtypes = [ctypes.POINTER(ctypes.c_ubyte), ctypes.c_size_t]
    library.vs_free.restype = None
    library.vs_last_error.argtypes = []
    library.vs_last_error.restype = ctypes.c_char_p

    operation_args = [
        ctypes.c_int32,
        ctypes.POINTER(ctypes.c_ubyte),
        ctypes.POINTER(ctypes.c_ubyte),
        ctypes.c_size_t,
        ctypes.POINTER(ctypes.c_ubyte),
        ctypes.c_size_t,
        ctypes.POINTER(ctypes.c_ubyte),
        ctypes.c_size_t,
        ctypes.POINTER(ctypes.POINTER(ctypes.c_ubyte)),
        ctypes.POINTER(ctypes.c_size_t),
    ]
    for operation in (library.vs_aead_seal, library.vs_aead_open):
        operation.argtypes = operation_args
        operation.restype = ctypes.c_int32

    if library.vs_abi_version() != 3:
        raise RuntimeError("voice shim did not report ABI version 3")
    if library.vs_last_error() is None:
        raise RuntimeError("voice shim returned a null error string")

    key = bytes(range(32))
    aad = b"discord.mbt voice shim smoke"
    plaintext = b"authenticated transport payload"
    for mode, nonce_length in ((0, 12), (1, 24)):
        nonce = bytes(range(nonce_length))
        ciphertext = call(library, library.vs_aead_seal, mode, key, nonce, aad, plaintext)
        opened = call(library, library.vs_aead_open, mode, key, nonce, aad, ciphertext)
        if opened != plaintext:
            raise RuntimeError(f"mode {mode} did not round-trip")


def call(library, operation, mode: int, key: bytes, nonce: bytes, aad: bytes, data: bytes) -> bytes:
    keepalive = []
    pointers = []
    for value in (key, nonce, aad, data):
        storage, pointer = byte_pointer(value)
        keepalive.append(storage)
        pointers.append(pointer)
    output = ctypes.POINTER(ctypes.c_ubyte)()
    output_length = ctypes.c_size_t()
    status = operation(
        mode,
        pointers[0],
        pointers[1],
        len(nonce),
        pointers[2],
        len(aad),
        pointers[3],
        len(data),
        ctypes.byref(output),
        ctypes.byref(output_length),
    )
    if status != 0:
        raise RuntimeError(f"voice shim operation failed with status {status}")
    try:
        return ctypes.string_at(output, output_length.value)
    finally:
        if output:
            library.vs_free(output, output_length.value)


if __name__ == "__main__":
    main()
