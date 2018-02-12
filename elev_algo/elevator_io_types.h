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


typedef struct {
    int (*floorSensor)(void);
    int (*requestButton)(int, Button);
    int (*stopButton)(void);
    int (*obstruction)(void);
    
} ElevInputDevice;

typedef struct {
    void (*floorIndicator)(int);
    void (*requestButtonLight)(int, Button, int);
    void (*doorLight)(int);
    void (*stopButtonLight)(int);
    void (*motorDirection)(Dirn);
} ElevOutputDevice;


char* elevio_dirn_toString(Dirn d);
char* elevio_button_toString(Button b);