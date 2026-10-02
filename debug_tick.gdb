# =====================================================================
#  debug_tick.gdb - watch the global variable `tick` free-run, and prove
#                  it increments at ~1000 per second.
#
#  Invoked by debug_tick.bat:
#      arm-none-eabi-gdb --batch -x debug_tick.gdb build/NO1homework.elf
#
#  How the "pause" works:
#  There is no tty in --batch mode, so a real Ctrl+C is impossible.
#  Instead the target is resumed asynchronously (`continue &`, which
#  returns to the GDB prompt immediately), we sleep on the host, then
#  issue `interrupt` - the CLI equivalent of Ctrl+C. Labels are ASCII
#  so they survive any console codepage in a screenshot.
# =====================================================================

set pagination off
set confirm off
set width 0

# ---- 1) connect to the OpenOCD gdb server on port 3333 ----
target extended-remote localhost:3333

# ---- 2) reset, halt, then flash the freshly built ELF ----
monitor reset halt
load

printf "\n>>> flashed, target running free (TIM2 fires every 1 ms -> tick++)\n"

# ---- 3) sample 1: run ~3 s, halt, read ----
continue &
shell ping -n 4 127.0.0.1 > nul
interrupt
set $t1 = tick
printf "\n===== sample 1 =====\n"
printf "tick = %u\n", $t1

# ---- 4) sample 2 ----
continue &
shell ping -n 4 127.0.0.1 > nul
interrupt
set $t2 = tick
printf "\n===== sample 2 =====\n"
printf "tick = %u      delta = %d\n", $t2, $t2 - $t1

# ---- 5) sample 3 ----
continue &
shell ping -n 4 127.0.0.1 > nul
interrupt
set $t3 = tick
printf "\n===== sample 3 =====\n"
printf "tick = %u      delta = %d\n", $t3, $t3 - $t2

# ---- 6) sample 4 ----
continue &
shell ping -n 4 127.0.0.1 > nul
interrupt
set $t4 = tick
printf "\n===== sample 4 =====\n"
printf "tick = %u      delta = %d\n", $t4, $t4 - $t3

printf "\n>>> each delta covers ~3 s of wall clock, so ~3000 is expected\n"
printf ">>> i.e. about 1000 increments per second\n"

# ---- 7) leave the board running normally ----
monitor reset run
quit
