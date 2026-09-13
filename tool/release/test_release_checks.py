import io
import struct
import tempfile
import unittest
import zipfile
from unittest.mock import patch

import check_native_alignment
import check_public_site


def elf(alignment):
    data = bytearray(120)
    data[:6] = b'\x7fELF\x02\x01'
    struct.pack_into('<Q', data, 32, 64)
    struct.pack_into('<HH', data, 54, 56, 1)
    struct.pack_into('<IIQQQQQQ', data, 64, 1, 5, 0, 0, 0, 0, 0, alignment)
    return data


class ReleaseChecksTest(unittest.TestCase):
    def test_16kb_load_segment(self):
        check_native_alignment.check_elf(elf(16384))

    def test_4kb_and_invalid_alignment_rejected(self):
        for alignment in (4096, 24576):
            with self.subTest(alignment=alignment), self.assertRaises(ValueError):
                check_native_alignment.check_elf(elf(alignment))

    def test_aab_checks_every_library(self):
        with tempfile.NamedTemporaryFile(suffix='.aab') as archive:
            with zipfile.ZipFile(archive.name, 'w') as bundle:
                bundle.writestr('base/lib/arm64-v8a/libflutter.so', elf(16384))
                bundle.writestr('base/lib/x86_64/vendor.so', elf(4096))
            with self.assertRaisesRegex(ValueError, 'vendor.so'):
                check_native_alignment.main(archive.name)

    def test_missing_native_libraries_rejected(self):
        with tempfile.NamedTemporaryFile(suffix='.aab') as archive:
            with zipfile.ZipFile(archive.name, 'w'):
                pass
            with self.assertRaisesRegex(ValueError, 'No 64-bit'):
                check_native_alignment.main(archive.name)

    def test_generic_success_page_is_not_a_privacy_policy(self):
        def response(*args, **kwargs):
            item = io.BytesIO(b'Unrecorded - page not found')
            item.status = 200
            return item

        with patch.object(check_public_site, 'urlopen', side_effect=response):
            with self.assertRaisesRegex(RuntimeError, 'privacy.html'):
                check_public_site.main()



if __name__ == '__main__':
    unittest.main()
