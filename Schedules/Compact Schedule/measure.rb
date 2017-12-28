# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class ConstantSchedule < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Constant Schedule"
  end

  # human readable description
  def description
    return "reates new constant schedule."
  end

  # human readable description of modeling approach
  def modeler_description
    return "Creates new constant schedule."
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new
	

    # the name of the new Constant Schedule to add to the model
    constSchName = OpenStudio::Ruleset::OSArgument.makeStringArgument("constSchName", true)
    constSchName.setDisplayName("New Constant Schedule name")
    #constSchName.setDescription("This name will be used as the name of the new space.")
    args << constSchName
	
	# argument for schedule type limits units type
	choices = OpenStudio::StringVector.new
    choices << "Dimensionless"
    choices << "Temperature"
	choices << "DeltaTemperature"
	choices << "PrecipitationRate"
	choices << "Angle"
	choices << "Convection Coefficient"
	choices << "Activity Level"
	choices << "Velocity"
	choices << "Capacity"
	choices << "Power"
	choices << "Availability"
	choices << "Percent"
	choices << "Control"
	choices << "Mode"
	choices << "Leave Empty"
	schTypeLim = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('schTypeLim', choices, false)
	schTypeLim.setDisplayName("Schedule Type Limits:")
	schTypeLim.setDefaultValue("Leave Empty")
	args << schTypeLim
	
	# argument for constant Schedule value
	constSchVal = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('constSchVal', false)
	constSchVal.setDisplayName("Constant Schedule value:")
	constSchVal.setDefaultValue(0.0)
	args << constSchVal

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    constSchName = runner.getStringArgumentValue("constSchName", user_arguments)
	schTypeLim = runner.getStringArgumentValue("schTypeLim", user_arguments)
	constSchVal = runner.getDoubleArgumentValue("constSchVal", user_arguments)

    # check the constSchName for reasonableness
    if constSchName.empty?
      runner.registerError("Empty Constant Schedule name was entered.")
      return false
    end

    # report initial condition of model
    runner.registerInitialCondition("The building started with #{model.getScheduleConstants.size} constant schedules and #{model.getScheduleTypeLimitss.size} Schedules Type Limits.")

	if (schTypeLim.to_s == 'Availability' or schTypeLim.to_s == 'Control' or schTypeLim.to_s == 'Mode')
		numType = 'Discrete'
	else
		numType = 'Continuous'
	end
	
    
	if !schTypeLim.to_s == 'Leave Empty'
		# add a new schedule type limits to the model
		newSchTypeLim = OpenStudio::Model::ScheduleTypeLimits.new(model)
		newSchTypeLim.setName(schTypeLim.to_s)
		newSchTypeLim.setUnitType(schTypeLim.to_s)
		newSchTypeLim.setNumericType(numType.to_s)
		# echo the new chedule type limits's name back to the user
		runner.registerInfo("Schedule type Limits #{newSchTypeLim.name} was added.")
	end

	# add a new constant schedule to the model
	newConstSch = OpenStudio::Model::ScheduleConstant.new(model)
	newConstSch.setName(constSchName.to_s)
	newConstSch.setValue(constSchVal)
	if !schTypeLim.to_s == 'Leave Empty'
		newConstSch.setScheduleTypeLimits(newSchTypeLim)
	end
    # echo the new constant schedule's name back to the user
    runner.registerInfo("Constant Schedule #{newConstSch.name} was added.")

    # report final condition of model
    runner.registerFinalCondition("The building started with #{model.getScheduleConstants.size} constant schedules and #{model.getScheduleTypeLimitss.size} Schedules Type Limits.")

    return true

  end
  
end

# register the measure to be used by the application
ConstantSchedule.new.registerWithApplication
