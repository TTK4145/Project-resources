import std.algorithm;
import std.range;
import std.stdio;

import elevator_state;
import config;



private bool requestsAbove(ElevatorState e){
    return e.requests[e.floor+1..$].map!(a => a.array.any).any;
}

private bool requestsBelow(ElevatorState e){
    return e.requests[0..e.floor].map!(a => a.array.any).any;
}

bool anyRequests(ElevatorState e){
    return e.requests.map!(a => a.array.any).any;
}

bool anyRequestsAtFloor(ElevatorState e){
    return e.requests[e.floor].array.any;
}


bool shouldStop(ElevatorState e){
    final switch(e.direction) with(Dirn){
    case up:
        return
            e.requests[e.floor][CallType.hallUp]    ||
            e.requests[e.floor][CallType.cab]       ||
            !e.requestsAbove                        ||
            e.floor == 0                            || 
            e.floor == e.requests.length-1;
    case down:
        return
            e.requests[e.floor][CallType.hallDown]  ||
            e.requests[e.floor][CallType.cab]       ||
            !e.requestsBelow                        ||
            e.floor == 0                            || 
            e.floor == e.requests.length-1;
    case stop:
        return true;
    }
}

Dirn chooseDirection(ElevatorState e){
    final switch(e.direction) with(Dirn){
    case up:
        return
            e.requestsAbove         ?   up      :
            e.anyRequestsAtFloor    ?   stop    :
            e.requestsBelow         ?   down    :
                                        stop;
    case down, stop:
        return
            e.requestsBelow         ?   down    :
            e.anyRequestsAtFloor    ?   stop    :
            e.requestsAbove         ?   up      :
                                        stop;
    }
}

ElevatorState clearReqsAtFloor(ElevatorState e, void delegate(CallType c) onClearedRequest = null){

    auto e2 = e;
    
    
    void clear(CallType c){
        if(e2.requests[e2.floor][c]){
            if(&onClearedRequest){
                onClearedRequest(c);
            }
            e2.requests[e2.floor][c] = false;
        }
    }

    
    final switch(clearRequestType) with(ClearRequestType){
    case all:    
        for(auto c = CallType.min; c < e2.requests[0].length; c++){
            clear(c);
        }
        break;

    case inDirn:
        clear(CallType.cab);
        
        final switch(e.direction) with(Dirn){
        case up:
            if(e2.requests[e2.floor][CallType.hallUp]){
                clear(CallType.hallUp);
            } else if(!e2.requestsAbove){
                clear(CallType.hallDown);
            }
            break;
        case down:
            if(e2.requests[e2.floor][CallType.hallDown]){
                clear(CallType.hallDown);
            } else if(!e2.requestsBelow){
                clear(CallType.hallUp);
            }
            break;
        case stop:
            clear(CallType.hallUp);
            clear(CallType.hallDown);
            break;
        }
        break;
    }    
    
    return e2;
}