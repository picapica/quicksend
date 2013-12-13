#!/usr/bin/env osascript

set fileName to "BJ"

global theGText
set theGText to "百思不得姐" & return & ¬
	"" & return & ¬
	"昨天在酒吧看到一个美女，好想上去搭讪，这时脑海里有个声音对我说：想想你的妻子吧！我想了想，确实不如眼前这个漂亮阿！" & return & ¬
	"" & return & ¬
	"看更多内涵小段子，点下面链接⬇" & return & ¬
	"http://ums.bz/OVQMa0/"

global myAccountName
set myAccountName to "E:liulantao.com@gmail.com"

global fileName
global fileList
global currentFileIndex
global dataFilePath
global logFilePath
global sentFilePath
global errFilePath
global allLogPath
global clickCommand
global commonHandlers
global phoneNumbers
global logFolder

set fileList to {}
set currentFileIndex to 1
set phoneNumbers to {}

tell application "Finder" to set theContainer to container of (path to me)

set dataFolder to (theContainer as text) & "data:"
set logFolder to (theContainer as text) & "log:"
set clickCommand to (POSIX path of ((theContainer as text) & "cliclick") & " -r c:")

set dataFilePath to (dataFolder & fileName & ".txt")
set errFilePath to POSIX path of (logFolder & "failed_" & fileName)
set sentFilePath to POSIX path of (logFolder & "sent_" & fileName)
set logFilePath to POSIX path of (logFolder & "TBD_" & fileName)
set allLogPath to POSIX path of (logFolder & "all")

set commonHandlers to commonHandlersScript

tell application "Messages" to activate

delay 2


--load phone numbers from the data file
set startLine to getStartLineFromLog()

readPhoneNumbers()
set theCount to count of phoneNumbers
if theCount = 0 then
	display dialog (fileName & " is empty!") buttons {"OK"} default button 1
	return
end if


repeat with i from startLine to theCount
	set theNumber to item i of phoneNumbers
	-- strip
	set whiteSpace to {character id 10, return, space, tab}
	set theNumber to theNumber's text 1 thru -2
	set target to (theNumber as text)
	
	sendMessage(target)
	delay 0.5
	
	repeat with j from 1 to 20
		if isDelivered() then
			log_event((theNumber as text) & " " & fileName & "," & i, sentFilePath) of commonHandlers
			exit repeat
		end if
		
		if handleFailedChats() then
			exit repeat
		end if
		
		set thePosition to detectExclaimation()
		if (count of thePosition) = 2 then
			do shell script clickCommand & (thePosition's item 1 as text) & "," & (thePosition's item 2 as text)
		end if
		if j = 10 then
			log_event((theNumber as text) & " " & fileName & "," & i, logFilePath) of commonHandlers
		else
			delay 0.2
		end if
	end repeat
	
	clearExistedChatsAndBuddies()
	log i
	log_event(fileName & "," & i, allLogPath) of commonHandlers
	if shouldAbort() then
		display dialog ("Unknown error, abort!") buttons {"OK"} default button 1
		return
	end if
end repeat

display dialog fileName & " was processed." buttons {"Okay"}

on readPhoneNumbers()
	tell application "TextEdit"
		if (count phoneNumbers) = 0 then
			set theDoc to open file dataFilePath
			copy paragraphs of the text of theDoc to phoneNumbers
			close theDoc saving no
		end if
		
		set theNumbers to {}
		set nAll to count phoneNumbers
		
		set lineNumber to 0
		set nRemain to nAll - lineNumber
		if nRemain = 0 then return {}
		set nBatch to 5
		if nRemain > nBatch then set nRemain to nBatch
		repeat with i from lineNumber + 1 to lineNumber + nRemain
			set theNumbers to theNumbers & ((item i of phoneNumbers) as text)
		end repeat
		set lineNumber to lineNumber + nRemain
		return theNumbers
	end tell
end readPhoneNumbers

on sendMessage(theNumber)
	tell application "Messages"
		set target to (theNumber)
		send theGText to buddy (target) of service (myAccountName)
	end tell
end sendMessage

on clearExistedChatsAndBuddies()
	tell application "Messages"
		set theNumber to count text chats
		repeat with i from theNumber to 1 by -1
			delete item i of text chats
			dismissPopupHandler() of commonHandlers
		end repeat
	end tell
end clearExistedChatsAndBuddies

on handleFailedChats()
	set isFailed to false
	tell application "System Events"
		tell application process "Messages"
			set numWindows to count windows
			set {theText} to {missing value}
			repeat with num from numWindows to 1 by -1
				set theWindow to window num
				set numTexts to count static texts of theWindow
				if numTexts > 1 then
					set theText to name of static text 1 of theWindow
					if theText contains "Your message could not be sent." then
						set theError to name of static text 2 of theWindow
						log_event(theError, errFilePath) of commonHandlers
						click button "OK" of theWindow
						set isFailed to true
					end if
				else if exists (sheet 1 of theWindow) then
					set theSheet to sheet 1 of theWindow
					set numTexts to count static texts of theSheet
					if numTexts > 1 then
						set theText to name of static text 1 of theSheet
						if theText contains "Your message could not be sent." then
							set theError to name of static text 2 of theSheet
							log_event(theError, errFilePath) of commonHandlers
							if exists (button "OK" of theSheet) then
								click button "OK" of theSheet
								set isFailed to true
							end if
							if exists (button "Try again" of sheet 1 of theWindow) then
								click button "Try again" of sheet 1 of theWindow
								set isFailed to false
							end if
						end if
					end if
				end if
			end repeat
		end tell
	end tell
	return isFailed
end handleFailedChats

on shouldAbort()
	tell application "System Events"
		tell application process "Messages"
			set numWindows to count windows
			if numWindows > 3 then
				return true
			end if
			repeat with i from 1 to numWindows
				if exists (sheet 1 of window i) then
					return true
				end if
			end repeat
		end tell
	end tell
	return false
end shouldAbort

script commonHandlersScript
	on dismissPopupHandler()
		tell application "System Events"
			tell application process "Messages"
				set numWindows to count windows
				repeat with num from numWindows to 1 by -1
					set theWindow to window num
					if exists (button "Close" of sheet 1 of theWindow) then
						click button "Close" of sheet 1 of theWindow
					end if
					if exists (button "Ok" of sheet 1 of theWindow) then
						click button "Ok" of sheet 1 of theWindow
					end if
				end repeat
			end tell
		end tell
	end dismissPopupHandler
	
	on log_event(themessage, pathName)
		--set theLine to (do shell script ¬
		--	"date  +'%Y-%m-%d %H:%M:%S'" as string) ¬
		--	& " " & themessage
		set theLine to themessage
		do shell script "echo \"" & theLine & ¬
			"\" >> " & pathName & ".log"
	end log_event
	
	on splitText(theString, theDelimiter)
		-- save delimiters to restore old settings
		set oldDelimiters to AppleScript's text item delimiters
		-- set delimiters to delimiter to be used
		set AppleScript's text item delimiters to theDelimiter
		-- create the array
		set theArray to every text item of theString
		-- restore the old setting
		set AppleScript's text item delimiters to oldDelimiters
		-- return the result
		return theArray
	end splitText
end script

on detectExclaimation()
	tell application "System Events"
		tell application process "Messages"
			set frontmost to true
			set {windowExists} to {window "Messages" exists}
			if not windowExists then
				return {}
			end if
			set theWindow to window "Messages"
			if not (exists (UI element 1 of scroll area 3 of splitter group 1 of theWindow)) then return {}
			if not (exists (group 2 of UI element 1 of scroll area 3 of splitter group 1 of theWindow)) then return {}
			if not (exists (group 1 of group 2 of UI element 1 of scroll area 3 of splitter group 1 of theWindow)) then return {}
			
			set theTextProperties to properties of group 1 of group 2 of UI element 1 of scroll area 3 of splitter group 1 of theWindow
			set theBoxProperites to properties of group 2 of UI element 1 of scroll area 3 of splitter group 1 of theWindow
			set theAreaProperties to properties of UI element 1 of scroll area 3 of splitter group 1 of theWindow
			
			if position of theAreaProperties = missing value or size of theAreaProperties = missing value then return {}
			if position of theBoxProperites = missing value or size of theBoxProperites = missing value then return {}
			if position of theTextProperties = missing value or size of theTextProperties = missing value then return {}
			
			set x1 to ((item 1 of position of theAreaProperties) + (item 1 of size of theAreaProperties))
			set x2 to ((item 1 of position of theBoxProperites) + (item 1 of size of theBoxProperites))
			set theDiff to x1 - x2
			if theDiff > 60 then
				set theHiddenButtonX to ((item 1 of position of theAreaProperties) + (item 1 of size of theAreaProperties) - 25)
				set theHiddenButtonY to ((item 2 of position of theTextProperties) + (item 2 of size of theTextProperties))
				return {theHiddenButtonX, theHiddenButtonY}
			end if
		end tell
	end tell
	return {}
end detectExclaimation

on isDelivered()
	tell application "System Events"
		tell application process "Messages"
			set delivered to exists (static text "Delivered" of UI element 1 of scroll area 3 of splitter group 1 of window "Messages")
			return delivered
		end tell
	end tell
end isDelivered

on getStartLineFromLog()
	tell application "TextEdit"
		set startLine to 1
		set theDoc to open file (logFolder & "all.log")
		set theParagraphs to paragraphs of the text of theDoc
		set theNumber to count of theParagraphs
		if theNumber > 0 then
			set theLine to item theNumber of theParagraphs
			set theArr to splitText(theLine as text, ",") of commonHandlers
			if ((count of theArr) > 1) and (fileName = (item 1 of theArr as text)) then
				set startLine to (((item 2 of theArr) as number) + 2)
			end if
		end if
		close theDoc saving no
	end tell
	return startLine
end getStartLineFromLog
