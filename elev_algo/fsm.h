#pragma once

#include "elevator_io_types.h"

void fsm_onInitBetweenFloors(void);
void fsm_onRequestButtonPress(int btn_floor, Button btn_type);
void fsm_onFloorArrival(int newFloor);
void fsm_onDoorTimeout(void);
