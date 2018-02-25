# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class AddAvailabilityManager < OpenStudio::Measure::ModelMeasure

  # human readable name
  def name
    return "Add Availability Manager"
  end

  # human readable description
  def description
    return "The Measure adds a Schedule Availability Manager to the Selected Plant Loop"
  end

  # human readable description of modeling approach
  def modeler_description
    return "The Measure adds a Schedule Availability Manager to the Selected Plant Loop"
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new
	
	#populate choice argument for Plantloops
    plantLoops_handles = OpenStudio::StringVector.new
    plantLoops_display_names = OpenStudio::StringVector.new

    #putting schedules into hash
    plantLoops_args = model.getPlantLoops
    plantLoops_args_hash = {}
    plantLoops_args.each do |plantLoops_arg|
      plantLoops_args_hash[plantLoops_arg.name.to_s] = plantLoops_arg
    end

    #looping through sorted hash of schedules
    plantLoops_args_hash.sort.map do |key,value|
      #only include if schedule use count > 0
      #if value.directUseCount > 0
        plantLoops_handles << value.handle.to_s
        plantLoops_display_names << key
      #end
    end

    #make an argument for selected plantloop
    selPlantLoop = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("selPlantLoop", plantLoops_handles, plantLoops_display_names,true)
    selPlantLoop.setDisplayName("Choose Plant Loop.")
    args << selPlantLoop

    # the name of the Availability Manager to add to the model
    aM_name = OpenStudio::Measure::OSArgument.makeStringArgument("aM_name", true)
    aM_name.setDisplayName("New Availability Manager name")
    aM_name.setDescription("This name will be used as the name of the new Availability Manager.")
    args << aM_name
	
	#populate choice argument for schedules
    schedule_handles = OpenStudio::StringVector.new
    schedule_display_names = OpenStudio::StringVector.new

    #putting schedules into hash
    schedule_args = model.getScheduleRulesets
    schedule_args_hash = {}
    schedule_args.each do |schedule_arg|
      schedule_args_hash[schedule_arg.name.to_s] = schedule_arg
    end

    #looping through sorted hash of schedules
    schedule_args_hash.sort.map do |key,value|
      #only include if schedule use count > 0
      if value.directUseCount > 0
        schedule_handles << value.handle.to_s
        schedule_display_names << key
      end
    end

    #make an argument for Availability Manager schedule
    a_schedule = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("a_schedule", schedule_handles, schedule_display_names,true)
    a_schedule.setDisplayName("Choose Schedule.")
    args << a_schedule
	

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
	selPlantLoop = runner.getOptionalWorkspaceObjectChoiceValue("selPlantLoop",user_arguments,model)
	a_schedule = runner.getOptionalWorkspaceObjectChoiceValue("a_schedule",user_arguments,model)
    aM_name = runner.getStringArgumentValue("aM_name", user_arguments)

    # check the space_name for reasonableness
    if aM_name.empty?
      runner.registerError("Empty Availability Manager name was entered.")
      return false
    end
	
	if a_schedule.empty?
      handle = runner.getStringArgumentValue("a_schedule",user_arguments)
      if handle.empty?
        runner.registerError("No schedule was chosen.")
      else
        runner.registerError("The selected schedule with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
      end
      return false
    else
      if not a_schedule.get.to_ScheduleRuleset.empty?
        a_schedule = a_schedule.get.to_ScheduleRuleset.get
      else
        runner.registerError("Script Error - argument not showing up as schedule.")
        return false
      end
    end  #end of if a_schedule.empty? 
	
	if selPlantLoop.empty?
      handle = runner.getStringArgumentValue("selPlantLoops",user_arguments)
      if handle.empty?
        runner.registerError("No Plant Loop was chosen.")
      else
        runner.registerError("The selected Plant Loop with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
      end
      return false
    else
      if not selPlantLoop.get.to_PlantLoop.empty?
        selPlantLoop = selPlantLoop.get.to_PlantLoop.get
      else
        runner.registerError("Script Error - argument not showing up as Plant Loop.")
        return false
      end
    end  #end of if selPlantLoop.empty? 

    # report initial condition of model
	aml = selPlantLoop.availabilityManagers
    runner.registerInitialCondition("The Plant Loop named #{selPlantLoop.name.to_s} started with #{aml.size} Availability Managers.")

    # create a new Availability Manager
	newAvailMan = OpenStudio::Model::AvailabilityManagerScheduled.new(model)
	newAvailMan.setName(aM_name.to_s) 
	newAvailMan.setSchedule(a_schedule)
	
	# echo the new Availability Manager's name back to the user
    runner.registerInfo("Availability Manager #{newAvailMan.name} was added.")
	
	
	# connect the new Availability Manager to the selected Plant Loop
    selPlantLoop.addAvailabilityManager(newAvailMan)

    # report final condition of model
	aml = selPlantLoop.availabilityManagers
    runner.registerFinalCondition("The Plant Loop named #{selPlantLoop.name.to_s} ended with #{aml.size} Availability Managers.")

    return true

  end
  
end

# register the measure to be used by the application
AddAvailabilityManager.new.registerWithApplication
