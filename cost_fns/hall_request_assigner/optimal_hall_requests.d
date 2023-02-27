//debug = optimal_hall_requests;

import elevator_state;
import elevator_algorithm;
import config;

import std.algorithm;
import std.conv;
import std.datetime;
import std.range;
import std.stdio;




bool[][][string] optimalHallRequests(
    bool[2][]                       hallReqs,
    LocalElevatorState[string]      elevatorStates,
)    
in {
        auto numFloors = hallReqs.length;
        assert(elevatorStates.length,
            "No elevator states provided");
        assert(elevatorStates.values.map!(a => a.cabRequests.length == numFloors).all,
            "Hall and cab requests do not all have the same length");
        bool isInBounds(int f){ return f >= 0 && f < numFloors; }
        assert(elevatorStates.values.map!(a => isInBounds(a.floor)).all,
            "Some elevator is at an invalid floor");
        assert(elevatorStates.values
                .filter!(a => a.behaviour == ElevatorBehaviour.moving)
                .map!(a => isInBounds(a.floor + a.direction))
                .all,
            "Some elevator is moving away from an end floor");
}
do {
    auto reqs   = hallReqs.toReq;
    auto states = initialStates(elevatorStates);
    
    debug(optimal_hall_requests) writefln("\n   ---   START   ---   ");
    debug(optimal_hall_requests) writefln("states:\n  %(%s,\n  %)", states);
    debug(optimal_hall_requests) writefln("reqs:\n%(  %(%s, %)\n%)", reqs);
    
    foreach(ref s; states){
        performInitialMove(s, reqs);
    }
    
    while(true){
        states.sort!("a.time < b.time")();
        
        debug(optimal_hall_requests) writeln;
        debug(optimal_hall_requests) writefln("states:\n  %(%s,\n  %)", states);
        debug(optimal_hall_requests) writefln("reqs:\n%(  %(%s, %)\n%)", reqs);
    
        bool done = true;
        if(reqs.anyUnassigned){
            done = false;
        }
        if(unvisitedAreImmediatelyAssignable(reqs, states)){
            debug(optimal_hall_requests) writefln("unvisited immediately assignable");
            assignImmediate(reqs, states);
            done = true;
        }
        
        if(done){
            break;
        }
        
        debug(optimal_hall_requests) writefln!("'%s' doing single move")(states[0].id);
        performSingleMove(states[0], reqs);
    }
    
    
    bool[][][string] result;
    
    if(includeCab){
        foreach(id, _; elevatorStates){
            result[id] = new bool[][](hallReqs.length, 3);
            for(int f = 0; f < hallReqs.length; f++){
                result[id][f][2] = elevatorStates[id].cabRequests[f];
            }
        }
    } else {
        foreach(id, _; elevatorStates){
            result[id] = new bool[][](hallReqs.length, 2);
        }
    }
    
    for(int f = 0; f < hallReqs.length; f++){
        for(int c = 0; c < 2; c++){
            if(reqs[f][c].active){
                result[reqs[f][c].assignedTo][f][c] = true;
            }
        }
    }

        
    debug(optimal_hall_requests) writefln("\nfinal:");
    debug(optimal_hall_requests) writefln("states:\n  %(%s,\n  %)", states);
    debug(optimal_hall_requests) writefln("reqs:\n%(  %(%s, %)\n%)", reqs);
    debug(optimal_hall_requests) writefln("result:\n%(  %s : %([%(%d, %)]%|, %)\n%)", result);
    debug(optimal_hall_requests) writefln("   ---    END    ---   \n");
    
    return result;
}

private :

struct Req {
    bool    active;
    string  assignedTo;
}

struct State {
    string              id;
    LocalElevatorState  state;
    Duration            time;
}


bool isUnassigned(Req r){
    return r.active && r.assignedTo == string.init;
}

bool[2][] filterReq(alias fn)(Req[2][] reqs){
    return reqs.map!(a => a.to!(Req[]).map!(fn).array).array.to!(bool[2][]);
}

Req[2][] toReq(bool[2][] hallReqs) {
    auto r = new Req[2][](hallReqs.length);
    foreach(f, reqsAtFloor; hallReqs){
        foreach(b, req; reqsAtFloor){
            r[f][b] = Req(hallReqs[f][b], string.init);
        }
    }
    return r;
}

ElevatorState withReqs(alias fn)(State s, Req[2][] reqs){
    return s.state.withRequests(reqs.filterReq!(fn));
}

bool anyUnassigned(Req[2][] reqs){
    return reqs
        .filterReq!(isUnassigned)
        .map!(a => a.to!(bool[]).any).any;
}

State[] initialStates(LocalElevatorState[string] states){
    return zip(states.keys, states.values)
        .sort!(q{a[0] < b[0]})
        .zip(iota(states.length))
        .map!(a => 
            State(a[0][0], a[0][1], a[1].usecs)
        )
        .array;
}



void performInitialMove(ref State s, ref Req[2][] reqs){
    debug(optimal_hall_requests) writefln("initial move: %s", s);
    final switch(s.state.behaviour) with(ElevatorBehaviour){    
    case doorOpen:
        debug(optimal_hall_requests) writefln!("  '%s' closing door at floor %d")(s.id, s.state.floor);
        s.time += doorOpenDuration.msecs/2;
        goto case idle;
    case idle:
        foreach(c; 0..2){
            if(reqs[s.state.floor][c].active){
                reqs[s.state.floor][c].assignedTo = s.id;
                s.time += doorOpenDuration.msecs;
                debug(optimal_hall_requests) writefln!("  '%s' taking req %s at floor %d")(s.id, c, s.state.floor);
            }
        }
        break;
    case moving:
        s.state.floor += s.state.direction;
        s.time += travelDuration.msecs/2;
        debug(optimal_hall_requests) writefln!("  '%s' arriving at %d")(s.id, s.state.floor);
        break;
    }
}

void performSingleMove(ref State s, ref Req[2][] reqs){
    
    auto e = s.withReqs!(isUnassigned)(reqs);
    debug(optimal_hall_requests) writefln("%s", e);
    
    auto onClearRequest = (CallType c){
        final switch(c) with(CallType){
        case hallUp, hallDown:
            reqs[s.state.floor][c].assignedTo = s.id;
            break;
        case cab:
            s.state.cabRequests[s.state.floor] = false;
        }
    };
    
    final switch(s.state.behaviour) with(ElevatorBehaviour){
    case moving:
        if(e.shouldStop){
            s.state.behaviour = doorOpen;
            s.time += doorOpenDuration.msecs;
            e.clearReqsAtFloor(onClearRequest);
            debug(optimal_hall_requests) writefln!("  '%s' stopping at %d")(s.id, s.state.floor);
        } else {
            s.state.floor += s.state.direction;
            s.time += travelDuration.msecs;
            debug(optimal_hall_requests) writefln!("  '%s' continuing to %d")(s.id, s.state.floor);
        }
        break;
    case idle, doorOpen:
        s.state.direction = e.chooseDirection;
        if(s.state.direction == Dirn.stop){            
            if(e.anyRequestsAtFloor){
                e.clearReqsAtFloor(onClearRequest);
                s.time += doorOpenDuration.msecs;
                s.state.behaviour = doorOpen;
                debug(optimal_hall_requests) writefln!("  '%s' taking req in opposite dirn at %d")(s.id, s.state.floor);
            } else {
                s.state.behaviour = idle;
                debug(optimal_hall_requests) writefln!("  '%s' idling at %d")(s.id, s.state.floor);
            }
        } else {
            s.state.behaviour = moving;
            s.state.floor += s.state.direction;
            s.time += travelDuration.msecs;
            debug(optimal_hall_requests) writefln!("  '%s' departing %s to %d")(s.id, s.state.direction, s.state.floor);
        }
        break;
    }
    
    debug(optimal_hall_requests) writefln("%s", s.withReqs!(isUnassigned)(reqs));
}

// no remaining cab requests, no floors with multiple hall requests, and all *unvisited* hall requests are at floors with elevators
bool unvisitedAreImmediatelyAssignable(Req[2][] reqs, State[] states){
    if(states.map!(a => a.state.cabRequests.any).any){
        return false;
    }
    foreach(f, reqsAtFloor; reqs){
        if(reqsAtFloor.array.map!(a => a.active).count!(a => a) == 2){
            return false;
        }
        foreach(c, req; reqsAtFloor){
            if(req.isUnassigned){
                if(states.filter!(a => a.state.floor == f && !a.state.cabRequests.any).empty){
                    return false;
                }
            }
        }
    }
    return true;
}

void assignImmediate(ref Req[2][] reqs, ref State[] states){
    foreach(f, ref reqsAtFloor; reqs){
        foreach(c, ref req; reqsAtFloor){
            foreach(ref s; states){
                if(req.isUnassigned){
                    if(s.state.floor == f && !s.state.cabRequests.any){
                        req.assignedTo = s.id;
                        s.time += doorOpenDuration.msecs;
                    }
                }
            }
        }
    }    
}







unittest {
    // Elevator 1 is idle one floor away, other elevators have several cab orders
    // Should give the order to the idle elevator
    LocalElevatorState[string] states = [
        "1" : LocalElevatorState(ElevatorBehaviour.idle,     0, Dirn.stop, [0, 0, 0, 0].to!(bool[])),
        "2" : LocalElevatorState(ElevatorBehaviour.doorOpen, 3, Dirn.down, [1, 0, 0, 0].to!(bool[])),
        "3" : LocalElevatorState(ElevatorBehaviour.moving,   2, Dirn.up,   [1, 0, 0, 1].to!(bool[])),
    ];

    bool[2][] hallreqs = [
        [false, false],
        [true,  false],
        [false, false],
        [false, false],
    ];
    

    auto optimal = optimalHallRequests(hallreqs, states);
    assert(optimal == [
        "1" : [[0,0],[1,0],[0,0],[0,0]].to!(bool[][]),
        "2" : [[0,0],[0,0],[0,0],[0,0]].to!(bool[][]),
        "3" : [[0,0],[0,0],[0,0],[0,0]].to!(bool[][]),
    ]);
}

unittest {
    // Two elevators moving from each "end" toward the middle floors
    // Elevators should stop at the closest order, even if it is in the "wrong" direction
    LocalElevatorState[string] states = [
        "1" : LocalElevatorState(ElevatorBehaviour.idle, 0, Dirn.stop, [0, 0, 0, 0].to!(bool[])),
        "2" : LocalElevatorState(ElevatorBehaviour.idle, 3, Dirn.stop, [0, 0, 0, 0].to!(bool[])),
    ];

    bool[2][] hallreqs = [
        [false, false],
        [false, true],
        [true,  false],
        [false, false],
    ];
    

    auto optimal = optimalHallRequests(hallreqs, states);
    assert(optimal == [
        "1" : [[0,0],[0,1],[0,0],[0,0]].to!(bool[][]),
        "2" : [[0,0],[0,0],[1,0],[0,0]].to!(bool[][]),
    ]);

    
    // Change E1 idle->moving, stop->up. E1 is closer, but otherwise same scenario
    states = [
        "1" : LocalElevatorState(ElevatorBehaviour.moving, 0, Dirn.up,   [0, 0, 0, 0].to!(bool[])), 
        "2" : LocalElevatorState(ElevatorBehaviour.idle,   3, Dirn.stop, [0, 0, 0, 0].to!(bool[])),
    ];

    optimal = optimalHallRequests(hallreqs, states);
    assert(optimal == [
        "1" : [[0,0],[0,1],[0,0],[0,0]].to!(bool[][]),
        "2" : [[0,0],[0,0],[1,0],[0,0]].to!(bool[][]),
    ]);
    
    
    // Add cab order to E1, so that it has to continue upward anyway
    // Changes scenario, now E1 skips order in "wrong" direction because there is work ahead in that dirn
    states = [
        "1" : LocalElevatorState(ElevatorBehaviour.idle,   0, Dirn.stop, [0, 0, 1, 0].to!(bool[])),
        "2" : LocalElevatorState(ElevatorBehaviour.idle,   3, Dirn.stop, [0, 0, 0, 0].to!(bool[])),
    ];

    optimal = optimalHallRequests(hallreqs, states);
    assert(optimal == [
        "1" : [[0,0],[0,0],[1,0],[0,0]].to!(bool[][]),
        "2" : [[0,0],[0,1],[0,0],[0,0]].to!(bool[][]),
    ]);
}

unittest {
    // Two elevators are the same number of floors away from an order, but one is moving toward it
    // Should give the order to the moving elevator
    LocalElevatorState[string] states = [
        "27" : LocalElevatorState(ElevatorBehaviour.moving,   1,  Dirn.down, [0, 0, 0, 0].to!(bool[])),
        "20" : LocalElevatorState(ElevatorBehaviour.doorOpen, 1,  Dirn.down, [0, 0, 0, 0].to!(bool[])),
    ];

    bool[2][] hallreqs = [
        [true,  false],
        [false, false],
        [false, false],
        [false, false],
    ];
    
    auto optimal = optimalHallRequests(hallreqs, states);
    assert(optimal == [
        "27" : [[1,0],[0,0],[0,0],[0,0]].to!(bool[][]),
        "20" : [[0,0],[0,0],[0,0],[0,0]].to!(bool[][]),
    ]);
}

unittest {
    // Two hall requests at the same floor, but the closest elevator also has a cab call further in the same direction
    // Should give the two hall orders to different elevators, the one in the "opposite" direction to the one without a cab order
    auto prev = clearRequestType;
    clearRequestType = ClearRequestType.inDirn;
    scope(exit) clearRequestType = prev;
    
    LocalElevatorState[string] states = [
        "1" : LocalElevatorState(ElevatorBehaviour.moving,  3,  Dirn.down, [1, 0, 0, 0].to!(bool[])),
        "2" : LocalElevatorState(ElevatorBehaviour.idle,    3,  Dirn.down, [0, 0, 0, 0].to!(bool[])),
    ];

    bool[2][] hallreqs = [
        [false, false],
        [true, true],
        [false, false],
        [false, false],
    ];
        
    auto optimal = optimalHallRequests(hallreqs, states);
    assert(optimal == [
        "1" : [[0,0],[0,1],[0,0],[0,0]].to!(bool[][]),
        "2" : [[0,0],[1,0],[0,0],[0,0]].to!(bool[][]),
    ]);
}


unittest {
    // Two identical elevators. Assignment should always be to the lexicographically lowest ID
    LocalElevatorState[string] states = [
        "1" : LocalElevatorState(ElevatorBehaviour.moving,  1,  Dirn.up,   [1, 0, 0, 0].to!(bool[])),
        "2" : LocalElevatorState(ElevatorBehaviour.idle,    1,  Dirn.stop, [1, 0, 0, 0].to!(bool[])),
        "3" : LocalElevatorState(ElevatorBehaviour.idle,    1,  Dirn.stop, [1, 0, 0, 0].to!(bool[])),
    ];

    bool[2][] hallreqs = [
        [true,  false],
        [false, false],
        [false, false],
        [false, true],
    ];
    

    auto optimal = optimalHallRequests(hallreqs, states);
    
    assert(optimal == [
        "1" : [[0,0], [0,0], [0,0], [0,1]].to!(bool[][]),
        "2" : [[1,0], [0,0], [0,0], [0,0]].to!(bool[][]),
        "3" : [[0,0], [0,0], [0,0], [0,0]].to!(bool[][]),
    ]);
}


unittest {
    // Single elevator starting at 0, up + down orders at both floor 1 and 2, for inDirn mode specifically:
    // Elevator should single-stop at 1, double-stop at 2, then single-stop at 1 again (for a total of 4 stops and 3 moves)
    auto prev = clearRequestType;
    clearRequestType = ClearRequestType.inDirn;
    scope(exit) clearRequestType = prev;
    
    auto states = initialStates([
        "one" : LocalElevatorState(ElevatorBehaviour.idle,  0,  Dirn.stop,   [0, 0, 0, 0].to!(bool[])),
    ]);

    auto hallreqs = [
        [false, false],
        [true,  true],
        [true,  true],
        [false, false],
    ].toReq;
    
    while(hallreqs.anyUnassigned){
        performSingleMove(states[0], hallreqs);
    }
    
    assert(states[0].time == (doorOpenDuration*4 + travelDuration*3).msecs);
}


unittest {
    // Two hall requests at the same floor, but the closest elevator also has a cab call further in the same direction
    // Should give the two hall orders to different elevators, the one in the "opposite" direction to the one without a cab order
    auto prev = clearRequestType;
    clearRequestType = ClearRequestType.inDirn;
    scope(exit) clearRequestType = prev;
    
    LocalElevatorState[string] states = [
        "one" : LocalElevatorState(ElevatorBehaviour.idle,    0,  Dirn.down, [0, 0, 0, 0].to!(bool[])),
        "two" : LocalElevatorState(ElevatorBehaviour.idle,    3,  Dirn.down, [0, 0, 0, 0].to!(bool[])),
    ];

    bool[2][] hallreqs = [
        [false, false],
        [true, true],
        [true, false],
        [false, false],
    ];
        
    auto optimal = optimalHallRequests(hallreqs, states);
    assert(optimal == [
        "one" : [[0,0],[1,0],[1,0],[0,0]].to!(bool[][]),
        "two" : [[0,0],[0,1],[0,0],[0,0]].to!(bool[][]),
    ]);
}


