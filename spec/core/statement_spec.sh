#shellcheck shell=sh

Describe "core/statement.sh"
  Describe "shellspec_statement_advance_subject()"
    it() {
      shellspec_statement_preposition() { echo "the $*"; }
      shellspec_output() { echo "$1"; }
      shellspec_statement_advance_subject "$@"
    }

    Example "reorder include 'the'"
      When invoke it should equal A the stdout
      The stdout should equal "the stdout should equal A"
    End

    Example "reorder include multiple 'the'"
      When invoke it should equal A the line 2 of the stdout
      The stdout should equal "the line 2 of the stdout should equal A"
    End

    Example "If missing 'the', raise error"
      When invoke it should equal A
      The stdout should equal "SYNTAX_ERROR"
      The exit status should be failure
    End
  End

  Describe "shellspec_statement_preposition()"
    the() {
      shellspec_statement_ordinal() { echo "the $*"; }
      shellspec_statement_preposition "$@"
    }

    Example "It reordering parameters and call shellspec_statement_ordinal"
      When invoke the C c1 c2 of B b1 b2 of A a1 a2 should equal abc
      The stdout should equal "the A a1 a2 B b1 b2 C c1 c2 should equal abc"
    End

    Example "It does not reorder parameters after 'should'"
      When invoke the C c1 c2 of B b1 b2 of A a1 a2 should equal E of D
      The stdout should equal "the A a1 a2 B b1 b2 C c1 c2 should equal E of D"
    End
  End

  Describe "shellspec_statement_ordinal()"
    the() {
      shellspec_statement_subject() { echo "the $*"; }
      shellspec_statement_ordinal "$@"
    }

    Example "Change ordinal number to number and exchange with the next word"
      When invoke the 2nd line should equal abc
      The stdout should equal "the line 2 should equal abc"
    End

    Example "Change ordinal name to number and exchange with the next word"
      When invoke the second line should equal abc
      The stdout should equal "the line 2 should equal abc"
    End

    Example "Do not change unknown word"
      When invoke the "a/b" line should equal abc
      The stdout should equal "the a/b line should equal abc"
    End
  End

  Describe "shellspec_statement_subject()"
    statement_subject() {
      shellspec_subject() { echo "$@"; }
      shellspec_statement_subject "$@"
    }

    Example "shellspec_statement_subject dispatch to shellspec_subject"
      When invoke statement_subject a b c
      The stdout should equal "a b c"
    End
  End
End