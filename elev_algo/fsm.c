
#include "fsm.h"

#include <stdio.h>

#include "con_load.h"
#include "elevator.h"
#include "requests.h"
#include "timer.h"



static void setAllLights(Elevator es){
    for(int floor = 0; floor < N_FLOORS; floor++){
        for(int btn = 0; btn < N_BUTTONS; btn++){
            elevator_requestButtonLight(floor, btn, es.requests[floor][btn]);
        }
    }
}

void fsm_onInitBetweenFloors(Elevator* e){
    elevator_motorDirection(D_Down);
    e->dirn = D_Down;
    e->behaviour = EB_Moving;
}


void fsm_onRequestButtonPress(Elevator* e, int btn_floor, Button btn_type){
    printf("\n\n%s(%d, %s)\n", __FUNCTION__, btn_floor, elevator_buttonToString(btn_type));
    elevator_print(*e);
    
    switch(e->behaviour){
    case EB_DoorOpen:
        if(requests_shouldClearImmediately(*e, btn_floor, btn_type)){
            timer_start(e->config.doorOpenDuration_s);
        } else {
            e->requests[btn_floor][btn_type] = 1;
        }
        break;

    case EB_Moving:
        e->requests[btn_floor][btn_type] = 1;
        break;
        
    case EB_Idle:    
        e->requests[btn_floor][btn_type] = 1;
        DirnBehaviourPair pair = requests_chooseDirection(*e);
        e->dirn = pair.dirn;
        e->behaviour = pair.behaviour;
        switch(pair.behaviour){
        case EB_DoorOpen:
            elevator_doorLight(1);
            timer_start(e->config.doorOpenDuration_s);
            *e = requests_clearAtCurrentFloor(*e);
            break;

        case EB_Moving:
            elevator_motorDirection(e->dirn);
            break;
            
        case EB_Idle:
            break;
        }
        break;
    }
    
    setAllLights(*e);
    
    printf("\nNew state:\n");
    elevator_print(*e);
}




void fsm_onFloorArrival(Elevator* e, int newFloor){
    printf("\n\n%s(%d)\n", __FUNCTION__, newFloor);
    elevator_print(*e);
    
    e->floor = newFloor;
    
    elevator_floorIndicator(e->floor);
    
    switch(e->behaviour){
    case EB_Moving:
        if(requests_shouldStop(*e)){
            elevator_motorDirection(D_Stop);
            elevator_doorLight(1);
            *e = requests_clearAtCurrentFloor(*e);
            timer_start(e->config.doorOpenDuration_s);
            setAllLights(*e);
            e->behaviour = EB_DoorOpen;
        }
        break;
    default:
        break;
    }
    
    printf("\nNew state:\n");
    elevator_print(*e); 
}




void fsm_onDoorTimeout(Elevator* e){
    printf("\n\n%s()\n", __FUNCTION__);
    elevator_print(*e);
    
    switch(e->behaviour){
    case EB_DoorOpen:;
        DirnBehaviourPair pair = requests_chooseDirection(*e);
        e->dirn = pair.dirn;
        e->behaviour = pair.behaviour;
        
        switch(e->behaviour){
        case EB_DoorOpen:
            timer_start(e->config.doorOpenDuration_s);
            *e = requests_clearAtCurrentFloor(*e);
            setAllLights(*e);
            break;
        case EB_Moving:
        case EB_Idle:
            elevator_doorLight(0);
            elevator_motorDirection(e->dirn);
            break;
        }
        
        break;
    default:
        break;
    }
    
    printf("\nNew state:\n");
    elevator_print(*e);
}













