# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class GrayWater < OpenStudio::Ruleset::WorkspaceUserScript

  # human readable name
  def name
    return "GrayWater"
  end

  # human readable description
  def description
    return "The measure adds gray water storage and let the user select source and sink water use connection for that storage."
  end

  # human readable description of modeling approach
  def modeler_description
    return "Gray water tank overflow will be dirrected to drainage. "
  end

   
   def getScheduleLimitType(workspace,schedule)
    sch_type_limits_name = schedule.getString(1).to_s
    if sch_type_limits_name == ""
      return ""
    else
      sch_type_limits = workspace.getObjectsByTypeAndName("ScheduleTypeLimits".to_IddObjectType,sch_type_limits_name)
      sch_type = sch_type_limits[0].getString(4).to_s
      if sch_type != ""
        return sch_type
      else
        return ""
      end
    end
  end


   # check to see if we have an exact match for this object already
  def check_for_object(runner, workspace, idf_object, idd_object_type)
    workspace.getObjectsByType(idd_object_type).each do |object|
      # all of these objects fields are data fields
      if idf_object.dataFieldsEqual(object)
        return true
      end
    end
    return false
  end
  
	# examines object and determines whether or not to add it to the workspace
  def add_object(runner, workspace, idf_object)

    num_added = 0
    idd_object = idf_object.iddObject
   
    allowed_objects = []
    allowed_objects << "Output:Surfaces:List"
    allowed_objects << "Output:Surfaces:Drawing"
    allowed_objects << "Output:Schedules"
    allowed_objects << "Output:Constructions"
    allowed_objects << "Output:Table:TimeBins"
    allowed_objects << "Output:Table:Monthly"
    allowed_objects << "Output:Variable"
    allowed_objects << "Output:Meter"
    allowed_objects << "Output:Meter:MeterFileOnly"
    allowed_objects << "Output:Meter:Cumulative"
    allowed_objects << "Output:Meter:Cumulative:MeterFileOnly"
    allowed_objects << "Meter:Custom"
    allowed_objects << "Meter:CustomDecrement"
    
    if allowed_objects.include?(idd_object.name)
      if !check_for_object(runner, workspace, idf_object, idd_object.type)
        runner.registerInfo("Adding idf object #{idf_object.to_s.strip}")
        workspace.addObject(idf_object)
        num_added += 1
      else
        runner.registerInfo("Workspace already includes #{idf_object.to_s.strip}")
      end
    end
    
    allowed_unique_objects = []
    #allowed_unique_objects << "Output:EnergyManagementSystem" # TODO: have to merge
    #allowed_unique_objects << "OutputControl:SurfaceColorScheme" # TODO: have to merge
    allowed_unique_objects << "Output:Table:SummaryReports" # TODO: have to merge
    # OutputControl:Table:Style # not allowed
    # OutputControl:ReportingTolerances # not allowed
    # Output:SQLite # not allowed
   
    if allowed_unique_objects.include?(idf_object.iddObject.name)
      if idf_object.iddObject.name == "Output:Table:SummaryReports"
        summary_reports = workspace.getObjectsByType(idf_object.iddObject.type)
        if summary_reports.empty?
          runner.registerInfo("Adding idf object #{idf_object.to_s.strip}")
          workspace.addObject(idf_object)
          num_added += 1
        elsif merge_output_table_summary_reports(summary_reports[0], idf_object)
          runner.registerInfo("Merged idf object #{idf_object.to_s.strip}")     
        else
          runner.registerInfo("Workspace already includes #{idf_object.to_s.strip}")
        end
      end
    end
    
    return num_added
  end
  

  # define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new
		
	
	# make choice argument Water Use Connections
	water_connections_choices = OpenStudio::StringVector.new
	water_connections_objs = workspace.getObjectsByType("WaterUse:Connections".to_IddObjectType)
	water_connections_objs.each do |water_connections_obj|
		water_connections_choices << water_connections_obj.getString(0).to_s
	end
	
	# argument for Sink Water Use Connections 
    sink_water_use_connections = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("sink_water_use_connections", water_connections_choices, true)
    sink_water_use_connections.setDisplayName("Water Use Connections to to be supplied with graywater:")
    args << sink_water_use_connections
	
	# argument for Source Water Use Connections 
    source_water_use_connections = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("source_water_use_connections", water_connections_choices, true)
    source_water_use_connections.setDisplayName("Water Use Connections to be used for gray water reclamation:")
    args << source_water_use_connections
	
	# argument for Drain Water Heat Exchanger Type
	choices = OpenStudio::StringVector.new
    choices << "None"
    choices << "Ideal"
	choices << "CounterFlow"
	choices << "CrossFlow"
	graywater_heat_exchange_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('graywater_heat_exchange_type', choices, false)
	graywater_heat_exchange_type.setDisplayName("Drain Water Heat Exchanger Type:")
	graywater_heat_exchange_type.setDefaultValue("CounterFlow")
	args << graywater_heat_exchange_type
	
	# argument for Drain Water Heat Exchanger Destination
	choices = OpenStudio::StringVector.new
    choices << "Plant"
    choices << "Equipment"
	choices << "PlantAndEquipment"
	graywater_heat_exchange_dest = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('graywater_heat_exchange_dest', choices, false)
	graywater_heat_exchange_dest.setDisplayName("Drain Water Heat Exchanger Destination:")
	graywater_heat_exchange_dest.setDefaultValue("PlantAndEquipment")
	args << graywater_heat_exchange_dest
	
	# argument for Drain Water Heat Exchanger U-Factor Times Area
	graywater_ua = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('graywater_ua', false)
	graywater_ua.setDisplayName("Drain Water Heat Exchanger U-Factor Times Area [W/K]:")
	args << graywater_ua
	
	# argument for GrayWaterer collecting tank name
	graywater_tank_name = OpenStudio::Ruleset::OSArgument::makeStringArgument('graywater_tank_name', false)
	graywater_tank_name.setDisplayName("Graywater tank name:")
	graywater_tank_name.setDefaultValue('Graywater Tank')
	args << graywater_tank_name
		
	# argument for graywater tank Maximum Capacity
	graywater_tank_capacity = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('graywater_tank_capacity', false)
	graywater_tank_capacity.setDisplayName("graywater tank Maximum Capacity [m3]:")
	graywater_tank_capacity.setDefaultValue(0.25)
	args << graywater_tank_capacity
	
	# argument for graywater tank Initial Volume
	graywater_tank_init_vol = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('graywater_tank_init_vol', false)
	graywater_tank_init_vol.setDisplayName("graywater tank Initial Volume [m3]:")
	graywater_tank_init_vol.setDefaultValue(0.2)
	args << graywater_tank_init_vol
	
	# argument for graywater tank Design In Flow Rate
	graywater_tank_in_flowrate = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('graywater_tank_in_flowrate', false)
	graywater_tank_in_flowrate.setDisplayName("graywater tank Design In Flow Rate [m3/s]:")
	graywater_tank_in_flowrate.setDefaultValue(0.2)
	args << graywater_tank_in_flowrate
	
	# argument for graywater tank Design out Flow Rate
	graywater_tank_out_flowrate = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('graywater_tank_out_flowrate', false)
	graywater_tank_out_flowrate.setDisplayName("graywater tank Design out Flow Rate [m3/s]:")
	graywater_tank_out_flowrate.setDefaultValue(0.01)
	args << graywater_tank_out_flowrate
	
	# argument for graywater tank Type of Supply Controlled by Float Valve
	choices = OpenStudio::StringVector.new
    choices << "None"
    choices << "Mains"
	graywater_tank_supply_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('graywater_tank_supply_type', choices, false)
	graywater_tank_supply_type.setDisplayName("graywater tank Type of Supply:")
	graywater_tank_supply_type.setDefaultValue("Mains")
	args << graywater_tank_supply_type
	
	# argument for Float Valve On Capacity
	float_valve_on_cap = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('float_valve_on_cap', false)
	float_valve_on_cap.setDisplayName("Float Valve On Capacity [m3]:")
	float_valve_on_cap.setDefaultValue(0.02)
	args << float_valve_on_cap
	
	# argument for Float Valve Off Capacity
	float_valve_off_cap = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('float_valve_off_cap', false)
	float_valve_off_cap.setDisplayName("Float Valve Off Capacity [m3]:")
	float_valve_off_cap.setDefaultValue(0.135)
	args << float_valve_off_cap
	
	# argument for Backup Mains Capacity
	float_backup_mains_cap = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('float_backup_mains_cap', false)
	float_backup_mains_cap.setDisplayName("Backup Mains Capacity [m3]:")
	float_backup_mains_cap.setDefaultValue(0.04)
	args << float_backup_mains_cap
	
	# make choice argument Tank Temperature schedule
	sch_choices = OpenStudio::StringVector.new
	sch_compacts = workspace.getObjectsByType("Schedule:Compact".to_IddObjectType)
	sch_constants = workspace.getObjectsByType("Schedule:Constant".to_IddObjectType)
	sch_years = workspace.getObjectsByType("Schedule:Year".to_IddObjectType)
	sch_files = workspace.getObjectsByType("Schedule:File".to_IddObjectType)
	sch_compacts.each do |sch|
	  if getScheduleLimitType(workspace,sch) == "temperature"
		sch_choices << sch.getString(0).to_s
	  end
	end
	sch_constants.each do |sch|
	  if getScheduleLimitType(workspace,sch) == "temperature"
		sch_choices << sch.getString(0).to_s
	  end
	end    
	sch_years.each do |sch|
	  if getScheduleLimitType(workspace,sch) == "temperature"
		sch_choices << sch.getString(0).to_s
	  end
	end
	sch_files.each do |sch|
	  if getScheduleLimitType(workspace,sch) == "temperature"
		sch_choices << sch.getString(0).to_s
	  end
	end
	
	# argument for Tank Temperature schedule
    tank_temp_schedule = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("tank_temp_schedule", sch_choices, true)
    tank_temp_schedule.setDisplayName("Tank Temperature schedule:")
    args << tank_temp_schedule
	
	
	#addargument for inserting graywater tank output meters
    add_meters = OpenStudio::Ruleset::OSArgument.makeBoolArgument("add_meters",true)
    add_meters.setDisplayName("Add Meter:Custom and Output:Meter objects for the graywater tank?")
    add_meters.setDefaultValue(true)
    args << add_meters
	
    return args
  end 

  # define what happens when the measure is run
  def run(workspace, runner, user_arguments)
    super(workspace, runner, user_arguments)

    # use the built-in error checking 
    if !runner.validateUserArguments(arguments(workspace), user_arguments)
      return false
    end

	
	
    # assign the user inputs to variables
	sink_water_use_connections = runner.getStringArgumentValue("sink_water_use_connections", user_arguments)
	source_water_use_connections = runner.getStringArgumentValue("source_water_use_connections", user_arguments)
	graywater_heat_exchange_type = runner.getStringArgumentValue("graywater_heat_exchange_type", user_arguments)
	graywater_heat_exchange_dest = runner.getStringArgumentValue("graywater_heat_exchange_dest", user_arguments)
	graywater_ua = runner.getDoubleArgumentValue("graywater_ua", user_arguments)
	graywater_tank_name = runner.getStringArgumentValue("graywater_tank_name", user_arguments)
	graywater_tank_capacity = runner.getDoubleArgumentValue("graywater_tank_capacity", user_arguments)
	graywater_tank_init_vol = runner.getDoubleArgumentValue("graywater_tank_init_vol", user_arguments)
	graywater_tank_in_flowrate = runner.getDoubleArgumentValue("graywater_tank_in_flowrate", user_arguments)
	graywater_tank_out_flowrate = runner.getDoubleArgumentValue("graywater_tank_out_flowrate", user_arguments)
	graywater_tank_supply_type = runner.getStringArgumentValue("graywater_tank_supply_type", user_arguments)
	float_valve_on_cap = runner.getDoubleArgumentValue("float_valve_on_cap", user_arguments)
	float_valve_off_cap = runner.getDoubleArgumentValue("float_valve_off_cap", user_arguments)
	float_backup_mains_cap = runner.getDoubleArgumentValue("float_backup_mains_cap", user_arguments)
	tank_temp_schedule = runner.getStringArgumentValue("tank_temp_schedule", user_arguments)
	add_meters = runner.getBoolArgumentValue("add_meters",user_arguments)
	
    # check the user_name for reasonableness
    if graywater_tank_name.empty?
      runner.registerError("Empty graywater tank name was entered.")
      return false
    end
		
	# check for WaterUse:Storage objrcts in the starting model
    wateruse_storage_objects = workspace.getObjectsByType("WaterUse:Storage".to_IddObjectType)

    # reporting initial condition of model
    runner.registerInitialCondition("The building started with #{wateruse_storage_objects.size} water storage objects ")

	
	# add a new  WaterUse:Storage object to the model
	new_water_storage_string = "    
	WaterUse:Storage,
      #{graywater_tank_name.to_s},             !- Name
      graywater,                               !- Water Quality Subcategory
      #{graywater_tank_capacity.to_s},         !- Maximum Capacity {m3}
      #{graywater_tank_init_vol.to_s},         !- Initial Volume {m3}
      #{graywater_tank_in_flowrate.to_s},      !- Design In Flow Rate {m3}
      #{graywater_tank_out_flowrate.to_s},     !- Design Out Flow Rate {m3}
      ,                                        !- Overflow Destination
      #{graywater_tank_supply_type.to_s},      !- Type of Supply Controlled by Float Valve
      #{float_valve_on_cap.to_s},              !- Float Valve On Capacity {m3}
      #{float_valve_off_cap.to_s},             !- Float Valve Off Capacity {m3}
      #{float_backup_mains_cap},               !- Backup Mains Capacity {m3}
      ,                                        !- Other Tank Name
      ScheduledTemperature,                    !- Water Thermal Mode
      #{tank_temp_schedule.to_s},              !- Water Temperature Schedule Name
      ,                                        !- Ambient Temperature Indicator
      ,                                        !- Ambient Temperature Schedule Name
      ,                                        !- Zone Name
      ,                                        !- Tank Surface Area {m2}
      ,                                        !- Tank U Value {W/m2-K}
      ;                                        !- Tank Outside Surface Material Name
	  "
	idfObject = OpenStudio::IdfObject::load(new_water_storage_string)
	object = idfObject.get
	wsObject = workspace.addObject(object)
	new_water_storage = wsObject.get

	# echo the that new WaterUse:Storage object was added to the model
	runner.registerInfo("A WaterUse:Storage object named #{new_water_storage.getString(0).to_s} was added to the model")
	
    
	# find the selected Source Water Use Connections
	water_connections_objs = workspace.getObjectsByType("WaterUse:Connections".to_IddObjectType)
	sel_source_water_connection = water_connections_objs[0]
	water_connections_objs.each do |water_connections_obj|
		if water_connections_obj.getString(0).to_s == source_water_use_connections.to_s
			sel_source_water_connection = water_connections_obj
		end
	end
	
	# connect the new wateruse:storage to the selected source wateruse:connection
	sel_source_water_connection.setString(4,graywater_tank_name.to_s)
	sel_source_water_connection.setString(7,graywater_heat_exchange_type.to_s)
	sel_source_water_connection.setString(8,graywater_heat_exchange_dest.to_s)
	sel_source_water_connection.setString(9,graywater_ua.to_s)
	
	# echo that the new wateruse:storage was connected as source to the selected wateruse:connection
	runner.registerInfo("the new WaterUse:Storage named #{graywater_tank_name.to_s} was connected to the selected WaterUse:Connection named #{sel_source_water_connection.to_s} as source.")
	
	# find the selected Sink Water Use Connections
	water_connections_objs = workspace.getObjectsByType("WaterUse:Connections".to_IddObjectType)
	sel_sink_water_connection = water_connections_objs[0]
	water_connections_objs.each do |water_connections_obj|
		if water_connections_obj.getString(0).to_s == sink_water_use_connections.to_s
			sel_sink_water_connection = water_connections_obj
		end
	end
	
	# connect the new wateruse:storage to the selected wateruse:connection as sink
	sel_sink_water_connection.setString(3,graywater_tank_name.to_s)
	
	# echo that the new wateruse:storage was connected as sink to the selected wateruse:connection
	runner.registerInfo("the new WaterUse:Storage named #{graywater_tank_name.to_s} was connected to the selected WaterUse:Connection named #{sel_sink_water_connection.to_s} as sink.")
	

	# WaterUse:Storage variables to include
	if add_meters
	
		output_meter_definitions = ["Output:Variable,*,Water System Storage Tank Volume,hourly;",
		"Output:Variable,*,Water System Storage Tank Net Volume Flow Rate,hourly;",
		"Output:Variable,*,Water System Storage Tank Inlet Volume Flow Rate,hourly;",
		"Output:Variable,*,Water System Storage Tank Outlet Volume Flow Rate,hourly;",
		"Output:Variable,*,Water System Storage Tank Mains Water Volume,hourly;",
		"Output:Variable,*,Water System Storage Tank Mains Water Volume Flow Rate,hourly;",
		"Output:Variable,*,Water System Storage Tank Water Temperature,hourly;",
		"Output:Variable,*,Water System Storage Tank Overflow Volume Flow Rate,hourly;",
		"Output:Variable,*,Water System Storage Tank Overflow Water Volume,hourly;",
		"Output:Variable,*,Water System Storage Tank Overflow Temperature,hourly;"]

	
	
		outputs_added=0
		output_meter_definitions.each do |output_meter_definition|
			idf_object = OpenStudio::IdfObject::load(output_meter_definition)
			idf_object = idf_object.get    
			outputs_added += add_object(runner, workspace, idf_object)
		end
	
	end
	
	
	# check for WaterUse:Storage objrcts in the starting model
    wateruse_storage_objects = workspace.getObjectsByType("WaterUse:Storage".to_IddObjectType)
	
    # reporting final condition of model
    runner.registerFinalCondition("The building ended with #{wateruse_storage_objects.size} water storage objects.")

    
    return true
 
  end

end 

# register the measure to be used by the application
GrayWater.new.registerWithApplication
