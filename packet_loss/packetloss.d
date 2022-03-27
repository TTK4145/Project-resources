

import std;


auto helpstr = `
Oversimplified packet loss script.
This program intentionally has significant limitations. Use 'iptables' directly for advanced operations.

Remember to run this program with 'sudo'

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
    sudo packetloss -f
        Removes all packet loss rules, disabling packet loss
        
    sudo packetloss -p 12345,23456,34567 -r 0.25
        Applies 25% packet loss to ports 12345, 23456, and 34567
        
    sudo packetloss -n executablename -r 0.25
        Applies 25% packet loss to all ports used by all programs named "executablename"
        
    sudo packetloss -p 12345 -n executablename -r 0.25
        Also applies 25% packet loss to port 12345

    sudo packetloss -n executablename -f
        Lists ports used by "executablename", but does not apply packet loss
        
`;

void main(string[] args){

    bool        help;
    bool        flush;
    ushort[]    ports;
    string      name;
    double      prob;
    
    string[]    chains = ["INPUT", "OUTPUT"];
    string[]    protocols = ["udp", "tcp"];

    arraySep = ",";
    string[] argsCpy = args;
    argsCpy.getopt(std.getopt.config.passThrough,
        "h|help",               &help,
        "f|flush",              &flush,
        "p|port|ports",         &ports,
        "n|name",               &name,
        "r|rate|probability",   &prob,
    );
    
    if(help || args.length == 1){
        helpstr.writeln;
        return;
    }
    
    if(name != string.init){
        auto pids = format!("pidof %s")(name).executeShell.output.split;
        writefln!("%d pids matching program name '%s': %-(%s, %)")(pids.length, name, pids);
        foreach(pid; pids){
            auto cmd = format!(
                `sudo netstat -aputn`~
                `| grep "0.0.0.0"`~
                `| grep "%s"`~
                `| awk '{print $4}'`~
                `| awk -F ':' '{print $2}'`
            )(pid).executeShell;
            ports ~= 
                cmd.output
                .split
                .map!(a => a.strip('\0').to!ushort)
                .array;
        }
        ports = ports.sort.uniq.array;
        writefln!("Found ports: %(%d, %)")(ports);
    }
    
    writeln("Flushing iptables chains...");
    foreach(chain; chains){
        format!("iptables -F %s")(chain).executeShell;
    }
    
    if(flush){
        goto done;
    }
    
    foreach(chainProtoPair; cartesianProduct(chains, protocols)){
        string command = 
            format!("iptables -A %s -p %s ")(chainProtoPair[0], chainProtoPair[1])
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
    writefln!("\n\nResult of 'iptables -L':\n\n%-(  %s\n%)")(
        executeShell("iptables -L").output.split("\n")
    );

}
