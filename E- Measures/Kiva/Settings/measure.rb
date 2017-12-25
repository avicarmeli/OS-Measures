# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class KivaSettings < OpenStudio::Ruleset::WorkspaceUserScript

  # human readable name
  def name
    return "Kiva Settings"
  end

  # human readable description
  def description
    return "E+ measure to popolate the Kiva settings values"
  end

  # human readable description of modeling approach
  def modeler_description
    return "E+ measure to popolate the Kiva settings values"
  end

  # define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new

  # argument for Soil Thermal Conductivity
	soilConductivity = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('soilConductivity', false)
	soilConductivity.setDisplayName("Soil Thermal Conductivity [W/m-K]:")
	soilConductivity.setDefaultValue(1.73)
	args << soilConductivity
	
  # argument for Soil Density
	soilDensity = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('soilDensity', false)
	soilDensity.setDisplayName("Soil Density [Kg/m3]:")
	soilDensity.setDefaultValue(1842)
	args << soilDensity
	
  # argument for Soil Specific Heat
	soilSpecificHeat = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('soilSpecificHeat', false)
	soilSpecificHeat.setDisplayName("Soil Specific Heat [J/kg-K]:")
	soilSpecificHeat.setDefaultValue(419)
	args << soilSpecificHeat

  # argument for Ground Solar Absorptivity
	groundSolarAbs = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('groundSolarAbs', false)
	groundSolarAbs.setDisplayName("Ground Solar Absorptivity:")
	groundSolarAbs.setDefaultValue(0.9)
	args << groundSolarAbs

 # argument for Ground Thermal Absorptivity
	groundThermalAbs = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('groundThermalAbs', false)
	groundThermalAbs.setDisplayName("Ground Thermal Absorptivity:")
	groundThermalAbs.setDefaultValue(0.9)
	args << groundThermalAbs	

# argument for Ground Surface Roughness
	groundSurfaceRough = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('groundSurfaceRough', false)
	groundSurfaceRough.setDisplayName("Ground Surface Roughness [m]:")
	groundSurfaceRough.setDefaultValue(0.03)
	args << groundSurfaceRough
	
# argument for Far-Field Width
	farFieldWidth = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('farFieldWidth', false)
	farFieldWidth.setDisplayName("Far-Field Width [m]:")
	farFieldWidth.setDefaultValue(40)
	args << farFieldWidth

# argument for Deep-Ground Boundary Condition 
	choices = OpenStudio::StringVector.new
    choices << "ZeroFlux"
    choices << "GroundWater"
	choices << "Autoselect"
	
	deepGroundBoundCond = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('deepGroundBoundCond', choices, false)
	deepGroundBoundCond.setDisplayName("Deep-Ground Boundary Condition:")
	deepGroundBoundCond.setDefaultValue("Autoselect")
	args << deepGroundBoundCond

# argument for Deep-Ground Depth
	deepGroundDepth = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('deepGroundDepth', false)
	deepGroundDepth.setDisplayName("Deep-Ground Depth [m]:")
	deepGroundDepth.setDefaultValue(40)
	args << deepGroundDepth
	
# argument for Minimum Cell Dimension
	minCellDim = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('minCellDim', false)
	minCellDim.setDisplayName("Minimum Cell Dimension [m]:")
	minCellDim.setDefaultValue(0.02)
	args << minCellDim
	
# argument for Maximum Cell Growth Coefficient
	maxCellGrowthCo = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('maxCellGrowthCo', false)
	maxCellGrowthCo.setDisplayName("Maximum Cell Growth Coefficient:")
	maxCellGrowthCo.setDefaultValue(1.5)
	args << maxCellGrowthCo

# argument for Simulation Timestep 
	choices = OpenStudio::StringVector.new
    choices << "Hourly"
    choices << "Timestep"
	
	simTstep = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('simTstep', choices, false)
	simTstep.setDisplayName("Simulation Timestep:")
	simTstep.setDefaultValue("Hourly")
	args << simTstep

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
	soilConductivity = runner.getDoubleArgumentValue("soilConductivity", user_arguments)
	soilDensity = runner.getDoubleArgumentValue("soilDensity", user_arguments)
	soilSpecificHeat = runner.getDoubleArgumentValue("soilSpecificHeat", user_arguments)
	groundSolarAbs = runner.getDoubleArgumentValue("groundSolarAbs", user_arguments)
	groundThermalAbs = runner.getDoubleArgumentValue("groundThermalAbs", user_arguments)
	groundSurfaceRough = runner.getDoubleArgumentValue("groundSurfaceRough", user_arguments)
	farFieldWidth = runner.getDoubleArgumentValue("farFieldWidth", user_arguments)
    deepGroundBoundCond = runner.getStringArgumentValue("deepGroundBoundCond", user_arguments)
	deepGroundDepth = runner.getDoubleArgumentValue("deepGroundDepth", user_arguments)
	minCellDim = runner.getDoubleArgumentValue("minCellDim", user_arguments)
	maxCellGrowthCo = runner.getDoubleArgumentValue("maxCellGrowthCo", user_arguments)
	simTstep = runner.getStringArgumentValue("simTstep", user_arguments)

    
    
    # are ther any Foundation Kiva Objects in the model?
    kivas = workspace.getObjectsByType("Foundation:Kiva".to_IddObjectType)
	kivaset = workspace.getObjectsByType("Foundation:Kiva:Settings".to_IddObjectType)
	state = 'Created and assigned'

    if kivas.size < 1
		runner.registerInfo("There are no Foundation Kiva Objects in the model.")
	end
	# reporting initial condition of model
    runner.registerInitialCondition("The building has #{kivas.size} Foundation Kiva Objects.")
	
	if kivaset.size < 1
		runner.registerInitialCondition("There is no Foundation Kiva Setting Object in the model. A new object will be created")
		state = 'Popolated'
	# add a new empty Foundation:Kiva:Settings to the model with the new name
    # http://apps1.eere.energy.gov/buildings/energyplus/pdfs/inputoutputreference.pdf#nameddest=Zone
    kivaSetString = "    
  Foundation:Kiva:Settings,
    1.73,                    !- Soil Conductivity {W/m-K}
    1842,                    !- Soil Density {kg/m3}
    419,                     !- Soil Specific Heat {J/kg-K}
    0.9,                     !- Ground Solar Absorptivity {dimensionless}
    0.9,                     !- Ground Thermal Absorptivity {dimensionless}
    0.03,                    !- Ground Surface Roughness {m}
    40,                      !- Far-Field Width {m}
    Autoselect,              !- Deep-Ground Boundary Condition
    40,                      !- Deep-Ground Depth {m}
    0.02,                    !- Minimum Cell Dimension {m}
    1.5,                     !- Maximum Cell Growth Coefficient {dimensionless}
    Hourly;                  !- Simulation Timestep
    "
		idfObject = OpenStudio::IdfObject::load(kivaSetString)
		object = idfObject.get
		wsObject = workspace.addObject(object)
		kivaset = wsObject.get
	else
		runner.registerInitialCondition("There is Foundation Kiva Setting Objects in the model. The new values will be assigend to it's keys")
		kivaset=kivaset[0]
	end

	kivaset.setString(0,soilConductivity.to_s)
	kivaset.setString(1,soilDensity.to_s)
	kivaset.setString(2,soilSpecificHeat.to_s)
	kivaset.setString(3,groundSolarAbs.to_s)
	kivaset.setString(4,groundThermalAbs.to_s)
	kivaset.setString(5,groundSurfaceRough.to_s)
	kivaset.setString(6,farFieldWidth.to_s)
	kivaset.setString(7,deepGroundBoundCond.to_s)
	kivaset.setString(8,deepGroundDepth.to_s)
	kivaset.setString(9,minCellDim.to_s)
	kivaset.setString(10,maxCellGrowthCo.to_s)
	kivaset.setString(11,simTstep.to_s)
		
	
    # report final condition of model
    runner.registerFinalCondition("Foundation Kiva Setting Object was #{state} with the entered values.")
    
    return true
 
  end

end 

# register the measure to be used by the application
KivaSettings.new.registerWithApplication
