# Troubleshooting and debugging


## Troubleshooting Lua script problems
 
- If an error occurs, a Lua Engine window will pop up. The latest Lua error's text appears BELOW previous errors' text in this Lua Engine window.

- In many error cases, the game will pause and Cheat Engine will make the Memory View window pop up. Just close this Memory View window and move on.

- Some layouts get an error if you run them while in a menu or during game startup. If this happens, make sure you are in the middle of gameplay before clicking Execute Script.

- If you're having trouble getting any layouts to display properly, and you're not getting any helpful error messages, it's possible that the script's start-address scan doesn't work for your version of Dolphin. Try a different Dolphin version and see if that works fine. If a certain Dolphin version doesn't seem to work, feel free to [post on GitHub or TASvideos](/README.md#support) saying so.


## Debugging Lua script problems

Cheat Engine Lua scripts can be tricky to debug, but it's possible to get by if you put a few imperfect debugging techniques together.

- The Game object can reach a lot of useful status information about your Lua script. You can access the Game object in a layout using `self.game`. So, try passing `function() return self.game.nameOfField end` into the `addItem()` function to display some status information.

- Use `error(mystring)`at any point in the code to raise an error and stop the script, printing `mystring` in the error message. This can be used in a few ways:

  - Verify that a certain line of code is being reached.
  
  - Verify that a certain line of code is being reached with a certain condition being true: Put the `error()` line in an 'if' statement checking for a condition you're curious about (e.g. is this variable nil?).
  
  - See what a variable's value is at a particular point in the program, using `error(tostring(myvariable))`. If you're printing a memory address, try `error(utils.intToHexStr(myvariable))`.
  
- Use `error(debug.traceback())` to print the function call stack. This can show you which function calls led to that error line being reached. The traceback is somewhat limited because it gets cut off at tail calls, but it can still help.

- Try commenting out lines of code until your script runs again. Then uncomment lines until it breaks again, and so on. It's a crude method, but it tends to help narrow down the problem when nothing else does.


## Performance concerns

Running one of these scripts alongside your game may cause the game to run slower, especially if the script uses a breakpoint to run the code. Using Cheat Engine's Timer class can have noticeably better performance than using breakpoints, even for very simple Lua scripts. The catch, of course, is that your script may miss some frames.

If you're in the middle of a Dolphin and Cheat Engine session, and you feel like performance is getting slower and slower, try closing and re-opening both Dolphin and Cheat Engine.
