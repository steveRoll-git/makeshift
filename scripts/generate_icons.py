import os
import shutil
import subprocess
import sys

OUTPUT_ICON_FILE = "src/images/icons/{0}_{1}.png"

rsvg_path = shutil.which("rsvg-convert")
if not rsvg_path:
    print("rsvg-convert not found - please make sure librsvg is installed and available in your PATH.")
    sys.exit(1)

def generate_icons():

    def icon(iconName: str, *sizes: int):
        fileName = f"assets/icons/{iconName}.svg"
        for size in sizes:
            with open(OUTPUT_ICON_FILE.format(iconName, size), "w") as outfile:
                subprocess.run([rsvg_path, "-h", str(size), fileName], stdout=outfile)

    os.makedirs(os.path.dirname(OUTPUT_ICON_FILE), exist_ok=True)

    icon("arrow_back", 24)
    icon("brush", 24)
    icon("bucket", 48)
    icon("cancel", 32)
    icon("close", 18)
    icon("code", 24)
    icon("edit", 48)
    icon("eraser", 48)
    icon("error_stopped", 32)
    icon("game", 24)
    icon("hourglass", 32)
    icon("library", 24)
    icon("line_weight", 24)
    icon("object_add", 24)
    icon("object", 14)
    icon("open_in_new", 24)
    icon("properties", 14)
    icon("scene", 24)
    icon("zoom_in", 14)

if __name__ == "__main__":
    generate_icons()