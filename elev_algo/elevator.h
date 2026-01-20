#pragma once

#define N_FLOORS 4
#define N_BUTTONS 3

typedef enum { 
    D_Down  = -1,
    D_Stop  = 0,
    D_Up    = 1
} Dirn;

typedef enum { 
    B_HallUp,
    B_HallDown,
    B_Cab
} Button;

typedef enum {
    EB_Idle,
    EB_DoorOpen,
    EB_Moving
} ElevatorBehaviour;

typedef struct {
    int                     floor;
    Dirn                    dirn;
    int                     requests[N_FLOORS][N_BUTTONS];
    ElevatorBehaviour       behaviour;
    
    struct {
        double              doorOpenDuration_s;
    } config;    
} Elevator;


char* elevator_behaviorToString(ElevatorBehaviour eb);
char* elevator_dirnToString(Dirn d);
char* elevator_buttonToString(Button b);

void elevator_print(Elevator es);

Elevator elevator_uninitialized(void);

int elevator_floorSensor(void);
int elevator_requestButton(int f, Button b);
int elevator_stopButton(void);
int elevator_obstruction(void);

void elevator_floorIndicator(int f);
void elevator_requestButtonLight(int f, Button b, int v);
void elevator_doorLight(int v);
void elevator_stopButtonLight(int v);
void elevator_motorDirection(Dirn d);