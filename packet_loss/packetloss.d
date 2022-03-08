/+
Oversimplified packet loss script.
This program intentionally has significant limitations. Use 'iptables' directly for advanced operations.

Options:
Either long or short options are allowed
    --ports -p  <network ports> (comma-separated)
        The ports to apply packet loss to
    --name  -n  <executablename>        
        Append ports used by any executables matching <executablename> to the ports list
    --rate  --probability  -r   <rate> (floating-point value between 0 and 1, inclusive)
        The packet loss rate. Use 1 for "disconnect".
        Omitting this argument will set the rate to 0.0
    --flush -f
        Remove all packet loss rules
        
Examples:
    packetloss -f
        Removes all packet loss rules, disabling packet loss
        
    packetloss -p 12345,23456,34567 -r 0.25
        Applies 25% packet loss to ports 12345, 23456, and 34567
        
    packetloss -n executablename -r 0.25
        Applies 25% packet loss to all ports used by all programs named "executablename"
        
    packetloss -p 12345 -n executablename -r 0.25
        Also applies 25% packet loss to port 12345

    packetloss -n executablename -f
        Lists ports used by "executablename", but does not apply packet loss
        
+/

import std;

void main(string[] args){

    bool        flush;
    ushort[]    ports;
    string      name;
    double      prob;

    arraySep = ",";
    args.getopt(std.getopt.config.passThrough,
        "f|flush",              &flush,
        "p|port|ports",         &ports,
        "n|name",               &name,
        "r|rate|probability",   &prob,
    );
    
    if(name != string.init){
        auto pids = format!("pidof %s")(name).executeShell.output.split;
        writefln!("Pids matching program name '%s': %-(%s, %)")(name, pids);
        foreach(pid; pids){
            ports ~= format!("lsof -e /run/user/1000/gvfs -aPn -i -p %s -F n")(pid)
                .executeShell
                .output
                .split[1..$]
                .map!(a => a[3..$].to!ushort)
                .array;
        }
        ports = ports.sort.uniq.array;
        writefln!("Found ports: %(%d, %)")(ports);
    }
    
    writeln("Flushing iptables chains...");
    executeShell("iptables -F INPUT");
    
    if(flush){
        goto done;
    }
    
    
    foreach(proto; ["udp", "tcp"]){
        string command = 
            format!("iptables -A INPUT -p %s ")(proto)
            ~ format!("-m multiport --destination-ports %-(%d,%) ")(ports) 
            ~ format!("-m statistic --mode random --probability %f ")(prob) 
            ~ "-j DROP";
                
        writefln!("Performing command:\n  %s")(command);
        
        auto r = command.executeShell;
        if(r.status){
            writefln!("Error:\n%-(  %s\n%)")(r.output.split("\n"));
            goto done;
        }
    }
    
done:
    writefln!("Result of 'iptables -L':\n%-(  %s\n%)")(
        executeShell("iptables -L").output.split("\n")
    );

}