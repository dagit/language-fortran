{
module Language.Fortran.Parser where
}

%name parse
%tokentype { Token }
%error     { parseError }

%token
  access_stmt { AccessStmt }
  allocatable_stmt { AllocatableStmt }
  allocate_stmt { AllocateStmt }
  arithmetic_if_stmt { ArithmeticIfStmt }
  assignment_stmt { AssignmentStmt }
  associate_construct { AssociateConstruct }
  asynchronous_stmt { AsynchronousStmt }
  backspace_stmt { BackspaceStmt }
  bind_stmt { BindStmt }
  block_data_stmt { BlockDataStmt }
  call_stmt { CallStmt }
  case_construct { CaseConstruct }
  close_stmt { CloseStmt }
  common_stmt { CommonStmt }
  computed_goto_stmt { ComputedGotoStmt }
  contains_stmt { ContainsStmt }
  continue_stmt { ContinueStmt }
  cycle_stmt { CycleStmt }
  data_stmt { DataStmt }
  deallocate_stmt { DeallocateStmt }
  derived_type_def { DerivedTypeDef }
  dimension_stmt { DimensionStmt }
  do_construct { DoConstruct }
  end_block_data_stmt { EndBlockDataStmt }
  end_function_stmt { EndFunctionStmt }
  end_module_stmt { EndModuleStmt }
  end_program_stmt { EndProgramStmt }
  end_subroutine_stmt { EndSubroutineStmt }
  endfile_stmt { EndfileStmt }
  entry_stmt { EntryStmt }
  enum_def { EnumDef }
  equivalence_stmt { EquivalenceStmt }
  exit_stmt { ExitStmt }
  external_stmt { ExternalStmt }
  flush_stmt { FlushStmt }
  forall_construct { ForallConstruct }
  forall_stmt { ForallStmt }
  format_stmt { FormatStmt }
  function_stmt { FunctionStmt }
  goto_stmt { GotoStmt }
  if_construct { IfConstruct }
  if_stmt { IfStmt }
  implicit_stmt { ImplicitStmt }
  import_stmt { ImportStmt }
  inquire_stmt { InquireStmt }
  intent_stmt { IntentStmt }
  interface_block { InterfaceBlock }
  intrinsic_stmt { IntrinsicStmt }
  module_stmt { ModuleStmt }
  namelist_stmt { NamelistStmt }
  nullify_stmt { NullifyStmt }
  open_stmt { OpenStmt }
  optional_stmt { OptionalStmt }
  parameter_stmt { ParameterStmt }
  pointer_assignment_stmt { PointerAssignmentStmt }
  pointer_stmt { PointerStmt }
  print_stmt { PrintStmt }
  procedure_declaration_stmt { ProcedureDeclarationStmt }
  program_stmt { ProgramStmt }
  protected_stmt { ProtectedStmt }
  read_stmt { ReadStmt }
  return_stmt { ReturnStmt }
  rewind_stmt { RewindStmt }
  save_stmt { SaveStmt }
  select_type_construct { SelectTypeConstruct }
  stmt_function_stmt { StmtFunctionStmt }
  stop_stmt { StopStmt }
  subroutine_subprogram { SubroutineSubprogram }
  target_stmt { TargetStmt }
  type_declaration_stmt { TypeDeclarationStmt }
  use_stmt { UseStmt }
  value_stmt { ValueStmt }
  volatile_stmt { VolatileStmt }
  wait_stmt { WaitStmt }
  where_construct { WhereConstruct }
  where_stmt { WhereStmt }
  write_stmt { WriteStmt }


%%

program : program_unit          { [$1]    }
        | program program_unit  { $2 : $1 }

program_unit : main_program        {}
             | external_subprogram {}
             | module              {}
             | block_data          {}

main_program : opt_program_stmt
                 opt_specification_part
                 opt_execution_part
                 opt_internal_subprogram_part
                 end_program_stmt             {}

opt_program_stmt : {- empty -}                {}
                 | program_stmt               {}

opt_specification_part : {- empty -}          {}
                       | specification_part   {}

opt_execution_part : {- empty -}              {}
                   | execution_part           {}

opt_internal_subprogram_part : {- empty -}              {}
                             | internal_subprogram_part {}

external_subprogram : function_subprogram               {}
                    | subroutine_subprogram             {}

function_subprogram : function_stmt
                        opt_specification_part
                        opt_execution_part
                        opt_internal_subprogram_part
                        end_subroutine_stmt          {}

module : module_stmt
           opt_specification_part
           opt_module_subprogram_part
           end_module_stmt            {}

opt_module_subprogram_part : {- empty -}            {}
                           | module_subprogram_part { $1 }

block_data : block_data_stmt
               opt_specification_part
               end_block_data_stmt    {}

specification_part : opt_use_stmts
                       opt_import_stmts
                       opt_implicit_parts
                       opt_declaration_constructs {}

opt_use_stmts : {- empty -}            { [] }
              | opt_use_stmts use_stmt { $2 : $1 }

opt_import_stmts : {- empty -}                  { [] }
                 | opt_import_stmts import_stmt { $2 : $1 }

opt_implicit_parts : {- empty -}                      { [] }
                   | opt_implicit_parts implicit_part { $2 : $1 }

opt_declaration_constructs : {- empty -}                                      { [] }
                           | opt_declaration_constructs declaration_construct { $2 : $1 }

implicit_part : opt_implicit_part_stmts implicit_stmt {}

opt_implicit_part_stmts : {- empty -}                                { [] }
                        | opt_implicit_part_stmts implicit_part_stmt { $2 : $1 }

implicit_part_stmt : implicit_stmt  {}
                   | parameter_stmt {}
                   | format_stmt    {}
                   | entry_stmt     {}

declaration_construct : derived_type_def           {}
                      | entry_stmt                 {}
                      | enum_def                   {}
                      | format_stmt                {}
                      | interface_block            {}
                      | parameter_stmt             {}
                      | procedure_declaration_stmt {}
                      | specification_stmt         {}
                      | type_declaration_stmt      {}
                      | stmt_function_stmt         {}

execution_part : executable_construct
                   opt_execution_part_constructs   {}

opt_execution_part_constructs : {- empty -}                                            { [] }
                              | opt_execution_part_constructs execution_part_construct { $2 : $1 }

execution_part_construct : executable_construct {}
                         | format_stmt          {}
                         | entry_stmt           {}
                         | data_stmt            {}

internal_subprogram_part : contains_stmt
                             internal_subprogram
                             opt_internal_subprograms {}

opt_internal_subprograms : {- empty -}                                  { [] }
                         | opt_internal_subprograms internal_subprogram { $2 : $1 }

internal_subprogram : function_subprogram   {}
                    | subroutine_subprogram {}

module_subprogram_part : contains_stmt
                           module_subprogram
                           opt_module_subprograms {}

opt_module_subprograms : {- empty -}                              { [] }
                       | opt_module_subprograms module_subprogram { $2 : $1 }

module_subprogram : function_subprogram   {}
                  | subroutine_subprogram {}

specification_stmt : access_stmt       {}
                   | allocatable_stmt  {}
                   | asynchronous_stmt {}
                   | bind_stmt         {}
                   | common_stmt       {}
                   | data_stmt         {}
                   | dimension_stmt    {}
                   | equivalence_stmt  {}
                   | external_stmt     {}
                   | intent_stmt       {}
                   | intrinsic_stmt    {}
                   | namelist_stmt     {}
                   | optional_stmt     {}
                   | pointer_stmt      {}
                   | protected_stmt    {}
                   | save_stmt         {}
                   | target_stmt       {}
                   | volatile_stmt     {}
                   | value_stmt        {}

executable_construct : action_stmt           {}
                     | associate_construct   {}
                     | case_construct        {}
                     | do_construct          {}
                     | forall_construct      {}
                     | if_construct          {}
                     | select_type_construct {}
                     | where_construct       {}

action_stmt : allocate_stmt           {}
            | assignment_stmt         {}
            | backspace_stmt          {}
            | call_stmt               {}
            | close_stmt              {}
            | continue_stmt           {}
            | cycle_stmt              {}
            | deallocate_stmt         {}
            | endfile_stmt            {}
            | end_function_stmt       {}
            | end_program_stmt        {}
            | end_subroutine_stmt     {}
            | exit_stmt               {}
            | flush_stmt              {}
            | forall_stmt             {}
            | goto_stmt               {}
            | if_stmt                 {}
            | inquire_stmt            {}
            | nullify_stmt            {}
            | open_stmt               {}
            | pointer_assignment_stmt {}
            | print_stmt              {}
            | read_stmt               {}
            | return_stmt             {}
            | rewind_stmt             {}
            | stop_stmt               {}
            | wait_stmt               {}
            | where_stmt              {}
            | write_stmt              {}
            | arithmetic_if_stmt      {}
            | computed_goto_stmt      {}

{

parseError :: [Token] -> a
parseError _ = error "Oh no!"

data Token
  = AccessStmt
  | AllocatableStmt
  | AllocateStmt
  | ArithmeticIfStmt
  | AssignmentStmt
  | AssociateConstruct
  | AsynchronousStmt
  | BackspaceStmt
  | BindStmt
  | BlockDataStmt
  | CallStmt
  | CaseConstruct
  | CloseStmt
  | CommonStmt
  | ComputedGotoStmt
  | ContainsStmt
  | ContinueStmt
  | CycleStmt
  | DataStmt
  | DeallocateStmt
  | DerivedTypeDef
  | DimensionStmt
  | DoConstruct
  | EndBlockDataStmt
  | EndFunctionStmt
  | EndModuleStmt
  | EndProgramStmt
  | EndSubroutineStmt
  | EndfileStmt
  | EntryStmt
  | EnumDef
  | EquivalenceStmt
  | ExitStmt
  | ExternalStmt
  | FlushStmt
  | ForallConstruct
  | ForallStmt
  | FormatStmt
  | FunctionStmt
  | GotoStmt
  | IfConstruct
  | IfStmt
  | ImplicitStmt
  | ImportStmt
  | InquireStmt
  | IntentStmt
  | InterfaceBlock
  | IntrinsicStmt
  | ModuleStmt
  | NamelistStmt
  | NullifyStmt
  | OpenStmt
  | OptionalStmt
  | ParameterStmt
  | PointerAssignmentStmt
  | PointerStmt
  | PrintStmt
  | ProcedureDeclarationStmt
  | ProgramStmt
  | ProtectedStmt
  | ReadStmt
  | ReturnStmt
  | RewindStmt
  | SaveStmt
  | SelectTypeConstruct
  | StmtFunctionStmt
  | StopStmt
  | SubroutineSubprogram
  | TargetStmt
  | TypeDeclarationStmt
  | UseStmt
  | ValueStmt
  | VolatileStmt
  | WaitStmt
  | WhereConstruct
  | WhereStmt
  | WriteStmt
  deriving (Show)
}
