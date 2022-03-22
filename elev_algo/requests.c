#include "requests.h"

static int requests_above(Elevator e){
    for(int f = e.floor+1; f < N_FLOORS; f++){
        for(int btn = 0; btn < N_BUTTONS; btn++){
            if(e.requests[f][btn]){
                return 1;
            }
        }
    }
    return 0;
}

static int requests_below(Elevator e){
    for(int f = 0; f < e.floor; f++){
        for(int btn = 0; btn < N_BUTTONS; btn++){
            if(e.requests[f][btn]){
                return 1;
            }
        }
    }
    return 0;
}

static int requests_here(Elevator e){
    for(int btn = 0; btn < N_BUTTONS; btn++){
        if(e.requests[e.floor][btn]){
            return 1;
        }
    }
    return 0;
}


DirnBehaviourPair requests_chooseDirection(Elevator e){
    switch(e.dirn){
    case D_Up:
        return  requests_above(e) ? (DirnBehaviourPair){D_Up,   EB_Moving}   :
                requests_here(e)  ? (DirnBehaviourPair){D_Down, EB_DoorOpen} :
                requests_below(e) ? (DirnBehaviourPair){D_Down, EB_Moving}   :
                                    (DirnBehaviourPair){D_Stop, EB_Idle}     ;
    case D_Down:
        return  requests_below(e) ? (DirnBehaviourPair){D_Down, EB_Moving}   :
                requests_here(e)  ? (DirnBehaviourPair){D_Up,   EB_DoorOpen} :
                requests_above(e) ? (DirnBehaviourPair){D_Up,   EB_Moving}   :
                                    (DirnBehaviourPair){D_Stop, EB_Idle}     ;
    case D_Stop: // there should only be one request in the Stop case. Checking up or down first is arbitrary.
        return  requests_here(e)  ? (DirnBehaviourPair){D_Stop, EB_DoorOpen} :
                requests_above(e) ? (DirnBehaviourPair){D_Up,   EB_Moving}   :
                requests_below(e) ? (DirnBehaviourPair){D_Down, EB_Moving}   :
                                    (DirnBehaviourPair){D_Stop, EB_Idle}     ;
    default:
        return (DirnBehaviourPair){D_Stop, EB_Idle};
    }
}



int requests_shouldStop(Elevator e){
    switch(e.dirn){
    case D_Down:
        return
            e.requests[e.floor][B_HallDown] ||
            e.requests[e.floor][B_Cab]      ||
            !requests_below(e);
    case D_Up:
        return
            e.requests[e.floor][B_HallUp]   ||
            e.requests[e.floor][B_Cab]      ||
            !requests_above(e);
    case D_Stop:
    default:
        return 1;
    }
}

int requests_shouldClearImmediately(Elevator e, int btn_floor, Button btn_type){
    switch(e.config.clearRequestVariant){
    case CV_All:
        return e.floor == btn_floor;
    case CV_InDirn:
        return 
            e.floor == btn_floor && 
            (
                (e.dirn == D_Up   && btn_type == B_HallUp)    ||
                (e.dirn == D_Down && btn_type == B_HallDown)  ||
                e.dirn == D_Stop ||
                btn_type == B_Cab
            );  
    default:
        return 0;
    }
}

Elevator requests_clearAtCurrentFloor(Elevator e){
        
    switch(e.config.clearRequestVariant){
    case CV_All:
        for(Button btn = 0; btn < N_BUTTONS; btn++){
            e.requests[e.floor][btn] = 0;
        }
        break;
        
    case CV_InDirn:
        e.requests[e.floor][B_Cab] = 0;
        switch(e.dirn){
        case D_Up:
            if(!requests_above(e) && !e.requests[e.floor][B_HallUp]){
                e.requests[e.floor][B_HallDown] = 0;
            }
            e.requests[e.floor][B_HallUp] = 0;
            break;
            
        case D_Down:
            if(!requests_below(e) && !e.requests[e.floor][B_HallDown]){
                e.requests[e.floor][B_HallUp] = 0;
            }
            e.requests[e.floor][B_HallDown] = 0;
            break;
            
        case D_Stop:
        default:
            e.requests[e.floor][B_HallUp] = 0;
            e.requests[e.floor][B_HallDown] = 0;
            break;
        }
        break;
        
    default:
        break;
    }
    
    return e;
}











