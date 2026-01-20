#pragma once

#include "elevator.h"

void fsm_onInitBetweenFloors(Elevator* e);
void fsm_onRequestButtonPress(Elevator* e, int btn_floor, Button btn_type);
void fsm_onFloorArrival(Elevator* e, int newFloor);
void fsm_onDoorTimeout(Elevator* e);
