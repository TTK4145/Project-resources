
#include "elevator.h"

#include <stdio.h>

#include "timer.h"
#include "driver/elevator_hardware.h"

char* elevator_behaviorToString(ElevatorBehaviour eb){
    return
        eb == EB_Idle       ? "EB_Idle"         :
        eb == EB_DoorOpen   ? "EB_DoorOpen"     :
        eb == EB_Moving     ? "EB_Moving"       :
                              "EB_UNDEFINED"    ;
}


char* elevator_dirnToString(Dirn d){
    return
        d == D_Up    ? "D_Up"         :
        d == D_Down  ? "D_Down"       :
        d == D_Stop  ? "D_Stop"       :
                       "D_UNDEFINED"  ;
}


char* elevator_buttonToString(Button b){
    return
        b == B_HallUp       ? "B_HallUp"        :
        b == B_HallDown     ? "B_HallDown"      :
        b == B_Cab          ? "B_Cab"           :
                              "B_UNDEFINED"     ;
}

void elevator_print(Elevator es){
    printf("  +--------------------+\n");
    printf(
        "  |floor = %-2d          |\n"
        "  |dirn  = %-12.12s|\n"
        "  |behav = %-12.12s|\n",
        es.floor,
        elevator_dirnToString(es.dirn),
        elevator_behaviorToString(es.behaviour)
    );
    printf("  +--------------------+\n");
    printf("  |  | up  | dn  | cab |\n");
    for(int f = N_FLOORS-1; f >= 0; f--){
        printf("  | %d", f);
        for(int btn = 0; btn < N_BUTTONS; btn++){
            if((f == N_FLOORS-1 && btn == B_HallUp)  || 
               (f == 0 && btn == B_HallDown) 
            ){
                printf("|     ");
            } else {
                printf(es.requests[f][btn] ? "|  #  " : "|  -  ");
            }
        }
        printf("|\n");
    }
    printf("  +--------------------+\n");
}

Elevator elevator_uninitialized(void){
    elevator_hardware_init();
    return (Elevator){
        .floor = -1,
        .dirn = D_Stop,
        .behaviour = EB_Idle,
        .config = {
            .doorOpenDuration_s = 3.0,
        },
    };
}


int elevator_floorSensor(void){
    return elevator_hardware_get_floor_sensor_signal();
}
int elevator_requestButton(int f, Button b){
    return elevator_hardware_get_button_signal((elevator_hardware_button_type_t)(b), f);
}
int elevator_stopButton(void){
    return elevator_hardware_get_stop_signal();
}
int elevator_obstruction(void){
    return elevator_hardware_get_obstruction_signal();
}

void elevator_floorIndicator(int f){
    elevator_hardware_set_floor_indicator(f);
}
void elevator_requestButtonLight(int f, Button b, int v){
    elevator_hardware_set_button_lamp((elevator_hardware_button_type_t)(b), f, v);
}
void elevator_doorLight(int v){
    elevator_hardware_set_door_open_lamp(v);
}
void elevator_stopButtonLight(int v){
    elevator_hardware_set_stop_lamp(v);
}
void elevator_motorDirection(Dirn d){
    elevator_hardware_set_motor_direction((elevator_hardware_motor_direction_t)(d));
}








