#include <stdio.h>
#include <sys/time.h>

static double get_wall_time(void){
    struct timeval time;
    gettimeofday(&time, NULL);
    return (double)time.tv_sec + (double)time.tv_usec * .000001;
}


static  double          timerEndTime;
static  int             timerActive;

void timer_start(double duration){
    timerEndTime    = get_wall_time() + duration;
    timerActive     = 1;
}

void timer_stop(void){
    timerActive = 0;
}

int timer_timedOut(void){
    return (timerActive  &&  get_wall_time() > timerEndTime);
}



