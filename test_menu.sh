#!/bin/bash
options=("start" "stop" "pause" "resume" "status")
selected=0
tput civis
print_menu() {
  if [ "$1" -gt 0 ]; then
    tput cuu ${#options[@]}
  fi
  for i in "${!options[@]}"; do
    if [ $i -eq $selected ]; then
      echo -e "\e[32m> ${options[$i]}\e[0m"
    else
      echo "  ${options[$i]}"
    fi
  done
}
print_menu 0
tput cnorm
echo "Selected: ${options[$selected]}"
