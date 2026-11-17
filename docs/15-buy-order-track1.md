# 15 - Buy order on track 1 (rival 0, MIA FERRARU)

Tool: `tools/buyorder.py docs/data/partsweep6_track1_2lap.csv [rival_s]`, using the two-lap totals of doc 14.

**Model (assumptions):** new game = $0, all tier 0 (tables in doc 03: prices oil 1 $200, tire 1 $400, tire 2 $1,500, engine 1 $2,000, muffler 1 $1,500, brake 1 $1,500, frame 1 $2,000);
a race is the 2-lap total of the current combination; the rival's total is taken as 2 x (110 + ~0.5) = 221.0 s (**not verified with a finished race**, see doc 00); win $1,200, loss within 10 s $800, else $400
(PHARMACY); purchases are made in the given order as soon as affordable; part wear and mechanic costs are ignored; goal: 5 wins (advances to the next rival). All 5,040 orders of the 7 items were tried.

## Results

* Stock bike: 224.28 s, **loses** by 3.3 s (narrow loss, $800).
* Best orders need **6 races** to get 5 wins (the first race is always a loss: with $0 nothing can be bought before it). Median order: 9 races, worst: 16.
* Best sequence (6 races, $1,700 left): race 1 lost (224.28) -> buy **oil 1 + tire 1** ($600) -> races 2-3 won at 220.78 -> **tire 2** ($1,500) -> 215.5 -> **muffler 1** -> 214.4. (Brake 1 appears in the ties as a filler purchase: it is worth ~0 s and can be skipped.)
* Engine first (hunch "engine is the biggest single gain"): 8 races, three losses in a row, because $2,000 takes three races to save and the engine alone only brings 220.43 s (a 0.6 s margin).
* Tire 2 first (skipping tire 1): $1,500 -> 216.43 s alone, a 4.6 s margin: the best single purchase by far; but it takes two races to afford (7 races in total).
* Cheapest combinations that beat 221.0 s: tire 1 + oil 1 ($600, 220.78), tire 2 ($1,500, 216.43), engine 1 alone ($2,000, 220.43). Cheapest under 213 s: tire 2 + engine 1 + oil 1 ($3,700, 212.73).

## Caveats

* tire 1 + oil 1 beats 221.0 by only 0.22 s. The rival's lap times have +0.30..0.66 s random per lap, so those wins are not safe (with a rival at 221.3 the same order still needs 6 races, with 220.6 it needs 7).
* Frame 1 and brake 1 are worth nothing on this track with the current autopilot (docs 13, 14).
* Engine, muffler and oil help mostly lap 1 (standing start); tires help both laps equally.
