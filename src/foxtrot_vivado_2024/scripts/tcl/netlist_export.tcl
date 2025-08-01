#!/usr/bin/env tclsh
# netlist_export.tcl
# ---------------------------------------------------------------------------
# Description : Export a post-implementation, timing-annotated Verilog netlist
#               from a Vivado project.
#
# Usage       :
#   vivado -mode batch -source netlist_export.tcl -tclargs \
#       project_name=<name>
#
# Inputs      :
#   project_name – Vivado project basename (without .xpr)
#
# Outputs     :
#   • <project_name>_impl.v written to $PWD
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
if {![info exists project_name] || $project_name eq ""} {
    abort "ERROR: 'project_name' argument is required."
}

set project_dir  [file join [pwd] vivado_project]
set project_file [file join $project_dir "${project_name}.xpr"]
if {![file exists $project_file]} { abort "ERROR: Project file not found: $project_file" }
open_project $project_file

set impl_run [get_runs impl_1]
if {[get_property PROGRESS $impl_run] ne "100%"} {
    abort "ERROR: Implementation run 'impl_1' is not complete."
}

open_run impl_1
set netlist_path [file join [pwd] "${project_name}_impl.v"]
write_verilog -mode timesim -sdf_anno true -force $netlist_path
puts "Wrote post-implementation netlist: $netlist_path"
close_project
puts "netlist_export.tcl finished OK"
