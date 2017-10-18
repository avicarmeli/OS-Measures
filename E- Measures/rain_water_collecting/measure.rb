# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class RainWaterCollecting < OpenStudio::Ruleset::WorkspaceUserScript

  # human readable name
  def name
    return "RainWater Collecting"
  end

  # human readable description
  def description
    return "The measure adds rain water storage and let the user select rainwater collector surface from the model's surfaces. The measure asks for the water use equipment to be connected to the rain water storage to use its water as well as other sizing parameters. Finally the measure let the user select schedule to use as site precipitation schedule."
  end

  # human readable description of modeling approach
  def modeler_description
    return "Rainwater tank overflow will be dirrected to drainage. Site precipitation is discreibed in m^3 and examples files can found at  E+ installation subfoldr: \DataSets\PrecipitationSchedulesUSA.idf"
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
	
	
	# make choice argument precipitation schedule
	sch_choices = OpenStudio::StringVector.new
	sch_compacts = workspace.getObjectsByType("Schedule:Compact".to_IddObjectType)
	sch_constants = workspace.getObjectsByType("Schedule:Constant".to_IddObjectType)
	sch_years = workspace.getObjectsByType("Schedule:Year".to_IddObjectType)
	sch_files = workspace.getObjectsByType("Schedule:File".to_IddObjectType)
	sch_compacts.each do |sch|
	  if getScheduleLimitType(workspace,sch) == ""
		sch_choices << sch.getString(0).to_s
	  end
	end
	sch_constants.each do |sch|
	  if getScheduleLimitType(workspace,sch) == ""
		sch_choices << sch.getString(0).to_s
	  end
	end    
	sch_years.each do |sch|
	  if getScheduleLimitType(workspace,sch) == ""
		sch_choices << sch.getString(0).to_s
	  end
	end
	sch_files.each do |sch|
	  if getScheduleLimitType(workspace,sch) == ""
		sch_choices << sch.getString(0).to_s
	  end
	end
	

    
	
	
	# argument for rainwater collecting surface
	roof_surfs = OpenStudio::StringVector.new
	surfaces = workspace.getObjectsByType("BuildingSurface:Detailed".to_IddObjectType)
	surfaces.each do |surface|
		if  surface.getString(1).to_s == "Roof"
			roof_surfs << surface.getString(0).to_s
		end
	end
	
	
	 roof_surfs.each do |roof_surf|
		rainwater_surf = OpenStudio::Ruleset::OSArgument::makeBoolArgument(roof_surf,true)
		# make a bool argument for each roof surface
		rainwater_surf.setDisplayName("Add #{roof_surf} Surface to Rainwater Collecting Surfaces?")
		rainwater_surf.setDefaultValue(false)		
		args << rainwater_surf
	 end
		 
		 
	

	# argument for precipitation schedule
    precipitation_schedule = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("precipitation_schedule", sch_choices, true)
    precipitation_schedule.setDisplayName("Precipitation Schedule:")
    args << precipitation_schedule
	
	# make choice argument Water Use Connections
	water_connections_choices = OpenStudio::StringVector.new
	water_connections_objs = workspace.getObjectsByType("WaterUse:Connections".to_IddObjectType)
	water_connections_objs.each do |water_connections_obj|
		water_connections_choices << water_connections_obj.getString(0).to_s
	end
	
	# argument for Water Use Connections
    water_use_connections = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("water_use_connections", water_connections_choices, true)
    water_use_connections.setDisplayName("Water Use Connections to Rainwater tank:")
    args << water_use_connections
	
	# argument for Rainwater collecting tank name
	rainwater_tank_name = OpenStudio::Ruleset::OSArgument::makeStringArgument('rainwater_tank_name', false)
	rainwater_tank_name.setDisplayName("Rainwater collecting tank name:")
	rainwater_tank_name.setDefaultValue('Rainwater Tank')
	args << rainwater_tank_name
		
	# argument for Rainwater tank Maximum Capacity
	rainwater_tank_capacity = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('rainwater_tank_capacity', false)
	rainwater_tank_capacity.setDisplayName("Rainwater tank Maximum Capacity [m3]:")
	rainwater_tank_capacity.setDefaultValue(4)
	args << rainwater_tank_capacity
	
	# argument for Rainwater tank Initial Volume
	rainwater_tank_init_vol = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('rainwater_tank_init_vol', false)
	rainwater_tank_init_vol.setDisplayName("Rainwater tank Initial Volume [m3]:")
	rainwater_tank_init_vol.setDefaultValue(4)
	args << rainwater_tank_init_vol
	
	# argument for Rainwater tank Design In Flow Rate
	rainwater_tank_in_flowrate = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('rainwater_tank_in_flowrate', false)
	rainwater_tank_in_flowrate.setDisplayName("Rainwater tank Design In Flow Rate [m3/s]:")
	rainwater_tank_in_flowrate.setDefaultValue(0.2)
	args << rainwater_tank_in_flowrate
	
	# argument for Rainwater tank Design out Flow Rate
	rainwater_tank_out_flowrate = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('rainwater_tank_out_flowrate', false)
	rainwater_tank_out_flowrate.setDisplayName("Rainwater tank Design out Flow Rate [m3/s]:")
	rainwater_tank_out_flowrate.setDefaultValue(0.005)
	args << rainwater_tank_out_flowrate
	
	# argument for Rainwater tank Type of Supply Controlled by Float Valve
	choices = OpenStudio::StringVector.new
    choices << "None"
    choices << "Mains"
	rainwater_tank_supply_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('rainwater_tank_supply_type', choices, false)
	rainwater_tank_supply_type.setDisplayName("Rainwater tank Type of Supply:")
	rainwater_tank_supply_type.setDefaultValue("Mains")
	args << rainwater_tank_supply_type
	
	# argument for Float Valve On Capacity
	float_valve_on_cap = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('float_valve_on_cap', false)
	float_valve_on_cap.setDisplayName("Float Valve On Capacity [m3]:")
	float_valve_on_cap.setDefaultValue(0.05)
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
	
	# argument for Rainwater collector name
	rainwater_collector_name = OpenStudio::Ruleset::OSArgument::makeStringArgument('rainwater_collector_name', false)
	rainwater_collector_name.setDisplayName("Rainwater collector name:")
	rainwater_collector_name.setDefaultValue('Rainwater Collector')
	args << rainwater_collector_name
	
	# argument for Collection Loss Factor
	collection_loss_factor = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('collection_loss_factor', false)
	collection_loss_factor.setDisplayName("Collection Loss Factor:")
	collection_loss_factor.setDefaultValue(0.2)
	args << collection_loss_factor
	
	# argument for Maximum Collection Rate
	max_collection_rate = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('max_collection_rate', false)
	max_collection_rate.setDisplayName("Maximum Collection Rate [m3/s]:")
	max_collection_rate.setDefaultValue(2)
	args << max_collection_rate
	
	# argument for Design Level Total Annual Precipitation
	design_total_ann_precip = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('design_total_ann_precip', false)
	design_total_ann_precip.setDisplayName("Design Level Total Annual Precipitation [m/yr]:")
	design_total_ann_precip.setDefaultValue(0.6)
	args << design_total_ann_precip
	
	# argument for Average Total Annual Precipitation
	ave_ann_precip = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('ave_ann_precip', false)
	ave_ann_precip.setDisplayName("Average Total Annual Precipitation [m/yr]:")
	ave_ann_precip.setDefaultValue(0.6)
	args << ave_ann_precip
	
	#addargument for inserting Rainwater tank output meters
    add_meters = OpenStudio::Ruleset::OSArgument.makeBoolArgument("add_meters",true)
    add_meters.setDisplayName("Add Meter:Custom and Output:Meter objects for the Rainwater tank?")
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

	
	# get the roof surfaces names
	roof_surfs = OpenStudio::StringVector.new
	surfaces = workspace.getObjectsByType("BuildingSurface:Detailed".to_IddObjectType)
	surfaces.each do |surface|
		if  surface.getString(1).to_s == "Roof"
			roof_surfs << surface.getString(0).to_s
		end
	end
	
	rainwater_surfs = OpenStudio::StringVector.new
	roof_surfs.each do |roof_surf|
		if  runner.getBoolArgumentValue(roof_surf,user_arguments) == true
			rainwater_surfs << roof_surf
		end
	end
	
	
    # assign the user inputs to variables
	precipitation_schedule = runner.getStringArgumentValue("precipitation_schedule", user_arguments)
	water_use_connections = runner.getStringArgumentValue("water_use_connections", user_arguments)
	rainwater_tank_name = runner.getStringArgumentValue("rainwater_tank_name", user_arguments)
	rainwater_tank_capacity = runner.getDoubleArgumentValue("rainwater_tank_capacity", user_arguments)
	rainwater_tank_init_vol = runner.getDoubleArgumentValue("rainwater_tank_init_vol", user_arguments)
	rainwater_tank_in_flowrate = runner.getDoubleArgumentValue("rainwater_tank_in_flowrate", user_arguments)
	rainwater_tank_out_flowrate = runner.getDoubleArgumentValue("rainwater_tank_out_flowrate", user_arguments)
	rainwater_tank_supply_type = runner.getStringArgumentValue("rainwater_tank_supply_type", user_arguments)
	float_valve_on_cap = runner.getDoubleArgumentValue("float_valve_on_cap", user_arguments)
	float_valve_off_cap = runner.getDoubleArgumentValue("float_valve_off_cap", user_arguments)
	float_backup_mains_cap = runner.getDoubleArgumentValue("float_backup_mains_cap", user_arguments)
	tank_temp_schedule = runner.getStringArgumentValue("tank_temp_schedule", user_arguments)
	rainwater_collector_name = runner.getStringArgumentValue("rainwater_collector_name", user_arguments)
	collection_loss_factor = runner.getDoubleArgumentValue("collection_loss_factor", user_arguments)
	max_collection_rate = runner.getDoubleArgumentValue("max_collection_rate", user_arguments)
	design_total_ann_precip = runner.getDoubleArgumentValue("design_total_ann_precip", user_arguments)
	ave_ann_precip = runner.getDoubleArgumentValue("ave_ann_precip", user_arguments)
	add_meters = runner.getBoolArgumentValue("add_meters",user_arguments)
	
    # check the user_name for reasonableness
    if rainwater_tank_name.empty?
      runner.registerError("Empty rainwater tank name was entered.")
      return false
    end
	
	# check the user_name for reasonableness
    if rainwater_collector_name.empty?
      runner.registerError("Empty rainwater collector name was entered.")
      return false
    end
    
    # check for Site:Precipitation in the starting model
    site_pre = workspace.getObjectsByType("Site:Precipitation".to_IddObjectType)
	
	# check for WaterUse:Storage objrcts in the starting model
    wateruse_storage_objects = workspace.getObjectsByType("WaterUse:Storage".to_IddObjectType)
	
	# check for WaterUse:RainCollector objrcts in the starting model
    wateruse_rain_collector_objects = workspace.getObjectsByType("WaterUse:RainCollector".to_IddObjectType)

    # reporting initial condition of model
    runner.registerInitialCondition("The building started with #{site_pre.size} site precipitation objects,  #{wateruse_storage_objects.size} water storage objects and  #{wateruse_rain_collector_objects.size} rain collector objects.")

	if site_pre.size == 0
		# add a new Site:Precipitation to the model
		new_site_precipitation_string = "    
		Site:Precipitation,
		  ScheduleAndDesignLevel,             !- Precipitation Model Type
		  #{design_total_ann_precip.to_s},     !- Design Level Total Annual Precipitation {m/yr}
		  #{precipitation_schedule.to_s},      !- Schedule Name for Precipitation Rates
		  #{ave_ann_precip.to_s};              !- Average Total Annual Precipitation {m/yr}
		  "
		idfObject = OpenStudio::IdfObject::load(new_site_precipitation_string)
		object = idfObject.get
		wsObject = workspace.addObject(object)
		new_site_precipitation = wsObject.get

		# echo the that new Site:Precipitation was added to the model
		runner.registerInfo("A Site:Precipitation was added to the model")
	end
	
	# add a new  WaterUse:Storage object to the model
	new_water_storage_string = "    
	WaterUse:Storage,
      #{rainwater_tank_name.to_s},             !- Name
      Rainwater,                               !- Water Quality Subcategory
      #{rainwater_tank_capacity.to_s},         !- Maximum Capacity {m3}
      #{rainwater_tank_init_vol.to_s},         !- Initial Volume {m3}
      #{rainwater_tank_in_flowrate.to_s},      !- Design In Flow Rate {m3}
      #{rainwater_tank_out_flowrate.to_s},     !- Design Out Flow Rate {m3}
      ,                                        !- Overflow Destination
      #{rainwater_tank_supply_type.to_s},      !- Type of Supply Controlled by Float Valve
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
	
	# add a new  WaterUse:RainCollector object to the model
	new_rain_coll_string = "    
	WaterUse:RainCollector,
      #{rainwater_collector_name.to_s},        !- Name
      #{rainwater_tank_name.to_s},             !- Storage Tank Name
      CONSTANT,                                !- Loss Factor Mode
      #{collection_loss_factor.to_s},          !- Collection Loss Factor
      ,                                        !- Collection Loss Factor Schedule Name
      #{max_collection_rate.to_s},             !- Maximum Collection Rate
	  "
	  
	rainwater_surfs.each_with_index do |rainwater_surf,index|
		if index < (rainwater_surfs.size - 1)
			new_rain_coll_string << "  #{rainwater_surf},                !- Collection Surface #{(index+1).to_s} Name\n"
		else
			new_rain_coll_string << "  #{rainwater_surf};                !- Collection Surface #{(index+1).to_s} Name\n"
		end
	end
	
	
	idfObject = OpenStudio::IdfObject::load(new_rain_coll_string)
	object = idfObject.get
	wsObject = workspace.addObject(object)
	new_rain_coll = wsObject.get

	# echo that new WaterUse:RainCollector object was added to the model
	runner.registerInfo("A WaterUse:RainCollector object named #{new_rain_coll.getString(0).to_s} was added to the model")
	
    
	# find the selected Water Use Connections
	water_connections_objs = workspace.getObjectsByType("WaterUse:Connections".to_IddObjectType)
	sel_water_connection = water_connections_objs[0]
	water_connections_objs.each do |water_connections_obj|
		if water_connections_obj.getString(0).to_s == water_use_connections.to_s
			sel_water_connection = water_connections_obj
		end
	end
	
	# connect the new wateruse:storage to the selected wateruse:connection
	sel_water_connection.setString(3,rainwater_tank_name.to_s)
	
	# echo that the new wateruse:storage was connected to the selected wateruse:connection
	runner.registerInfo("The selected WaterUse:Connection named #{water_use_connections.to_s} was connected to the new WaterUse:Storage named #{rainwater_tank_name.to_s}")
	

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
		"Output:Variable,*,Water System Storage Tank Overflow Temperature,hourly;",
		"Output:Variable,*,Site Precipitation Rate,hourly;",
		"Output:Variable,*,Water System Rainwater Collector Volume Flow Rate,hourly;",
		"Output:Variable,*,Water System Rainwater Collector Volume,hourly;"]
	
	
		outputs_added=0
		output_meter_definitions.each do |output_meter_definition|
			idf_object = OpenStudio::IdfObject::load(output_meter_definition)
			idf_object = idf_object.get    
			outputs_added += add_object(runner, workspace, idf_object)
		end
	
	end
	
	
	# check for Site:Precipitation in the starting model
    site_pre = workspace.getObjectsByType("Site:Precipitation".to_IddObjectType)
	
	# check for WaterUse:Storage objrcts in the starting model
    wateruse_storage_objects = workspace.getObjectsByType("WaterUse:Storage".to_IddObjectType)
	
	# check for WaterUse:RainCollector objrcts in the starting model
    wateruse_rain_collector_objects = workspace.getObjectsByType("WaterUse:RainCollector".to_IddObjectType)

    # reporting final condition of model
    runner.registerFinalCondition("The building ended with #{site_pre.size} site precipitation objects,  #{wateruse_storage_objects.size} water storage objects and  #{wateruse_rain_collector_objects.size} rain collector objects.")

    
    return true
 
  end

end 

# register the measure to be used by the application
RainWaterCollecting.new.registerWithApplication
