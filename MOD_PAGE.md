# GraveSense mod-page copy

## Short description

Makes post-combat loot scarcer by removing configurable amounts of repair kits,
potions, and bandages from fallen enemies before they can be looted. Lightweight,
MCM-configurable, and designed to curb excess supplies without affecting equipped
gear or money.

## Description

This mod has been in development for a long time. After numerous investigations,
a nine-month break, and a return to the project with a new approach, I am finally
happy to release **GraveSense**.

**GraveSense** is a lightweight loot-balancing, or more accurately,
**economy-balancing**, mod for **Kingdom Come: Deliverance II**. It reduces the
abundance of supplies obtained after combat by processing eligible enemies when
they die, before the corpse-looting screen becomes available.

During combat, GraveSense identifies nearby damaged NPCs and tracks them until
death. It can then remove repair kits, potions, and bandages according to separate
0-100% probabilities configured through the Mod Configuration Menu. Probability
is evaluated for each item individually, allowing a stack to be reduced rather
than always kept or removed in full. Setting a category to 0% disables its
removal, while 100% removes every eligible item in that category.

Each tracked character is processed only once per loaded gameplay session.
Equipped items and money are left untouched, and every attempted inventory change
is verified by recounting the affected item class.

The result is simple: fewer free healing and maintenance supplies from fallen
enemies, and more reason to buy, conserve, and manage your own resources.

## Core systems

- Tracks nearby damaged NPCs during combat and processes their inventories
  immediately after death.
- Provides separate 0-100% removal probabilities for repair kits, potions, and
  bandages.
- Can reduce stacked supplies item by item.
- Leaves equipped items and money untouched.
- Supports multiple enemies and continues watching tracked NPCs briefly after
  combat ends.
- Processes each character only once per loaded gameplay session.
- Pauses and resets safely during sleeping, waiting, Game Over, and save-loading
  sequences.

## Configuration

The Mod Configuration Menu provides:

- A master Enable switch.
- Bandage removal probability.
- Potion removal probability.
- Repair-kit removal probability.
- Optional Debug logging.

Settings are saved globally and remain active across save loads and game
sessions. Setting an item category to 0% disables that category.
