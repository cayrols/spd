# Split Parallel Debugger (spd)

This bash script helps to debug distributed applications.
It relies on `tmux` to display each rank in a correct manner. 
No installation is needed except maybe the creation of a `RC file`
which sets the paths and names of different variables and executables.

This script allows the user to use two modes:
* split
* gdb

In all cases, a left pane is created that contains the **master worker** which is
responsible for the management of the parallel execution.

### split
In this mode, the output of each process is redirected in a separated pane
using pipes.

### gdb
In this mode, a left pane contains the gdbserver and all stdout messages.
Each other pane is associated with a rank and a gdb, one gdb per rank.

## General execution

In substance, the script creates a tmux session called `spd`.
Then the script creates:
* a grid composed of panes
* setup a master on the `MASTER_PANE`,
* setup an environment per pane per rank.

# Installation
Clone the repository and move inside.
No installation needed except maybe the creation of configuration file
`spd_config.in` and RC file `.spdrc` either in your `${HOME}` directory or in the
current project the user consider (see RC file session for more info).

You may add the path of the repository into your `PATH` environment variable:
```
export PATH+=:<path_of_the_repo>
```

### Configuration and RC file

The general configuration of the script goes through the `spd_config.in` file.

It is possible to overwrite this file by creating a user
configuration file with the same name but located in a different place.
The order of loading is defined as follow:
* Try to load `./spd_config.in`,
* else, try to load `${HOME}/spd_config.in`,
* else, try to load `${SPD_ROOT}/spd_config.in`.

The definition of multiple configuration files allows the user to globally
(i,e, in ${HOME}) or locally (i,e, ./) overwrite the general behavior of the
script.

Moreover, it is possible to overwrite a subset of the configuration file by
creating a `RC file` named `.spdrc` either in ${HOME} or the local repository.

This approach allows the user to define a behavior for an application that
could be different from another application.

In order to setup the environment correctly, we provide a few examples for
different plateforms in the folder `rc_files`.

Make a copy of one of them into your ${HOME}, and rename it `.spdrc` as follow:
```
cp rc_files/spdrc_<machine_name> ${HOME}/.spdrc
```

Then update it as needed.

**Remark 1** By default, without `RC file`, only the `config_spd.in` file is
read which sets `gdb` and `gdbserver` to the default, i.e., gdb and gdbserver
available on the system.

**Remark 2** We note that on some machines the GNU `gdb`/`gdbserver` do not
work properly when reading the symbols.  We then switch to
`cuda-gdb`/`cuda-gdbserver` using `.spdrc` for example.

# Environment
We use the `tmux` software to display and manage the different modes of
execution.  We recommand at least `tmux/3.1b` as we basically have used using
it during development.
It does not mean this script does not work with older versions, just no
guarantee.

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
The classical way of using it is by considering the following standard way of execution of a parallel execution:
```
mpirun -n 4 ./exec_name <params_list>
```

The idea is to reuse this line and to add at the beginning the call to `spd` as follow:
```
spd -p 1 -q 4 --exec ./exec_name --run mpirun -n 4 ./exec_name <params_list>
```

The command above will create four panes and separate the output of each rank.

This command line works as follow:
* *-p* is the number of nodes
* *-q* is the number of ranks per node
* *--exec* is the name of the executable given to mpirun **MANDATORY**
* *--run* corresponds to the mpirun command line that will be executed **MANDATORY**.

Or,

imagine one of the ranks crashes, like raising `SIGSEGV`, we can do:
```
spd -p 1 -q 4 --gdb --exec ./exec_name --run mpirun -n 4 ./exec_name <params_list>
```

This command will launch one instance of gdb on each pane and they all connect to the gdb server, i.e., the master worker.

## Remarks
Some remarks:
* For now, we do not have a way to parse automatically the command line, so we **need** to provide the name of the executable using *--exec*, with the **EXACT** same syntax as used in mpirun. It could be set through a local `RC file`.
* The flag *--run* must be the **last flag** relative to spd
* It seems (at least on Saturn) even when the flag `--cuda-use-lockfile=0` is used, it is not possible to use cuda-gdb when the number of MPI processes is greater than the number of GPU (at least -n 2 and 1 GPU does not work. Error: gdbserver: Another cuda-gdb instance is working with the lock file. Try again

## Additional flags

Here is a non-exhaustive list of additional flags. For a full list,
```
spd -h
```
or
```
spd --help
```

### *--gdb_add_cmd* flag
Some additional arguments of `spd` can be provided. For example, we can pass 
gdb commands to all gdb instances, all at once. For that, we use the flag `--gdbaddcmd`, as follow:
```
spd -p 2 -q 6 --gdb_add_cmd "-ex 'c'" --exec ./exec_name --run mpirun -n 12 ./exec_name <params_list>
```

In the example above, we request all gdb to execute `continue`.

```
spd -p 3 -q 3 --gdb_add_cmd "-ex 'b MPI_Init' -ex 'c'" --exec ./exec_name --run mpirun -n 9 ./exec_name <params_list>
```
In the example above, we put a breakpoint when `MPI_Init` routine is encountered and then we start the execution.
It means all nine ranks will execute the sequence of instructions.

### paging flag (**EXPERIMENTAL**)
When a large number of ranks have to be considered, the standard display might not
be convenient. We added an experimental flag `--paging` that splits the 
nodes into groups of <int> nodes, displaying one group per tmux window:
```
spd -p 6 -q 6 --paging 1 --exec ./exec_name --run mpirun -n 36 ./exec_name <param_list>
```

### ranks flags (**EXPERIMENTAL**)
Sometimes, we know the subset of ranks we want to focus on. For that, we
introduce the flag `--ranks` followed by a (unordered) list of rank_id, all
separated by a comma:
```
spd -p 4 -q 2 --ranks 0,1,7 --exec ./exec_name --run mpirun -n 8 ./exec_name <param_list>
```

# Sandbox

If you want to play with it, we provide a test file named `example.c` and
located in `test` directory.
This example contains a few scenarii that generate different signals like `SIGSEGV`.

To compile it,
```
cd test && make
```

Now, the user can use it to test this script.
Here is a non-exhaustive list of executions and the expected output.

Create a grid of size 2x2:
```
./spd -p 2 -q 2 --exec ./test/example --run mpirun -n 4 ./test/example
```

Create a max size grid of 3x2 but focus on ranks 1 and 3:
```
./spd -p 3 -q 2 --ranks 3,1 --create_grid 1 --attach 1 --unpack_ranks 0 --exec ./test/example --run mpirun -n 6 ./test/example
```

Explanation:
* Create a grid of maximum size 3x2
* Attach to the spd session at the end of the execution of the script
* Since we request a subset of ranks, do not unpack them onto the grid

Let the grid already exist, say through:
```
./spd -p 3 -q 2 --create_grid 1 --attach 1 --exec ./test/example --run mpirun -n 6 ./test/example
```
then, focus on a subset and map then on this existing grid:
```
./spd -p 3 -q 2 --ranks 3,1,4 --create_grid 0 --attach 1 --unpack_ranks 1 --exec ./test/example --run mpirun -n 6 ./test/example
```

Use the paging to display the grid differently:
```
./spd -p 3 -q 2 --paging 1 --create_grid 1 --attach 1 --exec ./test/example --run mpirun -n 6 ./test/example
```
