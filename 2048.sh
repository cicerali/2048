#!/bin/bash

SIZE=4
score=0
scheme=0
declare -A board
initialized=false

function setBufferedInput() {
  : # not needed
}

function getColor() {
  local value=$1
  original=(8 255 1 255 2 255 3 255 4 255 5 255 6 255 7 255 9 0 10 0 11 0 12 0 13 0 14 0 255 0 255 0)
  blackwhite=(232 255 234 255 236 255 238 255 240 255 242 255 244 255 246 0 248 0 249 0 250 0 251 0 252 0 253 0 254 0 255 0)
  bluered=(235 255 63 255 57 255 93 255 129 255 165 255 201 255 200 255 199 255 198 255 197 255 196 255 196 255 196 255 196 255 196 255)
  declare -A schemes
  local i
  for ((i = 0; i < 32; i++)); do
    schemes[0, $i]=${original[$i]}
    schemes[1, $i]=${blackwhite[$i]}
    schemes[2, $i]=${bluered[$i]}
  done

  local b_id=0
  local f_id=1
  if ((value > 0)); then
    while ((value--)); do
      if (((b_id + 2) < 32)); then
        ((b_id += 2))
        ((f_id += 2))
      fi
    done
  fi
  background=${schemes[$scheme, $b_id]}
  foreground=${schemes[$scheme, $f_id]}

  echo "\033[38;5;${foreground};48;5;${background}m"
}

function drawBoard() {
  local x
  local y
  local reset="\033[m"
  printf "\033[H"

  printf "2048.sh %16d pts\n\n" "$score"

  for ((y = 0; y < SIZE; y++)); do
    for ((x = 0; x < SIZE; x++)); do
      color=$(getColor "${board[$x, $y]}")
      printf '%b' "$color"
      printf "       "
      printf '%b' "$reset"
    done
    printf "\n"
    for ((x = 0; x < SIZE; x++)); do
      color=$(getColor "${board[$x, $y]}")
      printf '%b' "$color"
      if ((board[$x, $y] != 0)); then
        s=$((1 << board[$x, $y]))
        t=$((7 - ${#s}))
        printf '%*s%s%*s' "$((t - (t / 2)))" "" "$s" "$((t / 2))" ""
      else
        printf "   ·   "
      fi
      printf '%b' "$reset"
    done
    printf "\n"
    for ((x = 0; x < SIZE; x++)); do
      color=$(getColor "${board[$x, $y]}")
      printf '%b' "$color"
      printf "       "
      printf '%b' "$reset"
    done
    printf "\n"
  done
  printf "\n"
  printf "        ←,↑,→,↓ or q        \n"
  printf "\033[A" # one line up
}

function findTarget() {
  local a=$1
  local x=$2
  local stop=$3
  # if the position is already on the first, don't evaluate
  if ((x == 0)); then
    echo "$x"
    return
  fi
  for ((t = (x - 1); ; t--)); do
    if ((board[$a, $t] != 0)); then
      if ((board[$a, $t] != board[$a, $x])); then
        # merge is not possible, take next position
        echo $((t + 1))
        return
      fi
      echo "$t"
      return
    else
      # we should not slide further, return this one
      if ((t == stop)); then
        echo "$t"
        return
      fi
    fi
  done
  # we did not find a
  echo "$x"
}

function slideArray() {
  local a=$1
  local success=0
  local x
  local t
  local stop=0

  for ((x = 0; x < SIZE; x++)); do
    if ((board[$a, $x] != 0)); then
      t=$(findTarget "$a" "$x" $stop)
      # if target is not original position, then move or merge
      if ((t != x)); then
        # if target is zero, this is a move
        if ((board[$a, $t] == 0)); then
          board[$a, $t]=${board[$a, $x]}
        elif ((board[$a, $t] == board[$a, $x])); then
          # merge (increase power of two)
          ((board[$a, $t]++))
          # increase score
          ((score += board[$a, $t]))
          # set stop to avoid double merge
          stop=$((t + 1))
        fi
        board[$a, $x]=0
        success=1
      fi
    fi
  done
  return $success
}

function rotateBoard() {
  local i
  local j
  local n=$SIZE
  local tmp
  for ((i = 0; i < (n / 2); i++)); do
    for ((j = i; j < (n - i - 1); j++)); do
      tmp=${board[$i, $j]}
      board[$i, $j]=${board[$j, $((n - i - 1))]}
      board[$j, $((n - i - 1))]=${board[$((n - i - 1)), $((n - j - 1))]}
      board[$((n - i - 1)), $((n - j - 1))]=${board[$((n - j - 1)), $i]}
      board[$((n - j - 1)), $i]=$tmp
    done
  done
}

function moveUp() {
  local success=0
  local x
  for ((x = 0; x < SIZE; x++)); do
    slideArray "$x"
    ((success |= $?))
  done
  return "$success"
}

function moveLeft() {
  local success=0
  rotateBoard
  moveUp
  success=$?
  rotateBoard
  rotateBoard
  rotateBoard
  return $success
}

function moveDown() {
  rotateBoard
  rotateBoard
  moveUp
  success=$?
  rotateBoard
  rotateBoard
  return $success
}

function moveRight() {
  rotateBoard
  rotateBoard
  rotateBoard
  moveUp
  success=$?
  rotateBoard
  return $success
}

function findPairDown() {
  local success=0
  local x
  local y
  for ((x = 0; x < SIZE; x++)); do
    for ((y = 0; y < (SIZE - 1); y++)); do
      if ((board[$x, $y] == board[$x, $((y + 1))])); then
        echo 1
        return
      fi
    done
  done
  echo $success
}

function countEmpty() {
  local count=0
  local x
  local y
  for ((x = 0; x < SIZE; x++)); do
    for ((y = 0; y < SIZE; y++)); do
      if ((board[$x, $y] == 0)); then
        ((count++))
      fi
    done
  done
  echo "$count"
}

function gameEnded() {
  local ended=1
  if (($(countEmpty) > 0)); then
    echo 0
    return
  fi
  if (($(findPairDown))); then
    echo 0
    return
  fi
  rotateBoard
  if (($(findPairDown))); then
    ended=0
  fi
  rotateBoard
  rotateBoard
  rotateBoard
  echo $ended
}

function addRandom() {
  local x
  local y
  local r
  local len=0
  local n
  declare -a list

  if ! $initialized; then
    initialized=true
  fi

  for ((x = 0; x < SIZE; x++)); do
    for ((y = 0; y < SIZE; y++)); do
      if ((board[$x, $y] == 0)); then
        list[$len, 0]=$x
        list[$len, 1]=$y
        ((len += 1))
      fi
    done
  done

  if ((len > 0)); then
    r=$((RANDOM % len))
    x=${list[$r, 0]}
    y=${list[$r, 1]}
    n=$(((RANDOM % 10) / 9 + 1))
    board[$x, $y]=$n
  fi
}

function initBoard() {
  local x
  local y
  for ((x = 0; x < SIZE; x++)); do
    for ((y = 0; y < SIZE; y++)); do
      board[$x, $y]=0
    done
  done
  addRandom
  addRandom
  drawBoard
  score=0
}

function getchar() {
  escape=$(printf "\u1b")
  read -rsn1 char
  local ret=$?
  if ((ret != 0)); then
    return $ret
  fi
  if [[ $char == "$escape" ]]; then
    read -rsn2 char
    ret=$?
    if ((ret != 0)); then
      return $ret
    fi
  fi
  echo "$char"
}

function test() {
  printf "All tests executed successfully\n"
  return 0
}

function signal_callback_handler() {
  printf "         TERMINATED         \n"
  setBufferedInput true

  # "\033[?25h" Make cursor visible
  # "\033[m" Reset special formatting
  printf "\033[?25h\033[m"
  exit 2
}

### main ###

if [[ $# == 1 && $1 == "test" ]]; then
  test
  exit $?
fi
if [[ $# == 1 && $1 == "blackwhite" ]]; then
  scheme=1
fi
if [[ $# == 1 && $1 == "bluered" ]]; then
  scheme=2
fi

# "\033[?25l"   Hide the cursor
# "\033[2J"     Clear the screen
printf "\033[?25l\033[2J"

# register signal handler for when ctrl-c is pressed
trap signal_callback_handler SIGINT

initBoard
setBufferedInput false

success=0

while :; do
  c=$(getchar)
  ret=$?
  if ((ret != 0)); then
    printf "\nError! Cannot read keyboard input!\n"
    break
  fi

  case $c in
  a | h | '[D')
    moveLeft
    success=$?
    ;;
  d | l | '[C')
    moveRight
    success=$?
    ;;
  w | k | '[A')
    moveUp
    success=$?
    ;;
  s | j | '[B')
    moveDown
    success=$?
    ;;
  *)
    success=0
    ;;
  esac

  if ((success)); then
    drawBoard
    sleep 0.15
    addRandom
    drawBoard
    if (($(gameEnded))); then
      printf "         GAME OVER          \n"
      break
    fi
  fi
  if [[ $c == "q" ]]; then
    printf "        QUIT? (y/n)         \n"
    c=$(getchar)
    if ((c == 'y')); then
      break
    fi
    drawBoard
  fi
  if [[ $c == 'r' ]]; then
    printf "       RESTART? (y/n)       \n"
    c=$(getchar)
    if ((c == 'y')); then
      initBoard
    fi
    drawBoard
  fi
  if [[ $c == c ]]; then
    printf "\033[H"
    printf "\033[J"
    drawBoard
  fi
done

setBufferedInput true

printf "\033[?25h\033[m"

exit 0
