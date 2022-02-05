#pragma once

#include "elevator.h"
#include "elevator_io_types.h"


typedef struct {
    Dirn                dirn;
    ElevatorBehaviour   behaviour;
} Action;



Action requests_nextAction(Elevator e) __attribute__((pure));

int requests_shouldStop(Elevator e) __attribute__((pure));

int requests_shouldClearImmediately(Elevator e, int btn_floor, Button btn_type) __attribute__((pure));

Elevator requests_clearAtCurrentFloor(Elevator e) __attribute__((pure));



