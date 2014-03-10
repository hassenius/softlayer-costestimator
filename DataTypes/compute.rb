#!/usr/bin/ruby
## Defines a standard structure for compute, regardless of type - CCI, Private CCI, Bare Metal or Dedicated
## Class is responsible for deducing information where required
require 'rubygems'
require 'softlayer_api'
require 'json'
require 'pry' # For debug only
require 'pp' # For testing and debugging only
# For testing and debugging only
$SL_API_USERNAME = "hans.moen" # parent of hans.ot.testing02
$SL_API_KEY = "ee168c98b5954aa71f7762fdff3384eb54fd4e0863855de47ead9adf045bb3ab"



class Compute
	@@compute_catalog = nil
	@@ram_index = Hash.new { |hash, capacity| hash[capacity] = [] }
	@@cpu_core_index = Hash.new { |hash, cores| hash[cores] = [] }
	@@disk_index = Hash.new { |hash, disk_capacity| hash[disk_capacity] = [] }
	@@package_index = Hash.new
	@possible_packages   = Array.new 
	@priority_order      = Array.new
	@compute_type        = nil # => Virtual, baremetal or dedicated
  @desired_cpu_cores   = 0
	@cpu_cores           = 0
  @desired_cpu_type    = nil
	@cpu_type            = nil
	@desired_ram         = 0
	@ram                 = 0
	@desired_disks       = 0
	@disks               = 0
	@desired_disk_size   = 0
	@disk_size           = 0
	@desired_disk_type   = nil
	@disk_type           = nil
	
	def initialize(args = {})
    @desired_cpu_cores  = args[:cpu_cores]          
    @desired_cpu_type   = args[:cpu_type]   # => Can be virtual, physical or a GHz value
    @desired_ram        = args[:ram].to_i
    @desired_disks      = args[:min_disks]  # => Number of spindels desired. Typically only relevant for dedicated machines
    @desired_disk_type  = args[:disk_type]  # => Typically most relevant for dedicated machines -- SSD, SAS, or SATA
    @priority_order     = args[:priority]   # => Array of order of priority for resources from most to least important. i.e. [cpu,memory,disk]
    @bias               = args[:bias]       # => higher/lower/nearest. When looking for resource match, whether to go matching or higher, matching or lower or closest match  
    
    # Build the compute catalog if it has not been done already
    build_compute_catalog() if @@compute_catalog == nil
    
    # Cycle through and find closest match for each resource item in order of priority
    @priority_order.each { |resource|
      
      case resource
        when "cpu"
          # find_cpu_match()
          @cpu_cores = find_package_match(@@cpu_core_index, @desired_cpu_cores, @bias)
          puts "cpu cores: #{@cpu_cores}"    
          
        when "ram"
          # Find closest ram

          @ram = find_package_match(@@ram_index, @desired_ram, @bias)
          puts "ram: #{@ram}"
   
        when "disk"
          # Find closest disk
          ## This is more complicated as we have more variables: amount of spindles, total size and type
          ## For now just do amount of spindles

          @disks = find_package_match(@@disk_index, @desired_disks, "higher") # makes no sense to bias lower with disks
          
        else 
          puts "You didn't tell me a priority"
          
      end 
      
    } 
	  
	  # Whe should now (at least have the option to) return a valid cart, with whatever assumptions we'd need to make
	  
	   # :compute_type, :cpu_count, :ram, :disk_size, :title:
	   
	
	end
	

  def find_candidate(candidates, desired_number, bias)
    # Get the closest matching cpu/ram/disk configuration from a list of candidates
    ## Example from CPU, migth be that there are 2,4,6,8,12,16,24,32,40 core configurations available (candidates)
    ## Select the best option for the desired number (i.e. 7) based on a set bias (higher, lower or nearest)
    ## Previous selections (RAM or Disk) will limit the amount of available options available

    case bias 
        
      when "higher" 
        # binding.pry
        return candidates.select{|item| item.to_i > desired_number.to_i}.min
      when "lower"
        return candidates.select{|item| item.to_i < desired_number.to_i}.max
      when "nearest"   
        return candidates.min{|a,b|  (desired_number-a).abs <=> (desired_number-b).abs }
      else 
        puts "Error: Not sure what #{bias} means"
    end
  end
  
	  ## TODO: Capture the cpu type necessary to purchase with this package to achieve the desired effect
	
  def find_package_match(index, desired, bias)



    # Create a new sorted array with the list of all the CPU/RAM/disk options
    options = index.keys.map(&:to_i).sort
    
    # Start out by finding a candidate match for the requested amount
    if index.key?(desired.to_s) 
      # Exact match available
      candidate = desired
    else
      # find closest match available
      candidate = find_candidate(options, desired, bias) 
    end

    
    # Compile a list of possible packages
    if @possible_packages == nil
      # This was the first resource type to be checked, all of our packages are potential final matches at this stage
      @possible_packages = index[candidate.to_s]
    else
      # Check if there are any of the package options in the existing @possible_packages also exists in the options we found in this run
      ## If not select a different option and try again
      until ((@possible_packages & index[candidate.to_s]).length != 0) 
        # Previous candidates have not been a match, delete current candidate from options list
        options.delete(candidate)
        # find new candidate
        candidate = find_candidate(options, desired, bias)
        ## TODO: We need to add a check and action to take if we exaust all options without finding a valid match
      end
      
      # Update the list of possible packages
      @possible_packages = index[candidate.to_s] & @possible_packages
      
    end
    ## TODO: Capture the cpu type necessary to purchase with this package to achieve the desired effect
    
    # Return the selected candidate so the caller knows what option we landed on
    return candidate
    
  end

  def get_product_container
    # Structure of a product container
    
    # packageId
    # hardware For orders that contain servers (dedicated, bare metal, CCI, big data, etc.), the hardware property is required
    # => http://sldn.softlayer.com/reference/datatypes/SoftLayer_Hardware
    # => Note that CCI (SoftLayer_Container_Product_Order_Virtual_Guest) orders may populate this field instead of the virtualGuests property
    
    # prices["id" => 1234,
    #        "id" => 4356]
    # optional? privateCloudContainerFlag: boolean
    # optional? privateCloudOrderFlag: boolean
    # quantity
    # quoteName
    
  end
  	
	def getAvailableOperatingSystems()
	  # Return a list of available operating systems
	  ## The list gets more restricted the more parameters are defined
	  
	end
	
	def build_compute_catalog()
	  # ram_index = Hash.new { |hash, capacity| hash[capacity] = [] }
	  
	  # First create an Object Mask that selects the RAM, CPU and storage options from each package type (including non server types which we will filter out later) 
	  #mask = "mask[id,name,description,availableStorageUnits,activeServerItems,activeRamItems,activeSoftwareItems]"
	  #  SoftLayer_Product_Item::capacityRestrictionType # The type of capacity restriction by which this item must abide.

	  mask = "mask[id,name,description,availableStorageUnits,activeServerItems,activeRamItems,type,activeSoftwareItems[thirdPartySupportVendor,softwareDescription[attributes,features]]]"
	  
	  # Pull down the full list
	  sl_packages = SoftLayer::Service.new("SoftLayer_Product_Package")
	  
	  @@compute_catalog = sl_packages.object_mask(mask).getAllObjects  # It seems the above returns an array. If this should fail at any stage add .to_json and then parse packages with JSON.parse(packages)
	  
	  # Drop packages that are not directly compute packages (assume they are of no interest if they have no RAM opetions) 
	  @@compute_catalog.delete_if { |l| l["activeRamItems"].length == 0 }
	  	  
  	  	  
      # Create neccessary indexes (Hashes) for lookups
  	  @@compute_catalog.each_index { |index|
  	     
       # Create a Package index with packageID as key
       @@package_index[@@compute_catalog[index]["id"]] = index
       
       # Create a CPU Index with coreCount as Key and packageID as array of values
       @@compute_catalog[index]["activeServerItems"].each { |coreItem|
         # Get some stats
         #puts "coreitem[corecount] is a \n" 
         #puts (coreItem["totalPhysicalCoreCount"].to_i).class
         
         # puts "totalPhysicalCoreCount is #{coreItem["totalPhysicalCoreCount"]}"
         @@cpu_core_index[coreItem["totalPhysicalCoreCount"].to_s] << @@compute_catalog[index]["id"]  
       }
       
       # Create a RAM index with memory size as key and packageID as array of values
  	   @@compute_catalog[index]["activeRamItems"].each { |ramItem|
  	     @@ram_index[ramItem["capacity"].to_s] << @@compute_catalog[index]["id"]
  	   }
  	   
  	   # Create a disk index with available disk slots as key and packageId as array of values
  	   @@disk_index[@@compute_catalog[index]["availableStorageUnits"].to_s] << @@compute_catalog[index]["id"] 
  	  
  	  
	    # We also need to get the CCIs CPU options and possibly memory options included in some way
	    
	    # We also need the operating systems mapped
	  
	  }
   	  
	end
	
	def dump_compute_catalog()
	  pp @@compute_catalog
	  
	end

  def print_result

    # Print the packages that match our requirements
    puts "Desired versus selected specs"
    puts "CPU:            desired - #{@desired_cpu_cores}   == selected - #{@cpu_cores}"
    puts "RAM:            desired - #{@desired_ram}   == selected - #{@ram}"
    puts "Disk spindles:  desired - #{@desired_disks}   == selected - #{@disks}"
    puts "=========== Possible packages meeting these requirements =================="
    @possible_packages.each { |package| 
      puts "==========================================================================="
      puts "ID: #{package}"
      puts "Name: #{@@compute_catalog[@@package_index[package]]["name"]}"
      puts "CPU options"
      @@compute_catalog[@@package_index[package]]["activeServerItems"].each { |cpu|
        puts "Name: #{cpu["description"]}"
        puts "ID: #{cpu["id"]} == Cores: #{cpu["totalPhysicalCoreCount"]}"
        puts "--------------------------------------------"  
      }
      puts "\nRam options:"
      @@compute_catalog[@@package_index[package]]["activeRamItems"].each { |ram|
        puts "ID: #{ram["id"]} Name: #{ram["description"]}"
      }
      puts "==========================================================================="
    }
  end
      
  def print_required_categories_per_possible_package
    
    #mask = "mask[id,name,description,availableStorageUnits,activeServerItems,activeRamItems]"
    
    # Pull down the full list
    sl_packages = SoftLayer::Service.new("SoftLayer_Product_Package")
    
     
    puts "Required categories for each package: "
    @possible_packages.each { |package|
      sl_packages.getConfiguration("")    
      
    }
  end
 
end

=begin
 TODO
  - Check when have exausted all options in ram, cpu or disk using higher or lower to restart using nearest
  - Investigate the use of SoftLayer_Product_Package_Server_Option, SoftLayer_Product_Package_Server and SoftLayer_Product_Package_Type
=end 
