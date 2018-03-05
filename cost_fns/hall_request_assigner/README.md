Hall request assigner
=====================

Made for "on-the-fly" / "dynamic" hall request assignment, ie. where all hall requests are completely re-assigned every time a new request (or other event) arrives.

### JSON format:

Input:
```
{
    "hallRequests" : 
        [[Boolean, Boolean], ...],
    "states" : 
        {
            "id_1" : {
                "behaviour"     : < "idle" | "moving" | "doorOpen" >
                "floor"         : NonNegativeInteger
                "direction"     : < "up" | "down" | "stop" >
                "cabRequests"   : [Boolean, ...]
            },
            "id_2" : {...}
        }
}
```

Output:
```
{
    "id_1" : [[Boolean, Boolean], ...],
    "id_2" : ...
}
```

The pairs of boolean hall requests are ordered `[[up-0, down-0], [up-1, down-1], ...]`, which is the standard in all official driver and example code.


### Example JSON:

Input:
```
{
    "hallRequests" : 
        [[false,false],[true,false],[false,false],[false,true]],
    "states" : {
        "one" : {
            "behaviour":"moving",
            "floor":2,
            "direction":"up",
            "cabRequests":[false,false,true,true]
        },
        "two" : {
            "behaviour":"idle",
            "floor":0,
            "direction":"stop",
            "cabRequests":[false,false,false,false]
        }
    }
}
```

Output:
```
{
    "one" : [[false,false],[false,false],[false,false],[false,true]],
    "two" : [[false,false],[true,false],[false,false],[false,false]]
}
```


Usage
-----

### Downloading:

See [the releases tab](https://github.com/TTK4145/Project-resources/releases/latest) to find executables.

To download the code in order to compile yourself, use `git clone --recursive https://github.com/TTK4145/Project-resources`

#### Building:

Run `build.sh`, or copy its one line of content and run that.

### Command line arguments:

 - `-i` | `--input` : JSON input. 
   - Example: `./hall_request_assigner --input '{"hallRequests":....}'`
 - `--travelDuration` : Travel time between two floors in milliseconds (default 2500)
 - `--doorOpenDuration` : Door open time in milliseconds (default 3000)
 - `--clearRequestType` : When stopping at a floor, clear either `all` requests or only those `inDirn` (default)
 - `--includeCab` : Includes the cab requests in the output. The output becomes a 3xN boolean matrix for each elevator (`[[up-0, down-0, cab-0], [...],...]`). (disabled by default)
 
If JSON input is not passed on the command line, the program will read the first line from stdin instead. JSON output is written to stdout.
