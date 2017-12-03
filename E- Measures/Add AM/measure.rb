# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class SolarThermalAddAvailabilityManagers < OpenStudio::Ruleset::WorkspaceUserScript

  # human readable name
  def name
    return "Solar Thermal add Availability Managers"
  end

  # human readable description
  def description
    return "Adds Availability Managers to Sollar Collector plant loop if present"
  end

  # human readable description of modeling approach
  def modeler_description
    return "Up to three Availability Managers will be added to the Solar collecttor Plant loop. An Availability Manager Assignment List will be added aswell with the 
 Availability Managers in the order entered."
  end

  # define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new

	# argument for plant loops selection
	plantLoopList = OpenStudio::StringVector.new
	plantLoops = workspace.getObjectsByType("PlantLoop".to_IddObjectType)
	plantLoops.each do |plantLoop|
		plantLoopList << plantLoop.getString(0).to_s
	end

	plantLoopsSel = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('plantLoopsSel', plantLoopList, false)
	plantLoopsSel.setDisplayName("Plant Loop To add Availability Managers to?")
	#plantLoopsSel.setDefaultValue(false)		
	args << plantLoopsSel
	
	# argument for First Availability Manager type 
	choices = OpenStudio::StringVector.new
    choices << "HighTemperatureTurnOff"
    choices << "LowTemperatureTurnOn"
	choices << "DifferentialThermostat"
	
	availManger01 = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('availManger01', choices, false)
	availManger01.setDisplayName("First Availability Manager type:")
	args << availManger01
	
	# argument for First Availability Manager name
	availManger01name = OpenStudio::Ruleset::OSArgument::makeStringArgument('availManger01name', false)
	availManger01name.setDisplayName("First Availability Manager name:")
	availManger01name.setDefaultValue('First Availability Manager')
	args << availManger01name
	
	# argument for node selection
	nodeListNames = []
	plantLoops.each do |plantLoop|
		nodeListNames << plantLoop.getString(10).to_s
		nodeListNames << plantLoop.getString(11).to_s
	end
	waterHeatersMixed = workspace.getObjectsByType("WaterHeater:Mixed".to_IddObjectType)
	waterHeatersMixed.each do |heaters|
		nodeListNames << heaters.getString(30).to_s
		nodeListNames << heaters.getString(31).to_s
		nodeListNames << heaters.getString(33).to_s
		nodeListNames << heaters.getString(34).to_s
	end
	solarColls = workspace.getObjectsByType("SolarCollector:FlatPlate:Water".to_IddObjectType)
	solarColls.each do |solarColl|
		nodeListNames << solarColl.getString(3).to_s
		nodeListNames << solarColl.getString(4).to_s
	end
	pumps = workspace.getObjectsByType("Pump:VariableSpeed".to_IddObjectType)
	pumps.each do |pump|
		nodeListNames << pump.getString(1).to_s
		nodeListNames << pump.getString(2).to_s
	end
	nodeListNames = nodeListNames.reject { |c| c.empty? }

	
	avMng01hotNode = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('avMng01hotNode', nodeListNames, false)
	avMng01hotNode.setDisplayName("1st Manager node/Hot Node name:")
	args << avMng01hotNode
	
	# argument for First Availability Manager Temperature
	avMng01onTemp = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('avMng01onTemp', false)
	avMng01onTemp.setDisplayName("1st Manager Temperature [C]/ dT On Limit [K]:")
	avMng01onTemp.setDefaultValue(60)
	args << avMng01onTemp
	
	# argument for cold node selection
	avMng01coldNode = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('avMng01coldNode', nodeListNames, false)
	avMng01coldNode.setDisplayName("1st Manager cold node name:")
	args << avMng01coldNode
	
	# argument for First Availability Manager Temperature
	avMng01offTemp = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('avMng01offTemp', false)
	avMng01offTemp.setDisplayName("1st Manager dT Off Limit [K]:")
	avMng01offTemp.setDefaultValue(60)
	args << avMng01offTemp
	
	# argument for Second Availability Manager type 
	choices << "None"	
	availManger02 = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('availManger02', choices, false)
	availManger02.setDisplayName("Second Availability Manager type:")
	availManger02.setDefaultValue("None")
	args << availManger02
	
	# argument for First Availability Manager name
	availManger02name = OpenStudio::Ruleset::OSArgument::makeStringArgument('availManger02name', false)
	availManger02name.setDisplayName("Second Availability Manager name:")
	availManger02name.setDefaultValue('Second Availability Manager')
	args << availManger02name
	
	# argument for node selection
	avMng02hotNode = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('avMng02hotNode', nodeListNames, false)
	avMng02hotNode.setDisplayName("2nd Manager node/Hot Node name:")
	args << avMng02hotNode
	
	# argument for Second Availability Manager Temperature
	avMng02onTemp = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('avMng02onTemp', false)
	avMng02onTemp.setDisplayName("2nd Manager Temperature [C]/ dT On Limit [K]:")
	avMng02onTemp.setDefaultValue(60)
	args << avMng02onTemp
	
	# argument for cold node selection
	avMng02coldNode = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('avMng02coldNode', nodeListNames, false)
	avMng02coldNode.setDisplayName("2nd Manager cold node name:")
	args << avMng02coldNode
	
	# argument for Second Availability Manager Temperature
	avMng02offTemp = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('avMng02offTemp', false)
	avMng02offTemp.setDisplayName("2nd Manager dT Off Limit [K]:")
	avMng02offTemp.setDefaultValue(60)
	args << avMng02offTemp	
	
	# argument for Third Availability Manager type 	
	availManger03 = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('availManger03', choices, false)
	availManger03.setDisplayName("Third Availability Manager type:")
	availManger03.setDefaultValue("None")
	args << availManger03
	
	# argument for First Availability Manager name
	availManger03name = OpenStudio::Ruleset::OSArgument::makeStringArgument('availManger03name', false)
	availManger03name.setDisplayName("Third Availability Manager name:")
	availManger03name.setDefaultValue('Third Availability Manager')
	args << availManger03name
	
	# argument for node selection
	avMng03hotNode = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('avMng03hotNode', nodeListNames, false)
	avMng03hotNode.setDisplayName("3rd Manager node/Hot Node name:")
	args << avMng03hotNode
	
	# argument for Second Availability Manager Temperature
	avMng03onTemp = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('avMng03onTemp', false)
	avMng03onTemp.setDisplayName("3rd Manager Temperature [C]/ dT On Limit [K]:")
	avMng03onTemp.setDefaultValue(60)
	args << avMng03onTemp
	
	# argument for cold node selection
	avMng03coldNode = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('avMng03coldNode', nodeListNames, false)
	avMng03coldNode.setDisplayName("3rd Manager cold node name:")
	args << avMng03coldNode
	
	# argument for Second Availability Manager Temperature
	avMng03offTemp = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('avMng03offTemp', false)
	avMng03offTemp.setDisplayName("3rd Manager dT Off Limit [K]:")
	avMng03offTemp.setDefaultValue(60)
	args << avMng03offTemp
	

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
    plantLoopsSel = runner.getStringArgumentValue("plantLoopsSel", user_arguments)
	
	availManger01 = runner.getStringArgumentValue("availManger01", user_arguments)
	availManger01name = runner.getStringArgumentValue("availManger01name", user_arguments)
	avMng01hotNode = runner.getStringArgumentValue("avMng01hotNode", user_arguments)
	avMng01onTemp = runner.getDoubleArgumentValue("avMng01onTemp", user_arguments)
	avMng01coldNode = runner.getStringArgumentValue("avMng01coldNode", user_arguments)
	avMng01offTemp = runner.getDoubleArgumentValue("avMng01offTemp", user_arguments)
	
	availManger02 = runner.getStringArgumentValue("availManger02", user_arguments)
	availManger02name = runner.getStringArgumentValue("availManger02name", user_arguments)
	avMng02hotNode = runner.getStringArgumentValue("avMng02hotNode", user_arguments)
	avMng02onTemp = runner.getDoubleArgumentValue("avMng02onTemp", user_arguments)
	avMng02coldNode = runner.getStringArgumentValue("avMng02coldNode", user_arguments)
	avMng02offTemp = runner.getDoubleArgumentValue("avMng02offTemp", user_arguments)
	
	availManger03 = runner.getStringArgumentValue("availManger03", user_arguments)
	availManger03name = runner.getStringArgumentValue("availManger03name", user_arguments)
	avMng03hotNode = runner.getStringArgumentValue("avMng03hotNode", user_arguments)
	avMng03onTemp = runner.getDoubleArgumentValue("avMng03onTemp", user_arguments)
	avMng03coldNode = runner.getStringArgumentValue("avMng03coldNode", user_arguments)
	avMng03offTemp = runner.getDoubleArgumentValue("avMng03offTemp", user_arguments)
	
    # check the name for reasonableness
    if availManger01name.empty?
      runner.registerError("Empty name was entered.")
      return false
    end
	
	if availManger02 != "None"
		if availManger02name.empty?
			runner.registerError("Empty name was entered.")
			return false
		end
	end
	
	if availManger03 != "None"
		if availManger03name.empty?
			runner.registerError("Empty name was entered.")
			return false
		end
	end

    # reporting initial condition of model
	avMngListsInWorkSpace = workspace.getObjectsByType("AvailabilityManagerAssignmentList".to_IddObjectType)
	avMngInWorkSpaceOff = workspace.getObjectsByType("AvailabilityManager:HighTemperatureTurnOff".to_IddObjectType)
	avMngInWorkSpaceOn = workspace.getObjectsByType("AvailabilityManager:LowTemperatureTurnOn".to_IddObjectType)
	avMngInWorkSpaceTher = workspace.getObjectsByType("AvailabilityManager:DifferentialThermostat".to_IddObjectType)
	avMngInWorkSpace = avMngInWorkSpaceOff + avMngInWorkSpaceOn + avMngInWorkSpaceTher
		
    runner.registerInitialCondition("The Model started with #{avMngListsInWorkSpace.size} Availability Manager Lists and \
	#{avMngInWorkSpace.size} Availability Managers.")

    # add a new Availability Manager List to the model with the new name

	avMngListName = plantLoopsSel + ' AM List' 
    new_avMngList_string = "    
    AvailabilityManagerAssignmentList,
	  #{avMngListName},            !- Name
	  AvailabilityManager:#{availManger01.to_s},            !- Availability Manager 1 Object Type
	  #{availManger01name.to_s};        !- Availability Manager 1 Name
	  "
	new_avMngList_string1 = "
	  AvailabilityManager:#{availManger02.to_s},            !- Availability Manager 2 Object Type
	  #{availManger02name.to_s};        !- Availability Manager 2 Name
	  "
	new_avMngList_string2 = "
	  AvailabilityManager:#{availManger03.to_s},            !- Availability Manager 3 Object Type
	  #{availManger03name.to_s};        !- Availability Manager 3 Name
	  "
	
	new_avMng01_string = "    
     AvailabilityManager:#{availManger01},
	  #{availManger01name},        !- Name"
	
	new_avMng01_string1 = " 
	  #{avMng01hotNode.to_s},           !- Hot Node Name
	  #{avMng01coldNode.to_s},          !- Cold Node Name
	  #{avMng01onTemp.to_s},            !- Temperature Difference On Limit {deltaC}
	  #{avMng01offTemp.to_s};           !- Temperature Difference Off Limit {deltaC}
	  " 
	 
	new_avMng01_string2 = "
	  #{avMng01hotNode.to_s},           !- Sensor Node Name
	  #{avMng01onTemp.to_s};            !- Temperature {C}
	  " 
	new_avMng02_string = "    
     AvailabilityManager:#{availManger02},
	  #{availManger02name},        !- Name"
	
	new_avMng02_string1 = "
	  #{avMng02hotNode.to_s},           !- Hot Node Name
	  #{avMng02coldNode.to_s},          !- Cold Node Name
	  #{avMng02onTemp.to_s},            !- Temperature Difference On Limit {deltaC}
	  #{avMng02offTemp.to_s};           !- Temperature Difference Off Limit {deltaC}
	" 
	new_avMng02_string2 = "
	  #{avMng02hotNode.to_s},           !- Sensor Node Name
	  #{avMng02onTemp.to_s};            !- Temperature {C}
	"
	
	new_avMng03_string = "    
	 AvailabilityManager:#{availManger03},
	  #{availManger03name},        !- Name"
	
	new_avMng03_string1 = "
	  #{avMng03hotNode.to_s},           !- Hot Node Name
	  #{avMng03coldNode.to_s},          !- Cold Node Name
	  #{avMng03onTemp.to_s},            !- Temperature Difference On Limit {deltaC}
	  #{avMng03offTemp.to_s};           !- Temperature Difference Off Limit {deltaC}
	" 
	
	new_avMng03_string2 = "
	  #{avMng03hotNode.to_s},           !- Sensor Node Name
	  #{avMng03onTemp.to_s};            !- Temperature {C}
	"
	
	if availManger01 == 'DifferentialThermostat'
		new_avMng01_string += new_avMng01_string1
    else
		new_avMng01_string += new_avMng01_string2
	end
	
	if availManger02 != "None"
		new_avMngList_string.gsub!(';',',')
		#new_avMngList_string = new_avMngList_string[0..(new_avMngList_string.size - 3)]
		new_avMngList_string += new_avMngList_string1
		
	
		if availManger02 == 'DifferentialThermostat'
			new_avMng02_string += new_avMng02_string1 
		else
			new_avMng02_string += new_avMng02_string2
		end
	end
	
	
	
	if availManger03 != "None"
		new_avMngList_string.gsub!(';',',')
		#new_avMngList_string = new_avMngList_string[0..new_avMngList_string.size - 3]
		new_avMngList_string += new_avMngList_string2
		
		if availManger03 == 'DifferentialThermostat'
			new_avMng03_string += new_avMng03_string1
		else
			new_avMng03_string += new_avMng03_string2
		end
	end
	
    idfObject = OpenStudio::IdfObject::load(new_avMng01_string)
    object = idfObject.get
    wsObject = workspace.addObject(object)
    new_avMng01 = wsObject.get
	
    # echo the new Availability Manager List's name back to the user, using the index based getString method
    runner.registerInfo("An Availability Manager List named '#{new_avMng01.getString(0)}' was added.")
	
	
	if availManger02 != "None"
		idfObject = OpenStudio::IdfObject::load(new_avMng02_string)
		object = idfObject.get
		wsObject = workspace.addObject(object)
		new_avMng02 = wsObject.get

		# echo the new Availability Manager List's name back to the user, using the index based getString method
		runner.registerInfo("An Availability Manager named '#{new_avMng02.getString(0)}' was added.")
	end
	
	if availManger03 != "None"
		idfObject = OpenStudio::IdfObject::load(new_avMng03_string)
		object = idfObject.get
		wsObject = workspace.addObject(object)
		new_avMng03 = wsObject.get

		# echo the new Availability Manager List's name back to the user, using the index based getString method
		runner.registerInfo("An Availability Manager named '#{new_avMng03.getString(0)}' was added.")
	end
	
	

	idfObject = OpenStudio::IdfObject::load( new_avMngList_string)
	object = idfObject.get
	wsObject = workspace.addObject(object)
	new_avMngList = wsObject.get

	# echo the new Availability Manager List's name back to the user, using the index based getString method
	runner.registerInfo("An Availability Manager named '#{new_avMngList.getString(0)}' was added.")


	selLoop = []
	plantLoops = workspace.getObjectsByType("PlantLoop".to_IddObjectType)
	plantLoops.each do |plantLoop|
		if plantLoop.getString(0).to_s == plantLoopsSel
			selLoop = plantLoop
		end
	end
	
	selLoop.setString(19,avMngListName)
	selLoop.setString(20,'')
	
    # report final condition of model
    avMngListsInWorkSpace = workspace.getObjectsByType("AvailabilityManagerAssignmentList".to_IddObjectType)
	avMngInWorkSpaceOff = workspace.getObjectsByType("AvailabilityManager:HighTemperatureTurnOff".to_IddObjectType)
	avMngInWorkSpaceOn = workspace.getObjectsByType("AvailabilityManager:LowTemperatureTurnOn".to_IddObjectType)
	avMngInWorkSpaceTher = workspace.getObjectsByType("AvailabilityManager:DifferentialThermostat".to_IddObjectType)
	avMngInWorkSpace = avMngInWorkSpaceOff + avMngInWorkSpaceOn + avMngInWorkSpaceTher
		
    runner.registerFinalCondition("The Model started with #{avMngListsInWorkSpace.size} Availability Manager Lists and \
	#{avMngInWorkSpace.size} Availability Managers.")
    return true
 
  end

end 

# register the measure to be used by the application
SolarThermalAddAvailabilityManagers.new.registerWithApplication
