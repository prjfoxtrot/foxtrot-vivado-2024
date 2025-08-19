#!/usr/bin/env tclsh
# run_flow.tcl
# ---------------------------------------------------------------------------
# Description : Batch-mode synthesis → implementation → bitstream flow for
#               Vivado 2024, used by the Foxtrot plug-in.
#
# Usage       :
#   vivado -mode batch -source run_flow.tcl -tclargs \
#       project_name=<name> \
#       jobs=<n>            ;# optional, default 24
#
# Outputs     :
#   • Bitstream + artefacts in ./vivado_project
# ---------------------------------------------------------------------------

proc abort {msg} {
    puts stderr $msg
    exit 1
}
proc parse_kv_pairs {argv} {
    foreach arg $argv {
        if {[regexp {([^=]+)=(.*)} $arg -> k v]} { set ::$k $v }
    }
}

set jobs 24
parse_kv_pairs $argv
if {![info exists project_name] || $project_name eq ""} { abort "ERROR: project_name is required." }

set project_dir  [file normalize [file join [pwd] vivado_project]]
set project_file [file join $project_dir "${project_name}.xpr"]
if {![file exists $project_file]} { abort "ERROR: project file not found:\n  $project_file" }
open_project $project_file

foreach r {synth_1 impl_1} { if {[get_runs $r] ne ""} { reset_run $r } }
set_param drc.disableLUTOverUtilError 1
set_param messaging.defaultLimit      2000000

launch_runs synth_1 -jobs $jobs
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} { abort "ERROR: synthesis failed." }

open_run synth_1
set impl [get_runs impl_1]
set_property STEPS.OPT_DESIGN.ARGS.DIRECTIVE           Default              $impl
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED          false                $impl
set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE         {NoTimingRelaxation} $impl

set lock_pins_tcl [file join [pwd] lock_pins_pre_place.tcl]
set fp [open $lock_pins_tcl w]
puts $fp {# Auto-generated – lock LUT pins just before placement
set lut_cells [get_cells -hier -filter {PRIMITIVE_TYPE =~ LUT*}]
foreach cell $lut_cells {
    set ptype [get_property PRIMITIVE_TYPE $cell]
    switch -- $ptype {
        LUT6 { set lock "I0:A1 I1:A2 I2:A3 I3:A4 I4:A5 I5:A6" }
        LUT5 { set lock "I0:A1 I1:A2 I2:A3 I3:A4 I4:A5" }
        LUT4 { set lock "I0:A1 I1:A2 I2:A3 I3:A4" }
        default { continue }
    }
    set_property LOCK_PINS $lock $cell
}}
close $fp
set_property STEPS.PLACE_DESIGN.TCL.PRE $lock_pins_tcl $impl

launch_runs impl_1 -to_step write_bitstream -jobs $jobs
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} { abort "ERROR: implementation failed." }

close_project
puts "run_flow.tcl finished OK"
