#pragma rtGlobals=1		// Use modern global access method
#include <AxisSlider>
#include <TransformAxis1.2>

//Igor support for PPMS data loading and plotting
// v. 0.3b3
// by Peter Beaucage (pab275@cornell.edu)
//
// Revision history:

// 0.3:
// - Added a transformed axis option for field periodicity in flux sweeps
// - Added plotting (& generation of) -log(-moment) to visualize transition onsets.
// - Rewrote loader to avoid prompt for duplicate variables.
// - Corrected bug for normalized moment.


Menu "PPMS"
	"Load PPMS Data File",PPMS_LoadData()
	"---"
	Submenu "VSM Plots"
		"NegLogNeg Normalized Moment vs Temperature",PPMS_NegLogNegMomentVsTempPlot()
		"NegLogNeg Normalized Moment vs Field",PPMS_NegLogNegMomentVsFieldPlot()
		"---"
		"Normalized Moment vs Temperature",PPMS_NormMomentVsTempPlot()
		"Normalized Moment vs Field",PPMS_NormMomentVsFieldPlot()
		"---"
		"Raw Moment vs Temperature",PPMS_MomentVsTempPlot()
		"Raw Moment vs Field",PPMS_MomentVsFieldPlot()
	End
	Submenu "VSM Plot Tools"
		"Add Field Periodicity Axis to Top Graph",PPMS_AddFieldPeriodicityAxis()
	End
	Submenu "Resistivity Plots"
		"Resistance vs Temperature"
		"Resistance vs Field"
	End
End Menu

function PPMS_LoadData()
	Variable refNum,refNum2,header,currentLineNum,stopLoop
	String fileToLoadPath,dataFileName,justReadLine
	
	Open /D /R /F="Data Files (*.dat):.dat;All Files:.*;" /M="Select data file to load" refNum
	fileToLoadPath = S_fileName
	print fileToLoadPath
	if(StringMatch(fileToLoadPath,""))
		abort("Error: You didn't select a file.")
	endif
	
	dataFileName = ParseFilePath(3,fileToLoadPath,":",0,0)
	
	Open/R refNum2 as fileToLoadPath
	newdatafolder/o/s $("root:"+dataFileName)
	
	currentLineNum=0
	stopLoop=0
	String /G dataFileHeader = ""
	String columnInfoStr = ""
	Variable /G sampleMass
	do
		FReadLine refNum2, justReadLine
		if(StringMatch(justReadLine,"*[Data]*"))
			header = currentLineNum + 1
			FReadLine refNum2, justReadLine
			Variable numItems = ItemsInList(justReadLine,","), i
  			for(i=0; i<numItems; i+=1)
          	columnInfoStr += "C=1,F=0,T=2,N='"
          	String variableName = StringFromList(i,justReadLine,",")
          	variableName = ReplaceString("'",variableName,"d")
          	variableName = ReplaceString("\"",variableName,"d2")
          	variableName = ReplaceString("µ",variableName,"u")
          	variableName = ReplaceString("\r",variableName,"")
          	variableName = ReplaceString("\n",variableName,"")
          	variableName = ReplaceString(" ",variableName,"_")
          	variableName = ReplaceString(".",variableName,"_")
          	variableName = ReplaceString("(",variableName,"_")
          	variableName = ReplaceString(")",variableName,"_")
          	columnInfoStr += variableName
          	columnInfoStr += "';"
  			endfor
  		
			stopLoop=1
		endif
		if(StringMatch(justReadLine,"*SAMPLE_MASS*"))
			sampleMass = str2num(StringFromList(1,justReadLine,","))
		endif
		dataFileHeader = dataFileHeader + justReadLine
		currentLineNum += 1
	while(stopLoop==0)
	
	print "Header:"
	print dataFileHeader

	if(SampleMass > 0)
	else
		variable samplemasstemp
		Prompt samplemasstemp,"Valid Sample Mass Not Found, Enter/Estimate Sample Mass (mg) for "+dataFileName
		DoPrompt "Enter Sample Parameters" samplemasstemp
		SampleMass = samplemasstemp
	endif
	LoadWave/J/D/W/A/B=columnInfoStr/K=0/L={header,header+1,0,0,0} fileToLoadPath
	PPMS_ComputeTempandFieldErrors()
	PPMS_ComputeNormMoment()
	PPMS_ComputeNegLogNeg()
	Variable/G firstPoint = 0
	Variable/G lastPoint = numpnts(Temperature__K_)
	
end

function PPMS_ComputeTempandFieldErrors()

	Wave Max__Temperature__K_, Min__Temperature__K_, Temperature__K_,Magnetic_Field__Oe_,Min__Field__Oe_,Max__Field__Oe_

	Make/D/O/N=(numpnts(Temperature__K_)) TempErrorPos,TempErrorNeg,FieldErrorPos,FieldErrorNeg
	
	TempErrorPos = Max__Temperature__K_ - Temperature__K_
	TempErrorNeg = Temperature__K_ - Min__Temperature__K_
	
	FieldErrorPos = Max__Field__Oe_ - Magnetic_Field__Oe_
	FieldErrorNeg = Magnetic_Field__Oe_ - Min__Field__Oe_
end

function PPMS_ComputeNormMoment()
	WAVE Moment__emu_,M__Std__Err___emu_,Temperature__K_
	Variable /G SampleMass
	
	Make/D/O/N=(numpnts(Temperature__K_)) NormMoment__emug_, NormMStdErr_
	
		NormMoment__emug_ = Moment__emu_ / (SampleMass/1000)
		NormMStdErr_ = M__Std__Err___emu_ / (SampleMass/1000)
end

function PPMS_ComputeNegLogNeg()
	WAVE NormMoment__emug_
	
	duplicate NormMoment__emug_ NegLogNegNormMoment__emug_
	NegLogNegNormMoment__emug_ = -log(-NormMoment__emug_)
end


Function TransAx_FieldPerOe(w, val)
	Wave/Z w
	Variable val
	
	if(val==0)
		return 0
	else
		return sqrt(abs(2.0678338e7/val))
	endif
end

Function TransAx_FieldPerAm(w, val)
	Wave/Z w
	Variable val
	
	if(val==0)
		return 0
	else
		return sqrt(abs(2.0678338e7/(val*(4*pi)/10^3)))
	endif
end


function PPMS_AddFieldPeriodicityAxis()
	SetupTransformMirrorAxis(WinName(0,1),"bottom","TransAx_FieldPer",$"",3,1,5,1)
	Label MT_bottom "Field Periodicity (nm)"
end

function PPMS_NormMomentVsFieldPlot()
	PPMS_SelectData()
	
	Wave Temperature__K_
	Variable /G firstPoint, lastPoint
	
	String currentFolder = GetDataFolder(0)
	String temperature = Num2Str(Temperature__K_(firstPoint))

	Display NormMoment__emug_[firstPoint,lastPoint] vs Magnetic_Field__Oe_[firstPoint,lastPoint]
	ModifyGraph mode=3,msize=2
	ErrorBars NormMoment__emug_ XY,wave=(FieldErrorPos[firstPoint,lastPoint],FieldErrorNeg[firstPoint,lastPoint]),wave=(NormMStdErr_[firstPoint,lastPoint],NormMStdErr_[firstPoint,lastPoint])
	Label left "Magnetic Moment (emu/g)"
	Label bottom "Magnetic Field (Oe)"
	TextBox/C/N=text0/A=MC "PPMS-VSM Moment vs Field\r" + currentFolder + "\rT=" + temperature + " K"
end
	
function PPMS_NormMomentVsTempPlot()
	PPMS_SelectData()

	Wave Magnetic_Field__Oe_
	Variable /G firstPoint, lastPoint
	
	String currentFolder = GetDataFolder(0)
	String field = Num2Str(Magnetic_Field__Oe_(firstPoint))
	
	Display NormMoment__emug_[firstPoint,lastPoint] vs Temperature__K_[firstPoint,lastPoint]
	ModifyGraph mode=3,msize=2
	ErrorBars NormMoment__emug_ XY,wave=(TempErrorPos[firstPoint,lastPoint],TempErrorNeg[firstPoint,lastPoint]),wave=(NormMStdErr_[firstPoint,lastPoint],NormMStdErr_[firstPoint,lastPoint])
	Label left "Magnetic Moment (emu/g)"
	SetAxis left *,0
	SetAxis bottom 2,12
	Label bottom "Temperature (K)"
	TextBox/C/N=text0/A=MC "PPMS-VSM Moment vs Temperature\r" + currentFolder + "\rField=" + field + " Oe"
end

function PPMS_NegLogNegMomentVsFieldPlot()
	PPMS_SelectData()
	
	Wave Temperature__K_
	Variable /G firstPoint, lastPoint
	
	String currentFolder = GetDataFolder(0)
	String temperature = Num2Str(Temperature__K_(firstPoint))

	Display NegLogNegNormMoment__emug_[firstPoint,lastPoint] vs Magnetic_Field__Oe_[firstPoint,lastPoint]
	ModifyGraph mode=3,msize=2
	Label left "-log(-Magnetic Moment) (emu/g)"
	Label bottom "Magnetic Field (Oe)"
	TextBox/C/N=text0/A=MC "PPMS-VSM Moment vs Field\r" + currentFolder + "\rT=" + temperature + " K"
end
	
function PPMS_NegLogNegMomentVsTempPlot()
	PPMS_SelectData()

	Wave Magnetic_Field__Oe_
	Variable /G firstPoint, lastPoint
	
	String currentFolder = GetDataFolder(0)
	String field = Num2Str(Magnetic_Field__Oe_(firstPoint))
	
	Display NegLogNegNormMoment__emug_[firstPoint,lastPoint] vs Temperature__K_[firstPoint,lastPoint]
	ModifyGraph mode=3,msize=2
	Label left "-log(-Magnetic Moment) (emu/g)"
	SetAxis left *,0
	SetAxis bottom 2,12
	Label bottom "Temperature (K)"
	TextBox/C/N=text0/A=MC "PPMS-VSM Moment vs Temperature\r" + currentFolder + "\rField=" + field + " Oe"
end

function PPMS_MomentVsFieldPlot()
	PPMS_SelectData()
	
	Wave Temperature__K_
	Variable /G firstPoint, lastPoint
	
	String currentFolder = GetDataFolder(0)
	String temperature = Num2Str(Temperature__K_(firstPoint))

	Display Moment__emu_[firstPoint,lastPoint] vs Magnetic_Field__Oe_[firstPoint,lastPoint]
	ModifyGraph mode=3,msize=2
	ErrorBars Moment__emu_ XY,wave=(FieldErrorPos[firstPoint,lastPoint],FieldErrorNeg[firstPoint,lastPoint]),wave=(M__Std__Err___emu_[firstPoint,lastPoint],M__Std__Err___emu_[firstPoint,lastPoint])
	Label left "Magnetic Moment (emu)"
	Label bottom "Magnetic Field (Oe)"
	TextBox/C/N=text0/A=MC "PPMS-VSM Moment vs Field\r" + currentFolder + "\rT=" + temperature + " K"
end
	
function PPMS_MomentVsTempPlot()
	PPMS_SelectData()

	Wave Magnetic_Field__Oe_
	Variable /G firstPoint, lastPoint
	
	String currentFolder = GetDataFolder(0)
	String field = Num2Str(Magnetic_Field__Oe_(firstPoint))
	
	Display Moment__emu_[firstPoint,lastPoint] vs Temperature__K_[firstPoint,lastPoint]
	ModifyGraph mode=3,msize=2
	ErrorBars Moment__emu_ XY,wave=(TempErrorPos[firstPoint,lastPoint],TempErrorNeg[firstPoint,lastPoint]),wave=(M__Std__Err___emu_[firstPoint,lastPoint],M__Std__Err___emu_[firstPoint,lastPoint])
	Label left "Magnetic Moment (emu)"
	SetAxis left *,0
	SetAxis bottom 2,12
	Label bottom "Temperature (K)"
	TextBox/C/N=text0/A=MC "PPMS-VSM Moment vs Temperature\r" + currentFolder + "\rField=" + field + " Oe"
end

//begin data selection +GUI code...
function PPMS_SelectData()
	Variable numberOfFolders, i
	String folderName,listOfFolderNames,dataFolder
	DFREF rootDFR
	
	SetDataFolder root:
	rootDFR = GetDataFolderDFR()
	
	folderName = ""
	listOfFolderNames = ""
	dataFolder = ""
	
	numberOfFolders = CountObjectsDFR(rootDFR,4)
	
	for(i=0;i< numberOfFolders;i+= 1)
		folderName = GetIndexedObjNameDFR(rootDFR,4,i)
		
		listOfFolderNames += ""
		listOfFolderNames += folderName
		listOfFolderNames += ";"
	endfor
	
	Prompt dataFolder, "Data to use", popup listOfFolderNames
	DoPrompt "Select Dataset", dataFolder
	
	if(V_flag == 1)
		Abort
	endif
	SetDataFolder dataFolder
	Variable /G firstPoint, lastPoint
	Variable first, last
	Wave Temperature__K_
	PPMS_DataPointGuide()
end

function PPMS_DataPointGuide()
	Wave Temperature__K_,Magnetic_Field__Oe_,Time_Stamp__sec_
	Display /K=1/N=PPMS_DPS_Tvst Temperature__K_  as "Temperature vs Point #"
	Label left, "Temperature (K)"
	Label bottom, "Point #"
	ControlBar 35
	SetVariable setFirstPoint,pos={1,2},size={200,15},title="First Point #: "
	SetVariable setFirstPoint,value= firstPoint
	SetVariable setLastPoint,pos={1,20},size={200,15},title="Last Point #: "
	SetVariable setLastPoint,value= lastPoint
	Button readCrsrA,pos={200,1},size={100,16},proc=ReadCursorA,title="Read Cursor A"
	Button readCrsrB,pos={199,18},size={100,16},proc=ReadCursorB,title="Read Cursor B"
	Button closeDataSelection,pos={432,9},size={100,20},proc=CloseDataPointGuide,title="Done!"


	ShowInfo
	Display /K=1 /N=PPMS_DPS_Fvst Magnetic_Field__Oe_  as "Field vs Point #"
	Label left, "Magnetic Field (Oe)"
	Label bottom, "Point #"
	ControlBar 35
	SetVariable setFirstPoint,pos={1,2},size={200,15},title="First Point #: "
	SetVariable setFirstPoint,value= firstPoint
	SetVariable setLastPoint,pos={1,20},size={200,15},title="Last Point #: "
	SetVariable setLastPoint,value= lastPoint
	Button readCrsrA,pos={200,1},size={100,16},proc=ReadCursorA,title="Read Cursor A"
	Button readCrsrB,pos={199,18},size={100,16},proc=ReadCursorB,title="Read Cursor B"
	Button closeDataSelection,pos={432,9},size={100,20},proc=CloseDataPointGuide,title="Done!"

	ShowInfo
	Execute "TileWindows /R/W=(5,5,20,50)/A=(2,1)/G=7 PPMS_DPS_Tvst, PPMS_DPS_Fvst"
	PauseForUser PPMS_DPS_Fvst, PPMS_DPS_Tvst
end

Function ReadCursorA(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			Variable/G firstPoint = NumberByKey("POINT",CsrInfo(A))
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End
Function ReadCursorB(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			Variable/G lastPoint = NumberByKey("POINT",CsrInfo(B))
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End
Function CloseDataPointGuide(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			DoWindow/K PPMS_DPS_Tvst
			DoWindow /K PPMS_DPS_Fvst
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End
