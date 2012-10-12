{
module Language.Fortran.Lexer where
}

%wrapper "basic"

$letter = [a-zA-Z]
$digit = 0-9 
$alphanumeric_character = [$letter $digit _]
-- Not sure if I should use '\ ' or $white here for "blanks"
$special_character = [\ \=\+\-\*\/\\\(\)\[\]\{\}\,\.\:\;\!\"\%\&\~\<\>\?\'\`\^\|\$\#\@] -- "
$character = [$alphanumeric_character $special_character]

@name = $letter $alphanumeric_character*

@power_op  = \*\*
$mult_op   = [\*\/]
$add_op    = [\+\-]
@concat_op = \/\/
@rel_op    = \.(eq|ne|[lg][te])\.
           | \=\= | \/\= | \< | \<\= | \> | \>\=
@not_op    = \.not\.
@or_op     = \.or\.
@and_op    = \.and\.
@equiv_op  = \.n?eqv\.

-- Why does the standard define both of these?
@defined_unary_op  = \.[$letter]+\.
@defined_binary_op = \.[$letter]+\.

@label = $digit{1,5}

-- @type_param_value = $scalar_int_expr | \* | \:

$sign = [\+\-]
@kind_param = $digit+ -- | @scalar_int_constant_name
@int_literal_constant = $digit+ _ @kind_param
$bit   = 0-1
$octal = 0-7
$hex   = [0-9a-fA-F]
@binary_constant = b(\' $bit+   \' | \" $bit+   \") -- "
@octal_constant  = o(\' $octal+ \' | \" $octal+ \") -- "
@hex_constant    = z(\' $hex+   \' | \" $hex+   \") -- "

@exponent = $sign? $digit+
$exponent_letter = [ed]
@significand = $digit+ \. ($digit+)?
@real_literal_constant = @significand ($exponent_letter @exponent)? (_ @kind_param)?
                       | $digit+ $exponent_letter @exponent (_ @kind_param)?

-- In the following list, the spaces are optional:
$space_without_line = $white # \n
@block_data         = block  $space_without_line* data
@else_if            = else   $space_without_line* if
@end_associate      = end    $space_without_line* associate
@end_do             = end    $space_without_line* do
@end_file           = end    $space_without_line* file
@end_function       = end    $space_without_line* function
@end_interface      = end    $space_without_line* interface
@end_program        = end    $space_without_line* program
@end_subroutine     = end    $space_without_line* subroutine
@end_where          = end    $space_without_line* where
@in_out             = in     $space_without_line* out
@select_type        = select $space_without_line* type
@double_precision   = double $space_without_line* precision
@else_where         = else   $space_without_line* where
@end_block_data     = end    $space_without_line* block $space_without_line* data
@end_enum           = end    $space_without_line* enum
@end_forall         = end    $space_without_line* forall
@end_if             = end    $space_without_line* if
@end_module         = end    $space_without_line* module
@end_select         = end    $space_without_line* select
@end_type           = end    $space_without_line* type
@go_to              = go     $space_without_line* to
@select_case        = select $space_without_line* case

tokens :-
	$white+;
        @equiv_op         { \s -> EquivOp s }
        @block_data       { \s -> BlockData }
        @else_if          { \s -> ElseIf }
        @end_associate    { \s -> EndAssociate }
        @end_do           { \s -> EndDo }
        @end_file         { \s -> EndFile }
        @end_function     { \s -> EndFunction }
        @end_interface    { \s -> EndInterface }
        @end_program      { \s -> EndProgram }
        @end_subroutine   { \s -> EndSubroutine }
        @end_where        { \s -> EndWhere }
        @in_out           { \s -> InOut }
        @select_type      { \s -> SelectType }
        @double_precision { \s -> DoublePrecision }
        @else_where       { \s -> ElseWhere }
        @end_block_data   { \s -> EndBlockData }
        @end_enum         { \s -> EndEnum }
        @end_forall       { \s -> EndForall }
        @end_if           { \s -> EndIf }
        @end_module       { \s -> EndModule }
        @end_select       { \s -> EndSelect }
        @end_type         { \s -> EndType }
        @go_to            { \s -> GoTo }
        @select_case      { \s -> SelectCase }

{
-- Each action has type :: String -> Token

-- The Token type:
data Token
  = EquivOp String
  | BlockData
  | ElseIf
  | EndAssociate
  | EndDo
  | EndFile
  | EndFunction
  | EndInterface
  | EndProgram
  | EndSubroutine
  | EndWhere
  | InOut
  | SelectType
  | DoublePrecision
  | ElseWhere
  | EndBlockData
  | EndEnum
  | EndForall
  | EndIf
  | EndModule
  | EndSelect
  | EndType
  | GoTo
  | SelectCase
  deriving (Eq, Show)

}
