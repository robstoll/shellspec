#!/bin/sh
#shellcheck disable=SC2004

set -eu

# shellcheck source=lib/general.sh
. "${SHELLSPEC_LIB:-./lib}/general.sh"
# shellcheck source=lib/libexec/translator.sh
. "${SHELLSPEC_LIB:-./lib}/libexec/translator.sh"

example_count=0 block_no=0 block_no_stack='' skip_id=0
inside_of_example=''

block_example_group() {
  if [ "$inside_of_example" ]; then
    syntax_error "Describe/Context cannot be defined inside of Example"
  fi

  increasese_id
  block_no=$(($block_no + 1))
  putsn "(" \
    "SHELLSPEC_BLOCK_NO=$block_no" \
    "SHELLSPEC_SPECFILE=\"$specfile\"" "SHELLSPEC_ID=$id" \
    "SHELLSPEC_LINENO_BEGIN=$lineno"
  putsn "shellspec_block${block_no}() { shellspec_example_group $1"
  putsn "}; shellspec_yield${block_no}() { :;"
  block_no_stack="$block_no_stack $block_no"
}

block_example() {
  if [ "$inside_of_example" ]; then
    syntax_error "Example/Todo cannot be defined inside of Example"
  fi

  increasese_id
  block_no=$(($block_no + 1)) example_count=$(($example_count + 1))
  putsn "(" \
    "SHELLSPEC_BLOCK_NO=$block_no" \
    "SHELLSPEC_SPECFILE=\"$specfile\"" "SHELLSPEC_ID=$id" \
    "SHELLSPEC_EXAMPLE_NO=$example_count" \
    "SHELLSPEC_LINENO_BEGIN=$lineno"
  putsn "shellspec_block${block_no}() { shellspec_example $1"
  putsn "}; shellspec_yield${block_no}() { :;"
  block_no_stack="$block_no_stack $block_no"
  inside_of_example="yes"
}

block_end() {
  if [ -z "$block_no_stack" ]; then
    syntax_error "unexpected 'End'"
  fi

  decrease_id
  putsn "}; SHELLSPEC_LINENO_END=$lineno"
  putsn "shellspec_block${block_no_stack##* }) ${1# }"
  block_no_stack="${block_no_stack% *}"
  inside_of_example=""
}

x() { "$@"; skip; }

todo() {
  block_example "$1"
  block_end ""
}

statement() {
  if [ -z "$inside_of_example" ]; then
    syntax_error "When/The/It cannot be defined outside of Example"
  fi

  putsn "SHELLSPEC_SPECFILE=\"$specfile\" SHELLSPEC_LINENO=$lineno"
  putsn "shellspec_statement $1$2"
}

control() {
  case $1 in (set|unset)
    if [ -z "$inside_of_example" ]; then
      syntax_error "Set/Unset cannot be defined outside of Example"
    fi
  esac
  case $1 in (before|after)
    if [ "$inside_of_example" ]; then
      syntax_error "Before/After cannot be defined inside of Example"
    fi
  esac
  putsn "shellspec_$1$2"
}

skip() {
  skip_id=$(($skip_id + 1))
  putsn "shellspec_skip ${skip_id}${1:-}"
}

syntax_error() {
  putsn "shellspec_exit 2 \"Syntax error: ${*:-} in $specfile line $lineno\""
}

translate() {
  initialize_id
  lineno=1
  while IFS= read -r line || [ "$line" ]; do
    work=$line
    while [ "$work" != "${work# }" ]; do work=${work# }; done

    case $work in
      Describe  | Describe\ * )   block_example_group "${work#Describe}"  ;;
      xDescribe | xDescribe\ *) x block_example_group "${work#xDescribe}" ;;
      Context   | Context\ *  )   block_example_group "${work#Context}"   ;;
      xContext  | xContext\ * ) x block_example_group "${work#xContext}"  ;;
      Example   | Example\ *  )   block_example       "${work#Example}"   ;;
      xExample  | xExample\ * ) x block_example       "${work#xExample}"  ;;
      Specify   | Specify\ *  )   block_example       "${work#Specify}"   ;;
      xSpecify  | xSpecify\ * ) x block_example       "${work#xSpecify}"  ;;
      End       | End\ *      )   block_end           "${work#End}"       ;;
      Todo      | Todo\ *     )   todo                "${work#Todo}"      ;;
      When      | When\ *     )   statement when      "${work#When}"      ;;
      The       | The\ *      )   statement the       "${work#The}"       ;;
      It        | It\ *       )   statement it        "${work#It}"        ;;
      Set       | Set\ *      )   control set         "${work#Set}"       ;;
      Unset     | Unset\ *    )   control unset       "${work#Unset}"     ;;
      Path      | Path\ *     )   control path        "${work#Path}"      ;;
      File      | File\ *     )   control path        "${work#File}"      ;;
      Dir       | Dir\ *      )   control path        "${work#Dir}"       ;;
      Before    | Before\ *   )   control before      "${work#Before}"    ;;
      After     | After\ *    )   control after       "${work#After}"     ;;
      Debug     | Debug\ *    )   control debug       "${work#Debug}"     ;;
      Pending   | Pending\ *  )   control pending     "${work#Pending}"   ;;
      Skip      | Skip\ *     )   skip                "${work#Skip}"      ;;
      *) putsn "$line" ;;
    esac
    lineno=$(($lineno + 1))
  done
}

putsn ". \"\$SHELLSPEC_LIB/bootstrap.sh\""
putsn "shellspec_metadata"
while IFS= read -r specfile; do
  [ "$specfile" ] || continue
  case $specfile in (*:*)
    echo "Filtering feature is not currently supported." >&2
    specfile=${specfile%:*}
  esac

  escape_quote specfile
  putsn "SHELLSPEC_SPECFILE='$specfile'"
  translate < "$specfile"

  if [ "$block_no_stack" ]; then
    while [ "$block_no_stack" ]; do block_end ""; done
    syntax_error "unexpected end of file (expecting 'End')"
    exit 0
  fi
done <<HERE
$(shellspec_find_files "*_spec.sh" "$@")
HERE
putsn "SHELLSPEC_SPECFILE=\"\""
putsn "shellspec_end"
putsn "# example count: $example_count"

if [ "${SHELLSPEC_TRANS_LOG:-}" ]; then
  putsn "examples $example_count" >> "$SHELLSPEC_TRANS_LOG"
fi