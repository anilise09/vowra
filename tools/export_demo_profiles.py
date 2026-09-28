"""Exports the app's bundled synthetic profiles (lib/main.dart) to
backend/fixtures/demo_profiles.json for the local test server's seed script.

Synthetic people only: the portraits are generated art bundled in the app.
Run from the repository root: python tools/export_demo_profiles.py
"""
import io
import json
import re

SRC = 'lib/main.dart'
OUT = 'backend/fixtures/demo_profiles.json'

STR = r"'((?:[^'\\]|\\.)*)'"
ENTRY = re.compile(
    r"DemoProfile\(\s*" + STR + r",\s*(\d+),\s*" + STR + r",\s*" + STR + r",\s*"
    + STR + r",\s*\[([^\]]*)\],\s*'([^']+)'(?:,\s*" + STR + r")?,?\s*\)",
    re.S,
)


def unescape(text):
    return text.replace("\\'", "'")


def main():
    src = io.open(SRC, encoding='utf-8').read()
    block = src[src.index('static const profiles = ['):]
    block = block[: block.index('\n  ];')]
    people = []
    for m in ENTRY.finditer(block):
        name, age, intent, _band, bio, interests, portrait, _background = m.groups()
        people.append({
            'name': unescape(name),
            'age': int(age),
            'intent_label': unescape(intent),
            'bio': unescape(bio),
            'interests': [unescape(i) for i in re.findall(STR, interests)],
            'portrait': portrait,
        })
    expected = block.count('DemoProfile(')
    if len(people) != expected:
        raise SystemExit(f'parsed {len(people)} of {expected} profiles; fix the pattern')
    io.open(OUT, 'w', encoding='utf-8', newline='\n').write(
        json.dumps(people, ensure_ascii=False, indent=1) + '\n')
    print(len(people), 'profiles ->', OUT)


if __name__ == '__main__':
    main()
