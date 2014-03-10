#!/usr/bin/ruby -s
require 'compute.rb'

def print_help_and_exit

  puts "Usage: #$0 -r=RAM -c=CPU_CORES [-d=DISK_SPINDELS] -p=PRIORITY -b=BIAS
  Options:
   -r=RAM			: Amount of memory desired in GB
   -c=CPU CORES		: Amount of CPU Cores desired
   -d=Disk Spindels 	: Amount of disk spindels desired
   -p=Priority		: What order to prioritse resources  (cpu, ram, disk) when searching
   -b=BIAS {higher, lower, nearest}	: If exact match for given resource is not found, which way to search

  Example:
   #$0 -r=120 -c=16 -d=8 -p=ram,disk,cpu -b=higher 
   Might return a server with 128GB Memory, 24 Disk Slots and 16CPU Cores"
   exit 1
end

unless defined? $r
 puts "Please declear desired amount of RAM"
 print_help_and_exit
end

unless defined? $c
 puts "please declear desired amount of CPU Cores"
 print_help_and_exit
end

unless defined? $p
 puts "Please declear desired priority"
 print_help_and_exit
else
 priority = $p.split(",")
end

unless defined? $b
 puts "Please declear desired search bias"
 print_help_and_exit
end

# Disk is the only optional input
if defined?($d)
  item = Compute.new(:ram => $r.to_i, :cpu_cores => $c.to_i, :min_disks => $d.to_i, :priority => priority, :bias => $b)
else
  item = Compute.new(:ram => $r.to_i, :cpu_cores => $c.to_i, :priority => priority, :bias => $b)
end

item.print_result

