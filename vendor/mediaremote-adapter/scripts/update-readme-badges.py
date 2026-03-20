#!/usr/bin/env python3

import subprocess
import urllib.parse
import os
import re


STATIC_BADGES = """
![](https://img.shields.io/github/stars/ungive/mediaremote-adapter?style=flat&label=stars&logo=github&labelColor=444&color=DAAA3F&cacheSeconds=3600)
"""


def get_output(command):
    result = subprocess.run(
        command,
        shell=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
    )
    return result.stdout.strip()


def normalize_whitespace(text):
    return re.sub(r'\s+', ' ', text.strip())


def generate_badges():
    system_version = get_output(
        "system_profiler SPSoftwareDataType | sed -En 's/.*System Version: *//p'"
    )
    date_output = normalize_whitespace(get_output("date"))
    encoded_system_version = urllib.parse.quote(system_version)
    encoded_date = urllib.parse.quote(date_output)
    badge1 = f"![](https://img.shields.io/static/v1?label=macOS&message={encoded_system_version}&labelColor=444&color=blue)"
    badge2 = f"![](https://img.shields.io/static/v1?label=last%20tested&message={encoded_date}&labelColor=444&color)"
    return f"{STATIC_BADGES.strip()}\n{badge1}\n{badge2}"


def update_readme(script_dir, new_badges):
    readme_path = os.path.join(script_dir, "..", "README.md")
    with open(readme_path, "r") as file:
        content = file.read()
    new_content = re.sub(
        r"<!-- BADGES BEGIN -->.*?<!-- BADGES END -->",
        f"<!-- BADGES BEGIN -->\n{new_badges}\n<!-- BADGES END -->",
        content,
        flags=re.DOTALL,
    )
    with open(readme_path, "w") as file:
        file.write(new_content)


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    badges = generate_badges()
    update_readme(script_dir, badges)


if __name__ == "__main__":
    main()
