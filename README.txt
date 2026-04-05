# TheoSIM

A lightweight in-game damage simulator for **Turtle WoW Warriors**.

## What it does

Snapshots your current character stats, weapon data, talents, and selected debuffs, then runs multiple simulated fights to estimate your average DPS.

It is mainly built to help compare:

* different talent setups
* ability priorities
* weapon choices
* target counts
* armor debuff combinations
* Slam, Bloodthirst, Mortal Strike, Sweeping Strikes, Whirlwind, Execute, Heroic Strike, and Cleave usage

## Current features

* Simulates single-target and multi-target warrior damage
* Reads your current:

  * talents
  * attack power
  * crit
  * hit
  * haste
  * armor penetration
  * weapon speed and damage ranges
  * weapon skill
* Supports talent-gated abilities so abilities like **Bloodthirst**, **Mortal Strike**, and **Sweeping Strikes** only work when actually talented
* Includes **Slam** timing logic with Turtle-specific cast-time handling
* Lets you toggle common armor debuffs such as:

  * Sunder Armor
  * Faerie Fire
  * Curse of Recklessness
  * Expose Armor
  * Homunculi
* Shows a DPS breakdown by ability after the sim finishes

## Notes

* This is a custom Turtle WoW warrior simulator and may not match live gameplay perfectly in every edge case.
* Results are only as accurate as the current talent detection, ability logic, and stat snapshot at the time of the sim.
* The addon is intended as a fast comparison tool, not a perfect combat log reconstruction.

## In short

**Turtle Warrior Sim** is an in-game tool for estimating and comparing Warrior DPS setups on Turtle WoW without needing to leave the game.
