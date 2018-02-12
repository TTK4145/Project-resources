
#include "elevator_io_device.h"

#include <assert.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <netdb.h>
#include <stdio.h>

#include "con_load.h"
#include "driver/channels.h"
#include "driver/io.h"


static int elev_comedi_read_floorSensor(void);
static int elev_comedi_read_requestButton(int floor, Button button);
static int elev_comedi_read_stopButton(void);
static int elev_comedi_read_obstruction(void);

static int elev_simulation_read_floorSensor(void);
static int elev_simulation_read_requestButton(int floor, Button button);
static int elev_simulation_read_stopButton(void);
static int elev_simulation_read_obstruction(void);

static void elev_comedi_write_floorIndicator(int floor);
static void elev_comedi_write_requestButtonLight(int floor, Button button, int value);
static void elev_comedi_write_doorLight(int value);
static void elev_comedi_write_stopButtonLight(int value);
static void elev_comedi_write_motorDirection(Dirn dirn);

static void elev_simulation_write_floorIndicator(int floor);
static void elev_simulation_write_requestButtonLight(int floor, Button button, int value);
static void elev_simulation_write_doorLight(int value);
static void elev_simulation_write_stopButtonLight(int value);
static void elev_simulation_write_motorDirection(Dirn dirn);

typedef enum {
    ET_Comedi,
    ET_Simulation
} ElevatorType;

static ElevatorType et = ET_Simulation;
static int sockfd;

static void __attribute__((constructor)) elev_init(void){
    int resetSimulator = 0;
    con_load("elevator.con",
        con_enum("elevatorType", &et,
            con_match(ET_Simulation)
            con_match(ET_Comedi)
        )
        con_val("resetSimulatorOnRestart", &resetSimulator, "%d")
    )
    
    switch(et) {
    case ET_Comedi:
        ;
        int success = io_init();
        assert(success && "Elevator hardware initialization failed");


        break;

    case ET_Simulation:
        ;
        char ip[16] = {0};
        char port[8] = {0};
        con_load("simulator.con",
            con_val("com_ip",   ip,   "%s")
            con_val("com_port", port, "%s")
        )
    
        sockfd = socket(AF_INET, SOCK_STREAM, 0);
        assert(sockfd != -1 && "Unable to set up socket");

        struct addrinfo hints = {
            .ai_family      = AF_UNSPEC, 
            .ai_socktype    = SOCK_STREAM, 
            .ai_protocol    = IPPROTO_TCP,
        };
        struct addrinfo* res;
        getaddrinfo(ip, port, &hints, &res);

        int fail = connect(sockfd, res->ai_addr, res->ai_addrlen);
        assert(fail == 0 && "Unable to connect to simulator server");

        freeaddrinfo(res);

        if(resetSimulator){
            send(sockfd, (char[4]){0}, 4, 0);
        }   

        break;
    }
    
    ElevOutputDevice eo = elevio_getOutputDevice();
    
    for(int floor = 0; floor < N_FLOORS; floor++) {
        for(Button btn = 0; btn < N_BUTTONS; btn++){
            eo.requestButtonLight(floor, btn, 0);
        }
    }

    eo.stopButtonLight(0);
    eo.doorLight(0);
    eo.floorIndicator(0);
}


ElevInputDevice elevio_getInputDevice(void){
    switch(et) {
    case ET_Comedi:
        return (ElevInputDevice){
            .floorSensor    = &elev_comedi_read_floorSensor,
            .requestButton  = &elev_comedi_read_requestButton,
            .stopButton     = &elev_comedi_read_stopButton,
            .obstruction    = &elev_comedi_read_obstruction
        };
    case ET_Simulation:
        return (ElevInputDevice){
            .floorSensor    = &elev_simulation_read_floorSensor,
            .requestButton  = &elev_simulation_read_requestButton,
            .stopButton     = &elev_simulation_read_stopButton,
            .obstruction    = &elev_simulation_read_obstruction
        };
    default:
        return (ElevInputDevice){0};
    }
}


ElevOutputDevice elevio_getOutputDevice(void){
    switch(et) {
    case ET_Comedi:
        return (ElevOutputDevice){
            .floorIndicator     = &elev_comedi_write_floorIndicator,
            .requestButtonLight = &elev_comedi_write_requestButtonLight,
            .doorLight          = &elev_comedi_write_doorLight,
            .stopButtonLight    = &elev_comedi_write_stopButtonLight,
            .motorDirection     = &elev_comedi_write_motorDirection
        };
    case ET_Simulation:
        return (ElevOutputDevice){
            .floorIndicator     = &elev_simulation_write_floorIndicator,
            .requestButtonLight = &elev_simulation_write_requestButtonLight,
            .doorLight          = &elev_simulation_write_doorLight,
            .stopButtonLight    = &elev_simulation_write_stopButtonLight,
            .motorDirection     = &elev_simulation_write_motorDirection
        };
    default:
        return (ElevOutputDevice){0};
    }
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





static const int floorSensorChannels[N_FLOORS] = {
    SENSOR_FLOOR1,
    SENSOR_FLOOR2,
    SENSOR_FLOOR3,
    SENSOR_FLOOR4,
};


static int elev_comedi_read_floorSensor(void){
    for(int f = 0; f < N_FLOORS; f++){
        if(io_read_bit(floorSensorChannels[f])){
            return f;
        }
    }
    return -1;
}

static int elev_simulation_read_floorSensor(void){
    send(sockfd, (char[4]){7}, 4, 0);
    unsigned char buf[4];
    recv(sockfd, buf, 4, 0);
    return buf[1] ? buf[2] : -1;
}


static const int buttonChannels[N_FLOORS][N_BUTTONS] = {
    {BUTTON_UP1, BUTTON_DOWN1, BUTTON_COMMAND1},
    {BUTTON_UP2, BUTTON_DOWN2, BUTTON_COMMAND2},
    {BUTTON_UP3, BUTTON_DOWN3, BUTTON_COMMAND3},
    {BUTTON_UP4, BUTTON_DOWN4, BUTTON_COMMAND4},
};

static int elev_comedi_read_requestButton(int floor, Button button){
    assert(floor >= 0);
    assert(floor < N_FLOORS);
    assert(button >= 0);
    assert(button < N_BUTTONS);

    return io_read_bit(buttonChannels[floor][button]);
}

static int elev_simulation_read_requestButton(int floor, Button button){
    send(sockfd, (char[4]){6, button, floor}, 4, 0);
    char buf[4];
    recv(sockfd, buf, 4, 0);
    return buf[1];
}


static int elev_comedi_read_stopButton(void){
    return io_read_bit(STOP);
}

static int elev_simulation_read_stopButton(void){
    send(sockfd, (char[4]){8}, 4, 0);
    char buf[4];
    recv(sockfd, buf, 4, 0);
    return buf[1];
}


static int elev_comedi_read_obstruction(void){
    return io_read_bit(OBSTRUCTION);
}

static int elev_simulation_read_obstruction(void){
    send(sockfd, (char[4]){9}, 4, 0);
    char buf[4];
    recv(sockfd, buf, 4, 0);
    return buf[1];
}





static void elev_comedi_write_floorIndicator(int floor){
    assert(floor >= 0);
    assert(floor < N_FLOORS);

    if(floor & 0x02){
        io_set_bit(LIGHT_FLOOR_IND1);
    } else {
        io_clear_bit(LIGHT_FLOOR_IND1);
    }

    if(floor & 0x01){
        io_set_bit(LIGHT_FLOOR_IND2);
    } else {
        io_clear_bit(LIGHT_FLOOR_IND2);
    }
}

static void elev_simulation_write_floorIndicator(int floor){
    send(sockfd, (char[4]){3, floor}, 4, 0);
}


static const int buttonLightChannels[N_FLOORS][N_BUTTONS] = {
    {LIGHT_UP1, LIGHT_DOWN1, LIGHT_COMMAND1},
    {LIGHT_UP2, LIGHT_DOWN2, LIGHT_COMMAND2},
    {LIGHT_UP3, LIGHT_DOWN3, LIGHT_COMMAND3},
    {LIGHT_UP4, LIGHT_DOWN4, LIGHT_COMMAND4},
};

static void elev_comedi_write_requestButtonLight(int floor, Button button, int value){
    assert(floor >= 0);
    assert(floor < N_FLOORS);
    assert(button >= 0);
    assert(button < N_BUTTONS);

    if(value){
        io_set_bit(buttonLightChannels[floor][button]);
    } else {
        io_clear_bit(buttonLightChannels[floor][button]);
    }
}

static void elev_simulation_write_requestButtonLight(int floor, Button button, int value){
    send(sockfd, (char[4]){2, button, floor, value}, 4, 0);
}


static void elev_comedi_write_doorLight(int value){
    if(value){
        io_set_bit(LIGHT_DOOR_OPEN);
    } else {
        io_clear_bit(LIGHT_DOOR_OPEN);
    }
}

static void elev_simulation_write_doorLight(int value){
    send(sockfd, (char[4]){4, value}, 4, 0);
}


static void elev_comedi_write_stopButtonLight(int value){
    if(value){
        io_set_bit(LIGHT_STOP);
    } else {
        io_clear_bit(LIGHT_STOP);
    }
}

static void elev_simulation_write_stopButtonLight(int value){
    send(sockfd, (char[4]){5, value}, 4, 0);
}


static void elev_comedi_write_motorDirection(Dirn dirn){
    switch(dirn){
    case D_Up:
        io_clear_bit(MOTORDIR);
        io_write_analog(MOTOR, 2800);
        break;
    case D_Down:
        io_set_bit(MOTORDIR);
        io_write_analog(MOTOR, 2800);
        break;
    case D_Stop:
    default:
        io_write_analog(MOTOR, 0);
        break;
    }
}

static void elev_simulation_write_motorDirection(Dirn dirn){
    send(sockfd, (char[4]){1, dirn}, 4, 0);
}





