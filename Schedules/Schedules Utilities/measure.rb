# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class ScheduleUtilities < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Schedule Utilities"
  end

  # human readable description
  def description
    return "The Measure creates new Ruleset Schedule according to the simple formula entered operated on up to two Ruleset Schedules selected from the model"
  end

  # human readable description of modeling approach
  def modeler_description
    return "A and B are the operands corresponding to the selected schedules A and B. The entered formula can use operators + - * and / any float numbers and at least one operand. Brackets are allowed. All Operations are carried minute by minute. The division is the only irregular operator; when the enumerator is an operand it's meaning is (schedule value != 0), so the output would be Boolean represented by zeroes and ones"
  end
	
 
 # carry operation on two day Schedules and return time (minutes from midnight) and values vector ( similar to day schedule style)
	def opDaySch( sch_1, sch_2, op, model, runner)
		allTimes = []
		allValues = []
		if ( sch_1.class == Float or  sch_2.class == Float)
			if  sch_1.class == Float
				#runner.registerInfo("#{sch_2.name.to_s} times size: #{sch_2.times.length.to_s}") ### Debug ###########################
				sch_2.times.each do |mtime|
					allTimes << (mtime.totalMinutes.to_i)
					allValues << sch_2.getValue(OpenStudio::Time.new(0,0,allTimes.last,0))	
				end
				
				opd = sch_1
				pre = 1
			else
				#runner.registerInfo("#{sch_1.name.to_s} times size: #{sch_1.times.length.to_s}") ### Debug ###########################
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
		#runner.registerInfo("dayScheds_1[0].name: #{dayScheds_1[0].name.to_s}") ### Debug ###########################
		#runner.registerInfo("dayScheds_1[1].name: #{dayScheds_1[1].name.to_s}") ### Debug ###########################
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
	def convertToRullSch(inSchedules,yearOccu,schName,model,runner)
		theYear = yearOccu
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
				endInd = daysPatern[1] - 1 # match almost all is also OK ????????????????
				workPat = wdays[uniqDaysIndex[i]][startInd..endInd+1] # holds the patern to work with
				workLen = endInd - startInd + 2 # size of patern ???????????????????????
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
				patFirst = workPat.index(patDaySch)
				workLen == 1 ? patLast = patFirst : patLast = workLen - 1 - workPat.reverse.index(patDaySch)
				yearStartDay = patFirst * 7 + uniqDaysIndex[i]
				yearEndDay = patLast * 7 + uniqDaysIndex[i]
				ruleDays = [0,0,0,0,0,0,0]
				ruleDays[weekDays[uniqDaysIndex[i] - 1]] = weekDays[uniqDaysIndex[i] - 1 ]
				# if there are similar days 
				if daysSim[uniqDaysIndex[i]][0] != 0 
					lastSimDay = daysSim[uniqDaysIndex[i]].last - 1
					yearEndDay = patLast * 7 + lastSimDay
					daysSim[uniqDaysIndex[i]].each do |dsim|
						ruleDays[weekDays[dsim - 1 ] = weekDays[dsim - 1 ]]
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
					yearStartDay = (patFirst + nextDaySchStart) * 7 + uniqDaysIndex[i]
					yearEndDay = (patFirst + nextDaySchEnd) * 7 + uniqDaysIndex[i]
					# if there are similar days 
					if daysSim[uniqDaysIndex[i]][0] != 0 
						lastSimDay = daysSim[uniqDaysIndex[i]].last - 1
						yearEndDay = (patFirst + nextDaySchEnd) * 7 + lastSimDay
					end # daysSim
					yearEndDay > 364? yearEndDay = 364 : yearEndDay = yearEndDay
					rulesTable.insert(nextRuleInd, [nextDaySch,yearStartDay,yearEndDay,ruleDays])
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
		if outSchedules != inSchedules or outSchYO != yearOccu 
			#runner.registerError("Resulting Ruleset schedule is not coherente with the formula output") 
		end
		
		
		return rullSetSchedule
	end
 
 
 # convert time (minutes from midnight) and values vectors ( similar to day schedule style) of all year into a compact Schedule
	def convertToCompactSch(inSchedules,yearOccu,schName,model,runner)
 
 
	end # convertToCompactSch
	
	def isVarValid(mystr, maxvar)
		return false if mystr.length > 2 
		i = 0
		if mystr.length == 2
			return false if (mystr[0] != '-' and mystr[0] != '+')
			i = 1
		end
		return false if ( mystr[i].ord < 'A'.ord or mystr[i].ord > maxvar.ord )
		return true
	  end
	
	def areParenthesesValid(mystr)
		valid = true
		mystr.gsub(/[^\(\)]/, '').split('').inject(0) do |counter, parenthesis|
		  counter += (parenthesis == '(' ? 1 : -1)
		  valid = false if counter < 0
		  counter
		end.zero? && valid
	  end
	
	def isNumeric(mystr)
		return true if mystr =~ /\A\d+\Z/
		true if Float(mystr) rescue false
	  end

	def indices(mystr, e) 
		start, result = -1, []
		result << start while start = (mystr.index e, start + 1)
		result
	  end
	
	def evalFormula(formula,level = 0, runner)
		if level > 25
			return 0,[6,'Formula is too nested']
		end
		if !areParenthesesValid(formula)
			return 0,[1,'Unblanced Parentheses']
		end
		doubleOp = formula.gsub(/[\da-zA-Z.()]/,' ').split(' ')
		# runner.registerInfo("doubleOp: #{doubleOp.to_s} ") ### Debug ###########################
		if (doubleOp.inject(0){|memo,v| v.length >1 ? memo +=1: memo=memo}) > 0
			opLen = doubleOp.map{|v| v.length}
			errorOpsInd = opLen.each_index.select{|i| opLen[i] > 1}
			errorOp = errorOpsInd.map { |i| doubleOp[i] }
			return 0,[2,"#{errorOp.to_s} Illigall Operator"]
		end
		if (errorOp = formula.gsub(/[\da-zA-Z().*+-\/]/,' ').split(' ')) != []
			return 0,[2.1,"#{errorOp.to_s} Illigall Operator"]
		end
		# runner.registerInfo("formula: #{formula.to_s} ") ### Debug ############################
		if formula.split(/[A-Z]/) == 1
			return 0,[3,'Formula missing valid Operande']
		end
		if (formula.count('-') + formula.count('+') + formula.count('*') + formula.count('/')< 1)
			return 0,[4,'Formula missing Operator']
		end
		workFormula = formula.dup.delete(' ')
		formulaOut = []
		while workFormula.length > 1 do
			if workFormula.length == 2
				formulaOut << [level,'*',[workFormula,'var',workFormula[1],false],['-1','num',-1.0,false]]
				return 1, formulaOut
			end #if workFormula.length
			# runner.registerInfo("workFormula: #{workFormula.to_s} ") ### Debug ############################
			if (pPlace = workFormula.index( ')')) != nil
				sPlace = indices(workFormula[0..pPlace], '(').last
				prase = workFormula[(sPlace + 1)...pPlace]
				good, praseOut = evalFormula(prase, level, runner)
				if good == 0 
					return good , praseOut
				end
				# runner.registerInfo("praseOut: #{praseOut.to_s} ") ### Debug ############################
				praseOut.each do |pOut|
					formulaOut << pOut
				end
				# runner.registerInfo("Befor level: #{level.to_s} ") ### Debug ############################
				level += praseOut.length
				# runner.registerInfo("After level: #{level.to_s} ") ### Debug ############################
				workFormula[sPlace..pPlace] = ('C'.ord + level -1 ).chr
			else
				while workFormula.length > 1 do
					if workFormula.length == 2
						formulaOut << [level,'*',[workFormula,'var',workFormula[1],false],['-1','num',-1.0,false]]
						return 1, formulaOut
					end #if workFormula.length
					ops = []
					workFormula.scan(/[-+*\/]/) {|c| ops << [c, $~.offset(0)[0]]}
					ops.delete_at(0) if ops[0][1] == 0
					workOp = (ops.map {|v| [(v[0].ord - '*'.ord + 1)%6,v[0],v[1]]}).sort.map{|v| v[1..2]}.first
					workVars = (workFormula[1...workFormula.length].gsub(/[-+*\/]/, ' ')).insert(0,workFormula[0]).split(' ')
					workVars = workVars.inject([]) {|memo,v| memo == [] ? memo = [[0,v]] : memo<<[memo.last[0]+1+memo.last[1].length,v]}
					curWorkVars = []
					runner.registerInfo("workVars: #{workVars.to_s} ") ### Debug ############################
					runner.registerInfo("workOp: #{workOp.to_s} ") ### Debug ############################
					workVars.each do |workVar|
						# runner.registerInfo("workFormula: #{workFormula.to_s} ") ### Debug ############################
						# runner.registerInfo("level: #{level.to_s} ") ### Debug ############################
						if isNumeric(workVar[1])
							workVar.insert(1,workVar[0] + (workVar[1]).length - 1)
							workVar.push('num')
							workVar.push((workVar[2]).to_f)
							workVar.push(0)
						elsif isVarValid(workVar[1], ('B'.ord + level).chr)
							workVar.insert(1,workVar[0] + (workVar[1]).length - 1)
							workVar.push('var')
							workVar.push(workVar[2][workVar[2].length-1])
							sign = (workVar[2][0]) == '-'
							workVar.push(sign)
						else
							# to do return error
							# runner.registerInfo("workVar in err: #{workVar.to_s} ") ### Debug ############################
							return 0 , [5,"Unrecordnize Varible: #{workVar[1].to_s}"]
						end # if workVar
					end #each workVars
					# runner.registerInfo("workVars: #{workVars.to_s} ") ### Debug ############################
					curWorkVars << workVars[(workVars.transpose[1]).index(workOp[1] - 1)]
					curWorkVars << workVars[(workVars.transpose[0]).index(workOp[1] + 1)]
					# runner.registerInfo("curWorkVars: #{curWorkVars.to_s} ") ### Debug ############################
					formulaOut << [level , workOp[0], curWorkVars[0][2...curWorkVars[0].length], curWorkVars[1][2...curWorkVars[1].length]]
					level += 1
					workFormula[curWorkVars[0][0]..curWorkVars[1][1]] = ('C'.ord + level -1 ).chr
					# runner.registerInfo("level: #{level.to_s} ") ### Debug ############################
					# runner.registerInfo("workFormula: #{workFormula.to_s} ") ### Debug ############################
				end #  2nd while	
			end # if pPlace
		end #while
		return 1, formulaOut
	end # def evalFormula
 
 
 #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

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

    #make an argument for convolving schedule
    a_schedule = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("a_schedule", schedule_handles, schedule_display_names,true)
    a_schedule.setDisplayName("Choose Schedule A.")
    #schedule.setDefaultValue("*No Convolution*")
    args << a_schedule

	#make an argument for target schedule
    b_schedule = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("b_schedule", schedule_handles, schedule_display_names,true)
    b_schedule.setDisplayName("Choose Schedule B.")
    args << b_schedule
	
	# argument for Formula
	formula = OpenStudio::Ruleset::OSArgument::makeStringArgument('formula', false)
	formula.setDisplayName("Enter Formula for schedules A and B")
	formula.setDefaultValue('A*B')
	args << formula
	
	# argument for result schedule name
	resultSchName = OpenStudio::Ruleset::OSArgument::makeStringArgument('resultSchName', false)
	resultSchName.setDisplayName("Result schedule name:")
	resultSchName.setDefaultValue('New Schedule')
	args << resultSchName
	
	# argument for schedule properties inheritance
	choices = OpenStudio::StringVector.new
    choices << "From Schedule A"
    choices << "From Schedule B"
	choices << "Only Type Limits From Schedule A"
	choices << "Only Type Limits From Schedule B"
	choices << "Only Default Days From Schedule A"
	choices << "Only Default Days From Schedule B"
	choices << "Leave Empty"
	schPropInher = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('schPropInher', choices, false)
	schPropInher.setDisplayName("Schedule properties inheritance:")
	schPropInher.setDefaultValue("Leave Empty")
	args << schPropInher

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
    a_schedule = runner.getOptionalWorkspaceObjectChoiceValue("a_schedule",user_arguments,model)
	b_schedule = runner.getOptionalWorkspaceObjectChoiceValue("b_schedule",user_arguments,model)
    formula = runner.getStringArgumentValue("formula", user_arguments)
	resultSchName = runner.getStringArgumentValue("resultSchName", user_arguments)
	schPropInher = runner.getOptionalWorkspaceObjectChoiceValue("schPropInher",user_arguments,model)

    #check the schedule for reasonableness
    
    if a_schedule.empty?
      handle = runner.getStringArgumentValue("a_schedule",user_arguments)
      if handle.empty?
        runner.registerError("No convolving schedule was chosen.")
      else
        runner.registerError("The selected concolving  schedule with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
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
	
	if b_schedule.empty?
      handle = runner.getStringArgumentValue("b_schedule",user_arguments)
      if handle.empty?
        runner.registerError("No target schedule was chosen.")
      else
        runner.registerError("The selected target  schedule with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
      end
      return false
    else
      if not b_schedule.get.to_ScheduleRuleset.empty?
        b_schedule = b_schedule.get.to_ScheduleRuleset.get
      else
        runner.registerError("Script Error - argument not showing up as schedule.")
        return false
      end
    end  #end of if b_schedule.empty?   

	 #get schedules for measure
    schedules = []
    raw_schedules = model.getScheduleRulesets
	schedules = raw_schedules

	#array of all profiles to change
	a_profiles = []

	#push default profiles to array
	default_rule = a_schedule.defaultDaySchedule
	a_profiles << default_rule

	#push profiles to array
	rules = a_schedule.scheduleRules
	rules.each do |rule|
	day_sch = rule.daySchedule
	a_profiles << day_sch
	end

	#add design days to array
	summer_design = a_schedule.summerDesignDaySchedule
	winter_design = a_schedule.winterDesignDaySchedule
	a_profiles << summer_design if !a_schedule.isSummerDesignDayScheduleDefaulted()
	a_profiles << winter_design if !a_schedule.isWinterDesignDayScheduleDefaulted()
	
	#array of all profiles to change
	b_profiles = []

	#push default profiles to array
	default_rule = b_schedule.defaultDaySchedule
	b_profiles << default_rule

	#push profiles to array
	rules = b_schedule.scheduleRules
	rules.each do |rule|
	day_sch = rule.daySchedule
	b_profiles << day_sch
	end

	#add design days to array
	summer_design = b_schedule.summerDesignDaySchedule
	winter_design = b_schedule.winterDesignDaySchedule
	b_profiles << summer_design if !b_schedule.isSummerDesignDayScheduleDefaulted()
	b_profiles << winter_design if !b_schedule.isWinterDesignDayScheduleDefaulted()


    #reporting initial condition of model
    runner.registerInitialCondition("#{schedules.size} schedules are in this model.\r\n \
	Schedule #{a_schedule.name} has #{a_profiles.size} profiles including design days.\r\n \
	Schedule #{b_schedule.name} has #{b_profiles.size} profiles including design days.")
    
    
	good, form = evalFormula(formula, runner)
	
	
	if good == 0 
		runner.registerError("#{form[1].to_s}")
	else
		runner.registerInfo("Formula: #{form.to_s} ")
	end
	
	tempSchedules = []
	memSch = []
	form.each_with_index do |prase, index|
		op = prase[1]
		if prase[2][1]=='var'
			if prase[2][2] == 'A'
				sch_1 = a_schedule
			elsif prase[2][2] == 'B'
				sch_1 = b_schedule
			else
				sch_1 = memSch
			end
			if prase[2][3] == true
				outSchedules, yearOccu = opRullSch( sch_1, -1.0 , '*', model, runner)
				sch_1 = convertToRullSch(outSchedules, yearOccu,'__Temp',model,runner)
				tempSchedules << sch_1
			end
		else
			sch_1 = prase[2][2]
		end
		if prase[3][1]=='var'
			if prase[3][2] == 'A'
				sch_2 = a_schedule
			elsif prase[3][2] == 'B'
				sch_2 = b_schedule
			else
				sch_2 = memSch
			end
		else
			sch_2 = prase[3][2]
		end
		if op == '/' and sch_2.class == Float and sch_2 == 0
			runner.registerError("Divide by Zero")
			return false
		end
		if (sch_1.class == Float and sch_2.class == Float)
			case op
			when '+'
				memSch = sch_1 + sch_2
			when '-'
				memSch = sch_1 - sch_2
			when '*'
				memSch = sch_1 * sch_2
			when '/'
				memSch = sch_1 / sch_2
			else
			end
		else
			schName = '__Temp'
			schName = resultSchName if index == form.length-1
			outSchedules, yearOccu = opRullSch( sch_1, sch_2 , op, model, runner)
			runner.registerInfo("outSchedules: #{outSchedules.to_s} ") ### Debug ###########################
			memSch = convertToRullSch(outSchedules, yearOccu,schName,model,runner)
			runner.registerInfo("memSch name: #{memSch.name.to_s} ") ### Debug ###########################
			tempSchedules << memSch if index < form.length-1
		end
	end #for.each
	
	# delete temp schedules
	tempSchedules.each do |tempSchedule|
		tempSchedule.remove
	end
	
	# set Rullset Schedule properties
	case schPropInher
	when "From Schedule A"
		memSch.setScheduleTypeLimits(a_schedule.scheduleTypeLimits)
		memSch.setSummerDesignDaySchedule(a_schedule.summerDesignDaySchedule)
		memSch.setWinterDesignDaySchedule(a_schedule.winterDesignDaySchedule)
	when "From Schedule B"
		memSch.setScheduleTypeLimits(b_schedule.scheduleTypeLimits)
		memSch.setSummerDesignDaySchedule(b_schedule.summerDesignDaySchedule)
		memSch.setWinterDesignDaySchedule(b_schedule.winterDesignDaySchedule)
	when "Only Type Limits From Schedule A"
		memSch.setScheduleTypeLimits(a_schedule.scheduleTypeLimits)
	when "Only Type Limits From Schedule B"
		memSch.setScheduleTypeLimits(b_schedule.scheduleTypeLimits)
	when "Only Default Days From Schedule A"
		memSch.setSummerDesignDaySchedule(a_schedule.summerDesignDaySchedule)
		memSch.setWinterDesignDaySchedule(a_schedule.winterDesignDaySchedule)
	when "Only Default Days From Schedule B"
		memSch.setSummerDesignDaySchedule(b_schedule.summerDesignDaySchedule)
		memSch.setWinterDesignDaySchedule(b_schedule.winterDesignDaySchedule)
	else # do nothing
	end
	
	
    #reporting final condition of model
	#get schedules for measure
    schedules = []
    raw_schedules = model.getScheduleRulesets
	schedules = raw_schedules


	#array of all profiles to change
	o_profiles = []

	#push default profiles to array
	default_rule = memSch.defaultDaySchedule
	o_profiles << default_rule

	#push profiles to array
	rules = memSch.scheduleRules
	rules.each do |rule|
	day_sch = rule.daySchedule
	o_profiles << day_sch
	end

	#add design days to array
	summer_design = memSch.summerDesignDaySchedule
	winter_design = memSch.winterDesignDaySchedule
	o_profiles << summer_design if !memSch.isSummerDesignDayScheduleDefaulted()
	o_profiles << winter_design if !memSch.isWinterDesignDayScheduleDefaulted()
	
    # if apply_to_all_schedules
	runner.registerFinalCondition("#{schedules.size} schedules are in this model.\r\n \
	Schedule #{memSch.name} was created and has #{o_profiles.size} profiles including design days.")
      
    return true

  end #end the run method

end #end the measure

# register the measure to be used by the application
ScheduleUtilities.new.registerWithApplication
