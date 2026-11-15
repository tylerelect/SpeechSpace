"""Content for scripts/seed_demo_data.py.

KIDS_* is written in a child's voice, inspired by "describe your perfect day"
interview transcripts (pools, puppies, ice cream, tag that keeps growing, a
kitten named Laser, little brother Lucas, a science lab on the moon, sleepovers,
carpool). ADULT_* is day-in-the-life material: commuting, work, groceries,
errands, health, family.

Templates use {slot} placeholders filled from the matching *_SLOTS table.
"""

# ---------------------------------------------------------------------------
# Categories (stored as `projects`, one set per profile)
# ---------------------------------------------------------------------------

KID_CATEGORIES = ['School', 'Family', 'Friends', 'Pets', 'Outdoors & Sports',
                  'Food & Treats', 'Science & Imagination', 'Holidays & Trips']

ADULT_CATEGORIES = ['Work', 'Home & Errands', 'Groceries & Cooking', 'Health',
                    'Family & Friends', 'Money', 'Travel & Fun']

# ---------------------------------------------------------------------------
# Hand-written recent entries (Oct-Nov 2026)
# (key, date, category, title, body, favorite, highlight, milestone, tags)
# ---------------------------------------------------------------------------

KID_ENTRIES = [
    ('pancakes', '2026-10-03', 'Food & Treats', 'Chocolate pancakes',
     'Today I woke up and it was sunny. Dad made chocolate pancakes for breakfast and I ate three. '
     'My sister did not throw a fit at all. I did not have to do any chores so I played frisbee in the backyard.',
     'Chocolate pancakes', 'A sunny Saturday with chocolate pancakes and frisbee.', False,
     ['breakfast', 'family', 'outside']),
    ('pump-track', '2026-10-04', 'Outdoors & Sports', 'Pump track with my bike',
     'We went to the pump track. It is kind of like a skate park made of dirt for bikes. '
     'I went over the big bumps without pedaling. I fell one time but I got back up.',
     'Going over the big bumps', 'Rode bikes at the dirt pump track and kept going after a fall.', False,
     ['bikes', 'outside', 'brave']),
    ('laser', '2026-10-07', 'Pets', 'Laser knocked over my cup',
     'Laser is my kitten. She knocked my water cup off the table and then ran away really fast. '
     'Lucas laughed so hard. Lucas is my little brother and he is four. I tried to draw Laser but cats are hard to draw.',
     'Laser running away', 'Funny moment with kitten Laser and little brother Lucas.', False,
     ['pets', 'family', 'drawing']),
    ('tag', '2026-10-09', 'Friends', 'The biggest game of tag',
     'At recess me and one friend started playing tag. Then another kid came and said can I join? '
     'Then two more people said can I join? Then it was like the whole class. The game kept getting bigger and bigger. '
     'Even our teacher played for a minute.',
     'Everybody joining the game', 'A game of tag at recess grew to include the whole class.', True,
     ['friends', 'school', 'games']),
    ('ice-cream', '2026-10-11', 'Food & Treats', 'Purple ice cream on a waffle',
     'We went to the ice cream shop with my whole family. I got purple ice cream on a waffle. '
     'Lucas got sprinkles everywhere. I had no tummy ache.',
     'Purple ice cream', 'Family trip to the ice cream shop.', False,
     ['food', 'family', 'treats']),
    ('lab', '2026-10-14', 'Science & Imagination', 'I did science',
     'I wanted to do science so me and mom went to the store to get ingredients. We made a volcano with baking soda '
     'and vinegar. It fizzed up so high. When I grow up I want my own lab, maybe on the moon.',
     'The volcano fizzing', 'Made a baking soda volcano with mom.', True,
     ['science', 'mom', 'experiments']),
    ('moon-school', '2026-10-15', 'Science & Imagination', 'If school was on the moon',
     'Today I thought about if school was on the moon. There is no gravity so kids would float in the air. '
     'A kid floating would say can I join while he is floating. Everybody would need helmets or they could not breathe.',
     'Floating kids', 'Imagined a school on the moon where everyone floats.', False,
     ['space', 'imagination', 'school']),
    ('rain-movie', '2026-10-18', 'Family', 'Movie theater day',
     'It rained so we went to the movie theater. We saw a wizard movie and I got popcorn and gummy worms. '
     'More gummy worms. I wish my puppy could come to the movies, but I do not have a puppy yet.',
     'Gummy worms', 'Rainy day at the movie theater.', False,
     ['movies', 'treats', 'puppy-wish']),
    ('grandma', '2026-10-21', 'Family', 'Helping grandma',
     'I helped grandma in her garden because she is old and her back hurts. I pulled weeds and she gave me a cookie. '
     'She told me a story about when my mom was little.',
     "Grandma's story", 'Helped grandma with the garden and heard a story about mom.', False,
     ['grandma', 'helping', 'family']),
    ('carpool', '2026-10-23', 'Friends', 'Carpool singing',
     'In carpool today everybody was singing the same song really loud. Jack kept poking me and it was annoying '
     'but kind of funny. Nobody puked in the car this time.',
     'Singing in the car', 'Loud, funny carpool ride with friends.', False,
     ['friends', 'music', 'school']),
    ('waterpark', '2026-10-25', 'Holidays & Trips', 'Indoor water park',
     'We went to the indoor water park. There was a wave pool and a really steep slide. I was a little scared '
     'but I went down anyway and it was so fast. The water was just lukewarm. After we got popsicles.',
     'The steep slide', 'Went down the steep water slide even though it was scary.', True,
     ['swimming', 'brave', 'treats']),
    ('halloween', '2026-10-31', 'Holidays & Trips', 'Halloween',
     "I was an astronaut for Halloween and Lucas was a dinosaur. We got so much candy. I traded my raisins for "
     "Lucas's chocolate. Laser was scared of the doorbell.",
     'Trading candy', 'Trick-or-treating as an astronaut with Lucas.', False,
     ['holiday', 'family', 'space']),
    ('sleepover', '2026-11-06', 'Friends', 'Sleepover party',
     'I had a sleepover with my friends. We had pizza for dinner, like a hundred pizzas (not really, just two). '
     'We had a dance party and stayed up late. It was kind of like a birthday party but even better.',
     'Dance party', 'Sleepover with friends, pizza and dancing.', True,
     ['friends', 'party', 'food']),
    ('smash', '2026-11-07', 'Friends', 'Video game tournament',
     'The morning after the sleepover we had a video game tournament. I won two rounds and Anders won the rest. '
     'Mom said we had to go outside after that.',
     'Winning two rounds', 'Video game tournament with friends after the sleepover.', False,
     ['games', 'friends']),
    ('lazy', '2026-11-08', 'Family', 'A resting day',
     'Today my perfect day was honestly resting. I stayed in my pajamas and read books and cuddled with mom. '
     'Laser slept on my feet.',
     'Cuddling with mom', 'A cozy rest day reading and cuddling.', False,
     ['rest', 'mom', 'reading']),
    ('stars', '2026-11-10', 'Science & Imagination', 'Drawing my perfect day',
     'I drew my perfect day. It has a puppy, a pool, an ice cream shop a couple miles away, a candy sign with people '
     'waiting in line, and a lab on the moon. I want to send it to my parents so they know what to make.',
     'The candy sign', 'Drew a picture of a perfect day with everything in it.', False,
     ['drawing', 'imagination', 'puppy-wish']),
    ('first-snow', '2026-11-13', 'Outdoors & Sports', 'First snow',
     'It snowed! It was not a lot but we still went sledding down the little hill. Lucas went down on his tummy. '
     'My cheeks got really cold and then we had hot chocolate.',
     'Sledding', 'First snow of the year and sledding with Lucas.', False,
     ['snow', 'outside', 'family']),
    ('puppy', '2026-11-14', 'Pets', 'We met a puppy!',
     'We went to the animal shelter just to look and there was a Pomeranian puppy. It licked my hand. '
     'Mom said maybe. Maybe means almost yes. This is the best day ever.',
     'The puppy licking my hand', 'Met a Pomeranian puppy at the shelter and mom said maybe.', True,
     ['pets', 'puppy-wish', 'family']),
]

KID_LINKS = [
    ('rain-movie', 'puppy', 'puppy wish'), ('stars', 'puppy', 'puppy wish'),
    ('lab', 'moon-school', 'space'), ('moon-school', 'halloween', 'space'),
    ('tag', 'carpool', 'friends'), ('sleepover', 'smash', 'same weekend'),
    ('ice-cream', 'waterpark', 'treats'), ('laser', 'lazy', 'Laser'),
    ('first-snow', 'halloween', 'Lucas'),
]

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

def V(titles, opener, details, favorites):
    return {'titles': titles, 'opener': opener, 'details': details, 'favorites': favorites}


SCHOOL_MONTHS = {1, 2, 3, 4, 5, 9, 10, 11, 12}
WARM = {5, 6, 7, 8, 9}
COLD = {12, 1, 2}
ANY = None
DISTINCT_SLOTS = {'groceries'}

KID_SLOTS = {
    'friend': ['Jack', 'Jafie', 'Anders', 'Priya', 'Leo', 'Sofia', 'Noah'],
    'snack': ['goldfish', 'gummy worms', 'popsicles', 'pretzels', 'cookies'],
    'flavor': ['purple', 'mint chip', 'strawberry', 'cookie dough', 'chocolate', 'rainbow'],
    'dinner': ['pizza', 'hamburgers and french fries', 'tacos', 'spaghetti', 'chicken nuggets', 'mac and cheese'],
    'subject': ['math', 'reading', 'art', 'music', 'science'],
    'book': ['a dragon book', 'a book about sharks', 'a comic book', 'a mystery book', 'a book about planets'],
    'game': ['tag', 'hide and seek', 'four square', 'red light green light', 'freeze tag'],
    'planet': ['the moon', 'Mars', 'Saturn', 'Jupiter'],
}

KID_ACTIVITIES = [
    dict(category='School', months=SCHOOL_MONTHS, days='weekday', weight=6, tags=['school'],
         extras=['{friend} sat next to me at lunch.', 'Lunch was {dinner}.', 'I got a sticker for helping clean up.'],
         variants=[
             V(['Recess', 'The best recess'], 'At recess we played {game}.',
               ['Then another kid said can I join? Then two more said can I join?', 'The game got so big the whole class was playing.',
                '{friend} was it for the whole time.', 'I was the last one caught!'],
               ['Recess', 'Playing {game}', 'Being the last one caught']),
             V(['{subject} class', 'What I learned today'], 'Today in {subject} we learned something new.',
               ['I raised my hand two times.', 'It was hard at first but then I got it.', 'Ms. Rivera said I did a great job.'],
               ['{subject}', 'Getting it right']),
             V(['Story time', 'Ms. Rivera read to us'], 'My teacher Ms. Rivera read us {book}.',
               ['Everybody was quiet because it was so good.', 'I want to read it again at home.', 'It had a really surprising ending.'],
               ['{book}', 'The ending']),
             V(['Indoor recess', 'Rainy school day'], 'It was raining so we had indoor recess.',
               ['We played a board game and I almost won.', 'We built a tower out of blocks taller than {friend}.'],
               ['The block tower', 'The board game']),
             V(['Field trip!', 'Our field trip'], 'Our class went on a field trip to the science museum.',
               ['There was a planet room and it was dark like space.', 'I saw a real moon rock.', 'We ate lunch on the bus.'],
               ['The moon rock', 'The planet room']),
         ]),
    dict(category='Friends', months=ANY, days='any', weight=4, tags=['friends', 'play'],
         extras=['Nobody was annoying me.', 'We had {snack} and juice boxes.'],
         variants=[
             V(['Fort with {friend}', 'Playdate with {friend}'], '{friend} came over to play.',
               ['We built a fort out of couch cushions.', 'We made a sign that said NO GROWNUPS.', 'Lucas wanted to come in so we let him.'],
               ['The fort', 'Playing with {friend}']),
             V(['At {friend}\'s house', 'Playdate'], 'I went to {friend}\'s house.',
               ['We made up a secret handshake.', 'We had a dance party in the living room.', 'We had a little fight but then we said sorry.'],
               ['Our secret handshake', 'The dance party']),
             V(['Park with {friend}', '{game} at the park'], 'Me and {friend} played {game} at the park.',
               ['More kids came and asked can I join?', 'Then it was like twenty kids.', 'We played until it got dark.'],
               ['Everybody joining', 'Playing {game}']),
             V(['Video games', 'Game day'], '{friend} came over and we played video games.',
               ['I won two rounds.', 'Mom said we had to go outside after one hour.', 'We battled for like six hours. Not really, like one hour.'],
               ['Winning', 'Video games with {friend}']),
         ]),
    dict(category='Family', months=ANY, days='any', weight=4, tags=['family'],
         extras=['We had {dinner} for dinner.', 'Lucas is my little brother and he is silly.'],
         variants=[
             V(['Playing with Lucas', 'Me and Lucas'], 'Me and Lucas played together all morning.',
               ['We made a race track for his cars.', 'We fought a little but then we made up.', 'He laughed so hard he got the hiccups.'],
               ['The race track', 'Lucas laughing']),
             V(['Day with mom', 'Mom and me'], 'I spent the day with mom.',
               ['We went to the library and I got {book}.', 'We cuddled on the couch.', 'She let me pick the music in the car.'],
               ['Cuddling with mom', 'Picking the music', '{book}']),
             V(['Cooking with dad', 'Dad and me'], 'I helped dad make {dinner}.',
               ['I stirred the pot by myself.', 'It was a little messy.', 'Everybody said it was yummy.'],
               ['Stirring the pot', 'Making {dinner}']),
             V(['Game night', 'Family game night'], 'We had family game night.',
               ['I won the card game.', 'Lucas made up his own rules.', 'Dad made popcorn.'],
               ['Winning the card game', 'Popcorn']),
             V(['Grandma', 'Visiting grandma'], 'We went to visit grandma.',
               ['I helped her because she is old.', 'She told me a story about when mom was little.', 'She gave me a cookie.'],
               ['Grandma\'s story', 'The cookie']),
             V(['Resting day', 'Pajama day'], 'My day was honestly resting.',
               ['I stayed in my pajamas.', 'I read {book}.', 'I did not have to do any chores.'],
               ['Pajamas', 'No chores', 'Reading']),
         ]),
    dict(category='Pets', months=ANY, days='any', weight=3, tags=['pets', 'Laser'],
         extras=['I still want a puppy too. A really cute one.'],
         variants=[
             V(['Laser in a box', 'Silly Laser'], 'Laser sat in a box that was way too small for her.',
               ['She looked so proud.', 'Lucas laughed so hard.'], ['Laser in the box']),
             V(['Laser chased a bug', 'Laser the hunter'], 'Laser chased a bug all over the house.',
               ['She jumped on the couch and knocked off a pillow.', 'She never caught it.'], ['Laser jumping']),
             V(['Feeding Laser', 'My job'], 'I fed Laser her breakfast all by myself.',
               ['Mom said I am very responsible.', 'Laser rubbed on my legs to say thank you.'], ['Feeding Laser']),
             V(['Laser the sleepy cat', 'Nap time'], 'Laser slept on my feet the whole time I read.',
               ['She purred really loud.', 'I did not want to move.'], ['Laser purring']),
             V(['Drawing Laser'], 'I tried to draw Laser.',
               ['Cats are hard to draw.', 'Her tail came out too long but mom put it on the fridge.'], ['My drawing on the fridge']),
         ]),
    dict(category='Outdoors & Sports', months=WARM, days='any', weight=4, tags=['outside', 'summer'],
         extras=['It was sunny and hot, like 80 degrees.', 'Birds were chirping.', 'After we had {snack}.'],
         variants=[
             V(['Pool day', 'Swimming'], 'We went to the pool.',
               ['I talked under the water.', 'The water was just lukewarm.', 'I jumped off the side by myself.'],
               ['Talking under water', 'Jumping in']),
             V(['Pump track', 'Bike ride'], 'We rode bikes on the pump track.',
               ['It is like a skate park made of dirt for bikes.', 'I went over the big bumps without pedaling.', 'I fell once but got back up.'],
               ['The big bumps', 'Riding my bike']),
             V(['At the park', 'Park day'], 'I played at the park with Lucas.',
               ['I went down the big slide.', 'I found a four-leaf clover!', 'We went really high on the swings.'],
               ['The four-leaf clover', 'The big slide', 'Swinging high']),
             V(['Frisbee', 'Backyard'], 'I played frisbee in the backyard with dad.',
               ['I caught it five times in a row.', 'It went over the fence once.'], ['Catching five in a row']),
         ]),
    dict(category='Outdoors & Sports', months=COLD, days='any', weight=3, tags=['snow', 'winter'],
         extras=['My cheeks got so cold.', 'We had hot chocolate after.'],
         variants=[
             V(['Sledding', 'Snow day'], 'It snowed and we went sledding.',
               ['Lucas went down the hill on his tummy.', 'I went so fast I almost hit a tree.'], ['Sledding']),
             V(['Snowman', 'Building a snowman'], 'We built a snowman in the front yard.',
               ['He had a carrot nose and button eyes.', 'Lucas named him Mister Cold.'], ['The snowman']),
             V(['Snowball fight'], 'We had a snowball fight with the neighbors.',
               ['I hit dad right in the back.', 'Our team won.'], ['Hitting dad with a snowball']),
         ]),
    dict(category='Outdoors & Sports', months={3, 4, 5, 9, 10}, days='weekend', weight=2, tags=['sports', 'soccer'],
         extras=['We had orange slices at halftime.'],
         variants=[
             V(['Soccer game', 'My game today'], 'I had a soccer game this morning.',
               ['I almost scored a goal.', 'Our team won!', 'Coach said I was a great defender.'], ['Almost scoring', 'Winning']),
             V(['Soccer practice'], 'We had soccer practice in the rain.',
               ['Everybody got muddy.', 'We practiced kicking really far.'], ['Getting muddy']),
         ]),
    dict(category='Food & Treats', months=ANY, days='any', weight=3, tags=['food', 'treats'],
         extras=['I had no tummy ache.'],
         variants=[
             V(['Ice cream!', '{flavor} ice cream'], 'We went to the ice cream shop and I got {flavor} ice cream.',
               ['I put it on a waffle.', 'Lucas got it all over his face.'], ['{flavor} ice cream']),
             V(['Chocolate pancakes', 'Pancake morning'], 'Dad made chocolate pancakes for breakfast.',
               ['I ate three.', 'I helped flip one and it only kind of broke.'], ['Chocolate pancakes']),
             V(['{dinner} night', 'Yummy dinner'], 'We had {dinner} for dinner.',
               ['It is my favorite.', 'I want it for every meal.'], ['{dinner}']),
             V(['Snack attack', 'Snacks!'], 'I ate {snack}, more {snack}, and more {snack}.',
               ['Mom said that is enough {snack}.', 'I shared some with Lucas.'], ['{snack}']),
             V(['Candy store'], 'We went to the candy store with the big sign that says CANDY.',
               ['There were so many people waiting in line.', 'I picked gummy worms.'], ['Gummy worms']),
         ]),
    dict(category='Science & Imagination', months=ANY, days='any', weight=3, tags=['science', 'imagination'],
         extras=['When I grow up I want my own lab.'],
         variants=[
             V(['Science experiment', 'I did science'], 'I did a science experiment with mom.',
               ['We mixed baking soda and vinegar.', 'It fizzed up really high.', 'We wrote down what happened like real scientists.'],
               ['The fizzing']),
             V(['My invention', 'Space food machine'], 'I invented a machine that makes space food.',
               ['It has a conveyor belt that brings the food to a different table.', 'There is a piston that pushes it through a tube.'],
               ['The conveyor belt', 'The piston']),
             V(['School on {planet}', 'If school was in space'], 'I thought about what school would be like on {planet}.',
               ['Kids would float because there is no gravity.', 'Everybody needs a helmet.', 'A floating kid would say can I join?'],
               ['Floating kids']),
             V(['My drawing', 'I drew {planet}'], 'I drew a picture of {planet}.',
               ['I put a rocket and an astronaut on it.', 'Mom hung it on the fridge.'], ['My drawing']),
         ]),
]

KID_EVENTS = [  # (month, day, category, title, body, favorite, milestone, tags)
    (12, 25, 'Holidays & Trips', 'Christmas!',
     'It was Christmas and it snowed. I got a science kit and Lucas got a toy truck. We went sledding after presents.',
     'The science kit', False, ['holiday', 'family', 'snow']),
    (10, 31, 'Holidays & Trips', 'Halloween',
     'I dressed up for Halloween and went trick-or-treating with Lucas. We got so much candy.',
     'Candy', False, ['holiday', 'candy']),
    (11, 27, 'Holidays & Trips', 'Thanksgiving',
     'We went to grandma\'s for Thanksgiving. I said I was thankful for my family and pie.',
     'Pie', False, ['holiday', 'grandma']),
    (3, 14, 'Holidays & Trips', 'My birthday!',
     'It was my birthday! I had a party with all my friends and a cake shaped like a rocket.',
     'The rocket cake', True, ['birthday', 'party', 'friends']),
    (6, 5, 'School', 'Last day of school',
     'Today was the last day of school! We had a party in class and signed each other\'s shirts. Summer!',
     'Signing shirts', True, ['school', 'summer']),
    (8, 26, 'School', 'First day of school',
     'First day of school. My new teacher is nice and {friend} is in my class again. I was a little nervous.',
     '{friend} in my class', True, ['school', 'new']),
    (7, 15, 'Holidays & Trips', 'Water park vacation',
     'We went on vacation to a water park. There was a wave pool and a really steep slide. I rode everything.',
     'The wave pool', True, ['vacation', 'swimming']),
    (4, 20, 'Pets', 'Laser came home',
     'We got a kitten! Her name is Laser. She is tiny and gray and she sleeps a lot.',
     'Naming her Laser', True, ['pets', 'Laser', 'new']),
]


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
     'Pizza on the floor', True, ['home', 'moving', 'friends']),
]
