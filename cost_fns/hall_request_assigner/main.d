
import std.conv;
import std.getopt;
import std.stdio;

import optimal_hall_requests;
import elevator_state;
import config;
import jsonx;

struct Input {
    bool[][] hallRequests;
    LocalElevatorState[string] states;
}

void main(string[] args){

    string input_str;

    args.getopt(
        std.getopt.config.passThrough,
        "doorOpenDuration", &doorOpenDuration,
        "travelDuration",   &travelDuration,
        "clearRequestType", &clearRequestType,
        "includeCab",       &includeCab,
        "i|input",          &input_str,
    );

    if(input_str == string.init){
        input_str = readln;
        input_str = input_str[0..$-1];  // remove trailing newline
    }
    
    Input i = input_str.jsonDecode!Input;
    
    optimalHallRequests(i.hallRequests.to!(bool[2][]), i.states)
        .jsonEncode
        .writeln;
}



unittest {
    import std.regex;

    Input i = jsonDecode!Input(q{
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
    }.replaceAll(regex(r"\s"), ""));
    
    string correctOutput = q{
        {
            "one" : [[false,false],[false,false],[false,false],[false,true]],
            "two" : [[false,false],[true,false],[false,false],[false,false]]
        }
    }.replaceAll(regex(r"\s"), "");
    
    
    string output = optimalHallRequests(i.hallRequests.to!(bool[2][]), i.states).jsonEncode;
    assert(output == correctOutput);
    
}

unittest {
    import std.regex;
    
    auto prev = includeCab;
    includeCab = true;
    scope(exit) includeCab = prev;
    
    Input i = jsonDecode!Input(q{
        {
            "hallRequests":
                [[true,false],[false,false],[true,true],[false,false]],
            "states" : {
                "a" : {
                    "behaviour":"doorOpen",
                    "floor":1,
                    "direction":"down",
                    "cabRequests":[false,false,false,false]
                },
                "b" : {
                    "behaviour":"moving",
                    "floor":0,
                    "direction":"up",
                    "cabRequests":[true,true,true,true]
                },
                "c" : {
                    "behaviour":"moving",
                    "floor":3,
                    "direction":"down",
                    "cabRequests":[false,false,false,false]
                }
            }
        }
    }.replaceAll(regex(r"\s"), ""));
    
    string correctOutput = q{
        {
            "a" : [[true,false,false],[false,false,false],[false,false,false],[false,false,false]],
            "b" : [[false,false,true],[false,false,true],[false,false,true],[false,false,true]],
            "c" : [[false,false,false],[false,false,false],[true,true,false],[false,false,false]]
        }
    }.replaceAll(regex(r"\s"), "");
    
    string output = optimalHallRequests(i.hallRequests.to!(bool[2][]), i.states).jsonEncode;
    assert(output == correctOutput);
    
}

