"""Shared template helpers and the Adult profile for scripts/seed_demo_data.py.

The four kids profiles live in seed_demo_kids.py. The adult (Jordan) is
day-in-the-life material: commuting, work, groceries, errands, health, family.

Activity: dict(category, months (None = any), days ('weekday'|'weekend'|'any'),
weight, tags, extras, variants). Each variant V(...) is one coherent story
(title, opener, details, favorites). {slot} placeholders come from the
profile's slots table. Events: (month, day, category, title, body, favorite,
milestone, tags[, only_year]).
"""

# ---------------------------------------------------------------------------
# Adult profile categories (stored as `projects`)
# ---------------------------------------------------------------------------

ADULT_CATEGORIES = ['Work', 'Home & Errands', 'Groceries & Cooking', 'Health',
                    'Family & Friends', 'Money', 'Travel & Fun']

# ---------------------------------------------------------------------------
# Hand-written recent entries (Oct-Nov 2026)
# (key, date, category, title, body, favorite, highlight, milestone, tags)
# ---------------------------------------------------------------------------

ADULT_ENTRIES = [
    ('commute', '2026-10-01', 'Work', 'Train was late again',
     'Left at 7:40 for the 8:05 train, which showed up at 8:25. Used the wait to clear my inbox. '
     'Standup ran long because the release got pushed. Ate lunch at my desk, which I keep promising to stop doing.',
     'Clearing my inbox on the platform', 'Late train, long standup, release pushed.', False,
     ['commute', 'work']),
    ('groceries-1', '2026-10-03', 'Groceries & Cooking', 'Saturday grocery run',
     'Went to the store at 9 before it got busy. Got eggs, spinach, chicken thighs, rice, oat milk, bananas, and coffee. '
     'Forgot the dish soap, which was the main reason I went. Spent $84.',
     'Getting there before the crowd', 'Weekly groceries, forgot dish soap.', False,
     ['groceries', 'weekend']),
    ('meal-prep', '2026-10-04', 'Groceries & Cooking', 'Meal prep Sunday',
     'Cooked a big pot of rice, roasted chicken and broccoli, and portioned out five lunches. Took about two hours '
     'with a podcast on. Kitchen looks like a disaster but weekday me will be grateful.',
     'Podcast while cooking', 'Prepped five lunches for the week.', False,
     ['cooking', 'routine']),
    ('one-on-one', '2026-10-06', 'Work', '1:1 with my manager',
     'Talked through the roadmap and I brought up wanting to lead the onboarding redesign. Dana said yes, '
     'pending the Q4 plan. Felt good to ask for it directly instead of hinting.',
     'Asking directly', 'Asked to lead the onboarding redesign; tentatively approved.', True,
     ['career', 'work', 'meetings']),
    ('gym', '2026-10-07', 'Health', 'Back to the gym',
     'First gym session in three weeks. Kept it light: 20 minutes on the bike, some rows and squats. '
     'Legs were shaky on the stairs home but I feel more awake than I have all week.',
     'Feeling awake after', 'Returned to the gym after a three-week break.', False,
     ['exercise', 'health']),
    ('dentist', '2026-10-09', 'Health', 'Dentist appointment',
     'Cleaning at 4:30, took the afternoon off to make it. No cavities. Hygienist said to floss more, as always. '
     'Picked up the dry cleaning on the way back since it was next door.',
     'No cavities', 'Routine dentist cleaning, no cavities.', False,
     ['appointments', 'errands']),
    ('call-mom', '2026-10-11', 'Family & Friends', 'Long call with Mom',
     "Called Mom while folding laundry. She is planning the garden for spring already and wants help building a "
     "raised bed. Dad's knee is better. We talked for an hour and a half.",
     'Hearing about the garden plans', "Caught up with Mom; Dad's knee is improving.", False,
     ['family', 'laundry']),
    ('launch', '2026-10-15', 'Work', 'Release finally shipped',
     'The release went out at 2pm. A couple of small bugs came in but nothing major. Team ordered tacos to celebrate. '
     'I left at 5 on the dot for the first time in two weeks.',
     'Team taco lunch', 'Shipped the delayed release; team celebrated.', True,
     ['work', 'team', 'milestone']),
    ('farmers-market', '2026-10-17', 'Groceries & Cooking', 'Farmers market',
     'Walked to the farmers market. Bought apples, a loaf of sourdough, honey, and a small pumpkin for the porch. '
     'Ran into my neighbor Priya and we got coffee after.',
     'Coffee with Priya', 'Farmers market haul and coffee with a neighbor.', False,
     ['groceries', 'neighbors', 'weekend']),
    ('car', '2026-10-20', 'Money', 'Oil change and tire rotation',
     'Dropped the car off before work and took the bus in. Mechanic said the brakes have maybe six months left. '
     'Added it to the budget sheet. $96 total.',
     '', 'Car maintenance; brakes need replacing within six months.', False,
     ['car', 'errands', 'budget']),
    ('workshop', '2026-10-22', 'Work', 'Ran my first design workshop',
     'Led a 90-minute workshop for the onboarding redesign. Nervous for the first ten minutes, then it got fun. '
     'We ended up with three clear problem statements and the sales team actually showed up.',
     'When the room got going', 'Led first workshop for the onboarding redesign.', True,
     ['work', 'leadership', 'career']),
    ('tired', '2026-10-24', 'Health', 'Low-energy Saturday',
     'Slept until 10 and still felt tired. Skipped the grocery run and ordered delivery. Did a short walk around '
     'the block in the afternoon. Going to try going to bed earlier this week.',
     'The afternoon walk', 'Tired weekend; resolved to sleep earlier.', False,
     ['rest', 'sleep']),
    ('friends-dinner', '2026-10-28', 'Family & Friends', 'Dinner with college friends',
     "Met Sam and Alex at the Thai place downtown. First time all three of us were in the same room since summer. "
     "Talked about Sam's new job and Alex's wedding plans. Got home at 11, worth it.",
     'Laughing about old dorm stories', 'Reunion dinner with college friends.', False,
     ['friends', 'food']),
    ('halloween-adult', '2026-10-31', 'Home & Errands', 'Handing out candy',
     'Bought two bags of candy on the way home and ran out by 7:30. Best costume was a kid dressed as an astronaut '
     'with a cardboard jetpack. Carved the farmers market pumpkin.',
     'The astronaut kid', 'Handed out Halloween candy and carved the pumpkin.', False,
     ['holiday', 'neighbors']),
    ('review', '2026-11-04', 'Work', 'Quarterly review',
     'Had my quarterly review. Feedback was mostly positive: the workshop and the release were called out. '
     'Growth area is delegating more instead of doing everything myself. Fair.',
     'Workshop getting called out', 'Positive quarterly review; work on delegating.', True,
     ['career', 'feedback', 'work']),
    ('wfh', '2026-11-06', 'Work', 'Work-from-home Friday',
     'Worked from the couch with the window open. Got through a full draft of the onboarding spec without meetings. '
     'Took a real lunch break and walked to the bakery.',
     'Uninterrupted focus time', 'Productive remote day drafting the onboarding spec.', False,
     ['remote', 'focus', 'work']),
    ('costco', '2026-11-08', 'Groceries & Cooking', 'Big warehouse store trip',
     'Stocked up: paper towels, olive oil, frozen berries, coffee beans, laundry detergent. Also impulse-bought a '
     'rug for the hallway. $212. Should last a month for everything but the rug.',
     'The new hallway rug', 'Monthly bulk shopping trip.', False,
     ['groceries', 'budget', 'home']),
    ('run', '2026-11-10', 'Health', 'First 5K in a while',
     'Ran a full 5K without stopping for the first time since spring. 31 minutes, slow but steady. '
     'The gym visits are adding up.',
     'Not stopping', 'Ran a full 5K without stopping.', True,
     ['exercise', 'running', 'goals']),
    ('sick-day', '2026-11-12', 'Health', 'Sick day',
     'Woke up with a sore throat and called out. Soup, tea, and two naps. Answered one urgent message and '
     'otherwise stayed offline. Delegated the vendor call, which I guess counts as progress.',
     'Two naps', 'Took a sick day and delegated a meeting.', False,
     ['health', 'rest']),
    ('thanksgiving-plan', '2026-11-14', 'Family & Friends', 'Planning Thanksgiving',
     "Booked train tickets to my parents' for Thanksgiving. Mom assigned me the stuffing and a pie. "
     "Made a grocery list for the week before so I am not scrambling.",
     'Getting assigned pie', 'Booked Thanksgiving travel and planned the menu.', False,
     ['family', 'holiday', 'planning']),
]

ADULT_LINKS = [
    ('one-on-one', 'workshop', 'onboarding redesign'), ('workshop', 'review', 'career'),
    ('launch', 'review', 'career'), ('review', 'sick-day', 'delegating'),
    ('gym', 'run', 'fitness'), ('tired', 'sick-day', 'rest'),
    ('groceries-1', 'meal-prep', 'same weekend'), ('farmers-market', 'halloween-adult', 'pumpkin'),
    ('call-mom', 'thanksgiving-plan', 'family'), ('wfh', 'workshop', 'onboarding redesign'),
]

# ---------------------------------------------------------------------------
# Templates for generated history
#
# Activity: category, months (None = any), days ('weekday'|'weekend'|'any'),
# weight, tags, extras (generic lines that fit any variant), variants.
# Variant V(titles, opener, details, favorites): everything in one variant
# belongs to the same story, so title/body/favorite always agree.
# {slot} placeholders are filled from *_SLOTS; the same slot repeats the same
# value within one entry, except slots listed in DISTINCT_SLOTS.
# ---------------------------------------------------------------------------

def V(titles, opener, details, favorites, w=1.0):
    """w: relative weight; use < 1 for things that should be rare (field trips)."""
    return {'titles': titles, 'opener': opener, 'details': details, 'favorites': favorites, 'w': w}


SCHOOL_MONTHS = {1, 2, 3, 4, 5, 9, 10, 11, 12}
WARM = {5, 6, 7, 8, 9}
COLD = {12, 1, 2}
ANY = None
DISTINCT_SLOTS = {'groceries'}

ADULT_SLOTS = {
    'groceries': ['eggs', 'spinach', 'chicken thighs', 'rice', 'oat milk', 'bananas', 'coffee', 'yogurt',
                  'pasta', 'tomatoes', 'onions', 'salmon', 'bread', 'apples', 'frozen berries', 'tofu'],
    'amount': ['$46', '$58', '$72', '$84', '$91', '$103', '$67'],
    'meeting': ['standup', 'sprint planning', 'a design review', 'the all-hands', 'a client call', 'retro'],
    'task': ['the onboarding spec', 'quarterly metrics', 'bug triage', 'the vendor contract', 'a slide deck',
             'interview feedback', 'the roadmap doc'],
    'coworker': ['Dana', 'Marcus', 'Elena', 'Ravi', 'Chloe'],
    'friend': ['Sam', 'Alex', 'Priya', 'Jamie'],
    'meal': ['a stir-fry', 'chili', 'sheet-pan chicken', 'pasta with pesto', 'tacos', 'lentil soup', 'salmon and rice'],
    'workout': ['a 30-minute run', 'a spin class', 'weights at the gym', 'yoga', 'a long walk', 'a swim'],
    'chore': ['doing laundry', 'vacuuming', 'cleaning the bathroom', 'changing the sheets', 'organizing the closet'],
}

ADULT_ACTIVITIES = [
    dict(category='Work', months=ANY, days='weekday', weight=8, tags=['work'],
         extras=['Ate lunch at my desk again.', 'Left right at 5:30.', 'Train home was packed.'],
         variants=[
             V(['Commute and inbox', 'Train was late'], 'Caught the 8:05 train, which showed up fifteen minutes late.',
               ['Cleared my inbox on the platform.', 'Got in just in time for {meeting}.'], ['Clearing my inbox']),
             V(['Meetings all morning', 'Meeting day'], 'Started with {meeting}, which ran long.',
               ['Back-to-back calls until lunch.', 'Honestly, it could have been an email.', 'Got nothing else done until 3.'],
               ['Lunch break', 'The one quiet hour']),
             V(['Focus day', 'Deep work'], 'Blocked off the morning for {task} and actually kept it.',
               ['Got a full draft done before lunch.', 'Turned off Slack for two hours.'], ['Uninterrupted focus', 'Finishing {task}']),
             V(['Working from home', 'WFH day'], 'Worked from home today.',
               ['Got through {task} from the couch.', 'Took a real lunch break and walked to the bakery.', 'Did laundry between calls.'],
               ['The walk to the bakery', 'No commute']),
             V(['Chat with {coworker}', 'Good 1:1'], 'Had a 1:1 with {coworker} about {task}.',
               ['We figured out a plan in twenty minutes.', 'Got some useful feedback.'], ['Talking with {coworker}']),
             V(['Late night at work', 'Deadline day'], 'Stayed late to finish {task} before the deadline.',
               ['Ordered takeout to my desk.', 'Got it in at 7:45.'], ['Hitting submit']),
         ]),
    dict(category='Groceries & Cooking', months=ANY, days='weekend', weight=4, tags=['groceries'],
         extras=['Spent {amount}.'],
         variants=[
             V(['Grocery run', 'Weekly groceries'], 'Went to the grocery store before it got busy.',
               ['Got {groceries}, {groceries}, {groceries}, and {groceries}.', 'Stuck to the list for once.'],
               ['Sticking to the list', 'Getting there early']),
             V(['Forgot the one thing', 'Grocery fail'], 'Did the weekly grocery run after coffee.',
               ['Got {groceries}, {groceries}, and {groceries}.', 'Forgot the one thing I actually went for.'], ['']),
             V(['Farmers market'], 'Walked to the farmers market.',
               ['Bought {groceries}, {groceries}, and a loaf of sourdough.', 'Ran into my neighbor Priya.'],
               ['Running into Priya', 'Fresh sourdough']),
         ]),
    dict(category='Groceries & Cooking', months=ANY, days='any', weight=3, tags=['cooking', 'food'],
         extras=['Listened to a podcast while cooking.'],
         variants=[
             V(['Cooked dinner', '{meal} for dinner'], 'Made {meal} for dinner.',
               ['Turned out better than expected.', 'Enough leftovers for two days.'], ['{meal}', 'Leftovers']),
             V(['Meal prep', 'Sunday meal prep'], 'Meal-prepped lunches for the week: {meal}.',
               ['Took about two hours.', 'Weekday me will be grateful.'], ['Five lunches done']),
             V(['New recipe', 'Trying something new'], 'Tried a new recipe: {meal}.',
               ['Too much salt, will adjust next time.', 'Will definitely make it again.'], ['Trying something new']),
         ]),
    dict(category='Home & Errands', months=ANY, days='any', weight=4, tags=['errands', 'home'],
         extras=['Crossed three things off the list.'],
         variants=[
             V(['Chores', 'Cleaning day'], 'Spent the morning {chore}.',
               ['Also took out the recycling.', 'Apartment feels so much better.'], ['A clean apartment']),
             V(['Post office and pharmacy', 'Errands after work'], 'Ran errands after work: post office, then the pharmacy.',
               ['The line at the post office was out the door.', 'Refilled my prescription while I was there.'], ['Being done']),
             V(['Haircut'], 'Got a haircut on my lunch break.',
               ['Went a little shorter than usual.', 'Feel like a new person.'], ['The new haircut']),
             V(['Donations run'], 'Finally dropped off the donation bags that have been in the hallway for a month.',
               ['Hallway looks huge now.'], ['Clear hallway']),
         ]),
    dict(category='Health', months=ANY, days='any', weight=4, tags=['exercise', 'health'],
         extras=['Slept better afterwards.'],
         variants=[
             V(['Morning workout', 'Before work'], 'Did {workout} before work.',
               ['Felt slow but showed up.', 'More awake than usual all morning.'], ['Showing up']),
             V(['After-work workout', 'Gym'], 'Did {workout} after work.',
               ['Felt strong today.', 'Legs are going to hurt tomorrow.'], ['Feeling strong']),
             V(['Rest day', 'Tired'], 'Skipped the workout and went to bed at 9:30.',
               ['Needed it.', 'Body was telling me to slow down.'], ['Going to bed early']),
         ]),
    dict(category='Family & Friends', months=ANY, days='any', weight=3, tags=['family', 'friends'],
         extras=['Made plans to do it again soon.'],
         variants=[
             V(['Called Mom', 'Catching up with Mom'], 'Called Mom on the walk home.',
               ['Talked for over an hour.', 'Dad says hi and his garden is doing well.'], ['Hearing about the garden']),
             V(['Dinner with {friend}', 'Catching up'], 'Met {friend} for dinner.',
               ['Laughed so hard about old stories.', 'Stayed until they closed.'], ['Laughing with {friend}']),
             V(['Coffee with {friend}'], 'Got coffee with {friend}.',
               ['We talked about {friend}\'s new job.', 'Walked around the block twice after.'], ['Coffee with {friend}']),
         ]),
    dict(category='Money', months=ANY, days='any', weight=2, tags=['budget', 'money'],
         extras=[],
         variants=[
             V(['Budget check-in', 'Monthly budget'], 'Did the monthly budget check-in.',
               ['Groceries came in under budget.', 'Spent too much eating out this month.', 'Moved some money into savings.'],
               ['Moving money to savings', 'Under budget']),
             V(['Paid bills', 'Bills day'], 'Paid rent and the utility bills.',
               ['Canceled a subscription I never use.', 'Set up autopay for the electric bill.'], ['Autopay']),
         ]),
    dict(category='Travel & Fun', months=ANY, days='weekend', weight=2, tags=['weekend', 'fun'],
         extras=['Felt like a real break.'],
         variants=[
             V(['Day trip to the city', 'Day trip'], 'Took the train to the city for the day.',
               ['Found a great new coffee shop.', 'Walked about 15,000 steps.'], ['The new coffee shop']),
             V(['Museum with {friend}', 'Museum day'], 'Went to the art museum with {friend}.',
               ['Spent way too long in the gift shop.', 'The new exhibit was worth it.'], ['The new exhibit']),
             V(['Lake walk', 'Walk by the lake'], 'Walked by the lake all afternoon.',
               ['Weather was perfect.', 'Sat on a bench and read for an hour.'], ['Reading by the lake']),
         ]),
]

ADULT_EVENTS = [
    (12, 25, 'Family & Friends', 'Christmas at my parents\'',
     'Took the train to my parents\' for Christmas. Mom made her usual feast and we played cards until midnight.',
     'Cards with Dad', False, ['holiday', 'family']),
    (11, 27, 'Family & Friends', 'Thanksgiving',
     'Thanksgiving at my parents\'. I made the stuffing and a pie. The pie was a hit.',
     'The pie', False, ['holiday', 'family', 'cooking']),
    (1, 1, 'Health', 'New year goals',
     'Wrote down goals for the year: run a 5K, cook more, save more, and stop eating lunch at my desk.',
     'Writing goals', True, ['goals', 'new year']),
    (2, 10, 'Work', 'Annual review',
     'Annual review today. Got a raise and good feedback. Dana wants me to take on more ownership this year.',
     'The raise', True, ['career', 'work']),
    (7, 8, 'Travel & Fun', 'Beach vacation',
     'First day of a week at the beach. Turned off work notifications. Read a whole book.',
     'Notifications off', True, ['vacation', 'travel']),
    (5, 18, 'Health', 'Annual checkup',
     'Annual physical. Everything looks normal. Doctor said keep up the exercise.',
     'Everything normal', False, ['health', 'appointments']),
    (9, 2, 'Home & Errands', 'Moved apartments',
     'Moving day. Friends helped carry boxes and we ate pizza on the floor. New place gets so much light.',
     'Pizza on the floor', True, ['home', 'moving', 'friends'], 2025),
]


ADULT = dict(key='adult', name='Jordan', kind='adult', themeId='indigo', categories=ADULT_CATEGORIES,
             slots=ADULT_SLOTS, activities=ADULT_ACTIVITIES, events=ADULT_EVENTS,
             written=ADULT_ENTRIES, links=ADULT_LINKS, introduced={})
