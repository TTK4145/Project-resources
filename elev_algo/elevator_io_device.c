
#include "elevator_io_device.h"

#include <assert.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <netdb.h>
#include <stdio.h>

#include "con_load.h"
#include "driver/elevator_hardware.h"



static void __attribute__((constructor)) elev_init(void){
    elevator_hardware_init();
}

static int _wrap_requestButton(int f, Button b){
    return elevator_hardware_get_button_signal(b, f);
}
static void _wrap_requestButtonLight(int f, Button b, int v){
    elevator_hardware_set_button_lamp(b, f, v);
}
static void _wrap_motorDirection(Dirn d){
    elevator_hardware_set_motor_direction(d);
}


ElevInputDevice elevio_getInputDevice(void){
    return (ElevInputDevice){
        .floorSensor    = &elevator_hardware_get_floor_sensor_signal,
        .requestButton  = &_wrap_requestButton,
        .stopButton     = &elevator_hardware_get_stop_signal,
        .obstruction    = &elevator_hardware_get_obstruction_signal
    };
}


ElevOutputDevice elevio_getOutputDevice(void){
    return (ElevOutputDevice){
        .floorIndicator     = &elevator_hardware_set_floor_indicator,
        .requestButtonLight = &_wrap_requestButtonLight,
        .doorLight          = &elevator_hardware_set_door_open_lamp,
        .stopButtonLight    = &elevator_hardware_set_stop_lamp,
        .motorDirection     = &_wrap_motorDirection
    };
}


char* elevio_dirn_toString(Dirn d){
    return
        d == D_Up    ? "D_Up"         :
        d == D_Down  ? "D_Down"       :
        d == D_Stop  ? "D_Stop"       :
                       "D_UNDEFINED"  ;
}


char* elevio_button_toString(Button b){
    return
        b == B_HallUp       ? "B_HallUp"        :
        b == B_HallDown     ? "B_HallDown"      :
        b == B_Cab          ? "B_Cab"           :
                              "B_UNDEFINED"     ;
}






