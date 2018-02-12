#pragma once

#include "elevator_io_types.h"

typedef enum {
    EB_Idle,
    EB_DoorOpen,
    EB_Moving
} ElevatorBehaviour;

typedef enum {
    // Assume everyone waiting for the elevator gets on the elevator, even if 
    // they will be traveling in the "wrong" direction for a while
    CV_All,
    
    // Assume that only those that want to travel in the current direction 
    // enter the elevator, and keep waiting outside otherwise
    CV_InDirn,
} ClearRequestVariant;

typedef struct {
    int                     floor;
    Dirn                    dirn;
    int                     requests[N_FLOORS][N_BUTTONS];
    ElevatorBehaviour       behaviour;
    
    struct {
        ClearRequestVariant clearRequestVariant;
        double              doorOpenDuration_s;
    } config;    
} Elevator;


void elevator_print(Elevator es);

Elevator elevator_uninitialized(void);
