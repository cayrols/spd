`pgdb` launches a tmux window for each MPI rank and runs gdb within each window.
So MPI programs can be easily debugged.

### Quick start

```
cd pgdb
```

Copy one of the configuration files under `rc_files` folder:

```
ln ./rc_files/pgdbrc_leconte ~/.pgdbrc
```

Run slate with two MPI ranks:

```
./pgdb.sh -p 1 -q 2 --gdbaddcmd "-ex 'c'" --exec $HOME/slate/test/tester --run  mpirun -n 2 -hosts leconte.icl.utk.edu,leconte.icl.utk.edu $HOME/slate/test/tester --dim 100x100x100 gemm
```


