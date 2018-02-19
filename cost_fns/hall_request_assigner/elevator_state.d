
import std.algorithm;
import std.array;
import std.conv;
import std.range;

enum CallType : int {
    hallUp,
    hallDown,
    cab
}

enum HallCallType : int {
    up,
    down
}

enum Dirn : int {
    down    = -1,
    stop    = 0,
    up      = 1
}

enum ElevatorBehaviour {
    idle,
    moving,
    doorOpen,
}


struct LocalElevatorState {
    ElevatorBehaviour   behaviour;
    int                 floor;
    Dirn                direction;
    bool[]              cabRequests;
    this(this){
        cabRequests = cabRequests.dup;
    }
}


struct ElevatorState {
    ElevatorBehaviour   behaviour;
    int                 floor;
    Dirn                direction;
    bool[3][]           requests;
    this(this){
        requests = requests.dup;
    }
}

LocalElevatorState local(ElevatorState e){
    return LocalElevatorState(
        e.behaviour,
        e.floor,
        e.direction
    );
}

ElevatorState withRequests(LocalElevatorState e, bool[2][] hallReqs){
    return ElevatorState(
        e.behaviour,
        e.floor,
        e.direction,
        zip(hallReqs, e.cabRequests).map!(a => a[0] ~ a[1]).array.to!(bool[3][]),
    );
}

bool[2][] hallRequests(ElevatorState e){
    return e.requests.to!(bool[][]).map!(a => a[0..2]).array.to!(bool[2][]);
}

