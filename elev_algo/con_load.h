
#include <stdio.h>
#include <string.h>

// Load values from a config file
// 
//  Key-value pairs in the config file are assumed to be of the form:
//  "--key value"
//  Lines not starting in "--" are ignored.
//  Keys are *not* case-sensitive
//  Enum values are *not* case-sensitive
//
// keyuments:
//  file:   Name of the file to load.
//  cases:  One or more instance of `con_val()` or `con_enum()`
//          The cases must *not* be separated by commas.
//
//  Example:
//      /* Content of "config.con":
//      ```
//          --integer 5
//          --greeting hello
//          --enumeration En2
//      ```
//      */
//
//      typedef enum { En1, En2, En3 } En;
//      int     i;
//      char    s[16];
//      En      en;
//
//      con_load("config.con",
//          con_val("integer", &i, "%d")
//          con_val("greeting", s, "%[^\n]")
//          con_enum("enumeration", &en, 
//              con_match(En1)
//              con_match(En2)
//              con_match(En3)
//          )
//      )
//      printf("%s, %d, %d\n", s, i, en);   // Should print "hello, 5, 1"
//
#define con_load(file, cases)                               \
{                                                           \
    FILE* _f = fopen(file, "r");                            \
    if(_f){                                                 \
        char _line[128] = {0};                              \
        while(fgets(_line, 128, _f)){                       \
            if(!strncmp(_line, "--", 2)){                   \
                char _key[64];                              \
                char _val[64];                              \
                sscanf(_line, "--%s %s", _key, _val);       \
                cases                                       \
            }                                               \
        }                                                   \
    } else {                                                \
        printf("Unable to open config file %s\n", file);    \
    }                                                       \
}


#define con_val(key, var, fmt)                              \
    if(!strcasecmp(_key, key)){                             \
        sscanf(_val, fmt, var);                             \
    }


#define con_enum(key, var, match_cases)                     \
    if(!strcasecmp(_key, key)){                             \
        typeof(*var) _v;                                    \
        match_cases                                         \
        *var = _v;                                          \
    }

#define con_match(id)                                       \
    if(!strcasecmp(_val, #id)){                             \
        _v = id;                                            \
    }




