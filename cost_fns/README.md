Rationale
=========

TTK4145 is not an algorithms course, nor is it an elevator system design course. Spending time on writing code for distributing requests in some optimal way is not an efficient way to learn about distributed systems, fault tolerance, and other things that are *actually relevant to the course*. So some default solutions are provided here.

However, *maturity in programming* is still part of the learning goals, so any time spent making this yourself is absolutely not a waste, just be sure to have your priorities straight.


Request distribution algorithms
===============================

Required data
-------------

In order to assign a new request, we need the following information:

 - The unassigned request
 - The whereabouts of the elevators (floor, direction, state/behavior (ie. moving, doorOpen, idle))
 - The current set of existing requests (cab requests and hall requests)
 - The availability or failure modes of the elevators
 
From here we have two main ways of doing assignment: Assigning only a single new hall request, or re-assigning every hall request

### Alternative 1: Assigning only the new request

In this alternative, a hall request is assigned to a particular elevator for the duration of the lifetime of that request, ie. the hall request is not "moved" to another elevator during normal operation (say, due to the assigned elevator getting a lot of cab requests). This means that we already know the combined cab and hall workload of each elevator.

From this we can calculate the cost of the new unassigned hall request by adding it to the existing workload and simulating the execution of the elevator. For this simulation we use the functions that we already have from the single elevator algorithm: Choose Direction, Should Stop, and Clear Requests At Current Floor:

#### Alternative 1.1: Time until completion/idle

As a reminder, this is the data a single elevator contains (see `[elevator.h](/../elev_algo/elevator.h)` from the single-elevator example):
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

If you are really scared of function pointers (or the designers of your language of choice were scared and didn't implement it), you can just make two functions (one simulated & one real), or pass a "simulate" boolean. Just make sure that the simulated behavior and real behavior are the same.
```C
Elevator requests_clearAtCurrentFloor(Elevator e_old, void onClearedRequest(Button b, int floor)){
    Elevator e = e_old;
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
 - An extra parameter for the floor (and button type, depending on how requests are cleared) of the new request
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

TODO: Migrate [the hall request assigner](https://github.com/klasbo/hall_request_assigner) to this repo  
TODO: Explain how it works. Short version: Simulate the elevators one step (travel or door open) at a time, always moving the elevator with the shortest duration, and picking up/assigning hall requests as they are reached.  
TODO: Provide executable

















































