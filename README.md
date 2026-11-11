# Names Ranking

Vote for the best character names straight from the `/who` window and see the leaderboard with `/nr`.

- Every row in `/who` gets four buttons: **1**, **2** and **3** points, and **X** to remove your vote.
- You can vote for as many characters as you like, but only once per character. A vote is final: to change it, remove it with **X** and vote again.
- A name's score is the **sum of all the points it received**. Ties go to the name with more 3-point votes, then more votes overall.
- The button on the minimap opens the leaderboard too. Drag it to move it around the map.
- The **My votes** tab in `/nr` has an **X** on each row to remove that vote.
- Votes are shared between players who have the addon. There is no central server, so each player's leaderboard is built from the votes their client has heard.

## Install

### CurseForge app

Search for **Names Ranking** in the CurseForge app under your WoW Forever installation, or get it from [its CurseForge page](https://www.curseforge.com/wow/addons/names-ranking).

### Manual

1. Copy the `NamesRanking` folder into `World of Warcraft\<Forever folder>\Interface\AddOns\`.
2. Start the game, open **AddOns** on the character screen and make sure **Names Ranking** is enabled.
3. If it shows as *out of date*, tick **Load out of date AddOns**. Then check the client's interface number in game with `/dump select(4, GetBuildInfo())` and put it first on the `## Interface:` line of `NamesRanking.toc`.

## Commands

| Command | What it does |
| --- | --- |
| `/nr` | Open or close the leaderboard |
| `/nr vote <Name> <1-3>` | Vote without the `/who` window (`0` removes your vote) |
| `/nr top [N]` | Print the top N names in your own chat (default 10) |
| `/nr sync on\|off` | Share votes with other players, or keep them on this computer |
| `/nr block <Name>` / `/nr unblock <Name>` | Ignore or restore a player's votes |
| `/nr status` | Show sync status (channel, addon users online, queued messages, voters, last message) |

## How sync works

- About 10–20 seconds after login the addon joins a hidden chat channel, `NamesRankingSync`. WoW Forever doesn't deliver addon messages sent to custom channels, so the channel is only used to find out who has the addon online. Votes then travel as invisible addon whispers to those players, plus your guild and group.
- Each client only sends **its own** votes, and only counts votes it hears **from the voter directly**. The game server sets who sent each message, so nobody can vote in someone else's name.
- A new vote is whispered right away to up to 10 online players. Every 3 seconds each client also says HELLO to the next online player: how many votes it has, plus a hash of them. Anyone whose copy doesn't match asks for the full list by whisper, so everyone online catches up without flooding anyone.
- Two players only exchange votes while both are online. A vote never reaches you through a third player, because that would let anyone invent votes in someone else's name.
- Limits: 60 live votes per voter per hour, 2000 active votes per voter (removed votes don't count), no self votes, and timestamps no more than 5 minutes in the future.
- Nothing is sent during boss encounters or while the game locks addon messages.

## Where votes are stored

`WTF\Account\<ACCOUNT>\SavedVariables\NamesRanking.lua`. There's one file per account, shared by all your characters, and each vote is tied to the character that cast it. The game writes this file when you log out, exit or `/reload`. Voters who haven't been seen for 90 days are pruned.

## Known unknowns

- Custom channels and whispers may not cross factions, so the leaderboard may effectively be per faction.
- Trial accounts can't send addon messages. They see others' votes, but their own votes stay local.
