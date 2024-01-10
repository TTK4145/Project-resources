Extra resources for the elevator project
========================================

In this repository you will find some extra resources that may be useful when working on the elevator project. Since these resources are not *required* for completing the project they are kept separate from the things that are, such as the specification and evaluation information.

Contents:

 - [Single elevator algorithm and demo code](/elev_algo) for implementing this as a finite state machine in C
 - [Cost functions](/cost_fns) and ways to assign new hall requests to elevators
 - [Packet loss script](/packet_loss) for Linux to easily simulate packet loss
 - Links to external programming language and design resources (below)




Language resources
------------------

We encourage submissions to this list! Tutorials, libraries, articles, blog posts, talks, videos...
 - [Python](http://python.org/)
   - [Official tutorial](https://docs.python.org/3/tutorial/)
   - [Python for Programmers](https://wiki.python.org/moin/BeginnersGuide/Programmers) (Several websites/books/tutorials)
   - [Advanced Python Programming](http://www.slideshare.net/vishnukraj/advanced-python-programming)
   - [Socket Programming HOWTO](http://docs.python.org/2/howto/sockets.html)
 - C
   - [Amended C99 standard](http://www.open-std.org/jtc1/sc22/wg14/www/docs/n1256.pdf) (pdf)
   - [GNU C library](http://www.gnu.org/software/libc/manual/html_node/)
   - [POSIX '97 standard headers index](http://pubs.opengroup.org/onlinepubs/7990989775/headix.html)
   - [POSIX.1-2008 standard](http://pubs.opengroup.org/onlinepubs/9699919799/) (Unnavigable terrible website)
   - [Beej's network tutorial](http://beej.us/guide/bgnet/)
   - [Deep C](http://www.slideshare.net/olvemaudal/deep-c)
 - [Go](http://golang.org/)
   - [Official tour](https://go.dev/tour/)
   - [Go by Example](https://gobyexample.com/)
   - [Learning Go](https://miek.nl/go/)
   - From [the wiki](http://code.google.com/p/go-wiki/): [Articles](https://code.google.com/p/go-wiki/wiki/Articles), [Talks](https://code.google.com/p/go-wiki/wiki/GoTalks)
   - [Advanced Go Concurrency Patterns](https://www.youtube.com/watch?v=QDDwwePbDtw) (video): transforming problems into the for-select-loop form
 - [D](http://dlang.org/)
   - [Official tour](https://tour.dlang.org/)
   - [Programming in D](http://ddili.org/ders/d.en/)
   - [Pragmatic D Tutorial](http://qznc.github.io/d-tut/)
   - DConf talks [2017](https://www.youtube.com/playlist?list=PL3jwVPmk_PRxo23yyoc0Ip_cP3-rCm7eB), [2016](https://www.youtube.com/playlist?list=PL3jwVPmk_PRyTWWtTAZyvmjDF4pm6EX6z), [2015](https://www.youtube.com/playlist?list=PL7VSm729VhTBTYNdLEMsUAmcYEoNUV6Jf)
   - [The book](http://www.amazon.com/exec/obidos/ASIN/0321635361/) by Andrei Alexandrescu ([Chapter 1](http://www.informit.com/articles/article.aspx?p=1381876), [Chapter 13](http://www.informit.com/articles/article.aspx?p=1609144))
 - [Erlang](http://www.erlang.org/)
   - [Learn you some Erlang for great good!](http://learnyousomeerlang.com/content)
   - [Erlang: The Movie](http://www.youtube.com/watch?v=uKfKtXYLG78), [Erlang: The Movie II: The sequel](http://www.youtube.com/watch?v=rRbY3TMUcgQ)
 - [Rust](http://www.rust-lang.org/)
 - Java
   - [The Java Tutorials](http://docs.oracle.com/javase/tutorial/index.html)
   - [Java 8 API spec](http://docs.oracle.com/javase/8/docs/api/)
 - [Scala](http://scala-lang.org/)
   - [Learn](http://scala-lang.org/documentation/)
 - [C#](https://msdn.microsoft.com/en-us/library/kx37x362.aspx?f=255&MSPPError=-2147217396)
   - [C# 6.0 and the .NET 4.6 Framework by Andrew Troelsen (free pdf-version for NTNU students)](http://link.springer.com/book/10.1007/978-1-4842-1332-2)
   - [Mono (.NET on Linux)](http://www.mono-project.com/docs/)
   - [Introduction to Socket Programming with C#](http://www.codeproject.com/Articles/10649/An-Introduction-to-Socket-Programming-in-NET-using)
   - Importing native libraries: [general](http://www.codeproject.com/Articles/403285/P-Invoke-Tutorial-Basics-Part) and [for Linux](http://www.mono-project.com/docs/advanced/pinvoke/)


Design and code quality
-----------------------

 - [Simple Made Easy](https://www.infoq.com/presentations/Simple-Made-Easy) (video): How choosing the easy path will lead to complexity
 - [Boundaries](https://www.destroyallsoftware.com/talks/boundaries) (video): The "Funcional Core / Imperative Shell" way of programming
 - [The State of Sock Tubes](http://james-iry.blogspot.no/2009/04/state-of-sock-tubes.html): How "state" is pervasive even in message-passing- and functional languages
 - [Defactoring](http://raganwald.com/2013/10/08/defactoring.html): Removing flexibility to better express intent
 - [Railway Oriented Programming](http://www.slideshare.net/ScottWlaschin/railway-oriented-programming): A functional approach to error handling
 - [Practical Unit Testing](https://www.youtube.com/watch?v=i_oA5ZWLhQc) (video): "Readable, Maintainable, and Trustworthy"
 - [Core Principles and Practices for Creating Lightweight Design](https://www.youtube.com/watch?v=3G-LO9T3D1M&t=4h31m25s) (video)
 - [Origins and pitfalls of the recursive mutex](http://zaval.org/resources/library/butenhof1.html). (TL;DR: Recursive mutexes are usually bad, because if you need one you're holding a lock for too long)
 - [The Future of Programming](http://vimeo.com/71278954) (video): A presentation on what programming may look like 40 years from now... as if it was presented 40 years ago.
