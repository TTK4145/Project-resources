
import std;
import core.thread;
import core.sys.posix.signal;
import core.sys.posix.unistd;

auto helpstr = format!(`
Network impairment script.
Impairments are only applied to inbound traffic.

Remember to run this program with 'sudo'.

Settings are in two groups: What ports are impaired, and what the impairments are.

Options:
  Port selection:
    (Ports 22 (SSH), 80 (HTTP), 443 (HTTPS) are always excluded)
    --ports -p  <network ports> (comma-separated)
        Specify a list of ports manually
    --name  -n  <executablename>        
        Continuously discover ports used by processes matching <executablename>
    --all -a
        Apply to all ports
        
  Impairment selection:
    Preset:
      --preset -r [off, light, medium, heavy, absurd]
        Apply a preset selection of impairments%(
          %-7s : %s%)

    Manual:
      --loss        <percentage (0-100)>
      --lossCorr    <percentage (0-100)>
      --duplicate   <percentage (0-100)>
      --delay       <milliseconds>
      --jitter      <milliseconds>
      --delayCorr   <percentage (0-100)>
      --reorder     <percentage (0-100)>
      --reorderCorr <percentage (0-100)>
      
  Disable:
    --flush -f --off
    --preset off
        Remove all packet loss rules
  
  List:
    --list -l
        List all traffic control rules
        
Examples:
    sudo netimpair -f
    sudo netimpair --off
    sudo netimpair --preset off
        Disables all network impairments
        
    sudo netimpair -p 12345,23456,34567 --loss 25
        Applies 25%% packet loss to ports 12345, 23456, and 34567
        
    sudo netimpair -n executablename --preset medium
        Applies the 'medium' impairment preset to all ports used by all programs named 'executablename'
        The program will keep running in order to continuously monitor what ports 'executablename' uses
        (for elixir programs, executable name would typically be 'beam.smp')
        
    sudo netimpair -n executablename -f
        Continuously monitors ports used by 'executablename', but does not apply any impariments
        
        
Notes:
    This script does not affect connections made to either 'localhost' or connections explicitly to
    self's IP, but does affect UDP broadcast messages received by self.
    
    The program will display all console commands related to network traffic control, and their responses. 
    Any errors can almost always be ignored.
    
    TCP will usually experience catastrophic backoff under the 'extreme' preset.
        
`)(presets);

enum Impairment[Preset] presets = [
    Preset.light:   Impairment(loss:5,  lossCorr:20, delay:10),
    Preset.medium:  Impairment(loss:10, lossCorr:30, delay:20, jitter:5,  reorder:1),
    Preset.heavy:   Impairment(loss:25, lossCorr:50, delay:30, jitter:10, reorder:2,  duplicate:1),
    Preset.extreme: Impairment(loss:35, lossCorr:50, delay:40, jitter:15, reorder:4,  duplicate:2),
    Preset.absurd:  Impairment(loss:50, lossCorr:60, delay:80, jitter:40, reorder:10, duplicate:10),
];

enum ushort[] excludeList = [22, 80, 443];

void main(string[] args){
    
    
    bool        help;
    bool        list;
    ushort[]    ports;
    string      name;
    bool        all;
    bool        flush;
    Preset      preset;
    
    try {
        auto argsCpy = args.dup;
        arraySep = ",";
        argsCpy.getopt(std.getopt.config.passThrough,
            "h|help",               &help,
            "l|list",               &list,
            "p|port|ports",         &ports,
            "n|name",               &name,
            "a|all",                &all,
            "f|flush|off",          &flush,
            "r|preset",             &preset,
        );
    } catch(Throwable t){
        t.msg.writeln;
        return;
    }
    
    if(help || args.length == 1){
        helpstr.writeln;
        return;
    }
    
    if(geteuid() != 0){
        writeln("Program must be run with 'sudo'!");
        return;
    }
    
    
    string iface = defaultNetIface();
    
    void reapply(ushort[] ports, Impairment i){
        auto prio = 0;
        exclude(excludeList, prio);
        include(ports, prio);
        impair(i);
    }
    
    Impairment i;
    switch(preset) with(Preset){
        case custom:
            structGetopt(i, args);
            break;
        case off:
            writeln("Teardown, removing all impairments");
            teardown(iface);
            return;
        default:
            i = presets[preset];
            break;
    }
    
    
    if(name != string.init){
        writeln("MODE: Port discovery from process name");
        auto portDiscoveryThread = spawn(&portDiscoveryTask);
        portDiscoveryThread.send(name);
        
        if(!flush){ setup(iface); }
        scope(exit){ if(!flush){ teardown(iface); } }
        
        signal(SIGINT, &ctrlCCallback);
        
        while(!ctrlC){
            receiveTimeout(100.msecs,
                (immutable(ushort)[] ports){
                    writefln!("Discovered ports: [%(%s, %)]")(ports);
                    if(!flush && ports.length){
                        reapply(ports.dup, i);
                    }
                },
            );
        }
        return;
    }
    
    if(ports.length){
        writefln!("MODE: Ports from supplied list:\n  %(%s, %)")(ports);
        setup(iface);
        reapply(ports, i);
        return;
    }
    
    if(all){
        writeln("MODE: All ports");
        setup(iface);
        auto prio = 0;
        exclude(excludeList, prio);
        includeAll(prio);
        impair(i);
        return;
    }
    
    if(flush){
        writeln("Teardown, removing all impairments");
        teardown(iface);
        return;
    }
    
    if(list){
        listRules();
        return;
    }
    
    
    helpstr.writeln;
}

struct Quit {}
__gshared bool ctrlC = false;
extern(C) void ctrlCCallback(int num) nothrow @nogc @system {
    printf("ctrlc presed");
    ctrlC = true;
}
void portDiscoveryTask(){
    ushort[] ports;
    string name;
    try {
        while(true){
            receiveTimeout(1.seconds,
                (string n){
                    name = n;
                },
            );
            auto newPorts = portsForProgramName(name);
            if(newPorts != ports){
                ports = newPorts;
                ownerTid.send(ports.idup);
            }
        }
    } catch(Throwable t){}
}


enum Preset : string {
    custom  = "custom",
    off     = "off",
    light   = "light",
    medium  = "medium",
    heavy   = "heavy",
    extreme = "extreme",
    absurd  = "absurd",
}
struct Impairment {
    int loss;
    int lossCorr;
    
    int duplicate;
    
    int delay;
    int jitter;
    int delayCorr;
    
    int reorder;
    int reorderCorr;
    
    string toString(){
        string[] s;
        static foreach(m; FieldNameTuple!(typeof(this))){
            s ~= format!("%s %2d")(m, __traits(getMember, this, m));
        }
        return s.join(", ");
    }
    string rule(){
        return i"loss $(loss)% $(lossCorr)% duplicate $(duplicate)% delay $(delay)ms $(jitter)ms $(delayCorr)% reorder $(reorder)% $(reorderCorr)%".text;
    }
}


void setup(string iface){
    execEcho([
        "sudo modprobe ifb",
        //"sudo ip link add name ifb0 type ifb",
        //"sudo ip link set dev ifb0 up",
        "sudo ip link add name ifb1 type ifb",
        "sudo ip link set dev ifb1 up",
       i"tc qdisc del       dev $(iface) ingress".text,
       i"tc qdisc replace   dev $(iface) ingress".text,
       i"tc filter replace dev $(iface) parent ffff: protocol ip prio 1 u32 match u32 0 0 flowid 1:1 action mirred egress redirect dev ifb1".text,
        "tc filter replace dev lo parent ffff: protocol ip prio 1 u32 match u32 0 0 flowid 1:1 action mirred egress redirect dev ifb1",
        "tc qdisc del dev ifb1 root",
        "tc qdisc add dev ifb1 root handle 1: prio",
    ]);
}
void exclude(ushort[] ports, ref int prio){
    foreach(port; ports){
        execEcho([
            i"tc filter add dev ifb1 protocol ip parent 1:0 prio $(++prio) u32 match ip dport $(port) 0xffff flowid 1:2".text,
            i"tc filter add dev ifb1 protocol ip parent 1:0 prio $(++prio) u32 match ip sport $(port) 0xffff flowid 1:2".text,
            //i"tc filter add dev ifb1 protocol ipv6 parent 1:0 prio $(++prio) u32 match ip6 dport $(port) 0xffff flowid 1:2".text,
            //i"tc filter add dev ifb1 protocol ipv6 parent 1:0 prio $(++prio) u32 match ip6 sport $(port) 0xffff flowid 1:2".text,
        ]);
    }
}
void includeAll(ref int prio){
    execEcho([
        i"tc filter add dev ifb1 protocol ip parent 1:0 prio $(++prio) u32 match ip src 0/0  flowid 1:3".text,
        //i"tc filter add dev ifb1 protocol ipv6 parent 1:0 prio $(++prio) u32 match ip6 src ::/0 flowid 1:3".text,
    ]);
}
void include(ushort[] ports, ref int prio){
    foreach(port; ports){
        execEcho([
            i"tc filter add dev ifb1 protocol ip parent 1:0 prio $(++prio) u32 match ip dport $(port) 0xffff flowid 1:3".text,
            i"tc filter add dev ifb1 protocol ip parent 1:0 prio $(++prio) u32 match ip sport $(port) 0xffff flowid 1:3".text,
            //i"tc filter add dev ifb1 protocol ipv6 parent 1:0 prio $(++prio) u32 match ip6 dport $(port) 0xffff flowid 1:3".text,
        ]);
    }
}
void impair(Impairment i){
    execEcho([
        "tc qdisc add    dev ifb1 parent 1:3 handle 30: netem",
        "tc qdisc change dev ifb1 parent 1:3 handle 30: netem "~i.rule,
    ]);
}
void teardown(string iface){
    execEcho([
        i"tc filter del dev $(iface) parent ffff: protocol ip prio 1".text,
        i"tc qdisc del dev $(iface) ingress".text,
        "ip link set dev ifb1 down",
        "tc qdisc del root dev ifb1",
        "sudo ip link del name ifb1",
    ]);
}
void listRules(){
    return execEcho([
        "sudo tc qdisc list",
    ]);
}

string defaultNetIface(){
    return executeShell("route | grep default | awk '{print $NF}'").output.strip;
}
ushort[] portsForProgramName(string name){
    auto pids = format!("pidof %s")(name).executeShell.output.split;
    //writefln!("%d pids matching program name '%s': %-(%s, %)")(pids.length, name, pids);
    ushort[] ports;
    foreach(pid; pids){
        ports ~= 
            executeShell(
                `sudo netstat -aputn` ~
               i`| grep $(pid)`.text ~
                `| awk '{print $4}'` ~
                `| awk -F ':' '{print $2}'`
            )
            .output
            .split
            .map!(a => a.strip('\0').to!ushort)
            .array;
    }
    ports = ports.sort.uniq.array;
    //writeln(ports);
    return ports;
}
void execEcho(string[] cmds){
    foreach(cmd; cmds){
        writefln!("\x1b[3m%s\x1b[0m")(cmd);
        string result = executeShell(cmd).output;
        if(result){
            writefln!("\x1b[3m\x1b[38;5;111m%s\x1b[0m")(result.strip);
        }
    }
}

void structGetopt(T)(ref T v, string[] args){
    static foreach(m; FieldNameTuple!T){
        args.getopt(
            std.getopt.config.passThrough,
            m,
            &__traits(getMember, v, m),
        );
    }
}