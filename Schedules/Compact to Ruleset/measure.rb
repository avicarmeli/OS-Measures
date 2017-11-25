# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class CompactToRulesetSchedule < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Compact to Ruleset Schedule"
  end

  # human readable description
  def description
    return "Translates Compact Schedule to Ruleset schedule."
  end

  # human readable description of modeling approach
  def modeler_description
    return "The measure use non optimal algoritem to represent Compact schedule as Ruleset schedule. if present Type Limits and summer and winter design day s are exported to the ruleset schedule."
  end
  
# carry operation on two day Schedules and return time (minutes from midnight) and values vector ( similar to day schedule style)
	def opDaySch( sch_1, sch_2, op, model, runner)
		allTimes = []
		allValues = []
		if ( sch_1.class == Float or  sch_2.class == Float)
			if  sch_1.class == Float
				sch_2.times.each do |mtime|
					allTimes << (mtime.totalMinutes.to_i)
					allValues << sch_2.getValue(OpenStudio::Time.new(0,0,allTimes.last,0))	
				end
				
				opd = sch_1
				pre = 1
			else
				sch_1.times.each do |mtime|
					allTimes << (mtime.totalMinutes.to_i)
					allValues << sch_1.getValue(OpenStudio::Time.new(0,0,allTimes.last,0))	
				end
				
				opd = sch_2
				pre = 0
			end	
			
			allValues.each_with_index do |allValue, index|
				case op
				when '+'
					allValues[index] = allValue + opd
				when '*'
					allValues[index] = allValue * opd
				when '-'
					if pre == 1
						allValues[index] = opd - allValue
					else
						allValues[index] = allValue - opd
					end
				when '/'
					if pre == 1
						allValues[index] = opd * [allValue].map {|v| v != 0 ? 1 : 0}.last
					else
						allValues[index] = allValue / opd
					end
				else
				end
			end
			#runner.registerInfo("allTimes: #{allTimes.to_s}") ### Debug ###########################
			#runner.registerInfo("allValues: #{allValues.to_s}") ### Debug ###########################
			return [allValues , allTimes]
		end
		
		sch_1.times.each do |time|
			allTimes << (time.totalMinutes.to_i)
		end
		
		sch_2.times.each do |time|
			allTimes << (time.totalMinutes.to_i)
		end
		allTimes.sort!
		allTimes.uniq!
		
		allTimes.each do |allTime|
			value_1 = sch_1.getValue(OpenStudio::Time.new(0,0,allTime,0))
			value_2 = sch_2.getValue(OpenStudio::Time.new(0,0,allTime,0))
			# runner.registerInfo("value_1 and 2: #{value_1.to_s} , #{value_2.to_s}") ### Debug ###########################
			if op == '*'
				allValues << value_1 * value_2
			elsif op == '+'
				allValues << value_1 + value_2
			elsif op == '-'
				allValues << value_1 - value_2
			elsif op == '/'
				allValues << value_1 * [value_2].map {|v| v != 0 ? 1 : 0}.last
			end
		end
		
		# find index of repeted values
		if allValues.length > 1
			repValIndx = allValues[0..allValues.length - 2].zip(allValues[1...allValues.length]).map{|a,b| a-b == 0}.compact
			# repValIndx.unshift(false)
			repValIndx = repValIndx.map.with_index {|a, i| a == true ? i : nil}.compact
			# delete them
			allValues = allValues.reject.with_index { |e,i| repValIndx.include? i }
			allTimes = allTimes.reject.with_index { |e,i| repValIndx.include? i }
		end
		# runner.registerInfo("allValues: #{allValues.to_s}") ### Debug ###########################
		return [allValues , allTimes]
	end

# carry operation on two Rule Schedules and return time (minutes from midnight) and values vectors ( similar to day schedule style) of all year
	def opRullSch( sch_1, sch_2 , op, model, runner)
		oneDay = OpenStudio::Time.new(1,0,0,0)
		oneYear = OpenStudio::Time.new(364,0,0,0)
		firstDay = OpenStudio::Date.new
		isSch_1Num = sch_1.class == Float
		isSch_2Num = sch_2.class == Float
		dayScheds_1 = dayScheds_2 = []
		isSch_1Num ? dayScheds_1 = Array.new(365, sch_1) : dayScheds_1 = sch_1.getDaySchedules(firstDay,firstDay+oneYear)
		isSch_2Num ? dayScheds_2 = Array.new(365, sch_2) : dayScheds_2 = sch_2.getDaySchedules(firstDay,firstDay+oneYear)
		outSchedules = []
		yearOccu = [1..365]
		outSchedules << opDaySch(dayScheds_1[0] , dayScheds_2[0], op, model, runner)
		yearOccu[0]=0
		for i in 1..364
			currDaySch = opDaySch(dayScheds_1[i] , dayScheds_2[i], op, model, runner)
			matchFound = false
			for j in 0...outSchedules.length
				if currDaySch == outSchedules[j]
					yearOccu[i] = j
					matchFound = true
					break
				end
			end
			unless matchFound
				outSchedules << currDaySch
				yearOccu[i] = (outSchedules.length - 1)
			end
		end
			
	return outSchedules, yearOccu
	
	end
	  
# convert time (minutes from midnight) and values vectors ( similar to day schedule style) of all year into a Rule Schedule
	def convertToRuleSch(inSchedules, yearOccu, schName, model, runner)
		theYear = yearOccu.dup
		# which week day is first day of the year
		firstDayOfYear = OpenStudio::Date.new().dayOfWeek.value
		weekDays = (firstDayOfYear..firstDayOfYear+6).map{|a| a%7 + 1}
		# count occurances
		occ = Array.new(inSchedules.length,0)
		yearOccu.each do |yocc|
			occ[yocc] += 1
		end
		
		defRule = occ.rindex(occ.max)   # occ.map.with_index.sort.map(&:last).reverse
		# mark the day schedule with the highest number of occurances as default ench doesn't need further clasification
		theYear.map! {|v| (v == defRule) ? v = - defRule -1 : v = v }
		nonDefDays = (0...occ.length).map {|i| i!= defRule ? i : nil}.compact
		rulesTable = []
		rulesTable << [defRule,0,364,[1,2,3,4,5,6,7]] #[dayRule index,start day in the year, end day in the year,applay sunday,monday,...]
		nonDefDays.each do |testday|
			dayMask = theYear.map {|a| a == testday ?  1 : 0}
			# find the  flashes of continoues non default rule and store their length and end place
			tempDay = (dayMask[1...dayMask.length].inject([dayMask[0]]){|memo,v| memo<<memo[memo.length-1]*v+v}) 
			tempDay = tempDay[0..tempDay.length-2].zip(tempDay[1...tempDay.length],(0..tempDay.length-2))
			dayFlashs = tempDay.map {|a| a[0]>3 && a[1]==0? [a[0],a[2]] : nil}.compact # the a[0]>3 means flash longer than 3 element - to be optimized
			dayFlashs.each do |dayFlash|
				theYear[(dayFlash[1]-dayFlash[0]+1)..dayFlash[1]] = Array.new(dayFlash[0],occ.length)    # -testday - 1) # mark as no further care needed
				rulesTable << [testday,(dayFlash[1]-dayFlash[0]+1),dayFlash[1],[1,2,3,4,5,6,7]]
			end
		end # nonDefDays.each
		
		# build vectors for each day of a week and find for each day the most common day Schedule
		wdays = []
		for j in 0..6 
			wdays << (0... theYear.length).select{ |x| x%7 == j }.map { |y| theYear[y] }
		end
		daysPaterns = []
		wdays.each do |dayX|
			nonDefRule=dayX.map {|a| a>=0 ? 1 : 0}.insert(0,0).push(0)
			# find the  flashes of continoues non default rule and store their length and end place
			tempDay = (nonDefRule[1...nonDefRule.length].inject([nonDefRule[0]]){|memo,v| memo<<memo[memo.length-1]*v+v}) 
			tempDay = tempDay[0..tempDay.length-2].zip(tempDay[1...tempDay.length],(-1..tempDay.length-2))
			posPaterns = tempDay.map {|a| a[0]>0 && a[1]==0? [a[0],a[2]] : nil}.compact.sort.reverse
			posPaterns.each_with_index do |posPatern, index|
				# if the patern is allready marked as flash delete it
				patEnd = posPatern[1]
				patStart = patEnd - posPatern[0] + 1
				pat = dayX[patStart..patEnd]
				pat.uniq.inject(pat.uniq.length) {|memo,v| (memo == 1) and (v == occ.length) ? posPaterns.delete_at(index) : posPaterns = posPaterns}
			end # each posPaterns
			daysPaterns << posPaterns
		end # wday.each
		# are there similar days all year long?
		daysSim=[]
		uniqDaysIndex=[0,1,2,3,4,5,6]
		for i in 0..6
			sim = []
			for j in (i + 1)..6
				if wdays[i][0..51] == wdays[j][0..51] # Todo: may be that almost same is also good
					sim << j+1
				end
			end
			if sim.empty? 
				daysSim << 0
			else
				daysSim << sim # daysSim holds a list of similar days for each day with the index of those days +1. [0] means no similarity
				sim.each do |eday|
					uniqDaysIndex[eday -1] = 0
				end
			end
		end
		nextRuleInd = 1
		uniqDaysIndex.uniq! # days need to be scaned
		dayNum = uniqDaysIndex.length - 1
		for i in 0..dayNum
			daysPaterns[uniqDaysIndex[i]].each do |daysPatern|
				startInd = daysPatern[1] - daysPatern[0] + 1
				endInd = daysPatern[1]
				workPat = wdays[uniqDaysIndex[i]][startInd..endInd] # holds the patern to work with
				workLen = endInd - startInd + 1 # size of patern ???????????????????????
				workUniq = workPat.uniq.select {|a| a < occ.length } # find what is inside the patern and remove allredy handled days 
				workCount = [] # how many occurances of each day schedule in the patern
				workUniq == [] ? workUniq = [workPat[0]] : workUniq = workUniq
				workUniq.each do |wu|
					workCount << workPat.count(wu)
				end
				workOcc = workCount.zip((0...workCount.length)).sort.reverse.map &:last #select the most common day schedule in the patern to start with
				workOcc.empty? ? workOcc = 0 : workOcc = workOcc
				# The most common day schedule in the patern will be last rule
				patDaySch = workUniq[workOcc[0]]
				patFirst = startInd + workPat.index(patDaySch) 
				workLen == 1 ? patLast = patFirst : patLast = startInd + workLen - 1 - workPat.reverse.index(patDaySch)
				yearStartDay = patFirst * 7 + uniqDaysIndex[i]
				yearEndDay = patLast * 7 + uniqDaysIndex[i]
				ruleDays = [0,0,0,0,0,0,0]
				ruleDays[weekDays[uniqDaysIndex[i]] - 1] = weekDays[uniqDaysIndex[i]] 
					
				# if there are similar days 
				if daysSim[uniqDaysIndex[i]][0] != 0 
					lastSimDay = daysSim[uniqDaysIndex[i]].last - 1 
					daysSim[uniqDaysIndex[i]].each do |dsim|
						ruleDays[weekDays[dsim - 1] - 1] = weekDays[dsim - 1]
					end
				end
				
				yearEndDay > 364? yearEndDay = 364 : yearEndDay = yearEndDay
				rulesTable.insert(nextRuleInd, [patDaySch,yearStartDay,yearEndDay,ruleDays])
				nextRuleInd += 1
				workPat.map! {|v| v == patDaySch  ? -1 : v}
				patInd = 0
				while (workPat.map {|v| v > 0 and v < occ.length ? 1 : 0}.count(1) > 0) and (workUniq.length > 1)
					nextDaySchStart = (workPat[patInd ... workPat.length]).index {|v| v >= 0 and v < occ.length} + patInd
					nextDaySch = workPat[nextDaySchStart]
					nextDaySchEnd = (workPat[nextDaySchStart ... workPat.length]).index {|v| v != nextDaySch and v!= occ.length} + nextDaySchStart -1
					yearStartDay = (startInd + nextDaySchStart) * 7 + uniqDaysIndex[i]
					yearEndDay = (startInd + nextDaySchEnd) * 7 + uniqDaysIndex[i]
					# if there are similar days 
					if daysSim[uniqDaysIndex[i]][0] != 0 
						lastSimDay = daysSim[uniqDaysIndex[i]].last - 1
						yearEndDay = (startInd + nextDaySchEnd) * 7 + lastSimDay
					end # daysSim
					yearEndDay > 364? yearEndDay = 364 : yearEndDay = yearEndDay
					rulesTable.insert(nextRuleInd, [nextDaySch,yearStartDay,yearEndDay,ruleDays])
					#runner.registerInfo("[nextDaySch,yearStartDay,yearEndDay,ruleDays]: #{[nextDaySch,yearStartDay,yearEndDay,ruleDays].to_s} ") ### Debug ###########################
					nextRuleInd += 1
					workPat[nextDaySchStart..nextDaySchEnd] = -1
					patInd = nextDaySchEnd + 1
				end
			end # each daysPaterns
		end # for Days
		# create RullSchedules
		rullSetSchedule = OpenStudio::Model::ScheduleRuleset.new(model)
		rullSetSchedule.setName(schName)
		# create Rulles
		defDaySch = rullSetSchedule.defaultDaySchedule
		defDaySch.clearValues
		defDaySch.setName(schName+ " Default")
		schValues = inSchedules[rulesTable[0][0]][0]
		schTimes = inSchedules[rulesTable[0][0]][1]
		schTimes.zip(schValues).each do |schEntry|
			defDaySch.addValue(OpenStudio::Time.new(0,0,schEntry[0],0),schEntry[1])
		end
		
		m = rulesTable.length - 1
		rulesTable[1...rulesTable.length].each do |rule|
			wkdy_rule = OpenStudio::Model::ScheduleRule.new(rullSetSchedule)
			wkdy_rule.setName(schName + " ruleset#{m}")
			wkdy = wkdy_rule.daySchedule
			wkdy.setName(schName + " Day Schedule #{m}")
			schValues = inSchedules[rule[0]][0]
			schTimes = inSchedules[rule[0]][1]
			schTimes.zip(schValues).each do |schEntry|
				wkdy.addValue(OpenStudio::Time.new(0,0,schEntry[0],0),schEntry[1])
			end
			wkdy_rule.setApplySunday(rule[3][0]!=0)
			wkdy_rule.setApplyMonday(rule[3][1]!=0)
			wkdy_rule.setApplyTuesday(rule[3][2]!=0)
			wkdy_rule.setApplyWednesday(rule[3][3]!=0)
			wkdy_rule.setApplyThursday(rule[3][4]!=0)
			wkdy_rule.setApplyFriday(rule[3][5]!=0)
			wkdy_rule.setApplySaturday(rule[3][6]!=0)
			wkdy_rule.setStartDate(OpenStudio::Date.new() + OpenStudio::Time.new(rule[1],0,0,0))
			wkdy_rule.setEndDate(OpenStudio::Date.new() + OpenStudio::Time.new(rule[2],0,0,0))
			m -= 1
		end
		# check for  coherence
		outSchedules, outSchYO = opRullSch(0.0,rullSetSchedule,'+', model, runner)
		checkCo=Array.new(outSchedules.length , -1)
		if outSchedules != inSchedules
			for i in 0... checkCo.length
				for j in 0...checkCo.length
					if outSchedules[i] == inSchedules [j]
						checkCo[i] = j
						break
					end
				end
			end
			if checkCo.include?(-1)
				runner.registerError("Resulting Day schedules are not coherente with the formula output")
			else
				yearOccu.map! {|v| v = checkCo.index(v)}
			end
		end
		if outSchYO != yearOccu 
			runner.registerError("Resulting Rules are not coherente with the formula output") 
		end
		
		return rullSetSchedule
	end
  
 # get  time (minutes from midnight) and values vectors ( similar to day schedule style) from compact schedule
	def getCompactScheduleDays(compSche, runner)
		# which week day is first day of the year
		firstDayOfYear = OpenStudio::Date.new().dayOfWeek.value
		weekDays = (firstDayOfYear..firstDayOfYear+6).map{|a| a%7 + 1}
		# create index for diffrent day groups
		sundays = (0..54).map {|v| weekDays.index(1)+7*v}.grep(0..364)
		mondays = (0..54).map {|v| weekDays.index(2)+7*v}.grep(0..364)
		tusdays = (0..54).map {|v| weekDays.index(3)+7*v}.grep(0..364)
		wednesdays = (0..54).map {|v| weekDays.index(4)+7*v}.grep(0..364)
		thursdays = (0..54).map {|v| weekDays.index(5)+7*v}.grep(0..364)
		fridays = (0..54).map {|v| weekDays.index(6)+7*v}.grep(0..364)
		saturdays = (0..54).map {|v|  weekDays.index(7)+7*v}.grep(0..364)
		weekdays = (mondays + tusdays + wednesdays + thursdays + fridays).sort
		weekends = (sundays + saturdays).sort
	
		outSchedules = []
		yearOccu = Array.new(368,-1)
		fromDayOfYear = 1
		maxIndex = compSche.numFields() - 1
		for i in 3..maxIndex
			if compSche.getString(i).to_s.include?('Through:')
				# get the untill Date
				mDate = compSche.getString(i).to_s.scan(/\d+/)
				mMounth = OpenStudio::MonthOfYear.new(mDate[0].to_i)
				mday = mDate[1].to_i
				trDate = OpenStudio::Date.new(mMounth,mday)
				toDayOfYear = trDate.dayOfYear
				
			elsif compSche.getString(i).to_s.include?('For:')
				# get the aplicable days
				applayIn = compSche.getString(i).to_s.gsub('For: ','')
				applayDays =[]
				sumDDay = false
				winDDay = false 
				if (applayIn.downcase).include?('sunday')
					applayDays += sundays.grep((fromDayOfYear - 1) ..(toDayOfYear - 1)) 
				end
				if (applayIn.downcase).include?('monday')
					applayDays += mondays.grep((fromDayOfYear - 1) ..(toDayOfYear - 1))
				end
				if (applayIn.downcase).include?('tuesday')
					applayDays += tusdays.grep((fromDayOfYear - 1) ..(toDayOfYear - 1))
				end
				if (applayIn.downcase).include?('wednesday')
					applayDays += wednesdays.grep((fromDayOfYear - 1) ..(toDayOfYear - 1))
				end
				if (applayIn.downcase).include?('thursday')
					applayDays += thursdays.grep((fromDayOfYear - 1) ..(toDayOfYear - 1))
				end
				if (applayIn.downcase).include?('friday')
					applayDays += fridays.grep((fromDayOfYear - 1) ..(toDayOfYear - 1))
				end
				if (applayIn.downcase).include?('saturday')
					applayDays += saturdays.grep((fromDayOfYear - 1) ..(toDayOfYear - 1))
				end
				if (applayIn.downcase).include?('weekdays')
					applayDays += weekdays.grep((fromDayOfYear - 1) ..(toDayOfYear - 1))
				end
				if (applayIn.downcase).include?('weekends')
					applayDays += weekends.grep((fromDayOfYear - 1) ..(toDayOfYear - 1))
				end
				if (applayIn.downcase).include?('alldays')
					applayDays = (0..364).grep((fromDayOfYear - 1) ..(toDayOfYear - 1))
				end
				if (applayIn.downcase).include?('allotherdays')
					applayDays = (yearOccu.each_index.select{|i| yearOccu[i] == - 1}).grep((fromDayOfYear - 1) ..(toDayOfYear - 1))	
				end
				if (applayIn.downcase).include?('summerdesignday')
					sumDDay = true
				end
				if (applayIn.downcase).include?('winterdesignday')
					winDDay = true	
				end
				applayDays.sort!.uniq!
				# get the day Schedule
				allTimes = []
				allValues = []
				while compSche.getString(i+1).to_s.include?('Until:')
					mTime = compSche.getString(i+1).to_s.scan(/\d+/)
					mHour = mTime[0].to_i
					mMinute = mTime[1].to_i
					allTimes << (mHour * 60 + mMinute)
					mValue = compSche.getString(i+2).to_s
					allValues << mValue.to_f
					i += 2
				end
				duptime = allTimes.each_index.group_by{|i| allTimes[i]}.values.select{|a| a.length > 1}.flatten
				if duptime != []
					allValues.delete_at(duptime.last)
					allTimes.delete_at(duptime.last)
				end
				currDaySch = [allValues , allTimes]
				if outSchedules.empty?
					outSchedules << currDaySch
					daySchInd = outSchedules.length - 1
				else
					matchFound = false
					for j in 0...outSchedules.length
						if currDaySch == outSchedules[j]
							daySchInd = j
							matchFound = true
							break
						end
					end
					unless matchFound
						outSchedules << currDaySch
						daySchInd = outSchedules.length - 1
					end
				end # if outSchedules
				applayDays.each do |aDay|
					yearOccu[aDay] = daySchInd
				end # each
				if winDDay
					yearOccu[366] = daySchInd
				end
				if sumDDay
					yearOccu[367] = daySchInd
				end
				
				if compSche.getString(i+1).to_s.include?('Through:')
					fromDayOfYear = toDayOfYear + 1
				elsif compSche.getString(i+1).to_s.empty?
					break
				end
			else
				# to do error
			end #if
		end # for i
		
		return outSchedules, yearOccu
		
	end # getCompactScheduleDays
	
  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    #populate choice argument for schedules 
    schedule_handles = OpenStudio::StringVector.new
    schedule_display_names = OpenStudio::StringVector.new

    schedule_args = model.getScheduleCompacts
    schedule_args_hash = {}
    schedule_args.each do |schedule_arg|
      schedule_args_hash[schedule_arg.name.to_s] = schedule_arg
    end

    #looping through sorted hash of schedules
    schedule_args_hash.sort.map do |key,value|
      if value.directUseCount > 0
        schedule_handles << value.handle.to_s
        schedule_display_names << key
      end
    end


    #make an argument for schedule
    schedule = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("schedule", schedule_handles, schedule_display_names,true)
    schedule.setDisplayName("Choose a Schedule to Translate to Ruleset.")
    # schedule.setDefaultValue("*All Ruleset Schedules*") #if no schedule is chosen this will run on all air loops
    args << schedule

    return args
  end #end the arguments method

  #define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    #use the built-in error checking 
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    #assign the user inputs to variables
    schedule = runner.getOptionalWorkspaceObjectChoiceValue("schedule",user_arguments,model)
    

    #check the schedule for reasonableness
    if schedule.empty?
      handle = runner.getStringArgumentValue("schedule",user_arguments)
      if handle.empty?
        runner.registerError("No schedule was chosen.")
      else
        runner.registerError("The selected schedule with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
      end
      return false
    end  #end of if schedule.empty?  
	
	# report initial condition
	
	#get ruleset schedules list
    schedules = model.getScheduleRulesets
	
	# get Compact schedules list
	cSchedules = model.getScheduleCompacts
	
	runner.registerInitialCondition("#{schedules.size} Ruleset schedules .\r\n \
	and #{cSchedules.size} Compact schedules are in this model.")

	# Do the real Job

	outSchedules, yearOccu = getCompactScheduleDays(schedule.get, runner)	
	schName = schedule.get.getString(1).to_s
	ruleSche = convertToRuleSch(outSchedules, yearOccu[0..364], schName, model, runner)
	
	# applay Type Limit
	schTypeLimit = schedule.get.getString(2).to_s
	if !schTypeLimit.empty?
		stls = model.getScheduleTypeLimitss
		mstl=[]
		stls.each do |stl|
			if (stl.name.to_s) == schTypeLimit.to_s
				mstl = stl
				break
			end
		end
		ruleSche.setScheduleTypeLimits(mstl)
	end
	
	# applay winter design day
	if yearOccu[366] != -1
		dsch = OpenStudio::Model::ScheduleDay.new(model)
		dsch.setName(schName + ' WDD')
		dsch.clearValues
		allValues = outSchedules[yearOccu[366]][0]  
		allTimes = outSchedules[yearOccu[366]][1]
		(allTimes.zip(allValues)).each do |mEntry|
			dsch.addValue(OpenStudio::Time.new(0,0,mEntry[0],0),mEntry[1])
		end
		ruleSche.setWinterDesignDaySchedule(dsch)
	end
	# applay summer design day
	if yearOccu[367] != -1
		dsch = OpenStudio::Model::ScheduleDay.new(model)
		dsch.setName(schName + ' SDD')
		dsch.clearValues
		allValues = outSchedules[yearOccu[367]][0]  
		allTimes = outSchedules[yearOccu[367]][1]
		(allTimes.zip(allValues)).each do |mEntry|
			dsch.addValue(OpenStudio::Time.new(0,0,mEntry[0],0),mEntry[1])
		end
		ruleSche.setSummerDesignDaySchedule(dsch)
	end
	

	
    #reporting final condition of model
	#get ruleset schedules list
    schedules = model.getScheduleRulesets
	
	# get Compact schedules list
	cSchedules = model.getScheduleCompacts
	
	runner.registerFinalCondition("#{schedules.size} Ruleset schedules \r\n \
	and #{cSchedules.size} Compact schedules are in this model. \r\n \
	Ruleset schedule named : #{ruleSche.name.to_s} was successfully added to the model ")
    

    return true

  end #end the run method

end #end the measure

# register the measure to be used by the application
CompactToRulesetSchedule.new.registerWithApplication
