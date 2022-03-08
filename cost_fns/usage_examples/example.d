// rdmd -I'..\hall_request_assigner\d-json' example.d

import std;
import jsonx;

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


struct ElevatorState {
    ElevatorBehaviour   behaviour;
    int                 floor;
    Dirn                direction;
    bool[]              cabRequests;
}

struct HRAInput {
    bool[][]                hallRequests;
    ElevatorState[string]   states;
}

void main(){
    auto input = HRAInput(
        [[false,false],[true,false],[false,false],[false,true]],
        [
            "one" : ElevatorState(ElevatorBehaviour.moving, 2, Dirn.up,   [false,false,true,true]),
            "two" : ElevatorState(ElevatorBehaviour.idle,   0, Dirn.stop, [false,false,false,false]),
        ]
    );
    writefln!("Input: %s")(input.jsonEncode);
    
    auto output = execute(["../hall_request_assigner/hall_Request_assigner.exe", "-i", input.jsonEncode])
        .output
        .strip
        .jsonDecode!(bool[][][string]);
    writefln!("Orders:\n%(  %s : %s\n%)")(output);
}