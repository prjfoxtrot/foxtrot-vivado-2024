#!/usr/bin/env tclsh
# project_setup.tcl
# ---------------------------------------------------------------------------
# Description : Bootstrap a self-contained Vivado project (.xpr).
#
# Usage       :
#   vivado -mode batch -source project_setup.tcl -tclargs \
#       project_name=<name> \
#       part=<xc7a35ticsg324-1L> \
#       top_entity=<top> \
#       files="foo.v,bar.v"
#
# Inputs      :
#   project_name – Vivado project basename (without .xpr)
#   part       – Part string accepted by *create_project -part*
#   top_entity   – Name of the top-level Verilog module/entity
#   files        – Optional comma-separated HDL file list
#
# Outputs     :
#   • ./vivado_project/<project_name>.xpr with sources added
# ---------------------------------------------------------------------------

# -- helpers -----------------------------------------------------------
proc abort {msg} {
    puts stderr $msg
    exit 1
}

proc parse_kv_pairs {argv arr_name} {
    # Populate associative array *arr_name* with key=value pairs
    upvar 1 $arr_name A
    array set A {}
    foreach arg $argv {
        if {[regexp {([^=]+)=(.*)} $arg -> k v]} {
            set A($k) $v
        }
    }
}

# -- 1 · parse -tclargs -----------------------------------------------
parse_kv_pairs $argv params

foreach mandatory {project_name part top_entity} {
    if {![info exists params($mandatory)] || $params($mandatory) eq ""} {
        abort "ERROR: Missing -tclargs $mandatory=<value>"
    }
}

set project_name $params(project_name)
set part         $params(part)
set top_entity   $params(top_entity)

set files_list {}
if {[info exists params(files)] && $params(files) ne ""} {
    set files_list [split $params(files) ","]
}

# -- 2 · create ./vivado_project shell --------------------------------
set project_dir [file normalize [file join [pwd] vivado_project]]
file mkdir $project_dir

create_project -force $project_name $project_dir -part $part
set_property TARGET_LANGUAGE    Verilog [current_project]
set_property SIMULATOR_LANGUAGE Verilog [current_project]

# -- 3 · add HDL sources + set top ------------------------------------
foreach f $files_list { add_files -norecurse $f }
set_property TOP $top_entity [current_fileset]
update_compile_order -fileset sources_1

puts "INFO: Vivado project created at $project_dir"
puts "INFO: Added [llength $files_list] HDL file(s); top = $top_entity"
