import tempfile
import unittest
from pathlib import Path

from scripts.patches.patch_cmake import patch_cmake
from scripts.patches.patch_jcef_tools import patch_make_readme


class PatchCMakeTests(unittest.TestCase):
    def test_replaces_platform_block(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "CMakeLists.txt"
            patch = root / "patch.txt"
            source.write_text(
                "before\n# Determine the platform.\nold\n"
                "# Add this project's cmake/ directory.\nafter\n",
                encoding="utf-8",
            )
            patch.write_text(
                "# Determine the platform.\n"
                "set(A linuxarm64)\nset(B windowsarm64)\nset(C macosarm64)\n",
                encoding="utf-8",
            )

            patch_cmake(source, patch)

            result = source.read_text(encoding="utf-8")
            self.assertNotIn("old", result)
            self.assertIn("linuxarm64", result)
            self.assertIn("# Add this project's cmake/ directory.", result)

    def test_rejects_missing_markers(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "CMakeLists.txt"
            patch = root / "patch.txt"
            source.write_text("no platform block\n", encoding="utf-8")
            patch.write_text("# Determine the platform.\n", encoding="utf-8")

            with self.assertRaises(RuntimeError):
                patch_cmake(source, patch)


class PatchJcefToolsTests(unittest.TestCase):
    def test_patches_current_make_readme_shape(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "make_readme.py"
            path.write_text(
                "import os\n"
                "write_file(os.path.join(output_dir, 'README.txt'), data.encode('utf-8'))\n"
                "read_readme_file(os.path.join(jcef_dir, 'jcef_build', 'README.txt'), args)\n",
                encoding="utf-8",
            )

            changes = patch_make_readme(path)
            result = path.read_text(encoding="utf-8")

            self.assertEqual(3, len(changes))
            self.assertIn("import glob", result)
            self.assertNotIn("data.encode('utf-8')", result)
            self.assertIn("readme_sources", result)


if __name__ == "__main__":
    unittest.main()
