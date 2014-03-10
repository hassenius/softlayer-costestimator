#!/usr/bin/ruby
require 'DataTypes/compute.rb'

#puts "test1"
#test1 = Compute.new(:ram => 31, :cpu_cores => 10, :priority => ["ram", "cpu", "disk"], :bias => "nearest")
#puts "test2"
#test2 = Compute.new(:ram => 31, :cpu_cores => 40, :priority => ["cpu", "ram", "disk"], :bias => "higher")
puts "test3"

test3 = Compute.new(:ram => 56, :cpu_cores => 8, :min_disks => 1, :priority => ["ram", "cpu"], :bias => "nearest")
test3.print_result
#test3.dump_compute_catalog


#test2 = Compute.new()
#
#test.test
#   
