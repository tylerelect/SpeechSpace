"""Seed MongoDB with two years of demo journal data for one Kids and one Adult profile.

* ~2 years of history (mid-Nov 2024 -> mid-Nov 2026). Each week is randomly
  "light" (1 entry), "normal" (3 entries on random days) or "busy" (3-4 days,
  some with 2 entries that day). Yearly events (holidays, birthdays, first day
  of school, reviews, vacations) are added on their dates.
* The last six weeks are hand-written entries (see seed_demo_content.py).
* Every entry is categorized into a per-profile project (the app's `projects`
  collection), and related entries are connected with `links` for the star map.
* Seeds a separate database (default `speechspace_demo`) so the dev database is
  untouched. Point the backend at it with MONGODB_DB=speechspace_demo.
* Deterministic: fixed random seed + uuid5 IDs, so re-running replaces the same
  documents instead of duplicating them.

Usage (from repo root):
    backend/.venv/bin/python scripts/seed_demo_data.py             # seed speechspace_demo
    backend/.venv/bin/python scripts/seed_demo_data.py --db NAME   # seed another database
    backend/.venv/bin/python scripts/seed_demo_data.py --dry-run   # print stats only
    backend/.venv/bin/python scripts/seed_demo_data.py --json out.json
    backend/.venv/bin/python scripts/seed_demo_data.py --remove    # delete seeded docs
"""
from __future__ import annotations

import argparse
import json
import os
import random
import re
import sys
import uuid
from collections import Counter
from datetime import date, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import seed_demo_content as C  # noqa: E402

OWNER = 'prototype-parent'
NAMESPACE = uuid.UUID('5b1f3c3e-2d0a-4c55-9a7e-5eed0000da7a')
HISTORY_START = date(2024, 11, 18)   # a Monday, ~2 years back
HISTORY_END = date(2026, 9, 30)      # hand-written entries take over from Oct 1
LASER_ARRIVES = date(2025, 4, 20)    # kids profile only mentions the cat after this
ONE_OFF_EVENTS = {'Laser came home': 2025, 'Moved apartments': 2025}

KID = {'id': '', 'name': 'Maya', 'kind': 'kids', 'themeId': 'space'}
ADULT = {'id': '', 'name': 'Jordan', 'kind': 'adult', 'themeId': 'indigo'}


def sid(*parts: str) -> str:
    return str(uuid.uuid5(NAMESPACE, '/'.join(parts)))


KID['id'] = sid('profile', 'kid')
ADULT['id'] = sid('profile', 'adult')


def iso(day: date | str) -> str:
    # Matches the Flutter client's DateTime.toIso8601String() for local midnight.
    return f'{day if isinstance(day, str) else day.isoformat()}T00:00:00.000'


class Filler:
    """Fills {slot} placeholders. A slot repeats the same value within one entry
    (so title, body and favorite agree), except C.DISTINCT_SLOTS which cycle."""

    _pat = re.compile(r'\{(\w+)\}')

    def __init__(self, rng: random.Random, slots: dict[str, list[str]]):
        self.pools = {k: rng.sample(v, len(v)) for k, v in slots.items()}
        self.used: Counter = Counter()

    def __call__(self, text: str) -> str:
        def take(m: re.Match) -> str:
            pool = self.pools[m[1]]
            if m[1] not in C.DISTINCT_SLOTS:
                return pool[0]
            self.used[m[1]] += 1
            return pool[(self.used[m[1]] - 1) % len(pool)]
        return self._pat.sub(take, text)


def weekly_days(rng: random.Random, monday: date) -> list[date]:
    """Entry dates for one week, with duplicates meaning two entries that day."""
    week = [monday + timedelta(days=i) for i in range(7)]
    mode = rng.choices(['light', 'normal', 'busy'], weights=[20, 55, 25])[0]
    if mode == 'light':
        return [rng.choice(week)]
    if mode == 'normal':
        return sorted(rng.sample(week, 3))
    days = sorted(rng.sample(week, rng.choice([3, 4])))
    doubles = [d for d in days if rng.random() < 0.35] or [rng.choice(days)]
    return sorted(days + doubles)


def pick_activity(rng: random.Random, activities: list[dict], day: date, exclude: set[int],
                  kids: bool) -> int:
    weekend = day.weekday() >= 5
    ok = []
    for i, a in enumerate(activities):
        if i in exclude or (a['months'] and day.month not in a['months']):
            continue
        if (a['days'] == 'weekday' and weekend) or (a['days'] == 'weekend' and not weekend):
            continue
        if kids and day < LASER_ARRIVES and a['category'] == 'Pets':
            continue
        ok.append(i)
    return rng.choices(ok, weights=[activities[i]['weight'] for i in ok])[0]


def mentions_laser(v: dict) -> bool:
    return 'Laser' in json.dumps(v)


def compose(rng: random.Random, a: dict, slots: dict, day: date, kids: bool) -> dict:
    variants = a['variants']
    if kids and day < LASER_ARRIVES:
        variants = [v for v in variants if not mentions_laser(v)] or variants
    v = rng.choice(variants)
    f = Filler(rng, slots)
    lines = [v['opener'], *rng.sample(v['details'], min(len(v['details']), rng.choice([1, 2, 2])))]
    if a['extras'] and rng.random() < 0.35:
        lines.append(rng.choice(a['extras']))
    body = f(' '.join(lines))
    # Only favorites that echo something actually in the body.
    words = set(re.findall(r'[a-z]{4,}', body.lower()))
    fits = [x for x in map(f, v['favorites']) if x and set(re.findall(r'[a-z]{4,}', x.lower())) & words]
    favorite = rng.choice(fits) if fits and rng.random() < 0.85 else ''
    favorite = favorite[:1].upper() + favorite[1:250]
    title = f(rng.choice(v['titles']))
    return {
        'title': title[0].upper() + title[1:100],
        'body': body,
        'favorite': favorite,
        'highlight': re.split(r'(?<=[.!?])\s', body)[0][:500],
        'isMilestone': rng.random() < 0.03,
        'tags': a['tags'][:3],
        'category': a['category'],
        'activity': a['category'] + '/' + v['titles'][0],
    }


def generate(rng: random.Random, profile: dict, activities: list[dict], events: list,
             slots: dict) -> list[dict]:
    kids = profile['kind'] == 'kids'
    out: list[dict] = []
    per_day: Counter = Counter()

    # Yearly events first so they claim their days.
    for year in (2024, 2025, 2026):
        for month, dom, category, title, body, fav, milestone, tags in events:
            if ONE_OFF_EVENTS.get(title, year) != year:
                continue
            day = date(year, month, dom)
            if not (HISTORY_START <= day <= HISTORY_END):
                continue
            f = Filler(rng, slots)
            out.append({'day': day, 'title': title, 'body': f(body), 'favorite': f(fav),
                        'highlight': re.split(r'(?<=[.!?])\s', f(body))[0], 'isMilestone': milestone,
                        'tags': tags, 'category': category, 'activity': 'event:' + title})
            per_day[day] += 1

    monday = HISTORY_START
    while monday <= HISTORY_END:
        used_today: dict[date, set[int]] = {}
        for day in weekly_days(rng, monday):
            if day > HISTORY_END or per_day[day] >= 2:
                continue
            exclude = used_today.setdefault(day, set())
            i = pick_activity(rng, activities, day, exclude, kids)
            exclude.add(i)
            out.append({'day': day, **compose(rng, activities[i], slots, day, kids)})
            per_day[day] += 1
        monday += timedelta(days=7)
    out.sort(key=lambda e: e['day'])
    return out


def build(seed: int = 2026) -> dict[str, list[dict]]:
    rng = random.Random(seed)
    data: dict[str, list[dict]] = {'children': [], 'projects': [], 'entries': [], 'links': []}

    for profile, cats, activities, events, slots, written, written_links in (
        (KID, C.KID_CATEGORIES, C.KID_ACTIVITIES, C.KID_EVENTS, C.KID_SLOTS, C.KID_ENTRIES, C.KID_LINKS),
        (ADULT, C.ADULT_CATEGORIES, C.ADULT_ACTIVITIES, C.ADULT_EVENTS, C.ADULT_SLOTS, C.ADULT_ENTRIES,
         C.ADULT_LINKS),
    ):
        kind = profile['kind']
        data['children'].append(dict(profile, ownerId=OWNER))
        project_ids = {name: sid('project', kind, name) for name in cats}
        data['projects'] += [{'id': pid, 'ownerId': OWNER, 'profileId': profile['id'], 'name': name}
                             for name, pid in project_ids.items()]

        def entry_doc(eid: str, day, e: dict) -> dict:
            assert len(e['title']) <= 100 and len(e['favorite']) <= 250 and len(e['tags']) <= 8
            return {'id': eid, 'ownerId': OWNER, 'childId': profile['id'],
                    'projectId': project_ids[e['category']], 'date': iso(day), 'title': e['title'],
                    'body': e['body'], 'favorite': e['favorite'], 'highlight': e['highlight'],
                    'isMilestone': e['isMilestone'], 'tags': e['tags']}

        def link(a: str, b: str, label: str) -> None:
            data['links'].append({'id': sid('link', a, b), 'ownerId': OWNER, 'childId': profile['id'],
                                  'fromId': a, 'toId': b, 'label': label})

        # Generated history, linking some entries to an earlier one of the same activity.
        last_by_activity: dict[str, tuple[str, date]] = {}
        seen_day: Counter = Counter()
        for e in generate(rng, profile, activities, events, slots):
            seen_day[e['day']] += 1
            eid = sid('entry', kind, e['day'].isoformat(), str(seen_day[e['day']]))
            data['entries'].append(entry_doc(eid, e['day'], e))
            prev = last_by_activity.get(e['activity'])
            if e['activity'].startswith('event:') and prev:
                link(prev[0], eid, 'every year')
            elif prev and (e['day'] - prev[1]).days <= 21 and rng.random() < 0.25:
                link(prev[0], eid, e['category'].lower())
            last_by_activity[e['activity']] = (eid, e['day'])

        # Hand-written recent entries.
        for key, day, category, title, body, fav, hl, ms, tags in written:
            e = {'category': category, 'title': title, 'body': body, 'favorite': fav,
                 'highlight': hl, 'isMilestone': ms, 'tags': tags}
            data['entries'].append(entry_doc(sid('entry', kind, key), day, e))
        for a, b, label in written_links:
            link(sid('entry', kind, a), sid('entry', kind, b), label)
    return data


def stats(data: dict) -> None:
    for name, docs in data.items():
        print(f'{name}: {len(docs)}')
    for profile in (KID, ADULT):
        entries = [e for e in data['entries'] if e['childId'] == profile['id']]
        names = {p['id']: p['name'] for p in data['projects']}
        days = Counter(e['date'][:10] for e in entries)
        weeks = Counter(date.fromisoformat(d).isocalendar()[:2] for d in days.elements())
        print(f"\n{profile['name']} ({profile['kind']}): {len(entries)} entries, "
              f"{entries[0]['date'][:10]} .. {max(e['date'] for e in entries)[:10]}")
        print('  entries/week:', dict(sorted(Counter(weeks.values()).items())),
              '| days with 2 entries:', sum(1 for v in days.values() if v == 2),
              '| milestones:', sum(e['isMilestone'] for e in entries))
        for pid, n in Counter(e['projectId'] for e in entries).most_common():
            print(f'  {names[pid]:<24}{n}')


def connect(db_name: str | None):
    from dotenv import load_dotenv
    from pymongo import ASCENDING, MongoClient

    root = Path(__file__).resolve().parent.parent
    load_dotenv(root / '.env')
    load_dotenv(root / 'backend' / '.env')
    uri = os.getenv('MONGODB_URI')
    if not uri:
        sys.exit('MONGODB_URI is not set (.env).')
    database = MongoClient(uri, serverSelectionTimeoutMS=8000)[db_name]
    # Same indexes as backend/app.py ensure_indexes().
    for coll in ('children', 'projects', 'entries', 'links'):
        database[coll].create_index([('ownerId', ASCENDING), ('id', ASCENDING)], unique=True)
    database.children.create_index([('ownerId', ASCENDING), ('kind', ASCENDING)])
    database.projects.create_index([('ownerId', ASCENDING), ('profileId', ASCENDING)])
    database.entries.create_index([('ownerId', ASCENDING), ('childId', ASCENDING), ('date', ASCENDING)])
    database.entries.create_index([('ownerId', ASCENDING), ('projectId', ASCENDING)])
    database.links.create_index([('ownerId', ASCENDING), ('childId', ASCENDING)])
    return database


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--db', default='speechspace_demo', help='target database (default: speechspace_demo)')
    ap.add_argument('--dry-run', action='store_true', help='print stats, do not touch the database')
    ap.add_argument('--json', metavar='PATH', help='write the generated documents to a JSON file')
    ap.add_argument('--remove', action='store_true', help='delete only the documents this script creates')
    args = ap.parse_args()

    data = build()
    stats(data)
    if args.json:
        Path(args.json).write_text(json.dumps(data, indent=2))
        print(f'\nwrote {args.json}')
    if args.dry_run or args.json:
        return

    database = connect(args.db)
    for name, docs in data.items():
        database[name].delete_many({'ownerId': OWNER, 'id': {'$in': [d['id'] for d in docs]}})
        if not args.remove:
            database[name].insert_many([dict(d) for d in docs])
    print(f"\n{'removed' if args.remove else 'seeded'} demo data in {database.name}")


if __name__ == '__main__':
    main()
