# ram-watch-cheat-engine

RAM watch is a powerful tool for researching games - for modding, speedrunning, or just generally learning how the game works.

The [tool-assisted speedrun community](http://tasvideos.org/) makes extensive use of RAM watch on emulated games. The most popular Gamecube/Wii emulator is Dolphin, and so far, Cheat Engine has been the most popular RAM watch solution for Dolphin. Here's a nice [tutorial by aldelaro](http://tasvideos.org/forum/viewtopic.php?t=17735) on using Cheat Engine with Dolphin.

In addition to supporting RAM viewing and scanning (and even modifying), Cheat Engine also includes a Lua scripting engine. This opens up many more possibilities for boosting research productivity, including:

- More interactivity. With Lua scripting, you can create a separate Cheat Engine window with arbitrary GUI elements: buttons, text fields, and so on. You can record values to a .txt file as the game runs, and then paste results into a spreadsheet to make a graph (e.g. showing your character's speed over time).

- More flexible RAM viewing compared to Cheat Engine's address list display. For example, you can set your font and font size, limit the number of decimal places in a float, and make the display update as often as once per frame.

- It's easier to build upon previous results. Instead of entering the same pointer base for 10 different address list entries, you can save that pointer to a Lua variable and re-use that variable. You can run RAM values through formulas like sqrt(x^2 + y^2) and display the result.

This repository contains:

- A Lua framework for writing custom RAM displays with the above features. Although the Lua framework can be used for any game, the main focus is on games running in Dolphin emulator.

- A tutorial covering the basics of the Lua framework.

- Advanced display layouts for a few games, most notably F-Zero GX and Super Mario Galaxy 1 and 2.

Here's an example of a Super Mario Galaxy RAM display in action: https://www.youtube.com/watch?v=Hri8f8Pgim8

You can get a RAM watch script up and running without any prior knowledge of Lua coding. If you do know some Lua (or are willing to learn), this framework can help you write display scripts for any game you like.


## Requirements

Windows or Linux. Cheat Engine doesn't have a Mac version, as of CE 6.6.


## Getting started

Go through the [Tutorial](/docs/tutorial/index.md) until you've got enough knowledge to do your game research.

Here's the first tutorial section: [Get a RAM watch script up and running](/docs/tutorial/run.md).

As a general recommendation, it's okay to skip doing a tutorial section if it doesn't really apply to you, but reading the sections you skip is probably still a good idea.


## Support

If you're having problems before even touching the Lua code, you might want to read [aldelaro's tutorial](http://tasvideos.org/forum/viewtopic.php?t=17735) on using Cheat Engine with Dolphin.

If you're having problems with a Lua script, try the [debugging and troubleshooting page](/docs/debugging.md).

If you've got a question, problem, error message, etc. that you want to ask about, try [this TASvideos forum thread](). (TODO: Add link) Note: In the Lua Engine window, the latest Lua error appears BELOW previous errors.

If you've got more of a suggestion or request, or you think you've found a bug, it might fit better in the GitHub issues section. In general, though, feel free to post at either GitHub or TASvideos.

If you've got a RAM watch script that used an old version of this framework, and you want to update that script, let me (yoshifan) know by PM, the TASvideos thread, Twitter, etc. I'll be happy to help with that.


## Disclaimer

Cheat Engine is a powerful tool, so don't be too careless when using it. For example, if you ever attempt to edit memory (such as when using the F-Zero GX stat-editing layouts), make extra sure that you've selected the Dolphin.exe process in Cheat Engine, and not some other process on your computer.


## Credits

Masterjun, for writing the Dolphin + Cheat Engine RAM watch script that this project was based on: http://pastebin.com/vUCmhwMQ (2013.08.26)

aldelaro, for the Dolphin + Cheat Engine tutorial I've linked a few times in these docs.
