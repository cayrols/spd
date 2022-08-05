This script helps to debug distributed applications. It relies on tmux to display
each rank in a correct manner. No installation are needed except the creation of a `RC file`
which sets the paths and names of different variables and executables.

This script allows the user to use two modes:
* split
* gdb

In all cases, a left pane is created and contains the master worker which is
responsible of the management of the parallel execution.

## split
In this mode, the output of each process is redirected in a separated pane.

## gdb
When the script is used, a left pane contains the gdbserver and all stdout messages.
The right part will contain all ranks with all gdb, one gdb per rank.

## Execution

In substance, the script creates a tmux session called `spd`, focuses on it if other tmux
sessions exist. If so, the user has to **detach** in order to resume.
Then the scripts creates either:
* a pane per rank, waits a few seconds and then the master
* the gdbserver, waits a few seconds and then creates a pane per rank.

# Install
Clone the repo and move inside. No installation needed except the creation of a `RC file`.

### RC file
In order to setup the environment correctly, we provide a few examples for different
plateforms in the folder `rc_files`.

Make a copy of one of them into your $HOME, and rename it .spdrc as follow:
```
cp rc_files/spdrc_<machine_name> $HOME/.spdrc
```

Then update it as needed.
**Remark** By default, without `RC file`, only the `config_spd.in` file is read
which sets `gdb` and `gdbserver` to the default, i.e., gdb and gdbserver.

**Remark 2** We note that on some machines the GNU `gdb`/`gdbserver` do not work properly when reading the symbols.
We then switch to `cuda-gdb`/`cuda-gdbserver`.

## Environment
We use the tmux software to display and manage the different modes of execution.
We recommand `tmux/3.1b` as we are mainly using it. It does not mean it does not work
with another version, just no guarantee.

### Some tmux commands
Tmux uses a prefix key, which is by default `Ctrl-b`.

* **detach** from a tmux session
  * `Ctrl-b d`
* **zoom/unzoom** in a pane
  * `Ctrl-b z`
* **move** between panes
  * `Ctrl-b arrow`
* **kill** all panes but the gdbserver pane
  * `Ctrl-b : kill-pane -a -t 0`

# Usage
The classical way of using it is by considering the following standard way of execution:
```
mpirun -n 4 ./exec_name <params_list>
```

The idea is to reuse this line and to add at the beginning the call to `spd` as follow:
```
spd -p 1 -q 4 --exec ./exec_name --run mpirun -n 4 ./exec_name <params_list>
```

The command above will create four panes and separate the output of each rank.

This command line works as follow:
* -p is the number of nodes
* -q is the number of ranks per node
* --exec is the name of the executable given to mpirun
* --run corresponds to the mpirun command line that will be executed.

Or, imagine one of the rank crashes like a `SIGSEGV`, we can do:
```
spd -p 1 -q 4 --gdb --exec ./exec_name --run mpirun -n 4 ./exec_name <params_list>
```

This command will launch one instance of gdb on each pane and they all connect to the gdb server, i.e., the master worker.

## Remarks
Some remarks:
* For now, we do not parse automatically the command line, so we **need** to provide the name of the executable, with the **EXACT** same syntax as used in mpirun.
* The flag --run must be the last one relative to spd
* It seems (at least on Saturn) even when the flag `--cuda-use-lockfile=0` is used, it is not possible to use cuda-gdb when the number of MPI processes is greater than the number of GPU (at least -n 2 and 1 GPU does not work. Error: gdbserver: Another cuda-gdb instance is working with the lock file. Try again

## Additional flags

### gdbaddcmd flag
Some additional arguments of `spd` can be provided. For example, we can pass 
gdb commands to all gdb instances, all at once. For that, we use the flag `--gdbaddcmd`, as follow:
```
spd -p 2 -q 6 --gdbaddcmd "-ex 'c'" --exec ./exec_name --run mpirun -n 12 ./exec_name <params_list>
```

In the example above, we request all gdb to execute `continue`.

```
spd -p 3 -q 3 --gdbaddcmd "-ex 'b MPI_Init' -ex 'c'" --exec ./exec_name --run mpirun -n 9 ./exec_name <params_list>
```
In the example above, we put a breakpoint when `MPI_Init` routine is encountered and then we start the execution.
It means all nine ranks will execute the sequence of instructions.

### paging flag (**EXPERIMENTAL - DISABLE FOR NOW**)
When a large number of ranks have to be debugged, the standard display might not
be convenient. We added an experimental flag `--paging` that splits the 
nodes into groups of two nodes, displaying one group per tmux window:
```
spd -p 6 -q 6 --paging --exec ./exec_name --run mpirun -n 36 ./exec_name <param_list>
```

### ranks flags (**EXPERIMENTAL - DISABLE FOR NOW**)
Sometimes, we know the subset of ranks we want to debug. For that, we introduce
the flag `--ranks` followed by a list of rank_id, all separated by a comma (for now):
```
spd -p 4 -q 2 --ranks 0,1,7 --exec ./exec_name --run mpirun -n 8 ./exec_name <param_list>
```
