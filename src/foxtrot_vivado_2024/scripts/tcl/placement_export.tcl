#!/usr/bin/env tclsh
# placement_export.tcl
# ---------------------------------------------------------------------------
# Description : Export BEL, LOC, NET, VALUE CSV for Foxtrot analysis.
#
# Usage       :
#   vivado -mode batch -source placement_export.tcl -tclargs \
#       project_name=<name> \
#       output_file=<abs-path>
#
# Inputs      :
#   project_name – Vivado project basename (without .xpr)
#   output_file  – Absolute path to output CSV file
#
# Outputs     :
#   • CSV with header "BEL,LOC,NET,VALUE"
# ---------------------------------------------------------------------------

proc abort {msg} {
    puts stderr $msg
    exit 1
}
proc parse_kv_pairs {argv} {
    foreach arg $argv {
        if {[regexp {([^=]+)=(.*)} $arg -> k v]} {
            set ::$k $v
        }
    }
}

parse_kv_pairs $argv
foreach v {project_name output_file} {
    if {![info exists ::$v]} { abort "ERROR: missing required argument: $v" }
}

set project_file [file join [file dirname $output_file] \
                          vivado_project "${project_name}.xpr"]
if {![file exists $project_file]} { abort "ERROR: Project file not found: $project_file" }
open_project $project_file

if {[catch {get_runs impl_1}]}                  { abort "ERROR: Run 'impl_1' not found" }
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
    abort "ERROR: Implementation run 'impl_1' not complete"
}
open_run impl_1

set fh [open $output_file w]
puts $fh "BEL,LOC,NET,VALUE"
foreach cell [get_cells -hierarchical] {
    set loc [get_property LOC $cell]
    if {$loc eq ""} { continue }

    set bel_name [get_property BEL $cell]
    if {$bel_name eq ""} { set bel_name [get_property PRIMITIVE_SUBGROUP $cell] }
    if {$bel_name eq ""} { set bel_name [get_property PRIMITIVE_TYPE    $cell] }

    set site_type ""
    set sites [get_sites -of_objects $cell]
    if {[llength $sites]} { set site_type [get_property SITE_TYPE [lindex $sites 0]] }

    set bel [string trim "${bel_name}" {.}]
    set net   [get_property NAME $cell]
    set value [get_property INIT $cell]

    puts $fh "$bel,$loc,$net,$value"
}
close $fh
close_project
puts "placement_export.tcl wrote $output_file"
