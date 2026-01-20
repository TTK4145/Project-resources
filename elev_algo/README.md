Rationale
=========

All 5-year cybernetics students should have previously done a smaller elevator project, where the goal was to control a single elevator (with some extra considerations for the stop button). Since not everyone taking this course has done this project, it is only fair to introduce you to the "standard" solution to (the relevant part of) that project. 

As usual, there are no "right" or "wrong" solutions, only solutions that do or do not work. This solution uses a 3-state event-based state machine (States: {Idle, Moving, Door open}, Events: {Button press, Arrive at floor, Timer timed out}). Your design may not, especially when considering that there are three (or more) elevators that need to interact with each other.


The basic elevator algorithm
============================

The elevator algorithm is based on preferring to continue in the direction of travel, as long as there are any requests in that direction. We implement this algorithm with three functions:
 - Choose direction:
   - Continue in the current direction of travel if there are any further requests in that direction
   - Otherwise, change direction if there are requests in the opposite direction
   - Otherwise, stop and become idle
 - Should stop:
   - Stop if there are passengers that want to get off at this floor
   - Stop if there is a request in the direction of travel at this floor 
   - Stop if there are no further requests in this direction
 - Clear requests at floor:  
   This function comes in two variants. We can either assume that anyone waiting for the elevator gets on the elevator regardless of which direction it is traveling in, or that they only get on the elevator if the elevator is going to travel in the direction the passenger desires. (Most people would expect the first behaviour, but there are elevators that only clear the requests "in the direction of travel". I believe the one outside EL6 behaves like this.)
   - Always clear the request for getting off the elevator and the request for entering the elevator in the direction of travel
   - Either:
     - A: Always clear the request for entering the elevator in the opposite direction
     - B: Clear the request in the opposite direction if there are no further requests in the direction of travel
     
The implementations of these three functions are found in [requests.c](requests.c).

**NB: For TTK4145, users are assumed to only enter an elevator moving in the direction they have requested. See "An individual elevator should behave sensibly and efficiently" in the specification.**

Running this program
====================

 - Make sure you have cloned this repository recursively, in order to get the c driver code (`git clone --recursive https://github.com/TTK4145/Project-resources.git`)
   - Alternatively, download the [C driver from this link](https://github.com/TTK4145/driver-c) and place it in the `driver` folder
 - Compile using `make`. Use `make CC=[compiler]` to use a different compiler (eg `make CC=clang-3.6`)
   - The executable is called `ttk4145demoelevator`
 - Start the elevator server or simulator before starting this demo program

The config file [elevator.con](elevator.con) can be edited to change the behaviour of the elevator. The elevator program must be restarted in order for the saved changes to take effect.


Implementation notes
====================

The standard disclaimer of "some parts of this were written in less than 10 minutes" applies.

The request buttons are called "Hall" and "Cab", as opposed to "external" and "internal" (or "Call" and "Command"), as I believe this is the correct terminology.

The "state-machine-state" is called "behaviour", as the full state of the elevator also includes direction, floor, and active requests. "Behaviour" just seems like a more precise name: An elevator that is "moving" is doing a different kind of thing (or "verbing a different verb", if you like) than an elevator that is "being idle".

There are three major boundaries in this program:
 - `main` -> `fsm`: Inputs need to be polled and passed on to the elevator algorithm  
    This boundary is just a function call, but you should consider making this a message
 - `fsm` -> `requests`: The elevator algorithm makes decisions  
    Requests-functions are pure, so they are extracted
 - `fsm` -> `elevator` output: The elevator algorithm has to affect the outside world  
    This prevents FSM-functions from being pure. Placing these as cases in a message-receive will be possible once the main-to-FSM boundary is changed to message passing

Since C does not have multiple return values or anonymous tuples, the "choose direction" function returns a struct. You should change this the whatever is the most language-appropriate mechanism. The door timer should also be replaced with whatever timeout mechanism you can find in your language's standard library.

Your events will probably be something else than direct button presses (since they can conceptually come from anywhere, not just the local hardware). 

