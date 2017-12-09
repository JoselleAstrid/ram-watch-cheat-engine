# Troubleshooting and debugging


## Troubleshooting Lua script problems
 
- If an error occurs, a Lua Engine window will pop up. The latest Lua error's text appears BELOW previous errors' text in this Lua Engine window.

- After an error occurs, you may close any error and debug windows that might have popped up, and close the current RAM display window. Make any script edits as needed, then click Execute Script again to start running a new RAM display window.

- In many error cases, the game will pause and Cheat Engine will make the Memory View window pop up. If you try to resume the game without closing this Memory View window, then another error will occur. You'll need to close this Memory View window to stop the script execution, before doing anything else.

- Some layouts get an error if you run them while in a game menu, during game startup, or during a loading or transition screen. If this happens, make sure you are in the middle of gameplay before clicking Execute Script.

  - We try to code layouts robustly so that they don't error in these cases, but it always takes some extra effort, so no guarantees.

- If you're having trouble getting any layouts to display properly, and you're not getting any helpful error messages:

  - If you've defined a [constantGameStartAddress](different_dolphin.md#optional-constantgamestartaddress), double-check that it's correct. Try removing the `constantGameStartAddress` to see if that is the problem.

  - If you're not using a `constantGameStartAddress`, it's possible that the Lua framework's start-address scan doesn't work for your version of Dolphin. Try a different Dolphin version and see if that works fine. If a certain Dolphin version doesn't seem to work, feel free to [report it](/README.md#support) and we'll see what we can do.

- If you can get a layout to display, but the values don't update as expected when you play the game, check if your layout's init function body has `setBreakpointUpdateMethod()` in the code. If so, it's possible that the [frameCounterAddress or oncePerFrameAddress](different_dolphin.md) are not defined correctly.

- It's quite possible that a layout we've coded is unusable or buggy in some way. If you've got any suspicions, feel free to [report it](/README.md#support).


## Debugging Lua script problems

If you're writing your own Lua scripts, you're generally not going to get it right on the first try. Sometimes, you'll be out of obvious solutions, and you'll need to dig for the solution with some debugging techniques.

Cheat Engine Lua scripts can be tricky to debug, but it's possible to get by if you put a few imperfect debugging techniques together.

- The Game object can reach a lot of useful status information about your Lua script. You can access the Game object in a layout using `self.game`. So, try passing `function() return self.game.nameOfField end` into the `addItem()` function to display some status information.

- Use `error(mystring)`at any point in the code to raise an error and stop the script, printing `mystring` in the error message. This can be used in a few ways:

  - Verify that a certain line of code is being reached.
  
  - Verify that a certain line of code is being reached with a certain condition being true: Put the `error()` line in an 'if' statement checking for a condition you're curious about (e.g. is this variable nil?).
  
  - See what a variable's value is at a particular point in the program, using `error(tostring(myvariable))`. If you're printing a memory address, try `error(utils.intToHexStr(myvariable))`.
  
- Use `error(debug.traceback())` to print the function call stack. This can show you which function calls led to that error line being reached. The traceback is somewhat limited because it gets cut off at tail calls, but it can still help.

- Try commenting out lines of code until your script runs again. Then uncomment lines until it breaks again, and so on. It's a crude method, but it tends to help narrow down the problem when nothing else does.


## Performance concerns

Running one of these scripts alongside your game may cause the game to run slower, especially if the script uses a breakpoint to run the code. Using timer-based updating can have noticeably better performance than using breakpoints, even for very simple Lua scripts. The catch, of course, is that your script may miss some frames.

If you're in the middle of a Dolphin and Cheat Engine session, and you feel like performance is getting slower and slower, try closing and re-opening both Dolphin and Cheat Engine.
