#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see your EnergyPlus installation or the URL below for information on EnergyPlus objects
# http://apps1.eere.energy.gov/buildings/energyplus/pdfs/inputoutputreference.pdf

#see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

#see the URL below for access to C++ documentation on workspace objects (click on "workspace" in the main window to view workspace objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/utilities/html/idf_page.html

#start the measure
class AddTimeInterpolation < OpenStudio::Ruleset::WorkspaceUserScript
  
  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "Add Time interpolation"
  end
  
  #define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new

   # add time interpolation selection
    time_interp = OpenStudio::Ruleset::OSArgument.makeBoolArgument("time_interp",true)
    time_interp.setDisplayName("Change all Day Schedules Time Interpolate to Yes?")
    time_interp.setDefaultValue(true)
    args << time_interp
    
    return args
  end #end the arguments method

  #define what happens when the measure is run
  def run(workspace, runner, user_arguments)
    super(workspace, runner, user_arguments)
    
    #use the built-in error checking 
    if not runner.validateUserArguments(arguments(workspace), user_arguments)
      return false
    end

    #assign the user inputs to variables
    time_interp = runner.getStringArgumentValue("time_interp",user_arguments)

    #reporting initial condition of model
    starting_objects = workspace.getObjectsByType("Schedule:Day:Interval".to_IddObjectType)
	
	#check how many Interpolate to Timestep are set to No
	set_to_no = 0
	starting_objects.each do |object|
      if object.getString(2).to_s == "No"
        set_to_no += 1
      end
    end
	
    runner.registerInitialCondition("The model started with #{starting_objects.size} Schedule:Day:Interval objects in the work space. In #{set_to_no} out of them the Interpolate to Timestep key is set to No")

	set_to_yes = 0
	
	if time_interp
	
		starting_objects.each do |object|
		  if object.getString(2).to_s == "No"
			object.setString(2,"Yes")
			set_to_yes += 1
		  end
		end
	end # end if time_interp
    #reporting final condition of model
    
    runner.registerFinalCondition("#{set_to_yes} Schedule:Day:Interval object's Interpolate to Timestep key were set to Yes.")

    return true
 
  end #end the run method

end #end the measure

#this allows the measure to be use by the application
AddTimeInterpolation.new.registerWithApplication