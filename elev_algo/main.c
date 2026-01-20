
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "con_load.h"
#include "fsm.h"
#include "timer.h"

int main(void){
    printf("Started!\n");
    

    Elevator elevator = elevator_uninitialized();
    int inputPollRate_ms = 25;
    
    con_load("elevator.con",
        con_val("doorOpenDuration_s", &elevator.config.doorOpenDuration_s, "%lf")
        con_val("inputPollRate_ms", &inputPollRate_ms, "%d")
    )
    
    if(elevator_floorSensor() == -1){
        fsm_onInitBetweenFloors(&elevator);
    }
        
    while(1){
        { // Request button
            static int prev[N_FLOORS][N_BUTTONS];
            for(int f = 0; f < N_FLOORS; f++){
                for(int b = 0; b < N_BUTTONS; b++){
                    int v = elevator_requestButton(f, b);
                    if(v  &&  v != prev[f][b]){
                        fsm_onRequestButtonPress(&elevator, f, b);
                    }
                    prev[f][b] = v;
                }
            }
        }
        
        { // Floor sensor
            static int prev = -1;
            int f = elevator_floorSensor();
            if(f != -1  &&  f != prev){
                fsm_onFloorArrival(&elevator, f);
            }
            prev = f;
        }
        
        
        { // Timer
            if(timer_timedOut()){
                timer_stop();
                fsm_onDoorTimeout(&elevator);
            }
        }
        
        usleep(inputPollRate_ms*1000);
    }
}









