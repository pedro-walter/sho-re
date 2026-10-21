Input scripts for `SHO_INPUT` (see docs/01). Use as `SHO_INPUT="$(cat scripts/scenarios/orig_race.txt)"`.
* `orig_race.txt` – title -> Original mode -> parts (buys with the poked money) -> mechanic screen -> RACE; then drives and crashes.
  Needs `SHO_POKE="1250:FFB638:00999999:l"` (money) to be able to buy.
* `arcade_race.txt` – title -> Arcade mode -> class/music select -> race.
* `orig_race_nobuy.txt` – older, shorter Original-mode run without the shop/mechanic steps.
Gotcha: the mechanic screen waits for B (leave) – C keeps buying/selecting; input is ignored while text animates.
