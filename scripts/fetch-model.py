#!/usr/bin/env python3
"""Download the tested Apple model using this Mac's Clean Up asset catalog."""
import hashlib
import pathlib
import plistlib
import shutil
import subprocess
import tempfile

root = pathlib.Path(__file__).resolve().parent.parent
output = root / "Models/inpainting.mlmodelc"
catalog = pathlib.Path(
    "/System/Library/AssetsV2/com_apple_MobileAsset_UAF_Photos_MagicCleanup/"
    "purpose_auto/com_apple_MobileAsset_UAF_Photos_MagicCleanup.xml"
)
if output.exists():
    raise SystemExit(f"Already present: {output}")
if not catalog.exists():
    raise SystemExit("Open Photos > Edit > Clean Up on this Mac to download its asset catalog, then try again.")
assets = plistlib.loads(catalog.read_bytes())["Assets"]
asset = next((a for a in assets if a.get("AssetVersion") == "6.0.81607.13.202356,0"), None)
if asset is None:
    raise SystemExit("This Mac's catalog does not contain the tested MagicCleanup 6.0.81607 model.")

with tempfile.TemporaryDirectory(prefix="cleanup-model-") as directory:
    temp = pathlib.Path(directory)
    archive = temp / "model.aea"
    subprocess.run(["curl", "--fail", "--location", "--output", str(archive),
                    asset["__BaseURL"] + asset["__RelativePath"]], check=True)
    digest = hashlib.sha256()
    with archive.open("rb") as file:
        for block in iter(lambda: file.read(1024 * 1024), b""):
            digest.update(block)
    if digest.hexdigest() != "c3b23edffb1576fafc536391b20ebd7d0d8b9f82a4c55d3824522f764ddc6864":
        raise SystemExit("The downloaded model archive does not match the tested version.")
    subprocess.run(["aea", "decrypt", "-i", str(archive), "-o", str(temp / "model.aar"),
                    "-key-value", "base64:" + asset["ArchiveDecryptionKey"]], check=True)
    (temp / "empty").mkdir()
    subprocess.run(["aa", "patch", "-i", str(temp / "model.aar"),
                    "-src", str(temp / "empty"), "-dst", str(temp / "asset")], check=True)
    dmg = next((temp / "asset/AssetData/Restore").glob("*.dmg"))
    mount = temp / "mounted"
    mount.mkdir()
    subprocess.run(["hdiutil", "attach", str(dmg), "-readonly", "-nobrowse",
                    "-mountpoint", str(mount)], check=True)
    try:
        model = next(mount.rglob("inpainting.mlmodelc"))
        output.parent.mkdir(exist_ok=True)
        shutil.copytree(model, output)
    finally:
        subprocess.run(["hdiutil", "detach", str(mount)], check=True)
print(output)
