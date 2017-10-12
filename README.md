

**Algorithms and Topologies included:**

Gossip:

1. Line
2. Full Network
3. Grid
4. Imperfect Grid

Push-sum:

1. Line
2. Full Network
3. Grid
4. Imperfect Grid

The executable included in the project can be run as follows:

project2 numNodes topology algorithm

::   ./gossip    numNodes    line|full|grid|i\_grid    gossip|pushsum



Failure models were also implemented in this project and can be run as follows:

project2 numNodes topology algorithm percentage

where our parameter for analyzing failure of nodes is percentage of total failed nodes in network (1-50%)

::   ./gossip    numNodes    line|full|grid|i\_grid    gossip|pushsum  percentage(1..50)

Networks dealt with, for the following topology and algorithm

Gossip

1. Line  -  512
2. Full Network - 100000
3. Grid - 100000
4. Imperfect Grid - 100000

Push-sum

1. Line - 256
2. Full Network -1024
3. Grid - 4096
4. Imperfect Grid – 4096

