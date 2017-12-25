# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class FoundationKiva < OpenStudio::Ruleset::WorkspaceUserScript

  # human readable name
  def name
    return "Foundation Kiva"
  end

  # human readable description
  def description
    return "Adds Foundation Kiva object to selected floor Surface and link that object to all walls in that zoon with boundery of Outdoors or Ground.
	Creates a SurfaceProperty:ExposedFoundationPerimeter object as well"
  end

  # human readable description of modeling approach
  def modeler_description
    return "Adds Foundation Kiva object to selected Surface"
  end

  # a method to get vertecies pairs from Surface object
  def getVerts(surface)
	surfVertecies = []
	i = 10
	while !(surface.getString(i).to_s).empty?
		vert = [(surface.getString(i).to_s).to_f , (surface.getString(i+1).to_s).to_f , (surface.getString(i+2).to_s).to_f]
		surfVertecies << vert
		i += 3
	end
	surfVerteciesTemp = surfVertecies.dup
	surfVerteciesTemp.delete_at(0)
	surfVerteciesTemp.push(surfVertecies[0])
	surfVertecies = surfVertecies.zip(surfVerteciesTemp)
	return surfVertecies
  end #getVerts
  
  # a method to check if to segments are the same
  def checkSeg (seg1, seg2, runner)
	# runner.registerInfo("seg1: #{seg1.to_s} seg2: #{seg2.to_s} ") ### Debug ############################
	check1 = seg1.zip(seg2).map{|v| ((v[0][0]-v[1][0])**2+(v[0][1]-v[1][1])**2+(v[0][2]-v[1][2])**2)**0.5}
	check2 = seg1.zip(seg2.reverse).map{|v| ((v[0][0]-v[1][0])**2+(v[0][1]-v[1][1])**2+(v[0][2]-v[1][2])**2)**0.5}
	check1 = check1[0] + check1[1]
	check2 = check2[0] + check2[1]
	#runner.registerInfo("check1: #{check1.to_s} ") ### Debug ############################
	#runner.registerInfo("check2: #{check2.to_s} ") ### Debug ############################
	rejection = 1.0/1000
	if check1 < rejection
		return true
	elsif check2 < rejection
		return true
	else
		return false
	end
  end # checkSeg
  
  # define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new
	
	
	# find floor surfaces with ground outside boundery conditions
	
	surfChoice = []
	surfs = workspace.getObjectsByType("BuildingSurface:Detailed".to_IddObjectType)
	surfs.each do |surf| 
		if surf.getString(4).to_s == 'Ground' and  surf.getString(1).to_s == 'Floor'
			surfChoice << surf.getString(0).to_s
		end
	end
	
	materialCh = []
	materialCh << 'none'
	materials = workspace.getObjectsByType("Material".to_IddObjectType)
	materials.each do |material| 
		materialCh << material.getString(0).to_s
	end
	
	constructionCh = []
	constructionCh << 'none'
	constructions = workspace.getObjectsByType("Construction".to_IddObjectType)
	constructions.each do |construction| 
		constructionCh << construction.getString(0).to_s
	end
	
    # the name of the Surface to add Foundation Kiva to
    surfName = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('surfName', surfChoice, false)
    surfName.setDisplayName("Select Surface")
    #surfName.setDescription("To this surface a foundation kive object will be added.")
    args << surfName
	
	# argument for FoundationKiva object name
	foundationKivaName = OpenStudio::Ruleset::OSArgument::makeStringArgument('foundationKivaName', false)
	foundationKivaName.setDisplayName("FoundationKiva object name:")
	args << foundationKivaName
	
	# the name of the Interior Horizontal Insulation Material
    intHorInsMat = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('intHorInsMat', materialCh, false)
    intHorInsMat.setDisplayName("Interior Horizontal Insulation Material Name")
	intHorInsMat.setDefaultValue('')
    args << intHorInsMat
	
	# argument for Interior Horizontal Insulation Depth
	intHorInsDep = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('intHorInsDep', false)
	intHorInsDep.setDisplayName("Interior Horizontal Insulation Depth [m]:")
	intHorInsDep.setDefaultValue(0.2)
	args << intHorInsDep
	
	# argument for Interior Horizontal Insulation Width
	intHorInsWid = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('intHorInsWid', false)
	intHorInsWid.setDisplayName("Interior Horizontal Insulation Width [m]:")
	intHorInsWid.setDefaultValue(0.6)
	args << intHorInsWid
	
	# the name of the Interior Vertical Insulation Material
    intVerInsMat = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('intVerInsMat', materialCh, false)
    intVerInsMat.setDisplayName("Interior Vertical Insulation Material Name")
	intVerInsMat.setDefaultValue('')
    args << intVerInsMat
	
	# argument for Interior Vertical Insulation Depth
	intVerInsDep = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('intVerInsDep', false)
	intVerInsDep.setDisplayName("Interior Vertical Insulation Depth [m]:")
	intVerInsDep.setDefaultValue(0.2)
	args << intVerInsDep
	
	# the name of the Exterior Horizontal Insulation Material
    extHorInsMat = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('extHorInsMat', materialCh, false)
    extHorInsMat.setDisplayName("Exterior Horizontal Insulation Material Name")
	extHorInsMat.setDefaultValue('')
    args << extHorInsMat
	
	# argument for Exterior Horizontal Insulation Depth
	extHorInsDep = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('extHorInsDep', false)
	extHorInsDep.setDisplayName("Exterior Horizontal Insulation Depth [m]:")
	extHorInsDep.setDefaultValue(0.2)
	args << extHorInsDep
	
	# argument for Exterior Horizontal Insulation Width
	extHorInsWid = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('extHorInsWid', false)
	extHorInsWid.setDisplayName("Exterior Horizontal Insulation Width [m]:")
	extHorInsWid.setDefaultValue(0.6)
	args << extHorInsWid
	
	# the name of the Exterior Vertical Insulation Material
    extVerInsMat = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('extVerInsMat', materialCh, false)
    extVerInsMat.setDisplayName("Exterior Vertical Insulation Material Name")
	extVerInsMat.setDefaultValue('')
    args << extVerInsMat
	
	# argument for Exterior Vertical Insulation Depth
	extVerInsDep = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('extVerInsDep', false)
	extVerInsDep.setDisplayName("Exterior Vertical Insulation Depth [m]:")
	extVerInsDep.setDefaultValue(0.2)
	args << extVerInsDep
	
	# argument for Wall Height Above Grade
	wallHeiAbGrade = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('wallHeiAbGrade', false)
	wallHeiAbGrade.setDisplayName("Wall Height Above Grade [m]:")
	wallHeiAbGrade.setDefaultValue(0.2)
	args << wallHeiAbGrade
	
	# argument for Wall Depth Below Slab
	wallDepBelSlab = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('wallDepBelSlab', false)
	wallDepBelSlab.setDisplayName("Wall Depth Below Slab [m]:")
	wallDepBelSlab.setDefaultValue(0.3)
	args << wallDepBelSlab
	
	# the name of the Footing Wall Construction
    footWallConstName = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('footWallConstName', constructionCh, false)
    footWallConstName.setDisplayName("Footing Wall Construction Name")
	footWallConstName.setDefaultValue('')
    args << footWallConstName

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
    surfName = runner.getStringArgumentValue("surfName", user_arguments)
	foundationKivaName = runner.getStringArgumentValue("foundationKivaName", user_arguments)
	intHorInsMat = runner.getStringArgumentValue("intHorInsMat", user_arguments)
	intHorInsDep = runner.getStringArgumentValue("intHorInsDep", user_arguments)
	intHorInsWid = runner.getStringArgumentValue("intHorInsWid", user_arguments)
	intVerInsMat = runner.getStringArgumentValue("intVerInsMat", user_arguments)
	intVerInsDep = runner.getStringArgumentValue("intVerInsDep", user_arguments)
	extHorInsMat = runner.getStringArgumentValue("extHorInsMat", user_arguments)
	extHorInsDep = runner.getStringArgumentValue("extHorInsDep", user_arguments)
	extHorInsWid = runner.getStringArgumentValue("extHorInsWid", user_arguments)
	extVerInsMat = runner.getStringArgumentValue("extVerInsMat", user_arguments)
	extVerInsDep = runner.getStringArgumentValue("extVerInsDep", user_arguments)
	wallHeiAbGrade = runner.getStringArgumentValue("wallHeiAbGrade", user_arguments)
	wallDepBelSlab = runner.getStringArgumentValue("wallDepBelSlab", user_arguments)
	footWallConstName = runner.getStringArgumentValue("footWallConstName", user_arguments)
	
	# runner.registerInfo("intHorInsMat: #{intHorInsMat.to_s} ") ### Debug ############################
	if intHorInsMat == '' or intHorInsMat == 'none'
		intHorInsDep = ''
		intHorInsWid = ''
	end
	
	if intVerInsMat == '' or intVerInsMat == 'none'
		intVerInsDep = ''
	end
	
	if extHorInsMat == '' or extHorInsMat == 'none'
		extHorInsDep = ''
		extHorInsWid = ''
	end
	
	if extVerInsMat == '' or extVerInsMat == 'none'
		extVerInsDep = ''
	end

    # check the user_name for reasonableness
    if foundationKivaName.empty?
      runner.registerError("Empty Foundation Kiva object name was entered.")
      return false
    end
    
    # get all Foundation:Kiva in the starting model
    foundationKivas = workspace.getObjectsByType("Foundation:Kiva".to_IddObjectType)
	
	# get all SurfaceProperty:ExposedFoundationPerimeter in the starting model
    foundationPerimeters = workspace.getObjectsByType("SurfaceProperty:ExposedFoundationPerimeter".to_IddObjectType)

    # reporting initial condition of model
    runner.registerInitialCondition("The model started with #{foundationKivas.size} Foundation Kiva objects 
	and #{foundationPerimeters.size} SurfaceProperty:ExposedFoundationPerimeter objects")

    # add a new Foundation:Kiva to the model with the new name
    # http://apps1.eere.energy.gov/buildings/energyplus/pdfs/inputoutputreference.pdf#nameddest=Zone
    newFoundationKivaString = "    
    Foundation:Kiva,
      #{foundationKivaName.to_s},                  !- Name
      #{intHorInsMat.to_s},                        !- Interior Horizontal Insulation Material Name
      #{intHorInsDep.to_s},                        !- Interior Horizontal Insulation Depth {m}
      #{intHorInsWid.to_s},                        !- Interior Horizontal Insulation Width {m}
      #{intVerInsMat.to_s},                        !- Interior Vertical Insulation Material Name
      #{intVerInsDep.to_s},                        !- Interior Vertical Insulation Depth {m}
      #{extHorInsMat.to_s},                        !- Exterior Horizontal Insulation Material Name
      #{extHorInsDep.to_s},                        !- Exterior Horizontal Insulation Depth {m}
      #{extHorInsWid.to_s},                        !- Exterior Horizontal Insulation Width {m}
      #{extVerInsMat.to_s},                        !- Exterior Vertical Insulation Material Name
      #{extVerInsDep.to_s},                        !- Exterior Vertical Insulation Depth {m}
      #{wallHeiAbGrade.to_s},                      !- Wall Height Above Grade {m}
      #{wallDepBelSlab.to_s},                      !- Wall Depth Below Slab {m}
      #{footWallConstName.to_s};                   !- Footing Wall Construction Name
      "
    idfObject = OpenStudio::IdfObject::load(newFoundationKivaString)
    object = idfObject.get
    wsObject = workspace.addObject(object)
    newFoundationKiva = wsObject.get

    # echo the new Foundation:Kiva's name back to the user, using the index based getString method
    runner.registerInfo("A Foundation Kiva object named '#{newFoundationKiva.getString(0)}' was added.")
	
	# find the selected Surface
	surfSelected = []
	surfs = workspace.getObjectsByType("BuildingSurface:Detailed".to_IddObjectType)
	surfs.each do |surf| 
		if surf.getString(0).to_s == surfName.to_s
			surfSelected = surf
			break
		end
	end
	
	# Link the new Foundation Kiva object to the selected surface
	surfSelected.setString(4,'Foundation')
	surfSelected.setString(5, foundationKivaName.to_s)
	
	# echo that the new Foundation Kiva objectwas linked to the selected surface
    runner.registerInfo("A Foundation Kiva object named '#{newFoundationKiva.getString(0)}' was Linked to #{surfName.to_s} Surface.")
	
	# calculate and create SurfaceProperty:ExposedFoundationPerimeter object
	theZoneWalls = []
	surfs.each do |surf|
		cond = surf.getString(4).to_s
		itIsInZone = surf.getString(3).to_s == surfSelected.getString(3).to_s
		itIsWall = surf.getString(1).to_s == 'Wall'
		itsBouCondGr = (cond == 'Ground')
		itsBouCondOut = (cond == 'Outdoors')
		itsBouCondGrOut = itsBouCondOut or itsBouCondGr
		#runner.registerInfo("itsBouCondGr: #{itsBouCondGr.to_s} itsBouCondOut: #{itsBouCondOut.to_s}") ### Debug ############################
		#runner.registerInfo("surf: #{surf.getString(0).to_s} itIsInZone: #{itIsInZone.to_s} itIsWall: #{itIsWall.to_s} itsBouCondGrOut: #{itsBouCondGrOut.to_s} surf.getString(4) #{cond}") ### Debug ############################
		if itIsInZone and itIsWall and (itsBouCondGr or itsBouCondGrOut)
			theZoneWalls << surf
			#runner.registerInfo("selected") ### Debug ############################
		end
		if itIsInZone and itIsWall
			#runner.registerInfo("surf: #{surf.to_s} ") ### Debug ############################
		end
	end
	selSurfVerts = getVerts(surfSelected)
	wallsVerts = []
	theZoneWalls.each do |theZoneWall|
		wallsVerts += getVerts(theZoneWall)
	end
	segmentsExp = []
	selSurfVerts.each do |selSurfVert|
		segmentsExp << 'No'
		wallsVerts.each do |wallsVert|
			#runner.registerInfo("checkSeg: #{checkSeg(selSurfVert , wallsVert, runner).to_s} ") ### Debug ############################
			if checkSeg(selSurfVert , wallsVert, runner)
				segmentsExp[segmentsExp.size-1] = 'Yes'
				break
			end
		end
	end
	runner.registerInfo("segmentsExp: #{segmentsExp.to_s} ") ### Debug ############################
	
	newExposedFoundationPerimeterString = " 
	 SurfaceProperty:ExposedFoundationPerimeter,
		#{surfName.to_s},        !- Surface Name
		BySegment,               !- Exposed Perimeter Calculation Method
		,                        !- Total Exposed Perimeter {m}
		;                        !- Exposed Perimeter Fraction {dimensionless}
	"
	idfObject = OpenStudio::IdfObject::load(newExposedFoundationPerimeterString)
	object = idfObject.get
	wsObject = workspace.addObject(object)
	newExposedFoundationPerimeter = wsObject.get
	
	segmentsExp.each.with_index do |theSegmentsExp, i|
		newExposedFoundationPerimeter.setString(4 + i,theSegmentsExp.to_s)
	end

	# echo the new SurfaceProperty:ExposedFoundationPerimeter's name back to the user, using the index based getString method
	runner.registerInfo("A SurfaceProperty:ExposedFoundationPerimeter object for Floor named '#{newExposedFoundationPerimeter.getString(0)}' was added.")

	theZoneWalls.each do |theZoneWall|
		if theZoneWall.getString(4).to_s == 'Ground'
			theZoneWall.setString(4,'Foundation')
			theZoneWall.setString(5,foundationKivaName.to_s)
			runner.registerInfo("A Foundation Kiva object named '#{newFoundationKiva.getString(0)}' was Linked to #{theZoneWall.getString(0).to_s} Wall.")
		end
		if theZoneWall.getString(4).to_s == 'Outdoors'
			theZoneWall.setString(5,foundationKivaName.to_s)
			runner.registerInfo("A Foundation Kiva object named '#{newFoundationKiva.getString(0)}' was Linked to #{theZoneWall.getString(0).to_s} Wall.")
		end
	end
	
	
    # report final condition of model
	# get all Foundation:Kiva in the starting model
    foundationKivas = workspace.getObjectsByType("Foundation:Kiva".to_IddObjectType)
	
	# get all SurfaceProperty:ExposedFoundationPerimeter in the starting model
    foundationPerimeters = workspace.getObjectsByType("SurfaceProperty:ExposedFoundationPerimeter".to_IddObjectType)

    # reporting initial condition of model
    runner.registerFinalCondition("The model started with #{foundationKivas.size} Foundation Kiva objects 
	and #{foundationPerimeters.size} SurfaceProperty:ExposedFoundationPerimeter objects")
	
    return true
 
  end

end 

# register the measure to be used by the application
FoundationKiva.new.registerWithApplication
