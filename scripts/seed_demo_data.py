"""Seed MongoDB with two years of demo journal data.

Profiles: four kids (Matthew, Luke, Andy, Sunny; see seed_demo_kids.py) and
one adult (Jordan; see seed_demo_content.py).

* ~2 years of history per profile (mid-Nov 2024 -> Nov 14, 2026). Each week
  is randomly "light" (1 entry), "normal" (3 entries on random days) or "busy"
  (3-4 days, some with 2 entries that day). Yearly events (holidays,
  birthdays, school days, reviews) land on their dates.
* Hand-written entries fill their own weeks first; generated entries make up
  the rest of that week's count.
* Every entry is categorized into a per-profile project (the app's `projects`
  collection); related entries are connected with `links` for the star map.
* Seeds a separate database (default `speechspace_demo`). Point the backend at
  it with MONGODB_DB=speechspace_demo.
* Entry text comes from scripts/seed_data/<profile>.json when present
  (authored per slot; see --export-slots), otherwise from the templates.
* Deterministic (fixed seed + uuid5 IDs). Re-running first deletes everything
  belonging to the seeded profiles (and the retired "Maya" profile), so there
  are never stale or duplicate documents. Other profiles are not touched.

Usage (from repo root):
    backend/.venv/bin/python scripts/seed_demo_data.py             # seed speechspace_demo
    backend/.venv/bin/python scripts/seed_demo_data.py --db NAME   # seed another database
    backend/.venv/bin/python scripts/seed_demo_data.py --dry-run   # print stats only
    backend/.venv/bin/python scripts/seed_demo_data.py --json out.json
    backend/.venv/bin/python scripts/seed_demo_data.py --remove    # delete seeded profiles
"""
from __future__ import annotations

import argparse
import json
import os
import random
import re
import sys
import uuid
from collections import Counter, defaultdict
from datetime import date, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import seed_demo_content as C  # noqa: E402
from seed_demo_kids import KIDS  # noqa: E402

OWNER = 'prototype-parent'
NAMESPACE = uuid.UUID('5b1f3c3e-2d0a-4c55-9a7e-5eed0000da7a')
HISTORY_START = date(2024, 11, 18)   # a Monday, ~2 years back
HISTORY_END = date(2026, 11, 14)
PROFILES = KIDS + [C.ADULT]
RECENT_WINDOW = 8                    # avoid reusing a story seen in the last N entries
AUTHORED_DIR = Path(__file__).resolve().parent / 'seed_data'


def sid(*parts: str) -> str:
    return str(uuid.uuid5(NAMESPACE, '/'.join(parts)))


def profile_id(p: dict) -> str:
    # 'adult' keeps the ID it had in the first version of this script.
    return sid('profile', p['key'])


RETIRED_PROFILE_IDS = [sid('profile', 'kid')]  # "Maya", replaced by the four kids


def iso(day: date) -> str:
    # Matches the Flutter client's DateTime.toIso8601String() for local midnight.
    return f'{day.isoformat()}T00:00:00.000'


def first_sentence(text: str) -> str:
    return re.split(r'(?<=[.!?])\s', text)[0][:500]


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


def week_slots(rng: random.Random, monday: date) -> list[date]:
    """Entry dates for one week; a repeated date means two entries that day."""
    week = [monday + timedelta(days=i) for i in range(7)]
    mode = rng.choices(['light', 'normal', 'busy'], weights=[20, 55, 25])[0]
    if mode == 'light':
        return [rng.choice(week)]
    if mode == 'normal':
        return sorted(rng.sample(week, 3))
    days = sorted(rng.sample(week, rng.choice([3, 4])))
    doubles = [d for d in days if rng.random() < 0.35] or [rng.choice(days)]
    return sorted(days + doubles)


class Writer:
    """Generates entries for one profile."""

    def __init__(self, rng: random.Random, profile: dict):
        self.rng, self.p = rng, profile
        self.recent: list[str] = []

    def hidden(self, obj, day: date) -> bool:
        """True if obj mentions something (e.g. the kitten) not introduced yet on `day`."""
        text = json.dumps(obj)
        return any(term in text and day < since for term, since in self.p['introduced'].items())

    def activity_ok(self, a: dict, day: date, taken: set[int], i: int) -> bool:
        if i in taken or (a['months'] and day.month not in a['months']):
            return False
        weekend = day.weekday() >= 5
        if (a['days'] == 'weekday' and weekend) or (a['days'] == 'weekend' and not weekend):
            return False
        return any(not self.hidden(v, day) for v in a['variants'])

    def entry(self, day: date, taken: set[int]) -> dict:
        rng, acts = self.rng, self.p['activities']
        ok = [i for i, a in enumerate(acts) if self.activity_ok(a, day, taken, i)]
        i = rng.choices(ok, weights=[acts[i]['weight'] for i in ok])[0]
        taken.add(i)
        a = acts[i]
        variants = [v for v in a['variants'] if not self.hidden(v, day)]
        weights = [v['w'] * (0.35 if v['titles'][0] in self.recent else 1) for v in variants]
        v = rng.choices(variants, weights=weights)[0]
        self.recent = (self.recent + [v['titles'][0]])[-RECENT_WINDOW:]

        f = Filler(rng, self.p['slots'])
        lines = [v['opener'], *rng.sample(v['details'], min(len(v['details']), rng.choice([1, 2, 2])))]
        extras = [x for x in a['extras'] if not self.hidden(x, day)]
        if extras and rng.random() < 0.35:
            lines.append(rng.choice(extras))
        body = f(' '.join(lines))
        # Only favorites that echo something actually in the body.
        words = set(re.findall(r'[a-z]{4,}', body.lower()))
        fits = [x for x in map(f, v['favorites']) if x and set(re.findall(r'[a-z]{4,}', x.lower())) & words]
        favorite = rng.choice(fits) if fits and rng.random() < 0.85 else ''
        title = f(rng.choice(v['titles']))
        return {'title': title[:1].upper() + title[1:100], 'body': body,
                'favorite': favorite[:1].upper() + favorite[1:250], 'highlight': first_sentence(body),
                'isMilestone': rng.random() < 0.03, 'tags': a['tags'][:3], 'category': a['category'],
                'thread': a['category'] + '/' + v['titles'][0]}

    def event(self, day: date, ev: tuple) -> dict:
        _, _, category, title, body, fav, milestone, tags, *_ = ev
        f = Filler(self.rng, self.p['slots'])
        text = f(body)
        return {'title': title, 'body': text, 'favorite': f(fav), 'highlight': first_sentence(text),
                'isMilestone': milestone, 'tags': tags, 'category': category, 'thread': 'event:' + title}


def generate(rng: random.Random, p: dict) -> list[dict]:
    """All entries for one profile, as dicts with a 'day' and a stable 'key'."""
    w = Writer(rng, p)
    out: list[dict] = []

    written_by_week: dict[date, list[dict]] = defaultdict(list)
    for key, day, category, title, body, fav, hl, ms, tags in p['written']:
        d = date.fromisoformat(day)
        written_by_week[d - timedelta(days=d.weekday())].append(
            {'day': d, 'key': key, 'title': title, 'body': body, 'favorite': fav, 'highlight': hl,
             'isMilestone': ms, 'tags': tags, 'category': category, 'thread': 'written:' + key})

    events_by_day: dict[date, list[tuple]] = defaultdict(list)
    for ev in p['events']:
        only_year = ev[8] if len(ev) > 8 else None
        for year in range(HISTORY_START.year, HISTORY_END.year + 1):
            d = date(year, ev[0], ev[1])
            if HISTORY_START <= d <= HISTORY_END and only_year in (None, year):
                events_by_day[d].append(ev)

    monday = HISTORY_START
    while monday <= HISTORY_END:
        written = written_by_week.get(monday, [])
        slots = [d for d in week_slots(rng, monday) if d <= HISTORY_END][len(written):]
        per_day: Counter = Counter(e['day'] for e in written)
        week: list[dict] = list(written)
        for d in sorted(events_by_day):
            if monday <= d < monday + timedelta(days=7) and per_day[d] < 2:
                for ev in events_by_day[d][:2 - per_day[d]]:
                    week.append({'day': d, **w.event(d, ev)})
                    per_day[d] += 1
        taken: dict[date, set[int]] = defaultdict(set)
        for d in slots:
            if per_day[d] < 2:
                week.append({'day': d, **w.entry(d, taken[d])})
                per_day[d] += 1
        seq: Counter = Counter()
        for e in sorted(week, key=lambda e: e['day']):
            seq[e['day']] += 1
            e.setdefault('key', f"{e['day'].isoformat()}/{seq[e['day']]}")
            out.append(e)
        monday += timedelta(days=7)
    return out


def schedule(p: dict, seed: int = 2026) -> list[dict]:
    """Deterministic per-profile schedule (template text included as a fallback/hint)."""
    return generate(random.Random(f'{seed}/{p["key"]}'), p)


def load_authored(p: dict, slots: list[dict]) -> tuple[dict[str, dict], list[dict]] | None:
    """Hand/agent-authored entries in seed_data/<key>.json, keyed by slot key."""
    path = AUTHORED_DIR / f"{p['key']}.json"
    if not path.exists():
        return None
    doc = json.loads(path.read_text())
    entries = {e['key']: e for e in doc['entries']}
    wanted = {s['key'] for s in slots}
    missing, extra = wanted - entries.keys(), entries.keys() - wanted
    if missing or extra:
        sys.exit(f"{path.name}: {len(missing)} missing / {len(extra)} unknown slot keys, e.g. "
                 f"{sorted(missing)[:3]} {sorted(extra)[:3]}")
    return entries, doc.get('links', [])


def export_slots(out_dir: Path) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    for p in PROFILES:
        slots = schedule(p)
        rows = []
        for e in slots:
            kind = ('written' if e['thread'].startswith('written:') else
                    'event' if e['thread'].startswith('event:') else 'regular')
            row = {'key': e['key'], 'date': e['day'].isoformat(), 'weekday': e['day'].strftime('%A'),
                   'kind': kind, 'category': e['category'], 'isMilestone': e['isMilestone']}
            if kind == 'regular':
                row['idea'] = e['title'] + ': ' + e['body']
            else:
                row.update(title=e['title'], body=e['body'], favorite=e['favorite'], tags=e['tags'])
            rows.append(row)
        doc = {'key': p['key'], 'name': p['name'], 'kind': p['kind'], 'categories': p['categories'],
               'slots': rows}
        (out_dir / f"{p['key']}.slots.json").write_text(json.dumps(doc, indent=1))
        print(f"{p['name']}: {len(rows)} slots -> {out_dir / (p['key'] + '.slots.json')}")


def build(seed: int = 2026) -> dict[str, list[dict]]:
    rng = random.Random(f'{seed}/links')
    data: dict[str, list[dict]] = {'children': [], 'projects': [], 'entries': [], 'links': []}

    for p in PROFILES:
        pid = profile_id(p)
        data['children'].append({'id': pid, 'ownerId': OWNER, 'name': p['name'], 'kind': p['kind'],
                                 'themeId': p['themeId']})
        projects = {name: sid('project', p['key'], name) for name in p['categories']}
        data['projects'] += [{'id': x, 'ownerId': OWNER, 'profileId': pid, 'name': n} for n, x in projects.items()]

        def link(a: str, b: str, label: str) -> None:
            data['links'].append({'id': sid('link', a, b), 'ownerId': OWNER, 'childId': pid,
                                  'fromId': a, 'toId': b, 'label': label})

        last: dict[str, tuple[str, date]] = {}
        keys: dict[str, str] = {}
        slots = schedule(p, seed)
        authored = load_authored(p, slots)
        for e in slots:
            if authored:
                a = authored[0][e['key']]
                e = {**e, **{k: a[k] for k in ('title', 'body', 'favorite', 'highlight', 'isMilestone', 'tags')},
                     'category': a.get('category', e['category'])}
            assert e['category'] in projects, (p['name'], e['category'])
            assert len(e['title']) <= 100 and len(e['tags']) <= 8 and e['body'].strip()
            eid = sid('entry', p['key'], e['key'])
            keys[e['key']] = eid
            data['entries'].append({'id': eid, 'ownerId': OWNER, 'childId': pid,
                                    'projectId': projects[e['category']], 'date': iso(e['day']),
                                    'title': e['title'], 'body': e['body'], 'favorite': e['favorite'],
                                    'highlight': e['highlight'], 'isMilestone': e['isMilestone'],
                                    'tags': e['tags']})
            prev = last.get(e['thread'])
            if prev and e['thread'].startswith('event:'):
                link(prev[0], eid, 'every year')
            elif prev and not authored and (e['day'] - prev[1]).days <= 30 and rng.random() < 0.3:
                link(prev[0], eid, e['category'].lower())
            last[e['thread']] = (eid, e['day'])
        pairs = [(x['from'], x['to'], x['label']) for x in authored[1]] if authored else []
        for a, b, label in pairs + list(p['links']):
            if sid('link', keys[a], keys[b]) not in {x['id'] for x in data['links']}:
                link(keys[a], keys[b], label)
    return data


def stats(data: dict) -> None:
    print({name: len(docs) for name, docs in data.items()})
    names = {p['id']: p['name'] for p in data['projects']}
    for child in data['children']:
        entries = [e for e in data['entries'] if e['childId'] == child['id']]
        days = Counter(e['date'][:10] for e in entries)
        weeks = Counter(date.fromisoformat(d).isocalendar()[:2] for d in days.elements())
        cats = Counter(names[e['projectId']] for e in entries)
        titles = Counter(e['title'] for e in entries).most_common(3)
        print(f"\n{child['name']} ({child['kind']}): {len(entries)} entries, "
              f"{min(days)} .. {max(days)}, {sum(e['isMilestone'] for e in entries)} milestones")
        print('  entries/week:', dict(sorted(Counter(weeks.values()).items())),
              '| days with 2 entries:', sum(1 for v in days.values() if v == 2))
        print('  ' + ', '.join(f'{n} {c}' for n, c in cats.most_common()))
        print('  most repeated titles:', ', '.join(f'{t} x{n}' for t, n in titles))


def connect(db_name: str):
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
    ap.add_argument('--export-slots', metavar='DIR', help='write each profile\'s schedule for authoring')
    ap.add_argument('--remove', action='store_true', help='delete the seeded profiles and everything in them')
    args = ap.parse_args()

    if args.export_slots:
        export_slots(Path(args.export_slots))
        return
    data = build()
    stats(data)
    if args.json:
        Path(args.json).write_text(json.dumps(data, indent=2))
        print(f'\nwrote {args.json}')
    if args.dry_run or args.json:
        return

    database = connect(args.db)
    ids = [c['id'] for c in data['children']] + RETIRED_PROFILE_IDS
    database.children.delete_many({'ownerId': OWNER, 'id': {'$in': ids}})
    database.projects.delete_many({'ownerId': OWNER, 'profileId': {'$in': ids}})
    database.entries.delete_many({'ownerId': OWNER, 'childId': {'$in': ids}})
    database.links.delete_many({'ownerId': OWNER, 'childId': {'$in': ids}})
    if not args.remove:
        for name, docs in data.items():
            database[name].insert_many([dict(d) for d in docs])
    print(f"\n{'removed' if args.remove else 'seeded'} demo profiles in {database.name}")


if __name__ == '__main__':
    main()
