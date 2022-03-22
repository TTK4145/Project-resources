Rationale
=========

TTK4145 is not an algorithms course, nor is it an elevator system design course. Spending time on writing code for distributing requests in some optimal way is not an efficient way to learn about distributed systems, fault tolerance, and other things that are *actually relevant to the course*. So some default solutions are provided here.

However, *maturity in programming* is still part of the learning goals, so any time spent making this yourself is absolutely not a waste, just be sure to have your priorities straight.


Request distribution algorithms
===============================

 - [Alternative 1](#alternative-1-assigning-only-the-new-request): Assigning only the new request
   - [Alternative 1.1](#alternative-11-time-until-completionidle): Time until completion/idle
   - [Alternative 1.2](#alternative-12-time-until-unassigned-request-served): Time until unassigned request served
 - [Alternative 2](#alternative-2-reassigning-all-requests): Reassigning all requests

Required data
-------------

In order to assign a new request, we need the following information:

 - The unassigned request
 - The whereabouts of the elevators (floor, direction, state/behavior (ie. moving, doorOpen, idle))
 - The current set of existing requests (cab requests and hall requests)
 - The availability or failure modes of the elevators
 
From here we have two main ways of doing assignment: Assigning only a single new hall request, or re-assigning every hall request

### Alternative 1: Assigning only the new request

In this alternative, a hall request is assigned to a particular elevator for the duration of the lifetime of that request, i.e. the hall request is not "moved" to another elevator during normal operation (say, due to the assigned elevator getting a lot of cab requests). This means that we already know the combined cab and hall workload of each elevator.

From this we can calculate the cost of the new unassigned hall request by adding it to the existing workload and simulating the execution of the elevator. For this simulation we use the functions that we already have from the single elevator algorithm: Choose Direction, Should Stop, and Clear Requests At Current Floor:

#### Alternative 1.1: Time until completion/idle

As a reminder, this is the data a single elevator contains (see [`elevator.h`](../elev_algo/elevator.h) from the single-elevator example):
```C
typedef struct {
    int                     floor;
    Dirn                    dirn;
    int                     requests[N_FLOORS][N_BUTTONS];
    ElevatorBehaviour       behaviour;
} Elevator;
```

Note that in order to reuse the function for clearing requests in a simulated context, we need to make sure it does not actually perform any side effects on its own. Otherwise, the simulation run might actually remove all the orders in the system, turn off lights, and so on.

The suggested modification is giving `requests_clearAtCurrentFloor` a second argument containing a function pointer to some side-effect, which lets us pass some function like "publish the clearing of this order", or in the case of our cost function - "do nothing", which is exactly what we want. *(For most sensible modern languages, the passed-in function would be a lambda, or some other thing that lets you capture the enclosing scope, so the `floor` parameter to the inner function is probably not necessary)*

If you are really scared of function pointers (or the designers of your language of choice were scared and didn't implement it), you can just make two functions (one simulated & one real), or pass a "simulate" boolean. Just make sure that the simulated behavior and real behavior are the same. Or, you could make the function return a list of orders to clear, then for-each through it afterwards.
```C
Elevator requests_clearAtCurrentFloor(Elevator e_old, void onClearedRequest(Button b, int floor)){
    Elevator e = e_old;
    // This shouldn't clear every single order - just to make the example shorter
    for(Button btn = 0; btn < N_BUTTONS; btn++){
        if(e.requests[e.floor][btn]){
            e.requests[e.floor][btn] = 0;
            if(onClearedRequest){
                onClearedRequest(btn, floor);
            }
        }
    }
    return e;
}
```

Now for the fun part, the `timeToIdle` function.

The main loop:

 - checks if we should stop, and if we are stopping:
   - adds the door open time to the total duration
   - removes the requests at that floor
   - chooses a new direction
 - travels to the next floor and adds the travel time to the total duration
 
The loop terminates when the new next direction is "stop", indicating that there is nowhere more to go and that we are idle.

In order to make sure we start in a state where we can ask if we should stop, we give the elevator the required "initial move":

 - Idle elevators must choose a direction
 - Moving elevators must go forward in time and arrive at the next floor
 - Elevators with the door open must go back in time to when they arrived at their current floor

*(That last one about going back in time relies on that we should always stop at this floor if we are going in a direction where there are no further requests. And if we are already going in the direction of the new unassigned request, we don't need to modify the direction)*
 
```C
int timeToIdle(Elevator e){
    int duration = 0;
    
    switch(e.behaviour){
    case EB_Idle:
        e.dirn = requests_chooseDirection(e);
        if(e.dirn == D_Stop){
            return duration;
        }
        break;
    case EB_Moving:
        duration += TRAVEL_TIME/2;
        e.floor += e.dirn;
        break;
    case EB_DoorOpen:
        duration -= DOOR_OPEN_TIME/2;
    }


    while(true){
        if(requests_shouldStop(e)){
            e = requests_clearAtCurrentFloor(e, NULL);
            duration += DOOR_OPEN_TIME;
            e.dirn = requests_chooseDirection(e);
            if(e.dirn == D_Stop){
                return duration;
            }
        }
        e.floor += e.direction;
        duration += TRAVEL_TIME;
    }
}
```

Remember to copy the Elevator data and add the new unassigned request to that copy before calling `timeToIdle`. Just as you don't want to remove requests when you are simulating, you also don't want to add requests when you are trying to figure out who you should add requests to in the first place.

#### Alternative 1.2: Time until unassigned request served

As a slight modification, we can take the time it takes to serve specifically this new unassigned request, as opposed to all requests combined. The two modifications are
 - An extra parameter for the floor and button type of the new request
 - Passing a comparison of the cleared request and the unassigned request to the Clear Requests function
 
(The example code is not technically valid C, but it compiles with GCC because they are gracious enough to supply [nested functions](https://gcc.gnu.org/onlinedocs/gcc/Nested-Functions.html) as a compiler extension. Thanks GCC!)

```C
int timeToServeRequest(Elevator e_old, Button b, floor f){
    Elevator e = e_old;
    e.requests[f][b] = 1;

    int arrivedAtRequest = 0;
    void ifEqual(Button inner_b, int inner_f){
        if(inner_b == b && inner_f == f){
            arrivedAtRequest = 1;
        }
    }

    int duration = 0;
    
    switch(e.behaviour){
    case EB_Idle:
        e.dirn = requests_chooseDirection(e);
        if(e.dirn == D_Stop){
            return duration;
        }
        break;
    case EB_Moving:
        duration += TRAVEL_TIME/2;
        e.floor += e.dirn;
        break;
    case EB_DoorOpen:
        duration -= DOOR_OPEN_TIME/2;
    }


    while(true){
        if(requests_shouldStop(e)){
            e = requests_clearAtCurrentFloor(e, ifEqual);
            if(arrivedAtRequest){
                return duration;
            }
            duration += DOOR_OPEN_TIME;
            e.dirn = requests_chooseDirection(e);
        }
        e.floor += e.direction;
        duration += TRAVEL_TIME;
    }
}

```

### Alternative 2: Reassigning all requests

For this alternative, all hall requests are reassigned whenever new data enters the system. This new data could be a new request, an updated state from some elevator, or an update on who is alive on the network. This redistribution means that a request is not necessarily assigned to the same elevator for the duration of its lifetime, but can instead be re-assigned to a new elevator, for example if a new idle elevator connects to the network, or the previously assigned elevator gets a lot of cab requests.

In order for this approach to work, it is necessary that either a) this distribution is uniquely calculated by some single elevator (some kind of master elevator), or b) all elevators that calculate the redistribution eventually come to the same conclusion - if the input data is not (eventually) consistent across the elevators, we can end up in a situation where a request is never served because all the elevators come to different conclusions that say "it is optimal that some other elevator is serving this request".

Unlike with Alternative 1, it is not recommended that you try to implement this code yourself - at least not without being inspired by (aka copying) existing code. This code [is found here](hall_request_assigner), and has already been compiled as a standalone executable which can be found in [the releases tab](https://github.com/TTK4145/Project-resources/releases/latest).

*If you are on linux (and osx?), you will likely have to give yourself permission to run the program after downloading it with `chmod a+rwx hall_request_assigner`*

----

Again, we reuse the functions that we already have from the single elevator algorithm: Choose Direction, Should Stop, and Clear Requests At Current Floor - with the modification for clearing requests such that there are no side-effects when they are being cleared.

The algorithm is very similar to that the Time To Idle function, but instead of simulating several single elevators to completion in turn, we simulate a single "step" for each elevator in turn. A "single step" here means something that takes time, which means either moving between floors or holding the door open. The main loop of the Time To Idle function must therefore be split into two phases, one for arriving at a floor and one for departing. And similarly, all elevators must be moved some initial step to put them into a state where they are either about to arrive or about to depart.

Since a single step can have different durations associated with them (holding the door open might take longer than moving between floors), we make sure to always select the elevator that has the shortest total duration when choosing which elevator to move. The table of hall requests contains both the information of which requests are active (a boolean), and also who has been assigned each request (if it is active). The main loop then terminates once all active hall requests have been assigned. 

A single step looks something like this:

 - Create a temporary copy of this elevator, and assign it all active but unassigned requests.
 - If arriving:
   - Check if we should stop (given these temporary requests), and if we are stopping:
     - Add the door open time
     - Clear the request(s) at this floor, where the side-effect is *assigning it to ourselves* in the main hall request table
   - Otherwise, keep moving to the next floor and add the travel time
 - If departing:
   - Choose a direction, and if we are idle:
     - Remain idle
   - Otherwise, depart in that direction and add the travel time

----

There is one major quirky issue though, involving the direction of the requests. Say we have one elevator at floor 0, one at floor 3, and two hall requests Down-1 and Up-2. The elevator at the bottom moves up to floor 1, the elevator at the top moves down to floor 2. In turn, they both see that there are requests further along in the direction of travel (as per the Should Stop function), and neither take the requests, but instead keep moving. Thus, the elevator at the top moved down to floor 1, and the elevator at the bottom moved up to floor 2, and have moved right past each other!

Which means we need a special case this situation, that can be expressed as "all the unassigned hall requests are at floors where there already is an elevator, and none of these elevators have any remaining cab requests". If this situation is true, we can take a shortcut in the main loop, and immediately assign all the remaining hall requests.















































