#!/usr/bin/env bash

# 1. Get ONLY the IDs from the Sinks section
# This regex looks for a number at the start of the line (ignoring the | and * symbols)
# It ensures the number is followed by a dot, and ignores anything later in the line (like vol: 0.60)
sinks=($(wpctl status | sed -n '/Sinks:/,/Sources:/p' | grep -oP '^[|│* \t]*\K[0-9]+(?=\.)'))

# 2. Get the current active Sink ID (the one with the *)
current=$(wpctl status | sed -n '/Sinks:/,/Sources:/p' | grep '*' | grep -oP '^[|│* \t]*\K[0-9]+(?=\.)')

# 3. Safety check: If current is empty, pick the first sink
if [ -z "$current" ]; then
    current=${sinks[0]}
fi

# 4. Find the next sink in the rotation
next_sink=${sinks[0]}
for i in "${!sinks[@]}"; do
   if [[ "${sinks[$i]}" == "$current" ]]; then
       next=$(( (i + 1) % ${#sinks[@]} ))
       next_sink=${sinks[$next]}
       break
   fi
done

# 5. Switch the output
wpctl set-default "$next_sink"

# 6. Send a notification
if command -v notify-send >/dev/null; then
    name=$(wpctl status | sed -n '/Sinks:/,/Sources:/p' | grep " $next_sink\." | sed -E "s/.*$next_sink\. //; s/ \[vol:.*//" | xargs)
    notify-send "Audio Output" "Active: $name" -i audio-speakers -t 2000
fi