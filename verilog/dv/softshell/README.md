# Softshell DV

Softshell has three different DV tests (full chip, block level behavioral, and
block gate level).

## Block Level Behavioral

This test checks CPU 0 execution and tests all the private / shared peripherals
and IO.

```
cd verilog/rtl/softshell/dv && make
```

## Block Gate Level

This test is the same as the behavioral verison but runs on the GL netlist.

```
cd verilog/rtl/softshell/dv && make GL=1
```

## Full Chip Behavioral

Checks basic clocking, reset, GPIO, and wishbone connectivity with Caravel.

```
cd verilog/dv/softshell/fullchip_shared_directed && make
```
