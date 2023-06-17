#cs ----------------------------------------------------------------------------

 AutoIt Version: 3.3.14.2
 Authors:         TheSaint
					jchd (improved sqlite code)
 Script Function: Find & Fix missing or wrong size ebook covers on a Kobo device.
	Template AutoIt script.

#ce ----------------------------------------------------------------------------

; FUNCTIONS
; DropboxGUI(), ImagesGUI(), SettingsGUI(), ViewerGUI()
; CheckForAlternateDrive($button), CreateFromImage($input, $output, $img), FindEbookImages(), GetContent(), GetDrives($device)
; GetImageDetails($picfile), GetMappedImage($prior, $next, $entries), GetOthers(), LoadTheList()
; _UserFunc($entries, $rows)

#include <Constants.au3>
#include <GUIConstantsEx.au3>
#include <ButtonConstants.au3>
#include <ComboConstants.au3>
#include <EditConstants.au3>
#include <ListViewConstants.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>
#include <AutoItConstants.au3>
#include <Misc.au3>
#include <GuiListView.au3>
#include <GuiListBox.au3>
#include <File.au3>
#include <Array.au3>
#include <SQLite.au3>
#include <SQLite.dll.au3>
#include <GDIPlus.au3>
#include <WinAPI.au3>
#include <ScreenCapture.au3>
#include "GDIP.au3"

_Singleton("kobo-cover-fixer-thsaint")

Global $Group_ebooks, $ListView_ebooks

Global $ans, $altfold, $author, $blackjpg, $button, $continue, $covers, $detail, $devfile, $device, $dpi, $drive, $drives
Global $Dropbox, $e, $ebooks, $emptyfle, $entries, $entry, $ents, $file, $filelist, $foldtxt, $high1, $high2, $high3, $icoC
Global $icoD, $icoF, $icoI, $icoO, $icoR, $icoS, $icoT, $icoX, $idx, $image1, $image2, $image3, $imageID, $images, $img
Global $imgfold, $imghigh, $imgwidth, $inifle, $input, $logfile, $lowid, $mapfile, $missfle, $OptionsGUI, $output, $picfile
Global $placebo, $placetxt, $psize, $recfile, $resfile, $ResultsGUI, $rows, $shell, $sort, $sqlfile, $sqlite, $title, $update
Global $updated, $use, $user32, $val, $version, $wide1, $wide2, $wide3

Global $item1, $item3, $item4, $items, $lastID, $mapini, $next, $others, $pic_eight, $pic_five, $pic_four, $pic_nine, $pic_one, $pic_seven
Global $pic_six, $pic_three, $pic_two, $prior, $row

$blackjpg = @ScriptDir & "\Black.jpg"
$covers = @ScriptDir & "\Ebook Covers"
$ebooks = @ScriptDir & "\Ebooks.txt"
$emptyfle = @ScriptDir & "\Empty.txt"
$foldtxt = @ScriptDir & "\Folders.txt"
$inifle = @ScriptDir & "\Settings.ini"
$logfile = @ScriptDir & "\Log.txt"
$mapfile = @ScriptDir & "\Mapped.txt"
$mapini = @ScriptDir & "\Mapped.ini"
$missfle = @ScriptDir & "\Missing.txt"
$others = @ScriptDir & "\Others.ini"
$placebo = @ScriptDir & "\Ebook Covers\Placebo"
$placetxt = @ScriptDir & "\Placebo.txt"
$recfile = @ScriptDir & "\Record.ini"
$resfile = @ScriptDir & "\Results.ini"
$sqlfile = @ScriptDir & "\KoboReader.sqlite"
$sqlite = @ScriptDir & "\sqlite3.dll"

$updated = "(updated June 2023)"
$version = "v1.0"

If Not FileExists($covers) Then DirCreate($covers)
If Not FileExists($placebo) Then DirCreate($placebo)

; OS SETTINGS
$user32 = @SystemDir & "\user32.dll"
$shell = @SystemDir & "\shell32.dll"
$icoC = -261
$icoD = -4
$icoF = -85
$icoI = -5
$icoO = -4
$icoR = -239
$icoS = -217
$icoT = -71
$icoX = -4

$wide1 = IniRead($inifle, "Image 1", "width", "")
If $wide1 = "" Then
	$wide1 = "1050"
	IniWrite($inifle, "Image 1", "width", $wide1)
EndIf
$high1 = IniRead($inifle, "Image 1", "height", "")
If $high1 = "" Then
	$high1 = "1680"
	IniWrite($inifle, "Image 1", "height", $high1)
EndIf
$wide2 = IniRead($inifle, "Image 2", "width", "")
If $wide2 = "" Then
	$wide2 = "330"
	IniWrite($inifle, "Image 2", "width", $wide2)
EndIf
$high2 = IniRead($inifle, "Image 2", "height", "")
If $high2 = "" Then
	$high2 = "530"
	IniWrite($inifle, "Image 2", "height", $high2)
EndIf
$wide3 = IniRead($inifle, "Image 3", "width", "")
If $wide3 = "" Then
	$wide3 = "140"
	IniWrite($inifle, "Image 3", "width", $wide3)
EndIf
$high3 = IniRead($inifle, "Image 3", "height", "")
If $high3 = "" Then
	$high3 = "225"
	IniWrite($inifle, "Image 3", "height", $high3)
EndIf
$dpi = IniRead($inifle, "DPI Resolution", "values", "")
If $dpi = "" Then
	$dpi = "300 x 300"
	IniWrite($inifle, "DPI Resolution", "values", $dpi)
EndIf
$use = IniRead($inifle, "Alternate Export Drive", "use", "")
If $use = "" Then
	$use = 4
	IniWrite($inifle, "Alternate Export Drive", "use", $use)
EndIf

$drive = ""

$val = IniRead($inifle, "Less Than 1024 Bytes", "percent", "")
If $val = "" Then
	$val = 100
	IniWrite($inifle, "Less Than 1024 Bytes", "percent", $val)
EndIf
$val = IniRead($inifle, "Less Than 300 Kilobytes", "percent", "")
If $val = "" Then
	$val = 0
	IniWrite($inifle, "Less Than 300 Kilobytes", "percent", $val)
EndIf
$val = IniRead($inifle, "Less Than 400 Kilobytes", "percent", "")
If $val = "" Then
	$val = 70
	IniWrite($inifle, "Less Than 400 Kilobytes", "percent", $val)
EndIf
$val = IniRead($inifle, "Less Than 500 Kilobytes", "percent", "")
If $val = "" Then
	$val = 65
	IniWrite($inifle, "Less Than 500 Kilobytes", "percent", $val)
EndIf
$val = IniRead($inifle, "Less Than 600 Kilobytes", "percent", "")
If $val = "" Then
	$val = 60
	IniWrite($inifle, "Less Than 600 Kilobytes", "percent", $val)
EndIf
$val = IniRead($inifle, "Less Than 700 Kilobytes", "percent", "")
If $val = "" Then
	$val = 55
	IniWrite($inifle, "Less Than 700 Kilobytes", "percent", $val)
EndIf
$val = IniRead($inifle, "Less Than 800 Kilobytes", "percent", "")
If $val = "" Then
	$val = 50
	IniWrite($inifle, "Less Than 800 Kilobytes", "percent", $val)
EndIf
$val = IniRead($inifle, "Less Than 900 Kilobytes", "percent", "")
If $val = "" Then
	$val = 45
	IniWrite($inifle, "Less Than 900 Kilobytes", "percent", $val)
EndIf
$val = IniRead($inifle, "Less Than 1024 Kilobytes", "percent", "")
If $val = "" Then
	$val = 40
	IniWrite($inifle, "Less Than 1024 Kilobytes", "percent", $val)
EndIf
$val = IniRead($inifle, "One Megabyte Or More", "percent", "")
If $val = "" Then
	$val = 30
	IniWrite($inifle, "One Megabyte Or More", "percent", $val)
EndIf

$psize = IniRead($inifle, "Placebo Image", "size", "")
If $psize = "" Then
	$psize = 3
	IniWrite($inifle, "Placebo Image", "size", $psize)
EndIf

If FileExists($sqlite) Then
	DropboxGUI()
Else
	MsgBox(262192, "Program Error", "The required 'sqlite3.dll' file could not be found." & @LF _
		& @LF & "This DLL file needs to be in the 'Kobo Cover Fixer'" _
		& @LF & "folder. It is freely available online.", 0)
EndIf

Exit


Func DropboxGUI()
	Local $Item_about, $Item_exit, $Item_fold, $Item_folders, $Item_list, $Item_viewer, $Label_drop, $Menu_drop
	;
	Local $attrib, $f, $fldpth, $folder, $folders, $foldlist, $left, $path, $right, $target, $top, $winpos
	;
	$right = @DesktopWidth - 87
	$left = IniRead($inifle, "Dropbox Window", "left", $right)
	$top = IniRead($inifle, "Dropbox Window", "top", 27)
	$Dropbox = GuiCreate("Dropbox", 82, 90, $left, $top, $WS_OVERLAPPED + $WS_CAPTION + $WS_SYSMENU + $WS_VISIBLE _
										+ $WS_CLIPSIBLINGS, $WS_EX_ACCEPTFILES + $WS_EX_TOPMOST + $WS_EX_TOOLWINDOW)
	;
	$Label_drop = GUICtrlCreateLabel("", 0, 0, 80, 88, $SS_CENTER + $SS_NOTIFY)
	GUICtrlSetState($Label_drop, $GUI_DROPACCEPTED)
	GUICtrlSetFont($Label_drop, 8, 400)
	GUICtrlSetTip($Label_drop, "Drop a Folder or Drive Here!")
	;
	; CONTEXT MENU
	$Menu_drop = GUICtrlCreateContextMenu($Label_drop)
	$Item_viewer = GUICtrlCreateMenuItem("Open the Viewer window", $Menu_drop)
	GUICtrlCreateMenuItem("", $Menu_drop)
	$Item_folders = GUICtrlCreateMenuItem("View the Folders List", $Menu_drop)
	GUICtrlCreateMenuItem("", $Menu_drop)
	$Item_list = GUICtrlCreateMenuItem("View the Ebooks List", $Menu_drop)
	GUICtrlCreateMenuItem("", $Menu_drop)
	$Item_fold = GUICtrlCreateMenuItem("Open the program folder", $Menu_drop)
	GUICtrlCreateMenuItem("", $Menu_drop)
	$Item_about = GUICtrlCreateMenuItem("About", $Menu_drop)
	GUICtrlCreateMenuItem("", $Menu_drop)
	GUICtrlCreateMenuItem("", $Menu_drop)
	$Item_exit = GUICtrlCreateMenuItem("Exit the program", $Menu_drop)
	;
	; SETTINGS
	GUICtrlSetBkColor($Label_drop, $COLOR_LIME)
	$target = "Some" & @LF & "Right-Click" & @LF & "Options Are" & @LF & "Available" & @LF & "HERE"
	GUICtrlSetData($Label_drop, @LF & $target)
	Sleep(2000)
	GUICtrlSetBkColor($Label_drop, $CLR_DEFAULT)
	$target = "Drop a Device" & @LF & "Folder HERE" & @LF & "or" & @LF & "Close To See" & @LF & "the Viewer"
	GUICtrlSetData($Label_drop, @LF & $target)

	GuiSetState()
	While 1
		$msg = GuiGetMsg()
		Select
		Case $msg = $GUI_EVENT_CLOSE Or $msg = $Item_exit
			; Close the Dropbox
			$winpos = WinGetPos($Dropbox, "")
			$left = $winpos[0]
			If $left < 0 Then
				$left = 2
			ElseIf $left > @DesktopWidth - $winpos[2] Then
				$left = @DesktopWidth - $winpos[2]
			EndIf
			IniWrite($inifle, "Dropbox Window", "left", $left)
			$top = $winpos[1]
			If $top < 0 Then
				$top = 2
			ElseIf $top > @DesktopHeight - $winpos[3] Then
				$top = @DesktopHeight - $winpos[3]
			EndIf
			IniWrite($inifle, "Dropbox Window", "top", $top)
			;
			GUIDelete($Dropbox)
			If $msg = $Item_exit Then
				Exit
			Else
				ExitLoop
			EndIf
		Case $msg = $GUI_EVENT_DROPPED
			; Folder added as new destination by drag and drop
			If @GUI_DragId = -1 Then
				If FileExists(@GUI_DragFile) Then
					$attrib = FileGetAttrib(@GUI_DragFile)
					If StringInStr($attrib, "D") > 0 Then
						$path = @GUI_DragFile
						$folder = StringSplit($path, "\", 1)
						$folder = $folder[$folder[0]]
						If $folder = ".kobo" Then
							IniWrite($inifle, "Device File Folder", "path", $path)
							$devfile = $path & "\KoboReader.sqlite"
							If FileExists($devfile) Then
								GUICtrlSetState($Label_drop, $GUI_DISABLE)
								SplashTextOn("", "Copying File!", 220, 100, -1, -1, 33)
								IniWrite($inifle, "Device File", "path", $devfile)
								FileCopy($devfile, $sqlfile, 1)
								If FileExists($sqlfile) Then
									_FileWriteLog($logfile, "Get device content.")
									GetContent()
									_FileCreate($foldtxt)
									$imgfold = $path & "-images"
									If FileExists($imgfold) Then
										IniWrite($inifle, "Device Images Folder", "path", $imgfold)
										SplashTextOn("", "Checking Folders!", 220, 100, -1, -1, 33)
										$folders = ""
										$foldlist = _FileListToArrayRec($imgfold, "*", 0, 1, 1, 2)
										For $f = 1 To $foldlist[0]
											$fldpth = $foldlist[$f]
											$folders &= $fldpth & @CRLF
										Next
										FileWriteLine($foldtxt, $folders)
										FindEbookImages()
									Else
										_FileWriteLog($logfile, "Folder Listing failed.")
										SplashOff()
										MsgBox(262192, "Program Error", "The required '.kobo-images' folder could not be found." & @LF _
											& @LF & "This folder should exist at the root of your" _
											& @LF & "Kobo device, along with the '.kobo' folder," _
											& @LF & "but for some reason it doesn't.", 0, $Dropbox)
									EndIf
								Else
									SplashOff()
									MsgBox(262192, "Program Error", "The required 'KoboReader.sqlite' file could not be found." & @LF _
										& @LF & "This sqlite file should have been copied to the" _
										& @LF & "'Kobo Cover Fixer' folder from a folder of your" _
										& @LF & "device, but for some reason it wasn't.", 0, $Dropbox)
								EndIf
								GUICtrlSetState($Label_drop, $GUI_ENABLE)
							Else
								MsgBox(262192, "Program Error", "The required 'KoboReader.sqlite' file could not be found." & @LF _
									& @LF & "This sqlite file should be located in the '.kobo' folder of" _
									& @LF & "your device. For some reason it appears to be missing.", 0, $Dropbox)
							EndIf
						Else
							MsgBox(262192, "Folder Error", "Needs to be the '.kobo' folder on your device.", 0, $Dropbox)
						EndIf
					Else
						MsgBox(262192, "Drag Error", "Needs to be a folder not file.", 0, $Dropbox)
					EndIf
				Else
					MsgBox(262192, "Drag Error", "Drag & Drop path doesn't exist.", 0, $Dropbox)
				EndIf
			Else
				MsgBox(262192, "Drag Error", "Drag & Drop failed.", 0, $Dropbox)
			EndIf
		Case $msg = $Item_viewer
			; Open the Viewer window
			GUISetState(@SW_HIDE, $Dropbox)
			ViewerGUI()
			GUISetState(@SW_SHOW, $Dropbox)
		Case $msg = $Item_folders
			; View the Folders List
			If FileExists($foldtxt) Then ShellExecute($foldtxt)
		Case $msg = $Item_fold
			; Open the program folder
			ShellExecute(@ScriptDir)
		Case $msg = $Item_about
			; About the program
			MsgBox(262208, "About The Program", _
				"This is a helper program to assist with missing or" & @LF & _
				"wrong size ebook cover images on a Kobo device." & @LF & @LF & _
				"BIG THANKS to jchd for his improved sqlite code." & @LF & @LF & _
				"BIG THANKS to Jon & team at the AutoIt Forum." & @LF & @LF & _
				"© May 2023 by TheSaint - Kobo Cover Fixer " & $version & @LF & _
				$updated, 0, $Dropbox)
		Case $msg = $Label_drop Or $msg = $Item_list
			; View the Ebooks List
			If FileExists($ebooks) Then ShellExecute($ebooks)
		Case Else
			;;;
		EndSelect
	WEnd
	ViewerGUI()
EndFunc ;=> DropboxGUI

Func ImagesGUI($entries)
	Local $Button_info, $Button_next, $Button_prior, $Button_quit, $Checkbox_preview, $Group_detail, $Group_images
	Local $Input_author, $Input_ID, $Input_on, $Input_owned, $Input_subs, $Input_title, $Label_author, $Label_ID
	Local $Label_on, $Label_owned, $Label_subs, $Label_title, $Pic_1, $Pic_2, $Pic_3, $Pic_4, $Pic_5, $Pic_6, $Pic_7
	Local $Pic_8, $Pic_9
	;
	Local $dll, $MappedGUI, $mpos, $ondevice, $owned, $part, $preview, $show, $size, $style, $sub, $xpos, $ypos
	;
	SplashTextOn("", "Please Wait!", 200, 100, -1, -1, 33)
	$style = BitOR($WS_OVERLAPPED, $WS_CAPTION, $WS_SYSMENU, $WS_CLIPSIBLINGS, $WS_MINIMIZEBOX) ;, $WS_VISIBLE
	$MappedGUI = GuiCreate("Mapped Images Viewer", 360, 665, -1, -1, $style, $WS_EX_TOPMOST, $OptionsGUI)
	GUISetBkColor($COLOR_SKYBLUE, $MappedGUI)
	;
	; CONTROLS
	$Group_images = GuiCtrlCreateGroup("Ebook Images", 10, 10, 340, 458)
	$Pic_1 = GUICtrlCreatePic($pic_one, 20, 30, 100, 136, $SS_NOTIFY)
	GUICtrlSetTip($Pic_1, "Click to see selected cover full size!")
	$Pic_2 = GUICtrlCreatePic($pic_two, 130, 30, 100, 136, $SS_NOTIFY)
	GUICtrlSetTip($Pic_2, "Click to see selected cover full size!")
	$Pic_3 = GUICtrlCreatePic($pic_three, 240, 30, 100, 136, $SS_NOTIFY)
	GUICtrlSetTip($Pic_3, "Click to see selected cover full size!")
	$Pic_4 = GUICtrlCreatePic($pic_four, 20, 176, 100, 136, $SS_NOTIFY)
	GUICtrlSetTip($Pic_4, "Click to see selected cover full size!")
	$Pic_5 = GUICtrlCreatePic($pic_five, 130, 176, 100, 136, $SS_NOTIFY)
	GUICtrlSetTip($Pic_5, "Click to see selected cover full size!")
	$Pic_6 = GUICtrlCreatePic($pic_six, 240, 176, 100, 136, $SS_NOTIFY)
	GUICtrlSetTip($Pic_6, "Click to see selected cover full size!")
	$Pic_7 = GUICtrlCreatePic($pic_seven, 20, 322, 100, 136, $SS_NOTIFY)
	GUICtrlSetTip($Pic_7, "Click to see selected cover full size!")
	$Pic_8 = GUICtrlCreatePic($pic_eight, 130, 322, 100, 136, $SS_NOTIFY)
	GUICtrlSetTip($Pic_8, "Click to see selected cover full size!")
	$Pic_9 = GUICtrlCreatePic($pic_nine, 240, 322, 100, 136, $SS_NOTIFY)
	GUICtrlSetTip($Pic_9, "Click to see selected cover full size!")
	;
	$Group_detail = GuiCtrlCreateGroup("Clicked Image Detail", 10, 478, 340, 125)
	$Label_ID = GUICtrlCreateLabel("Image ID", 20, 498, 68, 20, $SS_CENTER + $SS_CENTERIMAGE + $SS_SUNKEN)
	GUICtrlSetFont($Label_ID, 7, 600, 0, "Small Fonts")
	GUICtrlSetBkColor($Label_ID, $COLOR_BLACK)
	GUICtrlSetColor($Label_ID, $COLOR_WHITE)
	$Input_ID = GUICtrlCreateInput("", 88, 498, 252, 20)
	GUICtrlSetTip($Input_ID, "Selected ebook ID!")
	$Label_author = GUICtrlCreateLabel("AUTHOR", 20, 523, 68, 20, $SS_CENTER + $SS_CENTERIMAGE + $SS_SUNKEN)
	GUICtrlSetFont($Label_author, 7, 600, 0, "Small Fonts")
	GUICtrlSetBkColor($Label_author, $COLOR_BLACK)
	GUICtrlSetColor($Label_author, $COLOR_WHITE)
	$Input_author = GUICtrlCreateInput("", 88, 523, 252, 20)
	GUICtrlSetTip($Input_author, "Selected ebook author!")
	$Label_title = GUICtrlCreateLabel("TITLE", 20, 548, 50, 20, $SS_CENTER + $SS_CENTERIMAGE + $SS_SUNKEN)
	GUICtrlSetFont($Label_title, 7, 600, 0, "Small Fonts")
	GUICtrlSetBkColor($Label_title, $COLOR_BLACK)
	GUICtrlSetColor($Label_title, $COLOR_WHITE)
	$Input_title = GUICtrlCreateInput("", 70, 548, 270, 20)
	GUICtrlSetTip($Input_title, "Selected ebook title!")
	$Label_on = GUICtrlCreateLabel("DEVICE", 20, 573, 60, 20, $SS_CENTER + $SS_CENTERIMAGE + $SS_SUNKEN)
	GUICtrlSetFont($Label_on, 7, 600, 0, "Small Fonts")
	GUICtrlSetBkColor($Label_on, $COLOR_RED)
	GUICtrlSetColor($Label_on, $COLOR_WHITE)
	$Input_on = GUICtrlCreateInput("", 80, 573, 35, 20, $ES_CENTER)
	GUICtrlSetTip($Input_on, "On the device status!")
	$Label_owned = GUICtrlCreateLabel("OWNED", 125, 573, 60, 20, $SS_CENTER + $SS_CENTERIMAGE + $SS_SUNKEN)
	GUICtrlSetFont($Label_owned, 7, 600, 0, "Small Fonts")
	GUICtrlSetBkColor($Label_owned, $COLOR_GREEN)
	GUICtrlSetColor($Label_owned, $COLOR_WHITE)
	$Input_owned = GUICtrlCreateInput("", 185, 573, 35, 20, $ES_CENTER)
	GUICtrlSetTip($Input_owned, "Owned status!")
	$Label_subs = GUICtrlCreateLabel("SUBS", 230, 573, 50, 20, $SS_CENTER + $SS_CENTERIMAGE + $SS_SUNKEN)
	GUICtrlSetFont($Label_subs, 7, 600, 0, "Small Fonts")
	GUICtrlSetBkColor($Label_subs, $COLOR_BLUE)
	GUICtrlSetColor($Label_subs, $COLOR_WHITE)
	$Input_subs = GUICtrlCreateInput("", 280, 573, 60, 20, $ES_CENTER)
	GUICtrlSetTip($Input_subs, "Sub-folder numbers!")
	;
	$Button_prior = GuiCtrlCreateButton("RESTART", 10, 610, 90, 27)
	GUICtrlSetFont($Button_prior, 8, 600)
	GUICtrlSetTip($Button_prior, "Restart from the first lot of images!")
	;
	$Checkbox_preview = GUICtrlCreateCheckbox("Preview Image", 12, 640, 90, 20)
	GUICtrlSetTip($Checkbox_preview, "Show larger image preview!")
	;
	$Button_next = GuiCtrlCreateButton("NEXT", 110, 610, 60, 50)
	GUICtrlSetFont($Button_next, 9, 600)
	GUICtrlSetTip($Button_next, "View the next lot of images!")
	;
	$Button_fold = GuiCtrlCreateButton("D", 180, 610, 50, 50, $BS_ICON)
	GUICtrlSetTip($Button_fold, "Open the images folder!")
	;
	$Button_info = GuiCtrlCreateButton("Info", 240, 610, 50, 50, $BS_ICON)
	GUICtrlSetTip($Button_info, "Viewer Information!")
	;
	$Button_quit = GuiCtrlCreateButton("EXIT", 300, 610, 50, 50, $BS_ICON)
	GUICtrlSetTip($Button_quit, "Exit / Close / Quit the window!")
	;
	; SETTINGS
	GUICtrlSetImage($Button_fold, $shell, $icoD, 1)
	GUICtrlSetImage($Button_info, $user32, $icoI, 1)
	GUICtrlSetImage($Button_quit, $user32, $icoX, 1)
	;
	$show = IniRead($inifle, "Larger Preview Image", "show", "")
	If $show = "" Then
		$show = 1
		IniWrite($inifle, "Larger Preview Image", "show", $show)
	EndIf
	GUICtrlSetState($Checkbox_preview, $show)
	;
	$sub = ""

	SplashOff()
	GuiSetState(@SW_SHOWNORMAL, $MappedGUI)
	While 1
		$msg = GuiGetMsg()
		Select
		Case $msg = $GUI_EVENT_CLOSE Or $msg = $Button_quit
			; Close the Viewer window
			GUIDelete($MappedGUI)
			ExitLoop
		Case $msg = $Button_prior
			; View the previous lot of images
			$sub = ""
			GUICtrlSetData($Input_ID, "")
			GUICtrlSetData($Input_author, "")
			GUICtrlSetData($Input_title, "")
			GUICtrlSetData($Input_on, "")
			GUICtrlSetData($Input_owned, "")
			GUICtrlSetData($Input_subs, "")
			$row = 0
			; 1st Image
			GetMappedImage($pic_nine, $pic_one, $entries)
			GUICtrlSetImage($Pic_1, $pic_one)
			; 2nd Image
			GetMappedImage($pic_one, $pic_two, $entries)
			GUICtrlSetImage($Pic_2, $pic_two)
			; 3rd Image
			GetMappedImage($pic_two, $pic_three, $entries)
			GUICtrlSetImage($Pic_3, $pic_three)
			; 4th Image
			GetMappedImage($pic_three, $pic_four, $entries)
			GUICtrlSetImage($Pic_4, $pic_four)
			; 5th Image
			GetMappedImage($pic_four, $pic_five, $entries)
			GUICtrlSetImage($Pic_5, $pic_five)
			; 6th Image
			GetMappedImage($pic_five, $pic_six, $entries)
			GUICtrlSetImage($Pic_6, $pic_six)
			; 7th Image
			GetMappedImage($pic_six, $pic_seven, $entries)
			GUICtrlSetImage($Pic_7, $pic_seven)
			; 8th Image
			GetMappedImage($pic_seven, $pic_eight, $entries)
			GUICtrlSetImage($Pic_8, $pic_eight)
			; 9th Image
			GetMappedImage($pic_eight, $pic_nine, $entries)
			GUICtrlSetImage($Pic_9, $pic_nine)
		Case $msg = $Button_next
			; View the next lot of images
			$sub = ""
			GUICtrlSetData($Input_ID, "")
			GUICtrlSetData($Input_author, "")
			GUICtrlSetData($Input_title, "")
			GUICtrlSetData($Input_on, "")
			GUICtrlSetData($Input_owned, "")
			GUICtrlSetData($Input_subs, "")
			; 1st Image
			GetMappedImage($pic_nine, $pic_one, $entries)
			GUICtrlSetImage($Pic_1, $pic_one)
			; 2nd Image
			GetMappedImage($pic_one, $pic_two, $entries)
			GUICtrlSetImage($Pic_2, $pic_two)
			; 3rd Image
			GetMappedImage($pic_two, $pic_three, $entries)
			GUICtrlSetImage($Pic_3, $pic_three)
			; 4th Image
			GetMappedImage($pic_three, $pic_four, $entries)
			GUICtrlSetImage($Pic_4, $pic_four)
			; 5th Image
			GetMappedImage($pic_four, $pic_five, $entries)
			GUICtrlSetImage($Pic_5, $pic_five)
			; 6th Image
			GetMappedImage($pic_five, $pic_six, $entries)
			GUICtrlSetImage($Pic_6, $pic_six)
			; 7th Image
			GetMappedImage($pic_six, $pic_seven, $entries)
			GUICtrlSetImage($Pic_7, $pic_seven)
			; 8th Image
			GetMappedImage($pic_seven, $pic_eight, $entries)
			GUICtrlSetImage($Pic_8, $pic_eight)
			; 9th Image
			GetMappedImage($pic_eight, $pic_nine, $entries)
			GUICtrlSetImage($Pic_9, $pic_nine)
		Case $msg = $Button_info
			; Viewer Information
			; $mapini
		Case $msg = $Button_fold
			; Open the images folder
			If FileExists($imgfold) Then
				If $sub = "" Then
					ShellExecute($imgfold)
				Else
					ShellExecute($imgfold & "\" & $sub)
				EndIf
			EndIf
		Case $msg = $Checkbox_preview
			; Show larger image preview
			If GUICtrlRead($Checkbox_preview) = $GUI_CHECKED Then
				$show = 1
			Else
				$show = 4
			EndIf
			IniWrite($inifle, "Larger Preview Image", "show", $show)
		Case $msg = $Pic_1 Or $msg = $Pic_2 Or $msg = $Pic_3 Or $msg = $Pic_4 Or $msg = $Pic_5 _
			Or $msg = $Pic_6 Or $msg = $Pic_7 Or $msg = $Pic_8 Or $msg = $Pic_9
			; Full Size Preview
			GUICtrlSetState($Button_prior, $GUI_DISABLE)
			GUICtrlSetState($Button_next, $GUI_DISABLE)
			GUICtrlSetState($Button_fold, $GUI_DISABLE)
			GUICtrlSetState($Button_info, $GUI_DISABLE)
			GUICtrlSetState($Button_quit, $GUI_DISABLE)
			If $msg = $Pic_1 Then
				$preview = $pic_one
			ElseIf $msg = $Pic_2 Then
				$preview = $pic_two
			ElseIf $msg = $Pic_3 Then
				$preview = $pic_three
			ElseIf $msg = $Pic_4 Then
				$preview = $pic_four
			ElseIf $msg = $Pic_5 Then
				$preview = $pic_five
			ElseIf $msg = $Pic_6 Then
				$preview = $pic_six
			ElseIf $msg = $Pic_7 Then
				$preview = $pic_seven
			ElseIf $msg = $Pic_8 Then
				$preview = $pic_eight
			ElseIf $msg = $Pic_9 Then
				$preview = $pic_nine
			EndIf
			$imageID = StringSplit($preview, " - N3_", 1)
			$imageID = $imageID[1]
			$imageID = StringSplit($imageID, "\", 1)
			$part = $imageID[0]
			$sub = $imageID[$part - 2] & "\" & $imageID[$part - 1]
			GUICtrlSetData($Input_subs, $sub)
			$imageID = $imageID[$part]
			GUICtrlSetData($Input_ID, $imageID)
			;$author = IniRead($resfile, $imageID, "author", "other")
			$author = IniRead($resfile, $imageID, "author", "")
			If $author = "" Then
				$ondevice = "no"
				$author = IniRead($others, $imageID, "author", "other")
				$size = IniRead($others, $imageID, "size", "")
				If $size = 0 Then
					$owned = "no"
				Else
					$owned = "yes"
				EndIf
			Else
				$ondevice = "yes"
				$owned = "yes"
			EndIf
			GUICtrlSetData($Input_author, $author)
			$title = IniRead($resfile, $imageID, "title", "")
			If $title = "" Then
				$title = IniRead($others, $imageID, "title", "other")
			EndIf
			GUICtrlSetData($Input_title, $title)
			GUICtrlSetData($Input_on, $ondevice)
			GUICtrlSetData($Input_owned, $owned)
			;
			If $show = 1 Then
				SplashImageOn("", $preview, 230, 350, Default, Default, 17)
				Sleep(300)
				$mpos = MouseGetPos()
				$xpos = $mpos[0]
				$ypos = $mpos[1]
				Sleep(300)
				$dll = DllOpen("user32.dll")
				While 1
					$mpos = MouseGetPos()
					If $mpos[0] > $xpos + 40 Or $mpos[0] < $xpos - 40 Then ExitLoop
					If $mpos[1] > $ypos + 40 Or $mpos[1] < $ypos - 40 Then ExitLoop
					If _IsPressed("01", $dll) Then ExitLoop
					Sleep(300)
				WEnd
				DllClose($dll)
				SplashOff()
			EndIf
			GUICtrlSetState($Button_prior, $GUI_ENABLE)
			GUICtrlSetState($Button_next, $GUI_ENABLE)
			GUICtrlSetState($Button_fold, $GUI_ENABLE)
			GUICtrlSetState($Button_info, $GUI_ENABLE)
			GUICtrlSetState($Button_quit, $GUI_ENABLE)
		Case Else
			;;;
		EndSelect
	WEnd
EndFunc ;=> ImagesGUI

Func SettingsGUI()
	Local $Button_grab, $Button_info, $Button_map, $Button_quit, $Button_refresh, $Button_replace, $Button_show, $Button_view, $Checkbox_sort
	Local $Checkbox_update, $Checkbox_use, $Combo_drive, $Group_drive, $Group_export, $Group_folders, $Group_options, $Group_quality, $Input_300
	Local $Input_400, $Input_500, $Input_600, $Input_700, $Input_800, $Input_900, $Input_1024, $Input_bytes, $Input_dpi, $Input_height_1
	Local $Input_height_2, $Input_height_3, $Input_mega, $Input_width_1, $Input_width_2, $Input_width_3, $Label_300, $Label_400, $Label_500
	Local $Label_600, $Label_700, $Label_800, $Label_900, $Label_1024, $Label_bytes, $Label_advice, $Label_height_1, $Label_height_2
	Local $Label_height_3, $Label_image_1, $Label_image_2,$Label_image_3, $Label_mega, $Label_placebo, $Label_width_1, $Label_width_2
	Local $Label_width_3, $Radio_one, $Radio_two, $Radio_three
	;
	Local $array, $check, $devsql, $ebook, $erred, $f, $files, $flepth, $n, $N3, $num, $parts, $pos, $res, $sqlfold, $style
	Local $subfile, $subs, $value
	;
	; Script generated by GUIBuilder Prototype 0.9
	$style = BitOR($WS_OVERLAPPED, $WS_CAPTION, $WS_SYSMENU, $WS_VISIBLE, $WS_CLIPSIBLINGS, $WS_MINIMIZEBOX)
	$OptionsGUI = GuiCreate("Program Settings", 320, 675, -1, -1, $style, $WS_EX_TOPMOST, $ResultsGUI)
	GUISetBkColor($COLOR_CREAM, $OptionsGUI)
	;
	; CONTROLS
	$Group_export = GuiCtrlCreateGroup("Image Export Options", 10, 10, 300, 425)
	$Label_image_1 = GuiCtrlCreateLabel("Image 1", 20, 30, 75, 20, $SS_CENTER + $SS_CENTERIMAGE + $SS_SUNKEN)
	GUICtrlSetBkColor($Label_image_1, $COLOR_BLACK)
	GUICtrlSetColor($Label_image_1, $COLOR_WHITE)
	GUICtrlSetFont($Label_image_1, 9, 600)
	$Label_width_1 = GuiCtrlCreateLabel("Width", 100, 30, 45, 20, $SS_CENTER + $SS_CENTERIMAGE + $SS_SUNKEN)
	GUICtrlSetBkColor($Label_width_1, $COLOR_BLUE)
	GUICtrlSetColor($Label_width_1, $COLOR_WHITE)
	$Input_width_1 = GUICtrlCreateInput("", 145, 30, 50, 20, $ES_CENTER)
	$Label_height_1 = GuiCtrlCreateLabel("Height", 200, 30, 50, 20, $SS_CENTER + $SS_CENTERIMAGE + $SS_SUNKEN)
	GUICtrlSetBkColor($Label_height_1, $COLOR_BLUE)
	GUICtrlSetColor($Label_height_1, $COLOR_WHITE)
	$Input_height_1 = GUICtrlCreateInput("", 250, 30, 50, 20, $ES_CENTER)
	$Label_image_2 = GuiCtrlCreateLabel("Image 2", 20, 60, 75, 20, $SS_CENTER + $SS_CENTERIMAGE + $SS_SUNKEN)
	GUICtrlSetBkColor($Label_image_2, $COLOR_BLACK)
	GUICtrlSetColor($Label_image_2, $COLOR_WHITE)
	GUICtrlSetFont($Label_image_2, 9, 600)
	$Label_width_2 = GuiCtrlCreateLabel("Width", 100, 60, 45, 20, $SS_CENTER + $SS_CENTERIMAGE + $SS_SUNKEN)
	GUICtrlSetBkColor($Label_width_2, $COLOR_BLUE)
	GUICtrlSetColor($Label_width_2, $COLOR_WHITE)
	$Input_width_2 = GUICtrlCreateInput("", 145, 60, 50, 20, $ES_CENTER)
	$Label_height_2 = GuiCtrlCreateLabel("Height", 200, 60, 50, 20, $SS_CENTER + $SS_CENTERIMAGE + $SS_SUNKEN)
	GUICtrlSetBkColor($Label_height_2, $COLOR_BLUE)
	GUICtrlSetColor($Label_height_2, $COLOR_WHITE)
	$Input_height_2 = GUICtrlCreateInput("", 250, 60, 50, 20, $ES_CENTER)
	$Label_image_3 = GuiCtrlCreateLabel("Image 3", 20, 90, 75, 20, $SS_CENTER + $SS_CENTERIMAGE + $SS_SUNKEN)
	GUICtrlSetBkColor($Label_image_3, $COLOR_BLACK)
	GUICtrlSetColor($Label_image_3, $COLOR_WHITE)
	GUICtrlSetFont($Label_image_3, 9, 600)
	$Label_width_3 = GuiCtrlCreateLabel("Width", 100, 90, 45, 20, $SS_CENTER + $SS_CENTERIMAGE + $SS_SUNKEN)
	GUICtrlSetBkColor($Label_width_3, $COLOR_BLUE)
	GUICtrlSetColor($Label_width_3, $COLOR_WHITE)
	$Input_width_3 = GUICtrlCreateInput("", 145, 90, 50, 20, $ES_CENTER)
	$Label_height_3 = GuiCtrlCreateLabel("Height", 200, 90, 50, 20, $SS_CENTER + $SS_CENTERIMAGE + $SS_SUNKEN)
	GUICtrlSetBkColor($Label_height_3, $COLOR_BLUE)
	GUICtrlSetColor($Label_height_3, $COLOR_WHITE)
	$Input_height_3 = GUICtrlCreateInput("", 250, 90, 50, 20, $ES_CENTER)
	$Label_dpi = GuiCtrlCreateLabel("DPI", 20, 120, 40, 20, $SS_CENTER + $SS_CENTERIMAGE + $SS_SUNKEN)
	GUICtrlSetBkColor($Label_dpi, $COLOR_GREEN)
	GUICtrlSetColor($Label_dpi, $COLOR_WHITE)
	GUICtrlSetFont($Label_dpi, 9, 600)
	$Input_dpi = GUICtrlCreateInput("", 60, 120, 70, 20, $ES_CENTER)
	$Label_advice = GuiCtrlCreateLabel("Values Saved On Exit", 140, 120, 160, 20, $SS_CENTER + $SS_CENTERIMAGE)
	GUICtrlSetBkColor($Label_advice, $COLOR_YELLOW)
	GUICtrlSetColor($Label_advice, $COLOR_RED)
	GUICtrlSetFont($Label_advice, 9, 600)
	;
	$Group_quality = GuiCtrlCreateGroup("Image Export Quality Percentage - Based On Source", 27, 150, 266, 275)
	$Label_bytes = GuiCtrlCreateLabel("Less Than 1024 Bytes", 63, 170, 160, 20, $SS_CENTER + $SS_CENTERIMAGE + $SS_SUNKEN)
	GUICtrlSetBkColor($Label_bytes, $COLOR_BLACK)
	GUICtrlSetColor($Label_bytes, $COLOR_WHITE)
	GUICtrlSetFont($Label_bytes, 9, 600)
	$Input_bytes = GUICtrlCreateInput("", 223, 170, 35, 20, $ES_CENTER)
	$Label_300 = GuiCtrlCreateLabel("Less Than 300 Kilobytes", 48, 195, 190, 20, $SS_CENTER + $SS_CENTERIMAGE + $SS_SUNKEN)
	GUICtrlSetBkColor($Label_300, $COLOR_BLACK)
	GUICtrlSetColor($Label_300, $COLOR_WHITE)
	GUICtrlSetFont($Label_300, 9, 600)
	$Input_300 = GUICtrlCreateInput("", 238, 195, 35, 20, $ES_CENTER)
	$Label_400 = GuiCtrlCreateLabel("Less Than 400 Kilobytes", 48, 220, 190, 20, $SS_CENTER + $SS_CENTERIMAGE + $SS_SUNKEN)
	GUICtrlSetBkColor($Label_400, $COLOR_BLACK)
	GUICtrlSetColor($Label_400, $COLOR_WHITE)
	GUICtrlSetFont($Label_400, 9, 600)
	$Input_400 = GUICtrlCreateInput("", 238, 220, 35, 20, $ES_CENTER)
	$Label_500 = GuiCtrlCreateLabel("Less Than 500 Kilobytes", 48, 245, 190, 20, $SS_CENTER + $SS_CENTERIMAGE + $SS_SUNKEN)
	GUICtrlSetBkColor($Label_500, $COLOR_BLACK)
	GUICtrlSetColor($Label_500, $COLOR_WHITE)
	GUICtrlSetFont($Label_500, 9, 600)
	$Input_500 = GUICtrlCreateInput("", 238, 245, 35, 20, $ES_CENTER)
	$Label_600 = GuiCtrlCreateLabel("Less Than 600 Kilobytes", 48, 270, 190, 20, $SS_CENTER + $SS_CENTERIMAGE + $SS_SUNKEN)
	GUICtrlSetBkColor($Label_600, $COLOR_BLACK)
	GUICtrlSetColor($Label_600, $COLOR_WHITE)
	GUICtrlSetFont($Label_600, 9, 600)
	$Input_600 = GUICtrlCreateInput("", 238, 270, 35, 20, $ES_CENTER)
	$Label_700 = GuiCtrlCreateLabel("Less Than 700 Kilobytes", 48, 295, 190, 20, $SS_CENTER + $SS_CENTERIMAGE + $SS_SUNKEN)
	GUICtrlSetBkColor($Label_700, $COLOR_BLACK)
	GUICtrlSetColor($Label_700, $COLOR_WHITE)
	GUICtrlSetFont($Label_700, 9, 600)
	$Input_700 = GUICtrlCreateInput("", 238, 295, 35, 20, $ES_CENTER)
	$Label_800 = GuiCtrlCreateLabel("Less Than 800 Kilobytes", 48, 320, 190, 20, $SS_CENTER + $SS_CENTERIMAGE + $SS_SUNKEN)
	GUICtrlSetBkColor($Label_800, $COLOR_BLACK)
	GUICtrlSetColor($Label_800, $COLOR_WHITE)
	GUICtrlSetFont($Label_800, 9, 600)
	$Input_800 = GUICtrlCreateInput("", 238, 320, 35, 20, $ES_CENTER)
	$Label_900 = GuiCtrlCreateLabel("Less Than 900 Kilobytes", 48, 345, 190, 20, $SS_CENTER + $SS_CENTERIMAGE + $SS_SUNKEN)
	GUICtrlSetBkColor($Label_900, $COLOR_BLACK)
	GUICtrlSetColor($Label_900, $COLOR_WHITE)
	GUICtrlSetFont($Label_900, 9, 600)
	$Input_900 = GUICtrlCreateInput("", 238, 345, 35, 20, $ES_CENTER)
	$Label_1024 = GuiCtrlCreateLabel("Less Than 1024 Kilobytes", 48, 370, 190, 20, $SS_CENTER + $SS_CENTERIMAGE + $SS_SUNKEN)
	GUICtrlSetBkColor($Label_1024, $COLOR_BLACK)
	GUICtrlSetColor($Label_1024, $COLOR_WHITE)
	GUICtrlSetFont($Label_1024, 9, 600)
	$Input_1024 = GUICtrlCreateInput("", 238, 370, 35, 20, $ES_CENTER)
	$Label_mega = GuiCtrlCreateLabel("One Megabyte Or More", 57, 395, 170, 20, $SS_CENTER + $SS_CENTERIMAGE + $SS_SUNKEN)
	GUICtrlSetBkColor($Label_mega, $COLOR_BLACK)
	GUICtrlSetColor($Label_mega, $COLOR_WHITE)
	GUICtrlSetFont($Label_mega, 9, 600)
	$Input_mega = GUICtrlCreateInput("", 227, 395, 35, 20, $ES_CENTER)
	;
	$Group_options = GuiCtrlCreateGroup("Other Options", 10, 443, 300, 100)
	$Checkbox_sort = GuiCtrlCreateCheckbox("Sort Ebook Entries On Load", 20, 463, 150, 20)
	GUICtrlSetTip($Checkbox_sort, "Sort 'Ebook List' entries on load!")
	$Checkbox_update = GuiCtrlCreateCheckbox("Update Copied SQLite File", 20, 488, 145, 20)
	GUICtrlSetTip($Checkbox_update, "Update the 'KoboReader.sqlite' file!")
	$Button_grab = GuiCtrlCreateButton("Copy Device SQLite", 178, 459, 125, 22)
	GUICtrlSetFont($Button_grab, 7, 600, 0, "Small Fonts")
	GUICtrlSetTip($Button_grab, "Grab another copy of the device SQLite file!")
	$Button_replace = GuiCtrlCreateButton("Replace Device SQLite", 168, 486, 135, 22)
	GUICtrlSetFont($Button_replace, 7, 600, 0, "Small Fonts")
	GUICtrlSetTip($Button_replace, "Replace device SQLite file with updated copy!")
	$Label_placebo = GuiCtrlCreateLabel("Placebo Size", 20, 513, 90, 20, $SS_CENTER + $SS_CENTERIMAGE + $SS_SUNKEN)
	GUICtrlSetBkColor($Label_placebo, $COLOR_BLACK)
	GUICtrlSetColor($Label_placebo, $COLOR_WHITE)
	GUICtrlSetFont($Label_placebo, 7, 600, 0, "Small Fonts")
	$Radio_one = GuiCtrlCreateRadio("Image 1", 115, 513, 60, 20)
	GUICtrlSetTip($Radio_one, "Size of placebo images if selected!")
	$Radio_two = GuiCtrlCreateRadio("Image 2", 180, 513, 60, 20)
	GUICtrlSetTip($Radio_two, "Size of placebo images if selected!")
	$Radio_three = GuiCtrlCreateRadio("Image 3", 245, 513, 60, 20)
	GUICtrlSetTip($Radio_three, "Size of placebo images if selected!")
	;
	$Group_folders = GuiCtrlCreateGroup("Device Images Folder", 10, 551, 300, 54)
	$Button_map = GuiCtrlCreateButton("Map Folder Content", 20, 571, 124, 22)
	GUICtrlSetFont($Button_map, 7, 600, 0, "Small Fonts")
	GUICtrlSetTip($Button_map, "Make a list of all folders and their content!")
	$Button_show = GuiCtrlCreateButton("Show List", 149, 571, 69, 22)
	GUICtrlSetFont($Button_show, 7, 600, 0, "Small Fonts")
	GUICtrlSetTip($Button_show, "Show the list of all mapped folder content!")
	$Button_view = GuiCtrlCreateButton("View Sorted", 223, 571, 77, 22)
	GUICtrlSetFont($Button_view, 7, 600, 0, "Small Fonts")
	GUICtrlSetTip($Button_view, "View a sorted list of all mapped folder content!")
	;
	$Group_drive = GuiCtrlCreateGroup("Alternate Export Drive", 10, 615, 180, 50)
	$Combo_drive = GuiCtrlCreateCombo("", 20, 635, 50, 21)
	GUICtrlSetTip($Combo_drive, "Alternate drive to export images to!")
	$Button_refresh = GuiCtrlCreateButton("Refresh", 75, 635, 60, 21)
	GUICtrlSetTip($Button_refresh, "Refresh the drives list!")
	$Checkbox_use = GuiCtrlCreateCheckbox("Use", 145, 635, 40, 21)
	GUICtrlSetTip($Checkbox_use, "Use the Alternate Export Drive!")
	;
	$Button_info = GuiCtrlCreateButton("Info", 200, 615, 50, 50, $BS_ICON)
	GUICtrlSetTip($Button_info, "Settings Information!")
	;
	$Button_quit = GuiCtrlCreateButton("EXIT", 260, 615, 50, 50, $BS_ICON)
	GUICtrlSetTip($Button_quit, "Exit / Close / Quit the window!")
	;
	; SETTINGS
	GUICtrlSetImage($Button_info, $user32, $icoI, 1)
	GUICtrlSetImage($Button_quit, $user32, $icoX, 1)
	;
	; 1050 x 1680
	; 331 x 530
	; 139 x 223 or 145 x 223 or 146 or 144 or 124 or 148 or 149 x 198
	GUICtrlSetData($Input_width_1, $wide1)
	GUICtrlSetData($Input_height_1, $high1)
	GUICtrlSetData($Input_width_2, $wide2)
	GUICtrlSetData($Input_height_2, $high2)
	GUICtrlSetData($Input_width_3, $wide3)
	GUICtrlSetData($Input_height_3, $high3)
	;
	GUICtrlSetData($Input_dpi, $dpi)
	;
	$val = IniRead($inifle, "Less Than 1024 Bytes", "percent", "")
	GUICtrlSetData($Input_bytes, $val)
	$val = IniRead($inifle, "Less Than 300 Kilobytes", "percent", "")
	GUICtrlSetData($Input_300, $val)
	$val = IniRead($inifle, "Less Than 400 Kilobytes", "percent", "")
	GUICtrlSetData($Input_400, $val)
	$val = IniRead($inifle, "Less Than 500 Kilobytes", "percent", "")
	GUICtrlSetData($Input_500, $val)
	$val = IniRead($inifle, "Less Than 600 Kilobytes", "percent", "")
	GUICtrlSetData($Input_600, $val)
	$val = IniRead($inifle, "Less Than 700 Kilobytes", "percent", "")
	GUICtrlSetData($Input_700, $val)
	$val = IniRead($inifle, "Less Than 800 Kilobytes", "percent", "")
	GUICtrlSetData($Input_800, $val)
	$val = IniRead($inifle, "Less Than 900 Kilobytes", "percent", "")
	GUICtrlSetData($Input_900, $val)
	$val = IniRead($inifle, "Less Than 1024 Kilobytes", "percent", "")
	GUICtrlSetData($Input_1024, $val)
	$val = IniRead($inifle, "One Megabyte Or More", "percent", "")
	GUICtrlSetData($Input_mega, $val)
	;
	GUICtrlSetState($Checkbox_sort, $sort)
	;GUICtrlSetState($Checkbox_update, $update)
	;
	If $psize = 1 Then
		GUICtrlSetState($Radio_one, $GUI_CHECKED)
	ElseIf $psize = 2 Then
		GUICtrlSetState($Radio_two, $GUI_CHECKED)
	ElseIf $psize = 3 Then
		GUICtrlSetState($Radio_three, $GUI_CHECKED)
	EndIf
	;
	GetDrives(0)
	GUICtrlSetData($Combo_drive, $drives, $drive)
	;
	GUICtrlSetState($Checkbox_use, $use)

	GuiSetState()
	While 1
		$msg = GuiGetMsg()
		Select
		Case $msg = $GUI_EVENT_CLOSE Or $msg = $Button_quit
			; Close the Settings window
			$erred = 0
			For $n = 1 To 3
				If $n = 1 Then
					$val = GUICtrlRead($Input_width_1)
					$value = GUICtrlRead($Input_height_1)
				ElseIf $n = 2 Then
					$val = GUICtrlRead($Input_width_2)
					$value = GUICtrlRead($Input_height_2)
				ElseIf $n = 3 Then
					$val = GUICtrlRead($Input_width_3)
					$value = GUICtrlRead($Input_height_3)
				EndIf
				If StringIsDigit($val) Then
					If StringIsDigit($value) Then
						If $n = 1 Then
							$wide1 = $val
							IniWrite($inifle, "Image 1", "width", $wide1)
							$high1 = $value
							IniWrite($inifle, "Image 1", "height", $high1)
						ElseIf $n = 2 Then
							$wide2 = $val
							IniWrite($inifle, "Image 2", "width", $wide2)
							$high2 = $value
							IniWrite($inifle, "Image 2", "height", $high2)
						ElseIf $n = 3 Then
							$wide3 = $val
							IniWrite($inifle, "Image 3", "width", $wide3)
							$high3 = $value
							IniWrite($inifle, "Image 3", "height", $high3)
						EndIf
					Else
						$erred = $erred + 1
					EndIf
				Else
					$erred = $erred + 1
				EndIf
			Next
			$val = GUICtrlRead($Input_dpi)
			If StringInStr($val, " x ") > 0 Then
				$check = StringReplace($val, " x ", "")
				If StringIsDigit($check) Then
					$dpi = $val
					IniWrite($inifle, "DPI Resolution", "values", $dpi)
				Else
					$erred = $erred + 1
				EndIf
			Else
				$erred = $erred + 1
			EndIf
			For $p = 1 To 10
				If $p = 1 Then
					$val = GUICtrlRead($Input_bytes)
				ElseIf $p = 2 Then
					$val = GUICtrlRead($Input_300)
				ElseIf $p = 3 Then
					$val = GUICtrlRead($Input_400)
				ElseIf $p = 4 Then
					$val = GUICtrlRead($Input_500)
				ElseIf $p = 5 Then
					$val = GUICtrlRead($Input_600)
				ElseIf $p = 6 Then
					$val = GUICtrlRead($Input_700)
				ElseIf $p = 7 Then
					$val = GUICtrlRead($Input_800)
				ElseIf $p = 8 Then
					$val = GUICtrlRead($Input_900)
				ElseIf $p = 9 Then
					$val = GUICtrlRead($Input_1024)
				ElseIf $p = 10 Then
					$val = GUICtrlRead($Input_mega)
				EndIf
				If StringIsDigit($val) Then
					If $p = 1 Then
						IniWrite($inifle, "Less Than 1024 Bytes", "percent", $val)
					ElseIf $p = 2 Then
						IniWrite($inifle, "Less Than 300 Kilobytes", "percent", $val)
					ElseIf $p = 3 Then
						IniWrite($inifle, "Less Than 400 Kilobytes", "percent", $val)
					ElseIf $p = 4 Then
						IniWrite($inifle, "Less Than 500 Kilobytes", "percent", $val)
					ElseIf $p = 5 Then
						IniWrite($inifle, "Less Than 600 Kilobytes", "percent", $val)
					ElseIf $p = 6 Then
						IniWrite($inifle, "Less Than 700 Kilobytes", "percent", $val)
					ElseIf $p = 7 Then
						IniWrite($inifle, "Less Than 800 Kilobytes", "percent", $val)
					ElseIf $p = 8 Then
						IniWrite($inifle, "Less Than 900 Kilobytes", "percent", $val)
					ElseIf $p = 9 Then
						IniWrite($inifle, "Less Than 1024 Kilobytes", "percent", $val)
					ElseIf $p = 10 Then
						IniWrite($inifle, "One Megabyte Or More", "percent", $val)
					EndIf
				Else
					$erred = $erred + 1
				EndIf
			Next
			;
			If $erred > 0 Then
				$ans = MsgBox(262144 + 33 + 256, "Errors Found", $erred & " value(s) failed checking, perhaps more." & @LF & @LF & _
					"OK = Continue with prior values." & @LF & _
					"CANCEL = Abort & Retry.", 0, $OptionsGUI)
				If $ans = 2 Then
					ContinueLoop
				EndIf
			EndIf
			GUIDelete($OptionsGUI)
			ExitLoop
		Case $msg = $Button_view
			; View a sorted list of all mapped folder content
			Local $hUserFunction = _UserFunc
			GUISetState(@SW_MINIMIZE, $OptionsGUI)
			GUISetState(@SW_MINIMIZE, $ResultsGUI)
			SplashTextOn("", "Please Wait!", 200, 100, -1, -1, 33)
			_FileReadToArray($mapfile, $array, 1, @TAB)
			; Need to code some sorting options.
			_ArraySort($array, 0, 1, 0, 3)
			;_ArrayColDelete($sorted, 5, False)
			SplashOff()
			_ArrayDisplay($array, "Mapped Content", "", 0, @TAB, "Subs|Image ID|N3|Author & Title", 450, $COLOR_SKYBLUE, $hUserFunction)
		Case $msg = $Button_show
			; Show the list of all mapped folder content
			GUISetState(@SW_MINIMIZE, $OptionsGUI)
			GUISetState(@SW_MINIMIZE, $ResultsGUI)
			If FileExists($mapfile) Then ShellExecute($mapfile)
		Case $msg = $Button_replace
			; Replace device SQLite file with updated copy
			MsgBox(262144 + 48, "Alert", "This feature has been disabled for now.", 2, $OptionsGUI)
			ContinueLoop
			MsgBox(262144 + 64, "Replace Advice", "What device file gets replaced, depends on the" & @LF & _
				"'Use' the 'Alternate Export Drive' setting, as it" & @LF & _
				"will take precedence if enabled.", 0, $OptionsGUI)
			If $use = 1 Then
				If $drive = "" Then
					MsgBox(262144 + 48, "Path Error", "The drive of your Kobo device has not been set." & @LF & @LF & _
						"Make sure your Kobo device is connected via" & @LF & _
						"USB, and then click the 'Refresh' button.", 0, $OptionsGUI)
				Else
					$sqlfold = $drive & ".kobo"
					If FileExists($sqlfold) Then
						$devsql = $sqlfold & "\KoboReader.sqlite"
						If FileExists($devsql) Then
							If FileExists($sqlfile) Then
								$ans = MsgBox(262144 + 33 + 256, "Replace Query", "You are copying to the specified device location." & @LF & @LF & _
									"Do you want to replace the 'KoboReader.sqlite' file?" & @LF & @LF & _
									"OK = Replace that file." & @LF & _
									"CANCEL = Abort any Replace." & @LF & @LF & _
									"WARNING - You should be sure that the source" & @LF & _
									"file being copied, was once in the same state as" & @LF & _
									"the current destination file on your Kobo device." & @LF & _
									"If the file on your Kobo device has since changed," & @LF & _
									"due to new ebook additions or other changes like" & @LF & _
									"reading location or ebook finished etc, then you" & @LF & _
									"should probably not do a replacement - certainly" & @LF & _
									"not if ebooks have been added or removed. This" & @LF & _
									"could also be a change to a 'Collection'." & @LF & @LF & _
									"ADVICE - A backup copy is made in any case.", 0, $OptionsGUI)
								If $ans = 1 Then
									$res = FileMove($devsql, $devsql & ".bak")
									If $res = 1 Then
										$res = FileCopy($sqlfile, $devsql, 0)
										If $res = 1 Then
											MsgBox(262144 + 64, "Replace Result", "The device SQLite file wase replaced successfully.", 0, $OptionsGUI)
										Else
											MsgBox(262144 + 48, "Replace Error", "The device SQLite file could not be replaced." & @LF & @LF & _
												"Might be a source or destination issue.", 0, $OptionsGUI)
										EndIf
									Else
										MsgBox(262144 + 48, "Backup Error", "The existing SQLite file could not be renamed." & @LF & @LF & _
											"Maybe a backup copy already exists?", 0, $OptionsGUI)
									EndIf
								EndIf
							Else
								MsgBox(262144 + 48, "Source Error", "The SQLite file (working copy) could not be found." & @LF & @LF & _
									"It should be in the main program folder.", 0, $OptionsGUI)
							EndIf
						Else
							MsgBox(262144 + 48, "Path Error", "The device SQLite file cannot be found." & @LF & @LF & _
								"Make sure your Kobo device is connected via USB.", 0, $OptionsGUI)
						EndIf
					Else
						$altfold = ""
						MsgBox(262144 + 48, "Drive Error", "The drive for your Kobo device is not correct." & @LF & @LF & _
							"Make sure your Kobo device is connected via" & @LF & _
							"USB, and then click the 'Refresh' button ... or" & @LF & _
							"maybe just choose the correct drive.", 0, $OptionsGUI)
					EndIf
				EndIf
			Else
				$devfile = IniRead($inifle, "Device File", "path", "")
				If FileExists($devfile) Then
					If FileExists($sqlfile) Then
						$ans = MsgBox(262144 + 33 + 256, "Replace Query", "You are copying to the specified device location." & @LF & @LF & _
							"Do you want to replace the 'KoboReader.sqlite' file?" & @LF & @LF & _
							"OK = Replace that file." & @LF & _
							"CANCEL = Abort any Replace." & @LF & @LF & _
							"WARNING - You should be sure that the source" & @LF & _
							"file being copied, was once in the same state as" & @LF & _
							"the current destination file on your Kobo device." & @LF & _
							"If the file on your Kobo device has since changed," & @LF & _
							"due to new ebook additions or other changes like" & @LF & _
							"reading location or ebook finished etc, then you" & @LF & _
							"should probably not do a replacement - certainly" & @LF & _
							"not if ebooks have been added or removed. This" & @LF & _
							"could also be a change to a 'Collection'." & @LF & @LF & _
							"ADVICE - A backup copy is made in any case.", 0, $OptionsGUI)
						If $ans = 1 Then
							$res = FileMove($devfile, $devfile & ".bak")
							If $res = 1 Then
								$res = FileCopy($sqlfile, $devfile, 0)
								If $res = 1 Then
									MsgBox(262144 + 64, "Replace Result", "The device SQLite file wase replaced successfully.", 0, $OptionsGUI)
								Else
									MsgBox(262144 + 48, "Replace Error", "The device SQLite file could not be replaced." & @LF & @LF & _
										"Might be a source or destination issue.", 0, $OptionsGUI)
								EndIf
							Else
								MsgBox(262144 + 48, "Backup Error", "The existing SQLite file could not be renamed." & @LF & @LF & _
									"Maybe a backup copy already exists?", 0, $OptionsGUI)
							EndIf
						EndIf
					Else
						MsgBox(262144 + 48, "Source Error", "The SQLite file (working copy) could not be found." & @LF & @LF & _
							"It should be in the main program folder.", 0, $OptionsGUI)
					EndIf
				Else
					MsgBox(262144 + 48, "Path Error", "The device SQLite file cannot be found." & @LF & @LF & _
						"Make sure your Kobo device is connected via" & @LF & _
						"USB, or any external drive with a cloned copy" & @LF & _
						"of your Kobo device folders & files." & @LF & @LF & _
						"NOTE - This would be your working location.", 0, $OptionsGUI)
				EndIf
			EndIf
		Case $msg = $Button_refresh
			; Refresh the drives list
			GetDrives(0)
			If $drive <> "" Then
				If StringInStr($drives, $drive) < 1 Then $drive = ""
			EndIf
			GUICtrlSetData($Combo_drive, "", "")
			GUICtrlSetData($Combo_drive, $drives, $drive)
		Case $msg = $Button_map
			; Make a list of all folders and their content
			$imgfold = IniRead($inifle, "Device Images Folder", "path", "")
			If FileExists($imgfold) Then
				SplashTextOn("", "Please Wait!", 200, 100, -1, -1, 33)
				_FileCreate($mapfile)
				$files = ""
				$filelist = _FileListToArrayRec($imgfold, "*", 1, 1, 1, 1)
				For $f = 1 To $filelist[0]
					$flepth = $filelist[$f]
					$parts = StringSplit($flepth, " - ", 1)
					If $parts[0] = 2 Then
						$N3 = $parts[2]
					Else
						$N3 = "other"
					EndIf
					$subfile = $parts[1]
					$pos = StringInStr($subfile, "\", 0, -1)
					$subs = StringLeft($subfile, $pos)
					$imageID = StringMid($subfile, $pos + 1)
					$num = StringRight("0000" & $f, 5)
					$author = IniRead($resfile, $imageID, "author", $num)
					$title = IniRead($resfile, $imageID, "title", "other")
					$ebook = $author & " - " & $title
					;$entry = $subs & @TAB & $imageID & @TAB & $N3 & @TAB & $author & @TAB & $title & @TAB & $ebook
					$entry = $subs & @TAB & $imageID & @TAB & $N3 & @TAB & $author & " - " & $title
					$files &= $entry & @CRLF
				Next
				FileWriteLine($mapfile, $files)
				;
				If FileExists($sqlfile) Then
					GetOthers()
				EndIf
				SplashOff()
			EndIf
		Case $msg = $Button_info
			; Settings Information
			MsgBox(262208, "Settings Information", _
				"The values displayed (which can be modified)," & @LF & _
				"will be used for creating and then copying an" & @LF & _
				"ebook cover image to your Kobo device." & @LF & @LF & _
				"Values displayed for each of the three default" & @LF & _
				"images have been determined by averaging" & @LF & _
				"existing values found on my device." & @LF & @LF & _
				"The 'Alternate Export Drive' is only valid where" & @LF & _
				"the working content has been imitated in a PC" & @LF & _
				"folder, rather than working directly with your" & @LF & _
				"Kobo device." & @LF & @LF & _
				"Updating the SQLite device file or replacing" & @LF & _
				"it on your Kobo device has been disabled for" & @LF & _
				"safety reasons, and is probably not needed." & @LF & @LF & _
				"The default placebo image size is Image 3, the" & @LF & _
				"smallest size. Placebo images are experimental" & @LF & _
				"and only guesswork. One size might work.", 0, $OptionsGUI)
		Case $msg = $Button_grab
			; Grab another copy of the device SQLite file
			MsgBox(262144 + 64, "Copy Advice", "What device file gets copied from where, depends" & @LF & _
				"on the 'Use' the 'Alternate Export Drive' setting, as" & @LF & _
				"it will take precedence if enabled.", 0, $OptionsGUI)
			If $use = 1 Then
				If $drive = "" Then
					MsgBox(262144 + 48, "Path Error", "The drive of your Kobo device has not been set." & @LF & @LF & _
						"Make sure your Kobo device is connected via" & @LF & _
						"USB, and then click the 'Refresh' button.", 0, $OptionsGUI)
				Else
					$sqlfold = $drive & ".kobo"
					If FileExists($sqlfold) Then
						$devsql = $sqlfold & "\KoboReader.sqlite"
						If FileExists($devsql) Then
							If FileExists($sqlfile) Then
								$ans = MsgBox(262144 + 35 + 256, "Replace Query", "A copy of the device SQLite file already exists." & @LF & @LF & _
									"Do you want to replace (overwrite) that copy?" & @LF & @LF & _
									"YES = Replace that copy." & @LF & _
									"NO = Rename (backup) then Copy." & @LF & _
									"CANCEL = Abort any Copy.", 0, $OptionsGUI)
								If $ans = 6 Then
									FileCopy($devsql, $sqlfile, 1)
								ElseIf $ans = 7 Then
									$res = FileMove($sqlfile, $sqlfile & ".bak")
									If $res = 1 Then
										$res = FileCopy($devsql, $sqlfile, 0)
										If $res = 1 Then
											MsgBox(262144 + 64, "Copy Result", "The device SQLite file wase copied successfully.", 0, $OptionsGUI)
										Else
											MsgBox(262144 + 48, "Copy Error", "The device SQLite file could not be copied." & @LF & @LF & _
												"Might be a source or destination issue.", 0, $OptionsGUI)
										EndIf
									Else
										MsgBox(262144 + 48, "Rename Error", "The existing SQLite file could not be renamed." & @LF & @LF & _
											"Maybe a backup copy already exists?", 0, $OptionsGUI)
									EndIf
								EndIf
							Else
								MsgBox(262144 + 48, "Source Error", "The SQLite file (working copy) could not be found." & @LF & @LF & _
									"It should be in the main program folder.", 0, $OptionsGUI)
							EndIf
						Else
							MsgBox(262144 + 48, "Path Error", "The device SQLite file cannot be found." & @LF & @LF & _
								"Make sure your Kobo device is connected via USB.", 0, $OptionsGUI)
						EndIf
					Else
						$altfold = ""
						MsgBox(262144 + 48, "Drive Error", "The drive for your Kobo device is not correct." & @LF & @LF & _
							"Make sure your Kobo device is connected via" & @LF & _
							"USB, and then click the 'Refresh' button ... or" & @LF & _
							"maybe just choose the correct drive.", 0, $OptionsGUI)
					EndIf
				EndIf
			Else
				$devfile = IniRead($inifle, "Device File", "path", "")
				If FileExists($devfile) Then
					If FileExists($sqlfile) Then
						$ans = MsgBox(262144 + 35 + 256, "Replace Query", "A copy of the device SQLite file already exists." & @LF & @LF & _
							"Do you want to replace (overwrite) that copy?" & @LF & @LF & _
							"YES = Replace that copy." & @LF & _
							"NO = Rename (backup) then Copy." & @LF & _
							"CANCEL = Abort any Copy.", 0, $OptionsGUI)
						If $ans = 6 Then
							FileCopy($devfile, $sqlfile, 1)
						ElseIf $ans = 7 Then
							$res = FileMove($sqlfile, $sqlfile & ".bak")
							If $res = 1 Then
								$res = FileCopy($devfile, $sqlfile, 0)
								If $res = 1 Then
									MsgBox(262144 + 64, "Copy Result", "The device SQLite file wase copied successfully.", 0, $OptionsGUI)
								Else
									MsgBox(262144 + 48, "Copy Error", "The device SQLite file could not be copied." & @LF & @LF & _
										"Might be a source or destination issue.", 0, $OptionsGUI)
								EndIf
							Else
								MsgBox(262144 + 48, "Rename Error", "The existing SQLite file could not be renamed." & @LF & @LF & _
									"Maybe a backup copy already exists?", 0, $OptionsGUI)
							EndIf
						EndIf
					Else
						MsgBox(262144 + 48, "Source Error", "The SQLite file (working copy) could not be found." & @LF & @LF & _
							"It should be in the main program folder.", 0, $OptionsGUI)
					EndIf
				Else
					MsgBox(262144 + 48, "Path Error", "The device SQLite file cannot be found." & @LF & @LF & _
						"Make sure your Kobo device is connected via" & @LF & _
						"USB, or any external drive with a cloned copy" & @LF & _
						"of your Kobo device folders & files." & @LF & @LF & _
						"NOTE - This would be your working location.", 0, $OptionsGUI)
				EndIf
			EndIf
		Case $msg = $Checkbox_use
			; Use the Alternate Export Drive
			If GUICtrlRead($Checkbox_use) = $GUI_CHECKED Then
				$use = 1
			Else
				$use = 4
			EndIf
			IniWrite($inifle, "Alternate Export Drive", "use", $use)
		Case $msg = $Checkbox_update
			; Update the 'KoboReader.sqlite' file
			If GUICtrlRead($Checkbox_update) = $GUI_CHECKED Then
				$update = 1
				GUICtrlSetState($Checkbox_update, $GUI_UNCHECKED)
				MsgBox(262144 + 48, "Alert", "This feature is not yet fully supported.", 2, $OptionsGUI)
			Else
				$update = 4
			EndIf
			IniWrite($inifle, "Device SQLite File", "update", $update)
		Case $msg = $Checkbox_sort
			; Sort 'Ebook List' entries on load
			If GUICtrlRead($Checkbox_sort) = $GUI_CHECKED Then
				$sort = 1
			Else
				$sort = 4
			EndIf
			IniWrite($inifle, "Ebook Entries On Load", "sort", $sort)
		Case $msg = $Combo_drive
			; Alternate drive to export images to
			$drive = GUICtrlRead($Combo_drive)
		Case $msg = $Radio_two
			; Size of placebo images if selected - Image 2
			$psize = 2
			IniWrite($inifle, "Placebo Image", "size", $psize)
		Case $msg = $Radio_three
			; Size of placebo images if selected - Image 3
			$psize = 3
			IniWrite($inifle, "Placebo Image", "size", $psize)
		Case $msg = $Radio_one
			; Size of placebo images if selected - Image 1
			$psize = 1
			IniWrite($inifle, "Placebo Image", "size", $psize)
		Case Else
			;;;
		EndSelect
	WEnd
EndFunc ;=> SettingsGUI

Func ViewerGUI()
	Local $Button_add, $Button_author, $Button_backup, $Button_build, $Button_close, $Button_continue, $Button_copy, $Button_covers, $Button_create, $Button_device
	Local $Button_down, $Button_drive, $Button_empty, $Button_fix, $Button_fold, $Button_images, $Button_inf, $Button_info, $Button_list, $Button_log, $Button_mark
	Local $Button_missing, $Button_next, $Button_quit, $Button_refresh, $Button_reload, $Button_relocate, $Button_remove, $Button_setup, $Button_source, $Button_subs
	Local $Button_up, $Checkbox_1, $Checkbox_2, $Checkbox_3, $Checkbox_all, $Checkbox_cancel, $Combo_image, $Edit_detail, $Group_cover, $Group_covers, $Group_detail
	Local $Group_fix, $Group_image, $Group_missing, $Group_placebo, $Group_source, $Group_view, $Input_author, $Input_device, $Input_image_1, $Input_image_2
	Local $Input_image_3, $Input_isbn, $Input_source, $Input_subs, $Input_title, $Label_author, $Label_isbn, $Label_status, $Label_subs, $Label_title, $List_covers
	Local $Pic_cover
	;
	Local $added, $all, $array, $authfold, $backups, $c, $colnum, $copied, $covimg, $created, $disabled, $dll, $drvfold, $exists, $f, $files, $fix, $fixed, $folder
	Local $height, $icofle, $icoN, $icoP, $image, $imgfile, $ind, $ISBN, $left, $mark, $mpos, $names, $one, $over, $parts, $pos, $preview, $pth, $rename, $res
	Local $restart, $SelectionGUI, $size, $skip, $srcefold, $style, $styles, $subfile, $subs, $surname, $three, $top, $total, $two, $width, $winpos, $xpos, $ypos
	;
	$width = 1310
	$height = 570
	$left = IniRead($inifle, "Results Window", "left", @DesktopWidth - $width - 25)
	$top = IniRead($inifle, "Results Window", "top", @DesktopHeight - $height - 60)
	$styles = $WS_OVERLAPPED + $WS_CAPTION + $WS_MINIMIZEBOX ; + $WS_POPUP
	$ResultsGUI = GuiCreate("Image Search Results", $width - 5, $height, $left, $top, $styles + $WS_SIZEBOX + $WS_VISIBLE, $WS_EX_TOPMOST)
	GUISetBkColor($COLOR_MONEYGREEN, $ResultsGUI)
	; CONTROLS
	$Group_ebooks = GuiCtrlCreateGroup("Ebooks List", 10, 10, $width - 25, 372)
	$Label_status = GUICtrlCreateLabel("", ($width / 2) - 120, 5, 240, 20, $SS_CENTER + $SS_CENTERIMAGE)
	GUICtrlSetFont($Label_status, 9, 600)
	GUICtrlSetColor($Label_status, $COLOR_RED)
	GUICtrlSetState($Label_status, $GUI_HIDE)
	$ListView_ebooks = GUICtrlCreateListView("No.|Title|Author|Images|Image 1|Image 2|Image 3|Image ID", 20, 30, $width - 45, 260, $LVS_SHOWSELALWAYS _
												+ $LVS_SINGLESEL + $LVS_REPORT, $LVS_EX_FULLROWSELECT + $LVS_EX_GRIDLINES) ; + $LVS_EX_CHECKBOXES
	GUICtrlSetBkColor($ListView_ebooks, 0xF0D0F0)
	;
	$Label_title = GUICtrlCreateLabel("TITLE", 20, 300, 50, 20, $SS_CENTER + $SS_CENTERIMAGE + $SS_SUNKEN)
	GUICtrlSetFont($Label_title, 7, 600, 0, "Small Fonts")
	GUICtrlSetBkColor($Label_title, $COLOR_BLACK)
	GUICtrlSetColor($Label_title, $COLOR_WHITE)
	$Input_title = GUICtrlCreateInput("", 70, 300, 700, 20)
	$Label_author = GUICtrlCreateLabel("AUTHOR", 20, 325, 68, 20, $SS_CENTER + $SS_CENTERIMAGE + $SS_SUNKEN)
	GUICtrlSetFont($Label_author, 7, 600, 0, "Small Fonts")
	GUICtrlSetBkColor($Label_author, $COLOR_BLACK)
	GUICtrlSetColor($Label_author, $COLOR_WHITE)
	$Input_author = GUICtrlCreateInput("", 88, 325, 768, 20)
	GUICtrlSetTip($Input_author, "Selected ebook author!")
	GUICtrlSetTip($Input_title, "Selected ebook title!")
	$Button_author = GuiCtrlCreateButton("FIX", 860, 324, 41, 22)
	GUICtrlSetFont($Button_author, 7, 600, 0, "Small Fonts")
	GUICtrlSetTip($Button_author, "Fix the author name of selected ebook entry!")
	$Label_isbn = GUICtrlCreateLabel("ISBN", 780, 300, 45, 20, $SS_CENTER + $SS_CENTERIMAGE + $SS_SUNKEN)
	GUICtrlSetFont($Label_isbn, 7, 600, 0, "Small Fonts")
	GUICtrlSetBkColor($Label_isbn, $COLOR_BLUE)
	GUICtrlSetColor($Label_isbn, $COLOR_WHITE)
	$Input_isbn = GUICtrlCreateInput("", 825, 300, 225, 20)
	GUICtrlSetTip($Input_isbn, "ISBN!")
	$Label_subs = GUICtrlCreateLabel("SUBS", 910, 325, 45, 20, $SS_CENTER + $SS_CENTERIMAGE + $SS_SUNKEN)
	GUICtrlSetFont($Label_subs, 7, 600, 0, "Small Fonts")
	GUICtrlSetBkColor($Label_subs, $COLOR_GREEN)
	GUICtrlSetColor($Label_subs, $COLOR_WHITE)
	$Input_subs = GUICtrlCreateInput("", 955, 325, 55, 20, $ES_CENTER)
	GUICtrlSetTip($Input_subs, "Sub-folders for selected ebook entry!")
	$Button_subs = GuiCtrlCreateButton("ADD", 1010, 324, 41, 22)
	GUICtrlSetFont($Button_subs, 7, 600, 0, "Small Fonts")
	GUICtrlSetTip($Button_subs, "Add sub-folders for selected ebook entry!")
	$Button_copy = GuiCtrlCreateButton("C", 1060, 299, 45, 46, $BS_ICON)
	GUICtrlSetTip($Button_copy, "Copy the Title and ISBN to clipboard!")
	$Button_up = GuiCtrlCreateButton("UP", 1115, 299, 47, 46, $BS_ICON)
	GUICtrlSetTip($Button_up, "Move up to previous entry!")
	$Button_down = GuiCtrlCreateButton("DOWN", 1168, 299, 47, 46, $BS_ICON)
	GUICtrlSetTip($Button_down, "Move down to next entry!")
	$Button_mark = GuiCtrlCreateButton("MARK", 1225, 299, 60, 21)
	GUICtrlSetFont($Button_mark, 7, 600, 0, "Small Fonts")
	GUICtrlSetTip($Button_mark, "Mark the selected entry!")
	$Button_next = GuiCtrlCreateButton("NEXT", 1225, 324, 60, 21)
	GUICtrlSetFont($Button_next, 7, 600, 0, "Small Fonts")
	GUICtrlSetTip($Button_next, "Go to the next marked entry!")
	;
	$Input_image_1 = GUICtrlCreateInput("", 20, 350, ($width / 3) - 20, 20)
	GUICtrlSetTip($Input_image_1, "First image for ebook!")
	$Input_image_2 = GUICtrlCreateInput("", ($width / 3) + 8, 350, ($width / 3) - 20, 20)
	GUICtrlSetTip($Input_image_2, "Second image for ebook!")
	$Input_image_3 = GUICtrlCreateInput("", ($width / 3) + 432, 350, ($width / 3) - 20, 20)
	GUICtrlSetTip($Input_image_3, "Third image for ebook!")
	;
	$Group_source = GuiCtrlCreateGroup("Cover Images - Source Path", 10, 390, 380, 50)
	$Input_source = GUICtrlCreateInput("", 20, 410, 285, 20)
	GUICtrlSetBkColor($Input_source, 0xFFFFAA)
	GUICtrlSetTip($Input_source, "Path of images to use for creation and add (if needed)!")
	$Button_source = GuiCtrlCreateButton("B", 310, 410, 20, 20, $BS_ICON)
	GUICtrlSetTip($Button_source, "Browse to set the images source path!")
	$Button_covers = GuiCtrlCreateButton("O", 335, 409, 20, 22, $BS_ICON)
	GUICtrlSetTip($Button_covers, "Open the images source folder!")
	$Button_refresh = GuiCtrlCreateButton("O", 360, 409, 20, 22, $BS_ICON)
	GUICtrlSetTip($Button_refresh, "Refresh the list!")
	;
	$Group_missing = GuiCtrlCreateGroup("Missing Images", 10, 450, 105, 110)
	$Button_add = GuiCtrlCreateButton("ADD", 20, 470, 85, 35)
	GUICtrlSetFont($Button_add, 9, 600)
	GUICtrlSetTip($Button_add, "Add missing images to ebook folder!")
	$Button_create = GuiCtrlCreateButton("CREATE", 20, 515, 85, 35)
	GUICtrlSetFont($Button_create, 9, 600)
	GUICtrlSetTip($Button_create, "Create ALL missing images for an ebook folder!")
	;
	$Group_placebo = GuiCtrlCreateGroup("Placebo Images", 125, 450, 265, 60)
	$Button_build = GuiCtrlCreateButton("BUILD", 135, 470, 63, 30)
	GUICtrlSetFont($Button_build, 7, 600, 0, "Small Fonts")
	GUICtrlSetTip($Button_build, "Create placebo image files ready for the empty ebook folders!")
	$Button_relocate = GuiCtrlCreateButton("RELOCATE", 208, 470, 87, 30)
	GUICtrlSetFont($Button_relocate, 7, 600, 0, "Small Fonts")
	GUICtrlSetTip($Button_relocate, "Relocate placebo images to empty ebook folders!")
	$Button_remove = GuiCtrlCreateButton("REMOVE", 305, 470, 75, 30)
	GUICtrlSetFont($Button_remove, 7, 600, 0, "Small Fonts")
	GUICtrlSetTip($Button_remove, "Remove placebo images in empty ebook folders!")
	GuiCtrlCreateGroup("", 325, 502, 65, 58)
	$Button_list = GuiCtrlCreateButton("L", 335, 520, 45, 30, $BS_ICON)
	GUICtrlSetTip($Button_list, "View the placebo list!")
	;
	$Button_fix = GuiCtrlCreateButton("FIX COVERS", 125, 520, 120, 40)
	GUICtrlSetFont($Button_fix, 9, 600)
	GUICtrlSetTip($Button_fix, "Fix image size(s) in an ebook folder!")
	;
	$Button_log = GuiCtrlCreateButton("LOG", 255, 520, 60, 40)
	GUICtrlSetFont($Button_log, 9, 600)
	GUICtrlSetTip($Button_log, "View the Log Record!")
	;
	$Group_covers = GuiCtrlCreateGroup("Cover Images - Source", 400, 390, 360, 130)
	$List_covers = GUICtrlCreateList("", 410, 410, 340, 100)
	GUICtrlSetBkColor($List_covers, 0xFFFFAA)
	GUICtrlSetTip($List_covers, "List of covers to use for ebook fixes!")
	;
	$Button_device = GuiCtrlCreateButton("Find Kobo Device", 400, 530, 140, 29)
	GUICtrlSetFont($Button_device, 9, 600)
	GUICtrlSetTip($Button_device, "Find the Kobo device drive!")
	GuiCtrlCreateGroup("", 541, 524, 150, 34)
	$Input_device = GUICtrlCreateInput("", 547, 535, 138, 18)
	GUICtrlSetBkColor($Input_device, $COLOR_SKYBLUE)
	GUICtrlSetTip($Input_device, "Kobo device image folder path!")
	$Button_images = GuiCtrlCreateButton("O", 695, 530, 30, 29, $BS_ICON)
	GUICtrlSetTip($Button_images, "Open the device images folder!")
	$Button_drive = GuiCtrlCreateButton("O", 730, 530, 30, 29, $BS_ICON)
	GUICtrlSetTip($Button_drive, "Open the alternate drive images folder!")
	;
	$Group_cover = GuiCtrlCreateGroup("Cover Image", 770, 390, 120, 170)
	$Pic_cover = GUICtrlCreatePic($blackjpg, 780, 410, 100, 136, $SS_NOTIFY)
	GUICtrlSetTip($Pic_cover, "Click to see selected cover full size!")
	;
	$Group_detail = GuiCtrlCreateGroup("Detail", 900, 390, 180, 108)
	$Edit_detail = GUICtrlCreateEdit("", 910, 410, 160, 78, $ES_AUTOVSCROLL + $ES_AUTOHSCROLL + $ES_READONLY)
	GUICtrlSetBkColor($Edit_detail, $COLOR_SILVER)
	GUICtrlSetTip($Edit_detail, "Detail about the selected image when clicked!")
	;
	$Group_view = GuiCtrlCreateGroup("View - Lists", 1090, 390, 145, 108)
	$Button_missing = GuiCtrlCreateButton("MISSING IMAGES", 1100, 410, 125, 35)
	GUICtrlSetFont($Button_missing, 7, 600, 0, "Small Fonts")
	GUICtrlSetTip($Button_missing, "View the list of missing images!")
	$Button_empty = GuiCtrlCreateButton("EMPTY FOLDERS", 1100, 454, 125, 35)
	GUICtrlSetFont($Button_empty, 7, 600, 0, "Small Fonts")
	GUICtrlSetTip($Button_empty, "View the list of empty ebook folders!")
	;
	$Button_fold = GuiCtrlCreateButton("D", $width - 65, 390, 50, 50, $BS_ICON)
	GUICtrlSetTip($Button_fold, "Open the program folder!")
	;
	$Button_info = GuiCtrlCreateButton("Info", $width - 65, 450, 50, 50, $BS_ICON)
	GUICtrlSetTip($Button_info, "Program Information!")
	;
	$Group_image = GuiCtrlCreateGroup("Image", 900, 506, 90, 54)
	$Combo_image = GUICtrlCreateCombo("", 910, 526, 70, 21)
	;
	$Checkbox_cancel = GUICtrlCreateCheckbox("Cancel Backup", 1003, 545, 90, 17)
	GUICtrlSetState($Checkbox_cancel, $GUI_HIDE)
	$Button_backup = GuiCtrlCreateButton("BACKUP" & @LF & "IMAGES", 1000, 511, 95, 50, $BS_MULTILINE)
	GUICtrlSetFont($Button_backup, 9, 600)
	GUICtrlSetTip($Button_backup, "Backup cover images to a PC folder!")
	;
	$Button_reload = GuiCtrlCreateButton("Reload", 1105, 511, 55, 50, $BS_ICON)
	GUICtrlSetTip($Button_reload, "Reload the List!")
	;
	$Button_setup = GuiCtrlCreateButton("Setup", 1170, 511, 55, 50, $BS_ICON)
	GUICtrlSetTip($Button_setup, "Program Settings!")
	;
	$Button_quit = GuiCtrlCreateButton("EXIT", 1235, 511, 60, 50, $BS_ICON)
	GUICtrlSetTip($Button_quit, "Exit / Close / Quit the window!")
	;
	$lowid = $Button_quit + 1
	;
	; SETTINGS
	GUICtrlSetImage($Button_copy, $shell, $icoC, 1)
	GUICtrlSetImage($Button_source, $shell, $icoF, 0)
	GUICtrlSetImage($Button_covers, $shell, $icoO, 0)
	GUICtrlSetImage($Button_refresh, $shell, $icoR, 0)
	GUICtrlSetImage($Button_list, $shell, $icoT, 0)
	GUICtrlSetImage($Button_images, $shell, $icoO, 0)
	GUICtrlSetImage($Button_drive, $shell, -195, 0)
	GUICtrlSetImage($Button_reload, $shell, $icoR, 1)
	GUICtrlSetImage($Button_setup, $shell, $icoS, 1)
	GUICtrlSetImage($Button_fold, $shell, $icoD, 1)
	GUICtrlSetImage($Button_info, $user32, $icoI, 1)
	GUICtrlSetImage($Button_quit, $user32, $icoX, 1)
	If FileExists($shell) Then
		; Up & Down (bluish triangles)
		$icofle = $shell
		$icoP = -247
		$icoN = -248
	Else
		Local $ipsmsnap = @SystemDir & "\ipsmsnap.dll"
		If FileExists($ipsmsnap) Then
			; Up & Down (black)
			$icofle = $ipsmsnap
			$icoP = -2
			$icoN = -3
		Else
			$ipsmsnap = ""
			Local $netshell = @SystemDir & "\netshell.dll"
			If FileExists($netshell) Then
				; Up & Down (blue)
				$icofle = $netshell
				$icoP = -150
				$icoN = -151
			Else
				$netshell = ""
				Local $wlanpref = @SystemDir & "\wlanpref.dll"
				If FileExists($wlanpref) Then
					; Up & Down (blue)
					$icofle = $wlanpref
					$icoP = -4
					$icoN = -5
				Else
					$wlanpref = ""
					Local $wlangpui = @SystemDir & "\wlangpui.dll"
					If FileExists($wlangpui) Then
						; Up & Down (green)
						$icofle = $wlangpui
						$icoP = -7
						$icoN = -8
					Else
						$wlangpui = ""
						Local $xpsrchvw = @SystemDir & "\xpsrchvw.exe"
						If FileExists($xpsrchvw) Then
							; Up & Down (blue)
							$icofle = $xpsrchvw
							$icoP = -6
							$icoN = -8
						Else
							$xpsrchvw = ""
							Local $mmcndmgr = @SystemDir & "\mmcndmgr.dll"
							If FileExists($mmcndmgr) Then
								; Up & Down (small black)
								$icofle = $mmcndmgr
								$icoP = -58
								$icoN = -49
							Else
								$mmcndmgr = ""
								Local $wpdshext = @SystemDir & "\wpdshext.dll"
								If FileExists($wpdshext) Then
									; Up & Down (blue different)
									$icofle = $wpdshext
									$icoP = -26
									$icoN = -27
								Else
									$wpdshext = ""
									Local $netcfgx = @SystemDir & "\netcfgx.dll"
									If FileExists($netcfgx) Then
										; Up & Down (curly green)
										$icofle = $netcfgx
										$icoP = -8
										$icoN = -9
									Else
										$netcfgx = ""
										Local $rasdlg = @SystemDir & "\rasdlg.dll"
										If FileExists($rasdlg) Then
											; Up & Down (curly green)
											$icofle = $rasdlg
											$icoP = -18
											$icoN = -16
										Else
											$rasdlg = ""
											Local $dnscmmc = @SystemDir & "\dnscmmc.dll"
											If FileExists($dnscmmc) Then
												; Up & Down (curly green)
												$icofle = $dnscmmc
												$icoP = 0
												$icoN = -2
											Else
												$dnscmmc = ""
												Local $wmploc = @SystemDir & "\wmploc.DLL"
												If FileExists($wmploc) Then
													; Left & Right (blue)
													$icofle = $wmploc
													$icoP = -200
													$icoN = -199
												Else
													$wmploc = ""
													Local $msdbrptr = @SystemDir & "\MSDBRPTR.DLL"
													If FileExists($msdbrptr) Then
														; Left & Right (black)
														$icofle = $msdbrptr
														$icoP = -3
														$icoN = -4
													Else
														$msdbrptr = ""
														Local $explorer = @WindowsDir & "\explorer.exe"
														; Left & Right (black doubles)
														$icofle = $explorer
														$icoP = -12
														$icoN = -13
													EndIf
												EndIf
											EndIf
										EndIf
									EndIf
								EndIf
							EndIf
						EndIf
					EndIf
				EndIf
			EndIf
		EndIf
	EndIf
	GUICtrlSetImage($Button_up, $icofle, $icoP, 1)
	GUICtrlSetImage($Button_down, $icofle, $icoN, 1)
	;
	GUICtrlSetData($Combo_image, "Image 1|Image 2|Image 3|Source", "Image 2")
	;
	$sort = IniRead($inifle, "Ebook Entries On Load", "sort", "")
	If $sort = "" Then
		$sort = 4
		IniWrite($inifle, "Ebook Entries On Load", "sort", $sort)
	EndIf
	;
	$update = IniRead($inifle, "Device SQLite File", "update", "")
	If $update = "" Then
		$update = 4
		IniWrite($inifle, "Device SQLite File", "update", $update)
	EndIf
	;
	$ans = MsgBox(262144 + 33 + 256, "Load Query", "Load the 'Results' file?" & @LF & @LF & _
		"OK = Load the file now." & @LF & _
		"CANCEL = Abort loading." & @LF & @LF & _
		"(auto load in 5 seconds)", 5, $ResultsGUI)
	If $ans = 1 Or $ans = -1 Then
		LoadTheList()
	EndIf
	GUICtrlSetState($Input_subs, $GUI_DISABLE)
	GUICtrlSetState($Button_subs, $GUI_DISABLE)
	;
	$srcefold = IniRead($inifle, "Images Source", "path", "")
	GUICtrlSetData($Input_source, $srcefold)
	;
	$backups = IniRead($inifle, "Backup Images", "path", "")
	;
	$filelist = _FileListToArray($srcefold, "*", 1, False)
	$total = $filelist[0]
	For $f = 1 To $total
		$file = $filelist[$f]
		GUICtrlSetData($List_covers, $file)
	Next
	If $total > 0 Then
		GUICtrlSetData($Group_covers, "Cover Images - Source (" & $total & ")")
	EndIf
	;
	$disabled = ""
	$imgfold = IniRead($inifle, "Device Images Folder", "path", "")
	If Not FileExists($imgfold) Then
		$ans = MsgBox(262144 + 49, "Alert", "The device '.kobo-images' folder does not exist" & @LF & _
			"or cannot be found. Please make sure your USB" & @LF & _
			"Kobo device is connected." & @LF & @LF & _
			"OK = Device is connected, search for it." & @LF & _
			"CANCEL = Ignore." & @LF & @LF & _
			"NOTE - If the connected device drive is found" & @LF & _
			"with search, then the stored setting is updated.", 0, $ResultsGUI)
		If $ans = 1 Then
			; Search for a drive that has the '.kobo-images' folder.
			GetDrives(1)
		EndIf
		If Not FileExists($imgfold) Then
			; If not found then several controls should be disabled.
			$disabled = 1
			GUICtrlSetState($Button_add, $GUI_DISABLE)
			GUICtrlSetState($Button_backup, $GUI_DISABLE)
			GUICtrlSetState($Button_build, $GUI_DISABLE)
			GUICtrlSetState($Button_create, $GUI_DISABLE)
			GUICtrlSetState($Button_fix, $GUI_DISABLE)
			GUICtrlSetState($Button_relocate, $GUI_DISABLE)
			GUICtrlSetState($Button_remove, $GUI_DISABLE)
		EndIf
	EndIf
	GUICtrlSetData($Input_device, $imgfold)
	;
	$all = 1
	$one = 4
	$two = 4
	$three = 4
	;
	$restart = ""

	GuiSetState(@SW_SHOW)
	While 1
		$msg = GuiGetMsg()
		Select
		Case $msg = $GUI_EVENT_CLOSE Or $msg = $Button_quit
			; Exit / Close / Quit the window
			$winpos = WinGetPos($ResultsGUI, "")
			$left = $winpos[0]
			If $left < 0 Then
				$left = 2
			ElseIf $left > @DesktopWidth - $width Then
				$left = @DesktopWidth - $width - 25
			EndIf
			IniWrite($inifle, "Results Window", "left", $left)
			$top = $winpos[1]
			If $top < 0 Then
				$top = 2
			ElseIf $top > @DesktopHeight - ($height + 20) Then
				$top = @DesktopHeight - $height - 60
			EndIf
			IniWrite($inifle, "Results Window", "top", $top)
			;
			GUIDelete($ResultsGUI)
			ExitLoop
		Case $msg = $Button_up
			; Move up to previous entry
			$ents = _GUICtrlListView_GetItemCount($ListView_ebooks)
			If $ents > 0 Then
				$ind = _GUICtrlListView_GetSelectedIndices($ListView_ebooks, True)
				If IsArray($ind) Then
					If $ind[0] > 0 Then
						$ind = $ind[1]
						If $ind = 0 Then
							$ind = $ents - 1
						ElseIf $ind > 0 Then
							$ind = $ind - 1
						EndIf
						_GUICtrlListView_SetItemSelected($ListView_ebooks, $ind, False, True)
						_GUICtrlListView_ClickItem($ListView_ebooks, $ind, "left", False, 1, 1)
					EndIf
				EndIf
			EndIf
		Case $msg = $Button_subs
			; Enter sub-folders for selected ebook entry
			$subs = GUICtrlRead($Input_subs)
			IniWrite($resfile, $imageID, "subs", $subs)
		Case $msg = $Button_source
			; Browse to set the images source path
			$pth = FileSelectFolder("Browse to set the images source path. It is recommended to use the existing" _
				& " 'Ebook Covers' sub-folder within the program folder.", @ScriptDir, 7, $covers, $ResultsGUI)
			If @error <> 1 And StringMid($pth, 2, 2) = ":\" Then
				$srcefold = $pth
				IniWrite($inifle, "Images Source", "path", $srcefold)
				GUICtrlSetData($Input_source, $srcefold)
				;
				$filelist = _FileListToArray($srcefold, "*", 1, False)
				For $f = 1 To $filelist[0]
					$file = $filelist[$f]
					GUICtrlSetData($List_covers, $file)
				Next
			EndIf
		Case $msg = $Button_setup
			; Program Settings
			SettingsGUI()
		Case $msg = $Button_remove
			; Remove placebo images in empty ebook folders
			$ans = MsgBox(262144 + 35, "Removal Query", "What do you want to remove?" & @LF & @LF & _
				"YES = Remove placebo images from Kobo device." & @LF & _
				"NO = Remove images from 'Placebo' folder." & @LF & _
				"CANCEL = Abort any removal." & @LF & @LF & _
				"NOTE - YES also includes Alternate Drive if set.", 0, $ResultsGUI)
			If $ans = 6 Then
				If FileExists($imgfold) Then
					$continue = 1
					If $use = 1 Then
						CheckForAlternateDrive("CREATE")
					EndIf
					If $continue = 1 Then
						If FileExists($emptyfle) Then
							SplashTextOn("", "Removing Images!", 220, 100, -1, -1, 33)
							_FileReadToArray($emptyfle, $array, 1)
							For $e = 1 To $array[0]
								$line = $array[$e]
								If $line = "" Or StringInStr($line, "empty folders") > 0 Then
									ExitLoop
								Else
									FileDelete($line & "\*.parsed")
									If $altfold <> "" Then
										$subs = StringSplit($line, ".kobo-images", 1)
										$subs = $subs[2]
										;MsgBox(262192, "Sub-Folders", $subs, 0, $ResultsGUI)
										$drvfold = $altfold & $subs
										If FileExists($drvfold) Then
											FileDelete($drvfold & "\*.parsed")
										EndIf
									EndIf
								EndIf
							Next
							_FileWriteLog($logfile, "Placebo Images Removed - Device folders." & @CRLF & @CRLF)
							SplashOff()
						Else
							MsgBox(262192, "File Error", "The 'Empty.txt' file cannot be found!", 0, $ResultsGUI)
						EndIf
					EndIf
				Else
					; If not found then several controls should be disabled.
					$disabled = 1
					GUICtrlSetState($Button_add, $GUI_DISABLE)
					GUICtrlSetState($Button_backup, $GUI_DISABLE)
					GUICtrlSetState($Button_build, $GUI_DISABLE)
					GUICtrlSetState($Button_create, $GUI_DISABLE)
					GUICtrlSetState($Button_fix, $GUI_DISABLE)
					GUICtrlSetState($Button_remove, $GUI_DISABLE)
					GUICtrlSetState($Button_relocate, $GUI_DISABLE)
					MsgBox(262144 + 48, "Alert", "The device '.kobo-images' folder does not exist" & @LF & _
						"or cannot be found. Please make sure your USB" & @LF & _
						"Kobo device is connected.", 0, $ResultsGUI)
				EndIf
			ElseIf $ans = 7 Then
				If FileExists($placebo) Then
					SplashTextOn("", "Removing Images!", 220, 100, -1, -1, 33)
					$filelist = _FileListToArray($placebo, "*", 2, True)
					For $f = 1 To $filelist[0]
						$folder = $filelist[$f]
						DirRemove($folder & "\", 1)
					Next
					_FileWriteLog($logfile, "Placebo Images Removed - Placebo folder." & @CRLF & @CRLF)
					SplashOff()
				EndIf
			EndIf
		Case $msg = $Button_relocate
			; Relocate placebo images to empty ebook folders
			If FileExists($imgfold) Then
				$continue = 1
				If $use = 1 Then
					CheckForAlternateDrive("RELOCATE")
				EndIf
				If $continue = 1 Then
					If FileExists($placebo) Then
						;SplashTextOn("", "Renaming Images!", 220, 100, -1, -1, 33)
						;$filelist = _FileListToArray($placebo, "*", 2, True)
						;For $f = 1 To $filelist[0]
						;	$folder = $filelist[$f]
						;	FileMove($folder & "\*.jpg", $folder & "\*.parsed")
						;Next
						;SplashOff()
						If FileExists($emptyfle) Then
							GUICtrlSetState($Button_add, $GUI_DISABLE)
							GUICtrlSetState($Button_author, $GUI_DISABLE)
							GUICtrlSetState($Button_backup, $GUI_DISABLE)
							GUICtrlSetState($Button_build, $GUI_DISABLE)
							GUICtrlSetState($Button_copy, $GUI_DISABLE)
							GUICtrlSetState($Button_covers, $GUI_DISABLE)
							GUICtrlSetState($Button_create, $GUI_DISABLE)
							GUICtrlSetState($Button_device, $GUI_DISABLE)
							GUICtrlSetState($Button_down, $GUI_DISABLE)
							GUICtrlSetState($Button_drive, $GUI_DISABLE)
							GUICtrlSetState($Button_empty, $GUI_DISABLE)
							GUICtrlSetState($Button_fix, $GUI_DISABLE)
							GUICtrlSetState($Button_fold, $GUI_DISABLE)
							GUICtrlSetState($Button_images, $GUI_DISABLE)
							GUICtrlSetState($Button_info, $GUI_DISABLE)
							GUICtrlSetState($Button_list, $GUI_DISABLE)
							GUICtrlSetState($Button_log, $GUI_DISABLE)
							GUICtrlSetState($Button_mark, $GUI_DISABLE)
							GUICtrlSetState($Button_missing, $GUI_DISABLE)
							GUICtrlSetState($Button_next, $GUI_DISABLE)
							GUICtrlSetState($Button_quit, $GUI_DISABLE)
							GUICtrlSetState($Button_refresh, $GUI_DISABLE)
							GUICtrlSetState($Button_reload, $GUI_DISABLE)
							GUICtrlSetState($Button_relocate, $GUI_DISABLE)
							GUICtrlSetState($Button_remove, $GUI_DISABLE)
							GUICtrlSetState($Button_setup, $GUI_DISABLE)
							GUICtrlSetState($Button_source, $GUI_DISABLE)
							GUICtrlSetState($Button_up, $GUI_DISABLE)
							GUICtrlSetState($Combo_image, $GUI_DISABLE)
							GUICtrlSetState($Button_subs, $GUI_HIDE)
							;
							;SplashTextOn("", "Relocating Images!", 220, 140, -1, -1, 33)
							GUICtrlSetData($Label_status, "Getting Started - Please Wait")
							GUICtrlSetState($Label_status, $GUI_SHOW)
							;
							$copied = 0
							_FileReadToArray($emptyfle, $array, 1)
							$filelist = _FileListToArray($placebo, "*", 2, True)
							For $f = 1 To $filelist[0]
								$folder = $filelist[$f]
								$line = $array[$f]
								FileCopy($folder & "\*.parsed", $line & "\", 0)
								If $altfold <> "" Then
									$subs = StringSplit($line, ".kobo-images", 1)
									$subs = $subs[2]
									;MsgBox(262192, "Sub-Folders", $subs, 0, $ResultsGUI)
									$drvfold = $altfold & $subs
									If FileExists($drvfold) Then
										FileCopy($folder & "\*.parsed", $drvfold & "\", 0)
									EndIf
								EndIf
								$copied = $copied + 1
								;If StringRight($f, 2) = "50" Or StringRight($f, 2) = "00" Then
								;If StringRight($f, 1) = "0" Then
								If StringRight($f, 1) = "0" Or StringRight($f, 1) = "2" Or StringRight($f, 1) = "4" Or StringRight($f, 1) = "6" Or StringRight($f, 1) = "8" Then
									;SplashTextOn("", "Relocating Images!" & @LF & @LF & $f, 220, 140, -1, -1, 33)
									GUICtrlSetData($Label_status, $copied & " Placebo Image Folders Copied")
								EndIf
							Next
							_FileWriteLog($logfile, "Copied placebo images to device folders.")
							_FileWriteLog($logfile, $copied & " placebo folders content relocated." & @CRLF & @CRLF)
							GUICtrlSetState($Label_status, $GUI_HIDE)
							;SplashOff()
							;
							GUICtrlSetState($Button_add, $GUI_ENABLE)
							GUICtrlSetState($Button_author, $GUI_ENABLE)
							GUICtrlSetState($Button_backup, $GUI_ENABLE)
							GUICtrlSetState($Button_build, $GUI_ENABLE)
							GUICtrlSetState($Button_copy, $GUI_ENABLE)
							GUICtrlSetState($Button_covers, $GUI_ENABLE)
							GUICtrlSetState($Button_create, $GUI_ENABLE)
							GUICtrlSetState($Button_device, $GUI_ENABLE)
							GUICtrlSetState($Button_down, $GUI_ENABLE)
							GUICtrlSetState($Button_drive, $GUI_ENABLE)
							GUICtrlSetState($Button_empty, $GUI_ENABLE)
							GUICtrlSetState($Button_fix, $GUI_ENABLE)
							GUICtrlSetState($Button_fold, $GUI_ENABLE)
							GUICtrlSetState($Button_images, $GUI_ENABLE)
							GUICtrlSetState($Button_info, $GUI_ENABLE)
							GUICtrlSetState($Button_list, $GUI_ENABLE)
							GUICtrlSetState($Button_log, $GUI_ENABLE)
							GUICtrlSetState($Button_mark, $GUI_ENABLE)
							GUICtrlSetState($Button_missing, $GUI_ENABLE)
							GUICtrlSetState($Button_next, $GUI_ENABLE)
							GUICtrlSetState($Button_quit, $GUI_ENABLE)
							GUICtrlSetState($Button_refresh, $GUI_ENABLE)
							GUICtrlSetState($Button_reload, $GUI_ENABLE)
							GUICtrlSetState($Button_relocate, $GUI_ENABLE)
							GUICtrlSetState($Button_remove, $GUI_ENABLE)
							GUICtrlSetState($Button_setup, $GUI_ENABLE)
							GUICtrlSetState($Button_source, $GUI_ENABLE)
							GUICtrlSetState($Button_up, $GUI_ENABLE)
							GUICtrlSetState($Combo_image, $GUI_ENABLE)
							GUICtrlSetState($Button_subs, $GUI_SHOW)
							;
							MsgBox(262144 + 64, "Placebo Result", $copied & " placebo image folders content relocated!", 0, $ResultsGUI)
						Else
							MsgBox(262192, "File Error", "The 'Empty.txt' file cannot be found!", 0, $ResultsGUI)
						EndIf
					Else
						MsgBox(262192, "Source Error", "The 'Placebo' folder cannot be found!", 0, $ResultsGUI)
					EndIf
				EndIf
			Else
				; If not found then several controls should be disabled.
				$disabled = 1
				GUICtrlSetState($Button_add, $GUI_DISABLE)
				GUICtrlSetState($Button_backup, $GUI_DISABLE)
				GUICtrlSetState($Button_build, $GUI_DISABLE)
				GUICtrlSetState($Button_create, $GUI_DISABLE)
				GUICtrlSetState($Button_fix, $GUI_DISABLE)
				GUICtrlSetState($Button_remove, $GUI_DISABLE)
				GUICtrlSetState($Button_relocate, $GUI_DISABLE)
				MsgBox(262144 + 48, "Alert", "The device '.kobo-images' folder does not exist" & @LF & _
					"or cannot be found. Please make sure your USB" & @LF & _
					"Kobo device is connected.", 0, $ResultsGUI)
			EndIf
		Case $msg = $Button_reload
			; Reload the List
			$ents = _GUICtrlListView_GetItemCount($ListView_ebooks)
			If $ents > 0 Then _GUICtrlListView_DeleteAllItems($ListView_ebooks)
			LoadTheList()
		Case $msg = $Button_refresh
			; Refresh the Covers list
			GUICtrlSetData($List_covers, "")
			$filelist = _FileListToArray($srcefold, "*", 1, False)
			$total = $filelist[0]
			If $total > 0 Then
				For $f = 1 To $total
					$file = $filelist[$f]
					GUICtrlSetData($List_covers, $file)
				Next
				GUICtrlSetData($Group_covers, "Cover Images - Source (" & $total & ")")
			Else
				GUICtrlSetData($Group_covers, "Cover Images - Source")
			EndIf
		Case $msg = $Button_next Or $restart = 1
			; Go to the next marked entry
			$ind = _GUICtrlListView_GetSelectedIndices($ListView_ebooks, True)
			If IsArray($ind) Then
				If $ind[0] > 0 Then
					$ind = $ind[1]
					For $e = $ind To $ents - 1
						$imageID = _GUICtrlListView_GetItemText($ListView_ebooks, $e + 1, 7)
						$mark = IniRead($resfile, $imageID, "mark", "")
						If $mark = 1 Then
							$ind = $e + 1
							_GUICtrlListView_EnsureVisible($ListView_ebooks, $ind, False)
							_GUICtrlListView_SetItemSelected($ListView_ebooks, $ind, True, True)
							_GUICtrlListView_ClickItem($ListView_ebooks, $ind, "left", False, 1, 1)
							ExitLoop
						EndIf
					Next
					If $mark = "" And $restart = "" Then
						$ind = 0
						_GUICtrlListView_EnsureVisible($ListView_ebooks, $ind, False)
						_GUICtrlListView_SetItemSelected($ListView_ebooks, $ind, True, True)
						$restart = 1
					Else
						$restart = ""
					EndIf
				Else
					$restart = ""
					MsgBox(262192, "Selection Error", "Select a list entry to start at!", 0, $ResultsGUI)
				EndIf
			Else
				$restart = ""
			EndIf
		Case $msg = $Button_missing
			; View the list of ebooks missing images
			If FileExists($missfle) Then ShellExecute($missfle)
		Case $msg = $Button_mark
			; Mark the selected entry
			$ind = _GUICtrlListView_GetSelectedIndices($ListView_ebooks, True)
			If IsArray($ind) Then
				If $ind[0] > 0 Then
					$ind = $ind[1]
					$imageID = _GUICtrlListView_GetItemText($ListView_ebooks, $ind, 7)
					$idx = $lowid + $ind
					$rename = IniRead($resfile, $imageID, "rename", "")
					$mark = IniRead($resfile, $imageID, "mark", "")
					If $mark = "" Then
						$mark = 1
						IniWrite($resfile, $imageID, "mark", $mark)
						If $rename = 1 Then
							; Light Olive
							GUICtrlSetBkColor($idx, 0xA7BE01)
						Else
							GUICtrlSetBkColor($idx, $COLOR_YELLOW)
						EndIf
					Else
						$mark = ""
						IniDelete($resfile, $imageID, "mark")
						If $rename = 1 Then
							GUICtrlSetBkColor($idx, $COLOR_AQUA)
						Else
							If IsInt($idx / 2) = 1 Then
								GUICtrlSetBkColor($idx, 0xC0F0C0)
							Else
								GUICtrlSetBkColor($idx, 0xF0D0F0)
							EndIf
						EndIf
					EndIf
				EndIf
			EndIf
		Case $msg = $Button_log
			; View the Log Record
			If FileExists($logfile) Then ShellExecute($logfile)
		Case $msg = $Button_list
			; View the placebo list
			If FileExists($placetxt) Then ShellExecute($placetxt)
		Case $msg = $Button_info
			; Program Information
			MsgBox(262208, "Program Information", _
				"This is a helper program to assist with missing or" & @LF & _
				"wrong size ebook cover images on a Kobo device." & @LF & @LF & _
				"The EMPTY FOLDERS LIST button shows the list of" & @LF & _
				"empty folders." & @LF & @LF & _
				"Click the Cover Image to see it full size & get detail." & @LF & @LF & _
				"[ADDED ROW COLORS]" & @LF & _
				"AQUA = Renamed Author." & @LF & _
				"FUCHSIA = Created image(s) for an entry." & @LF & _
				"LIME = Fixed image(s) for an entry." & @LF & _
				"OLIVE = Renamed Author & Marked entry." & @LF & _
				"RED = Added image(s) to an entry." & @LF & _
				"YELLOW = Marked entry." & @LF & @LF & _
				"BIG THANKS to jchd for his improved sqlite code." & @LF & @LF & _
				"BIG THANKS to Jon & team at the AutoIt Forum." & @LF & @LF & _
				"© May 2023 by TheSaint - Kobo Cover Fixer " & $version & @LF & _
				$updated, 0, $ResultsGUI)
		Case $msg = $Button_images
			; Open the device image folder
			$imgfold = IniRead($inifle, "Device Images Folder", "path", "")
			If FileExists($imgfold) Then ShellExecute($imgfold)
		Case $msg = $Button_fold
			; Open the program folder
			ShellExecute(@ScriptDir)
		Case $msg = $Button_fix
			; Fix image size in an ebook folder
			If FileExists($imgfold) Then
				$continue = 1
				If $use = 1 Then
					CheckForAlternateDrive("FIX")
					If $altfold = "" Then
						$drvfold = ""
					Else
						$drvfold = $altfold
					EndIf
				Else
					$drvfold = ""
				EndIf
				If $continue = 1 Then
					$ind = _GUICtrlListView_GetSelectedIndices($ListView_ebooks, True)
					If IsArray($ind) Then
						If $ind[0] > 0 Then
							$ind = $ind[1]
							$title = _GUICtrlListView_GetItemText($ListView_ebooks, $ind, 1)
							$author = _GUICtrlListView_GetItemText($ListView_ebooks, $ind, 2)
							For $colnum = 4 To 6
								$image = _GUICtrlListView_GetItemText($ListView_ebooks, $ind, $colnum)
								If $image <> "" Then
									$pos = StringInStr($image, "\", 0, -1)
									$subs = StringLeft($image, $pos)
									;MsgBox(262192, "Sub-Folders", $subs, 0, $ResultsGUI)
									If $drvfold <> "" Then $altfold = $drvfold & "\" & $subs
									$imageID = _GUICtrlListView_GetItemText($ListView_ebooks, $ind, 7)
									$covimg = GUICtrlRead($List_covers)
									If $covimg <> "" Then
										$covimg = $srcefold & "\" & $covimg
										If FileExists($covimg) Then
											$style = BitOR($WS_OVERLAPPED, $WS_CAPTION, $WS_SYSMENU, $WS_VISIBLE, $WS_CLIPSIBLINGS, $WS_MINIMIZEBOX)
											$SelectionGUI = GuiCreate("Image Selection", 285, 135, Default, Default, $style, $WS_EX_TOPMOST, $ResultsGUI)
											GUISetBkColor($COLOR_CREAM, $SelectionGUI)
											;
											; CONTROLS
											$Group_fix = GuiCtrlCreateGroup("Images To Fix", 10, 10, 265, 55)
											$Checkbox_all = GuiCtrlCreateCheckbox("ALL", 20, 30, 40, 20)
											GUICtrlSetTip($Checkbox_all, "Select ALL images!")
											$Checkbox_1 = GuiCtrlCreateCheckbox("Image 1", 70, 30, 60, 20)
											GUICtrlSetTip($Checkbox_1, "Select Image 1!")
											$Checkbox_2 = GuiCtrlCreateCheckbox("Image 2", 140, 30, 60, 20)
											GUICtrlSetTip($Checkbox_2, "Select Image 2!")
											$Checkbox_3 = GuiCtrlCreateCheckbox("Image 3", 210, 30, 60, 20)
											GUICtrlSetTip($Checkbox_3, "Select Image 3!")
											;
											$Button_continue = GuiCtrlCreateButton("CONTINUE", 10, 75, 140, 50)
											GUICtrlSetFont($Button_continue, 9, 600)
											GUICtrlSetTip($Button_continue, "Continue with Selection!")
											;
											$Button_inf = GuiCtrlCreateButton("Info", 160, 75, 50, 50, $BS_ICON)
											GUICtrlSetTip($Button_inf, "Selection Information!")
											;
											$Button_close = GuiCtrlCreateButton("EXIT", 220, 75, 55, 50, $BS_ICON)
											GUICtrlSetTip($Button_close, "Exit / Close / Quit the window!")
											;
											; SETTINGS
											GUICtrlSetImage($Button_inf, $user32, $icoI, 1)
											GUICtrlSetImage($Button_close, $user32, $icoX, 1)
											;
											If $all = 1 Then
												GUICtrlSetState($Checkbox_all, $all)
											Else
												If $one = 1 Then GUICtrlSetState($Checkbox_1, $one)
												If $two = 1 Then GUICtrlSetState($Checkbox_2, $two)
												If $three = 1 Then GUICtrlSetState($Checkbox_3, $three)
											EndIf

											GuiSetState()
											While 1
												$msg = GuiGetMsg()
												Select
												Case $msg = $GUI_EVENT_CLOSE Or $msg = $Button_close
													; Close the Selection window
													$fix = ""
													GUIDelete($SelectionGUI)
													ExitLoop
												Case $msg = $Button_inf
													; Settings Information
													MsgBox(262208, "Selection Information", _
														"Select one or more images to fix on your" & @LF & _
														"Kobo device." & @LF & @LF & _
														"You will be queried about each one." & @LF & @LF & _
														"The FIX will remove (delete) the existing" & @LF & _
														"ebook image file on your Kobo device," & @LF & _
														"and replace it with your chosen one.", 0, $SelectionGUI)
												Case $msg = $Button_continue
													; Continue with Selection
													If $all = 1 Or $one = 1 Or $two = 1 Or $three = 1 Then
														$fix = 1
														GUIDelete($SelectionGUI)
														ExitLoop
													Else
														MsgBox(262192, "Selection Error", "No image fixes selected!", 0, $SelectionGUI)
													EndIf
												Case $msg = $Checkbox_all
													; Select ALL images
													If GUICtrlRead($Checkbox_all) = $GUI_CHECKED Then
														$all = 1
														If $one = 1 Then
															$one = 4
															GUICtrlSetState($Checkbox_1, $one)
														EndIf
														If $two = 1 Then
															$two = 4
															GUICtrlSetState($Checkbox_2, $two)
														EndIf
														If $three = 1 Then
															$three = 4
															GUICtrlSetState($Checkbox_3, $three)
														EndIf
													Else
														$all = 4
													EndIf
												Case $msg = $Checkbox_3
													; Select Image 3
													If GUICtrlRead($Checkbox_3) = $GUI_CHECKED Then
														$three = 1
														If $all = 1 Then
															$all = 4
															GUICtrlSetState($Checkbox_all, $all)
														EndIf
													Else
														$three = 4
													EndIf
												Case $msg = $Checkbox_2
													; Select Image 2
													If GUICtrlRead($Checkbox_2) = $GUI_CHECKED Then
														$two = 1
														If $all = 1 Then
															$all = 4
															GUICtrlSetState($Checkbox_all, $all)
														EndIf
													Else
														$two = 4
													EndIf
												Case $msg = $Checkbox_1
													; Select Image 1
													If GUICtrlRead($Checkbox_1) = $GUI_CHECKED Then
														$one = 1
														If $all = 1 Then
															$all = 4
															GUICtrlSetState($Checkbox_all, $all)
														EndIf
													Else
														$one = 4
													EndIf
												Case Else
													;;;
												EndSelect
											WEnd
											If $fix = 1 Then
												_FileWriteLog($logfile, "Processing - " & $author & " - " & $title)
												$fixed = 0
												$skip = 0
												If $one = 1 Or $all = 1 Then
													$image1 = _GUICtrlListView_GetItemText($ListView_ebooks, $ind, 4)
													If $image1 <> "" Then
														$imgfile = $imgfold & "\" & $image1
														$ans = MsgBox(262144 + 33, "FIX Query - 1", $title & @LF & $author & @LF & @LF & _
															"Replace the following image file -" & @LF & _
															$imgfile & @LF & @LF & _
															"Using the following source file -" & @LF & _
															$covimg & @LF & @LF & _
															"OK = Create the specified image." & @LF & _
															"CANCEL = Abort Creation.", 0, $ResultsGUI)
														If $ans = 1 Then
															_FileWriteLog($logfile, "Fixing '" & $image1 & "' on device.")
															CreateFromImage($covimg, $imgfile, 1)
															$fixed = $fixed + 1
														Else
															$skip = $skip + 1
														EndIf
													EndIf
												EndIf
												If $two = 1 Or $all = 1 Then
													$image2 = _GUICtrlListView_GetItemText($ListView_ebooks, $ind, 5)
													If $image2 <> "" Then
														$imgfile = $imgfold & "\" & $image2
														$ans = MsgBox(262144 + 33, "FIX Query - 2", $title & @LF & $author & @LF & @LF & _
															"Replace the following image file -" & @LF & _
															$imgfile & @LF & @LF & _
															"Using the following source file -" & @LF & _
															$covimg & @LF & @LF & _
															"OK = Create the specified image." & @LF & _
															"CANCEL = Abort Creation.", 0, $ResultsGUI)
														If $ans = 1 Then
															_FileWriteLog($logfile, "Fixing '" & $image2 & "' on device.")
															CreateFromImage($covimg, $imgfile, 2)
															$fixed = $fixed + 1
														Else
															$skip = $skip + 1
														EndIf
													EndIf
												EndIf
												If $three = 1 Or $all = 1 Then
													$image3 = _GUICtrlListView_GetItemText($ListView_ebooks, $ind, 6)
													If $image3 <> "" Then
														$imgfile = $imgfold & "\" & $image3
														$ans = MsgBox(262144 + 33, "FIX Query - 3", $title & @LF & $author & @LF & @LF & _
															"Replace the following image file -" & @LF & _
															$imgfile & @LF & @LF & _
															"Using the following source file -" & @LF & _
															$covimg & @LF & @LF & _
															"OK = Create the specified image." & @LF & _
															"CANCEL = Abort Creation.", 0, $ResultsGUI)
														If $ans = 1 Then
															_FileWriteLog($logfile, "Fixing '" & $image3 & "' on device.")
															CreateFromImage($covimg, $imgfile, 3)
															$fixed = $fixed + 1
														Else
															$skip = $skip + 1
														EndIf
													EndIf
												EndIf
												If $fixed > 0 Then
													$idx = $lowid + $ind
													GUICtrlSetBkColor($idx, $COLOR_LIME)
												EndIf
												If $skip = 3 Then
													_FileWriteLog($logfile, "All images skipped.")
												ElseIf $skip = 2 Then
													If ($one = 1 And $two = 1 And $three = 4) Or ($one = 1 And $two = 4 And $three = 1) Or ($one = 4 And $two = 1 And $three = 1) Then
														_FileWriteLog($logfile, "Two images skipped.")
													EndIf
												ElseIf $skip = 1 Then
													If ($one = 1 And $two = 4 And $three = 4) Or ($one = 4 And $two = 1 And $three = 4) Or ($one = 4 And $two = 4 And $three = 1) Then
														_FileWriteLog($logfile, "One image skipped.")
													EndIf
												EndIf
												_FileWriteLog($logfile, "Process Complete." & @CRLF & @CRLF)
											EndIf
										EndIf
									Else
										MsgBox(262192, "Selection Error", "No source cover image is selected!", 0, $ResultsGUI)
									EndIf
									ExitLoop
								EndIf
							Next
						Else
							MsgBox(262192, "Selection Error", "Badly selected entry!", 0, $ResultsGUI)
						EndIf
					Else
						MsgBox(262192, "Selection Error", "No entry is selected!", 0, $ResultsGUI)
					EndIf
				EndIf
			Else
				; If not found then several controls should be disabled.
				$disabled = 1
				GUICtrlSetState($Button_add, $GUI_DISABLE)
				GUICtrlSetState($Button_backup, $GUI_DISABLE)
				GUICtrlSetState($Button_build, $GUI_DISABLE)
				GUICtrlSetState($Button_create, $GUI_DISABLE)
				GUICtrlSetState($Button_fix, $GUI_DISABLE)
				GUICtrlSetState($Button_relocate, $GUI_DISABLE)
				GUICtrlSetState($Button_remove, $GUI_DISABLE)
				MsgBox(262144 + 48, "Alert", "The device '.kobo-images' folder does not exist" & @LF & _
					"or cannot be found. Please make sure your USB" & @LF & _
					"Kobo device is connected.", 0, $ResultsGUI)
			EndIf
		Case $msg = $Button_empty
			; Show the list of empty ebook folders
			If FileExists($emptyfle) Then ShellExecute($emptyfle)
		Case $msg = $Button_drive
			; Open the alternate drive images folder
			If $drive = "" Then
				$altfold = ""
				MsgBox(262192, "Path Error", "No alternate drive has been set!", 0, $ResultsGUI)
			Else
				$altfold = $drive & ".kobo-images"
				If FileExists($altfold) Then
					ShellExecute($altfold)
				Else
					$altfold = ""
					MsgBox(262192, "Path Error", "Correct alternate drive not found!", 0, $ResultsGUI)
				EndIf
			EndIf
		Case $msg = $Button_down
			; Move down to next entry
			$ents = _GUICtrlListView_GetItemCount($ListView_ebooks)
			If $ents > 0 Then
				$ind = _GUICtrlListView_GetSelectedIndices($ListView_ebooks, True)
				If IsArray($ind) Then
					If $ind[0] > 0 Then
						$ind = $ind[1]
						If $ind = $ents - 1 Then
							$ind = 0
						ElseIf $ind < $ents - 1 Then
							$ind = $ind + 1
						EndIf
						_GUICtrlListView_SetItemSelected($ListView_ebooks, $ind, False, True)
						_GUICtrlListView_ClickItem($ListView_ebooks, $ind, "left", False, 1, 1)
					EndIf
				EndIf
			EndIf
		Case $msg = $Button_device
			; Find the Kobo device drive
			$imgfold = IniRead($inifle, "Device Images Folder", "path", "")
			If FileExists($imgfold) Then
				If $disabled = 1 Then
					$disabled = ""
					GUICtrlSetData($Input_device, $imgfold)
					GUICtrlSetState($Button_add, $GUI_ENABLE)
					GUICtrlSetState($Button_backup, $GUI_ENABLE)
					GUICtrlSetState($Button_build, $GUI_ENABLE)
					GUICtrlSetState($Button_create, $GUI_ENABLE)
					GUICtrlSetState($Button_fix, $GUI_ENABLE)
					GUICtrlSetState($Button_relocate, $GUI_ENABLE)
					GUICtrlSetState($Button_remove, $GUI_ENABLE)
				EndIf
			Else
				$ans = MsgBox(262144 + 49, "Alert", "The device '.kobo-images' folder does not exist" & @LF & _
					"or cannot be found. Please make sure your USB" & @LF & _
					"Kobo device is connected." & @LF & @LF & _
					"OK = Device is connected, search for it." & @LF & _
					"CANCEL = Ignore." & @LF & @LF & _
					"NOTE - If the connected device drive is found" & @LF & _
					"with search, then the stored setting is updated.", 0, $ResultsGUI)
				If $ans = 1 Then
					; Search for a drive that has the '.kobo-images' folder.
					GetDrives(1)
				EndIf
				If FileExists($imgfold) Then
					GUICtrlSetData($Input_device, $imgfold)
					If $disabled = 1 Then
						$disabled = ""
						GUICtrlSetState($Button_add, $GUI_ENABLE)
						GUICtrlSetState($Button_backup, $GUI_ENABLE)
						GUICtrlSetState($Button_build, $GUI_ENABLE)
						GUICtrlSetState($Button_create, $GUI_ENABLE)
						GUICtrlSetState($Button_fix, $GUI_ENABLE)
						GUICtrlSetState($Button_relocate, $GUI_ENABLE)
						GUICtrlSetState($Button_remove, $GUI_ENABLE)
					EndIf
				Else
					; If not found then several controls should be disabled.
					$disabled = 1
					GUICtrlSetState($Button_add, $GUI_DISABLE)
					GUICtrlSetState($Button_backup, $GUI_DISABLE)
					GUICtrlSetState($Button_build, $GUI_DISABLE)
					GUICtrlSetState($Button_create, $GUI_DISABLE)
					GUICtrlSetState($Button_fix, $GUI_DISABLE)
					GUICtrlSetState($Button_relocate, $GUI_DISABLE)
					GUICtrlSetState($Button_remove, $GUI_DISABLE)
				EndIf
			EndIf
		Case $msg = $Button_create
			; Create ALL missing images for an ebook folder
			If FileExists($imgfold) Then
				$continue = 1
				If $use = 1 Then
					CheckForAlternateDrive("CREATE")
					If $altfold = "" Then
						$drvfold = ""
					Else
						$drvfold = $altfold
					EndIf
				Else
					$drvfold = ""
				EndIf
				If $continue = 1 Then
					$ind = _GUICtrlListView_GetSelectedIndices($ListView_ebooks, True)
					If IsArray($ind) Then
						If $ind[0] > 0 Then
							$ind = $ind[1]
							$title = _GUICtrlListView_GetItemText($ListView_ebooks, $ind, 1)
							$author = _GUICtrlListView_GetItemText($ListView_ebooks, $ind, 2)
							$images = _GUICtrlListView_GetItemText($ListView_ebooks, $ind, 3)
							If $images = 0 Then
								$imageID = _GUICtrlListView_GetItemText($ListView_ebooks, $ind, 7)
								$subs = IniRead($resfile, $imageID, "subs", "")
								If $subs = "" Then
									MsgBox(262192, "Source Error", "This entry does not have any sub-folders set!", 0, $ResultsGUI)
								Else
									$subs = $subs & "\"
									If $drvfold <> "" Then $altfold = $drvfold & "\" & $subs
									$covimg = GUICtrlRead($List_covers)
									If $covimg <> "" Then
										$covimg = $srcefold & "\" & $covimg
										If FileExists($covimg) Then
											_FileWriteLog($logfile, "Processing - " & $author & " - " & $title)
											$created = 0
											$skip = 0
											$image1 = $subs & $imageID & " - N3_FULL.parsed"
											$imgfile = $imgfold & "\" & $image1
											$ans = MsgBox(262144 + 33, "CREATE Query", $title & @LF & $author & @LF & @LF & _
												"Create the following image file -" & @LF & _
												$imgfile & @LF & @LF & _
												"Using the following source file -" & @LF & _
												$covimg & @LF & @LF & _
												"OK = Create the specified image." & @LF & _
												"CANCEL = Abort Creation.", 0, $ResultsGUI)
											If $ans = 1 Then
												_FileWriteLog($logfile, "Creating '" & $image1 & "' on device.")
												CreateFromImage($covimg, $imgfile, 1)
												_GUICtrlListView_SetItemText($ListView_ebooks, $ind, $image1, 4)
												$created = $created + 1
											Else
												$skip = $skip + 1
											EndIf
											$image2 = $subs & $imageID & " - N3_LIBRARY_FULL.parsed"
											$imgfile = $imgfold & "\" & $image2
											$ans = MsgBox(262144 + 33, "CREATE Query", $title & @LF & $author & @LF & @LF & _
												"Create the following image file -" & @LF & _
												$imgfile & @LF & @LF & _
												"Using the following source file -" & @LF & _
												$covimg & @LF & @LF & _
												"OK = Create the specified image." & @LF & _
												"CANCEL = Abort Creation.", 0, $ResultsGUI)
											If $ans = 1 Then
												_FileWriteLog($logfile, "Creating '" & $image2 & "' on device.")
												CreateFromImage($covimg, $imgfile, 2)
												_GUICtrlListView_SetItemText($ListView_ebooks, $ind, $image2, 5)
												$created = $created + 1
											Else
												$skip = $skip + 1
											EndIf
											$image3 = $subs & $imageID & " - N3_LIBRARY_GRID.parsed"
											$imgfile = $imgfold & "\" & $image3
											$ans = MsgBox(262144 + 33, "CREATE Query", $title & @LF & $author & @LF & @LF & _
												"Create the following image file -" & @LF & _
												$imgfile & @LF & @LF & _
												"Using the following source file -" & @LF & _
												$covimg & @LF & @LF & _
												"OK = Create the specified image." & @LF & _
												"CANCEL = Abort Creation.", 0, $ResultsGUI)
											If $ans = 1 Then
												_FileWriteLog($logfile, "Creating '" & $image3 & "' on device.")
												CreateFromImage($covimg, $imgfile, 3)
												_GUICtrlListView_SetItemText($ListView_ebooks, $ind, $image3, 6)
												$created = $created + 1
											Else
												$skip = $skip + 1
											EndIf
											If $created > 0 Then
												_GUICtrlListView_SetItemText($ListView_ebooks, $ind, $created, 3)
												$idx = $lowid + $ind
												GUICtrlSetBkColor($idx, $COLOR_FUCHSIA)
											EndIf
											If $skip = 3 Then
												_FileWriteLog($logfile, "All images skipped.")
											ElseIf $skip = 2 Then
												_FileWriteLog($logfile, "Two images skipped.")
											ElseIf $skip = 1 Then
												_FileWriteLog($logfile, "One image skipped.")
											EndIf
											_FileWriteLog($logfile, "Process Complete." & @CRLF & @CRLF)
										EndIf
									Else
										MsgBox(262192, "Selection Error", "No source cover image is selected!", 0, $ResultsGUI)
									EndIf
								EndIf
							Else
								MsgBox(262192, "Selection Error", "This entry already has some images!", 0, $ResultsGUI)
							EndIf
						Else
							MsgBox(262192, "Selection Error", "Badly selected entry!", 0, $ResultsGUI)
						EndIf
					Else
						MsgBox(262192, "Selection Error", "No entry is selected!", 0, $ResultsGUI)
					EndIf
				EndIf
			Else
				; If not found then several controls should be disabled.
				$disabled = 1
				GUICtrlSetState($Button_add, $GUI_DISABLE)
				GUICtrlSetState($Button_backup, $GUI_DISABLE)
				GUICtrlSetState($Button_build, $GUI_DISABLE)
				GUICtrlSetState($Button_create, $GUI_DISABLE)
				GUICtrlSetState($Button_fix, $GUI_DISABLE)
				GUICtrlSetState($Button_remove, $GUI_DISABLE)
				GUICtrlSetState($Button_relocate, $GUI_DISABLE)
				MsgBox(262144 + 48, "Alert", "The device '.kobo-images' folder does not exist" & @LF & _
					"or cannot be found. Please make sure your USB" & @LF & _
					"Kobo device is connected.", 0, $ResultsGUI)
			EndIf
		Case $msg = $Button_covers
			; Open the images source folder
			If FileExists($srcefold) Then ShellExecute($srcefold)
		Case $msg = $Button_copy
			; Copy the Title and ISBN to clipboard
			$title = GUICtrlRead($Input_title)
			If $title <> "" Then
				$title = StringReplace($title, ":", "")
				$title = StringReplace($title, "\", "&")
				$title = StringReplace($title, "/", "&")
				$title = StringStripWS($title, 7)
				$ISBN = GUICtrlRead($Input_isbn)
				If $ISBN <> "" Then
					ClipPut($title & " - " & $ISBN)
				EndIf
			EndIf
		Case $msg = $Button_build
			; Create placebo image files ready for the empty ebook folders
			If Not FileExists($placebo) Then DirCreate($placebo)
			$cnt = IniRead($inifle, "Empty Folders", "count", 0)
			If $cnt > 0 Then
				Local $fsize, $hBitmap, $hImage, $hGraphic, $hBrush, $hFormat, $hFamily, $hFont, $iHeight, $imgpth, $imgtxt, $iWidth
				Local $parsed, $rechigh, $result, $tLayout, $txtlen, $x, $y
				;
				GUICtrlSetState($Button_add, $GUI_DISABLE)
				GUICtrlSetState($Button_author, $GUI_DISABLE)
				GUICtrlSetState($Button_backup, $GUI_DISABLE)
				GUICtrlSetState($Button_build, $GUI_DISABLE)
				GUICtrlSetState($Button_copy, $GUI_DISABLE)
				GUICtrlSetState($Button_covers, $GUI_DISABLE)
				GUICtrlSetState($Button_create, $GUI_DISABLE)
				GUICtrlSetState($Button_device, $GUI_DISABLE)
				GUICtrlSetState($Button_down, $GUI_DISABLE)
				GUICtrlSetState($Button_drive, $GUI_DISABLE)
				GUICtrlSetState($Button_empty, $GUI_DISABLE)
				GUICtrlSetState($Button_fix, $GUI_DISABLE)
				GUICtrlSetState($Button_fold, $GUI_DISABLE)
				GUICtrlSetState($Button_images, $GUI_DISABLE)
				GUICtrlSetState($Button_info, $GUI_DISABLE)
				GUICtrlSetState($Button_list, $GUI_DISABLE)
				GUICtrlSetState($Button_log, $GUI_DISABLE)
				GUICtrlSetState($Button_mark, $GUI_DISABLE)
				GUICtrlSetState($Button_missing, $GUI_DISABLE)
				GUICtrlSetState($Button_next, $GUI_DISABLE)
				GUICtrlSetState($Button_quit, $GUI_DISABLE)
				GUICtrlSetState($Button_refresh, $GUI_DISABLE)
				GUICtrlSetState($Button_reload, $GUI_DISABLE)
				GUICtrlSetState($Button_relocate, $GUI_DISABLE)
				GUICtrlSetState($Button_remove, $GUI_DISABLE)
				GUICtrlSetState($Button_setup, $GUI_DISABLE)
				GUICtrlSetState($Button_source, $GUI_DISABLE)
				GUICtrlSetState($Button_up, $GUI_DISABLE)
				GUICtrlSetState($Combo_image, $GUI_DISABLE)
				GUICtrlSetState($Button_subs, $GUI_HIDE)
				;
				GUICtrlSetData($Label_status, "Getting Started - Please Wait")
				GUICtrlSetState($Label_status, $GUI_SHOW)
				_FileCreate($placetxt)
				; Initialize GDI+ library
				_GDIPlus_Startup ()
				_FileWriteLog($logfile, "Creating placebo ebook images.")
				$entries = ""
				$imgtxt = 0
				If $psize = 1 Then
					; 1050 x 1680
					$iWidth = $wide1
					$iHeight = $high1
					$parsed = " - N3_FULL.parsed"
					$x = 215
					$y = 725
					$w = 650
					$fsize = 148
					$rechigh = 450
				ElseIf $psize = 2 Then
					; 330 x 530
					$iWidth = $wide2
					$iHeight = $high2
					$parsed = " - N3_LIBRARY_FULL.parsed"
					$x = 55
					$y = 210
					$w = 230
					$fsize = 48
					$rechigh = 250
				ElseIf $psize = 3 Then
					; 140 x 225
					$iWidth = $wide3
					$iHeight = $high3
					$parsed = " - N3_LIBRARY_GRID.parsed"
					$x = 10
					$y = 80
					$w = 120
					$fsize = 26
					$rechigh = 100
				EndIf
				For $c = 1 To $cnt
					$folder = $placebo & "\" & $c
					If Not FileExists($folder) Then DirCreate($folder)
					For $e = 0 To $ents - 1
						_GUICtrlListView_EnsureVisible($ListView_ebooks, $e, False)
						_GUICtrlListView_SetItemSelected($ListView_ebooks, $e, True, True)
						;_GUICtrlListView_ClickItem($ListView_ebooks, $e, "left", False, 1, 1)
						$images = _GUICtrlListView_GetItemText($ListView_ebooks, $e, 3)
						If $images = 0 Then
							$imgtxt = $imgtxt + 1
							$title = _GUICtrlListView_GetItemText($ListView_ebooks, $e, 1)
							$author = _GUICtrlListView_GetItemText($ListView_ebooks, $e, 2)
							$entry = $imgtxt & " = " & $title & " - " & $author
							$entries &= $entry & @CRLF
							$imageID = _GUICtrlListView_GetItemText($ListView_ebooks, $e, 7)
							$image = $imageID & $parsed
							; Only while testing
							;$image = StringTrimRight($image, 7) & ".jpg"
							;
							$imgpth = $folder & "\" & $image
							If Not FileExists($imgpth) Then
								; Capture screen region
								$hBitmap = _ScreenCapture_Capture("", 0, 0, $iWidth, $iHeight)
								$hImage = _GDIPlus_BitmapCreateFromHBITMAP($hBitmap)
								; Clear the screen capture to solid white
								$hGraphic = _GDIPlus_ImageGetGraphicsContext($hImage)
								_GDIPlus_GraphicsClear($hGraphic, 0xFFFFFFFF)
								; Add black text
								$hBrush = _GDIPlus_BrushCreateSolid(0xFF000000)
								$hFormat = _GDIPlus_StringFormatCreate()
								_GDIPlus_StringFormatSetAlign($hFormat, 1)
								$hFamily = _GDIPlus_FontFamilyCreate("Verdana")
								$hFont = _GDIPlus_FontCreate($hFamily, $fsize, 1)
								$txtlen = StringLen($imgtxt)
								$tLayout = _GDIPlus_RectFCreate($x, $y, $w, $rechigh)
								_GDIPlus_GraphicsDrawStringEx($hGraphic, $imgtxt, $hFont, $tLayout, $hFormat, $hBrush)
								; DPI always seems to default to 96 x 96, so setting DPI anyway.
								$result = _GDIPlus_BitmapSetResolution($hImage, 300, 300)
								; Save resultant image
								$CLSID = _GDIPlus_EncodersGetCLSID("JPG")
								_GDIPlus_ImageSaveToFileEx($hImage, $imgpth, $CLSID, 0)
								; Clean up resources
								_GDIPlus_FontDispose($hFont)
								_GDIPlus_FontFamilyDispose($hFamily)
								_GDIPlus_StringFormatDispose($hFormat)
								_GDIPlus_BrushDispose($hBrush)
								_GDIPlus_GraphicsDispose($hGraphic)
								_GDIPlus_ImageDispose($hImage)
								_WinAPI_DeleteObject($hBitmap)
							EndIf
							If StringRight($imgtxt, 1) = "0" Then
								GUICtrlSetData($Label_status, $imgtxt & " Placebo Images Created")
							EndIf
							; Only while testing
							;If $imgtxt = 1000 Then
							;	ExitLoop 2
							;EndIf
						EndIf
					Next
				Next
				_GUICtrlListView_ClickItem($ListView_ebooks, $e, "left", False, 1, 1)
				; Shut down GDI+ library
				_GDIPlus_ShutDown()
				_FileWriteLog($logfile, $imgtxt & " placebo ebook images created." & @CRLF & @CRLF)
				FileWrite($placetxt, $entries)
				GUICtrlSetState($Label_status, $GUI_HIDE)
				MsgBox(262144 + 64, "Placebo Result", $imgtxt & " placebo ebook images created!", 0, $ResultsGUI)
				;
				GUICtrlSetState($Button_add, $GUI_ENABLE)
				GUICtrlSetState($Button_author, $GUI_ENABLE)
				GUICtrlSetState($Button_backup, $GUI_ENABLE)
				GUICtrlSetState($Button_build, $GUI_ENABLE)
				GUICtrlSetState($Button_copy, $GUI_ENABLE)
				GUICtrlSetState($Button_covers, $GUI_ENABLE)
				GUICtrlSetState($Button_create, $GUI_ENABLE)
				GUICtrlSetState($Button_device, $GUI_ENABLE)
				GUICtrlSetState($Button_down, $GUI_ENABLE)
				GUICtrlSetState($Button_drive, $GUI_ENABLE)
				GUICtrlSetState($Button_empty, $GUI_ENABLE)
				GUICtrlSetState($Button_fix, $GUI_ENABLE)
				GUICtrlSetState($Button_fold, $GUI_ENABLE)
				GUICtrlSetState($Button_images, $GUI_ENABLE)
				GUICtrlSetState($Button_info, $GUI_ENABLE)
				GUICtrlSetState($Button_list, $GUI_ENABLE)
				GUICtrlSetState($Button_log, $GUI_ENABLE)
				GUICtrlSetState($Button_mark, $GUI_ENABLE)
				GUICtrlSetState($Button_missing, $GUI_ENABLE)
				GUICtrlSetState($Button_next, $GUI_ENABLE)
				GUICtrlSetState($Button_quit, $GUI_ENABLE)
				GUICtrlSetState($Button_refresh, $GUI_ENABLE)
				GUICtrlSetState($Button_reload, $GUI_ENABLE)
				GUICtrlSetState($Button_relocate, $GUI_ENABLE)
				GUICtrlSetState($Button_remove, $GUI_ENABLE)
				GUICtrlSetState($Button_setup, $GUI_ENABLE)
				GUICtrlSetState($Button_source, $GUI_ENABLE)
				GUICtrlSetState($Button_up, $GUI_ENABLE)
				GUICtrlSetState($Combo_image, $GUI_ENABLE)
				GUICtrlSetState($Button_subs, $GUI_SHOW)
			EndIf
		Case $msg = $Button_backup
			; Backup cover images to a PC folder
			$ans = MsgBox(262144 + 35, "Location Query", "The best folder to backup your ebook images to," & @LF & _
				"is probably a 'Backups' named sub-folder of the" & @LF & _
				"'Images Source' folder. Do you want to use that?" & @LF & @LF & _
				"YES = Use the 'Images Source' folder." & @LF & _
				"NO = Browse to select another folder." & @LF & @LF & _
				"CANCEL = Abort any backup." & @LF & @LF & _
				"NOTE - This is optional for existing image files on" & @LF & _
				"your Kobo device, as a potential recovery source.", 0, $ResultsGUI)
			If $ans = 6 Then
				If FileExists($srcefold) Then
					$backups = $srcefold & "\Backups"
					IniWrite($inifle, "Backup Images", "path", $backups)
					If Not FileExists($backups) Then DirCreate($backups)
				Else
					MsgBox(262192, "Alert", "The 'Images Source' folder does not exist" & @LF & _
						"or cannot be found. Please set that first.", 0, $ResultsGUI)
					ContinueLoop
				EndIf
			ElseIf $ans = 7 Then
				$pth = FileSelectFolder("Browse to set the 'Backup Images' path.", @ScriptDir, 7, $backups, $ResultsGUI)
				If @error <> 1 And StringMid($pth, 2, 2) = ":\" Then
					$backups = $pth
					IniWrite($inifle, "Backup Images", "path", $backups)
				Else
					ContinueLoop
				EndIf
			ElseIf $ans = 2 Then
				ContinueLoop
			EndIf
			If $backups <> "" Then
				$ans = MsgBox(262144 + 33 + 256, "Overwrite Query", "If image files for an ebook already exist in"  & @LF & _
					"the 'Backups' folder, do you want them to" & @LF & _
					"be replaced?  This is not usually needed." & @LF & @LF & _
					"OK = Replace existing image files." & @LF & _
					"CANCEL = Don't replace.", 0, $ResultsGUI)
				If $ans = 1 Then
					$over = 1
				Else
					$over = 0
				EndIf
				GUICtrlSetState($Button_add, $GUI_DISABLE)
				GUICtrlSetState($Button_author, $GUI_DISABLE)
				GUICtrlSetPos($Button_backup, 1000, 511, 95, 32)
				GUICtrlSetFont($Button_backup, 8, 600)
				GUICtrlSetState($Button_backup, $GUI_DISABLE)
				GUICtrlSetState($Button_build, $GUI_DISABLE)
				GUICtrlSetState($Button_copy, $GUI_DISABLE)
				GUICtrlSetState($Button_covers, $GUI_DISABLE)
				GUICtrlSetState($Button_create, $GUI_DISABLE)
				GUICtrlSetState($Button_device, $GUI_DISABLE)
				GUICtrlSetState($Button_down, $GUI_DISABLE)
				GUICtrlSetState($Button_drive, $GUI_DISABLE)
				GUICtrlSetState($Button_empty, $GUI_DISABLE)
				GUICtrlSetState($Button_fix, $GUI_DISABLE)
				GUICtrlSetState($Button_fold, $GUI_DISABLE)
				GUICtrlSetState($Button_images, $GUI_DISABLE)
				GUICtrlSetState($Button_info, $GUI_DISABLE)
				GUICtrlSetState($Button_list, $GUI_DISABLE)
				GUICtrlSetState($Button_log, $GUI_DISABLE)
				GUICtrlSetState($Button_mark, $GUI_DISABLE)
				GUICtrlSetState($Button_missing, $GUI_DISABLE)
				GUICtrlSetState($Button_next, $GUI_DISABLE)
				GUICtrlSetState($Button_quit, $GUI_DISABLE)
				GUICtrlSetState($Button_refresh, $GUI_DISABLE)
				GUICtrlSetState($Button_reload, $GUI_DISABLE)
				GUICtrlSetState($Button_relocate, $GUI_DISABLE)
				GUICtrlSetState($Button_remove, $GUI_DISABLE)
				GUICtrlSetState($Button_setup, $GUI_DISABLE)
				GUICtrlSetState($Button_source, $GUI_DISABLE)
				GUICtrlSetState($Button_up, $GUI_DISABLE)
				GUICtrlSetState($Combo_image, $GUI_DISABLE)
				GUICtrlSetState($Button_subs, $GUI_HIDE)
				GUICtrlSetState($Checkbox_cancel, $GUI_SHOW)
				Sleep(5000)
				_FileWriteLog($logfile, "'Backup Images' process has started.")
				$copied = 0
				For $e = 0 To $ents - 1
					_GUICtrlListView_EnsureVisible($ListView_ebooks, $e, False)
					_GUICtrlListView_SetItemSelected($ListView_ebooks, $e, True, True)
					;_GUICtrlListView_ClickItem($ListView_ebooks, $e, "left", False, 1, 1)
					$images = _GUICtrlListView_GetItemText($ListView_ebooks, $e, 3)
					If $images > 0 Then
						$author = _GUICtrlListView_GetItemText($ListView_ebooks, $e, 2)
						$authfold = StringSplit($author, ",", 1)
						$authfold = $authfold[1]
						$authfold = $backups & "\" & $authfold
						DirCreate($authfold)
						For $colnum = 4 To 6
							$image = _GUICtrlListView_GetItemText($ListView_ebooks, $e, $colnum)
							If $image <> "" Then
								$pos = StringInStr($image, "\", 0, -1)
								$subs = StringLeft($image, $pos)
								$subfile = $imgfold & "\" & $subs & "*.parsed"
								If FileExists($subfile) Then
									$res = FileCopy($subfile, $authfold & "\", $over)
									If $res = 1 Then
										$copied = $copied + 1
										ExitLoop
									Else
										$exists = $authfold & "\*.parsed"
										If FileExists($exists) And FileExists($subfile) Then
											ExitLoop
										Else
											_FileWriteLog($logfile, "'Backup Images' process was aborted.")
											MsgBox(262192, "WARNING", "One or more images failed to copy, which" & @LF & _
												"could be due to a USB connection issue." & @LF  & @LF & _
												"Backup process has aborted.", 0, $ResultsGUI)
											ExitLoop 2
										EndIf
									EndIf
								Else
									_FileWriteLog($logfile, "'Backup Images' process was aborted.")
									MsgBox(262192, "WARNING", "Images device folder does not exist, which" & @LF & _
										"is likely due to a USB connection issue." & @LF  & @LF & _
										"Backup process has aborted.", 0, $ResultsGUI)
									ExitLoop 2
								EndIf
							EndIf
						Next
					EndIf
					If GUICtrlRead($Checkbox_cancel) = $GUI_CHECKED Then
						GUICtrlSetState($Checkbox_cancel, $GUI_UNCHECKED)
						_FileWriteLog($logfile, "'Backup Images' process was cancelled by user.")
						ExitLoop
					EndIf
				Next
				_FileWriteLog($logfile, $copied & " ebooks had their image files backed up.")
				If $copied > 0 Then
					$size = DirGetSize($backups, 1)
					$files = $size[1]
					$size = $size[0]
					$size = Round($size / 1024 / 1024, 1)
					_FileWriteLog($logfile, "Folder is " & $size & " Mb. " & $files & " files.")
				EndIf
				_FileWriteLog($logfile, "'Backup Images' process has finished." & @CRLF & @CRLF)
				MsgBox(262144 + 64, "Backup Results", $copied & " ebooks had their image files backed up.", 0, $ResultsGUI)
				GUICtrlSetState($Checkbox_cancel, $GUI_HIDE)
				GUICtrlSetState($Button_add, $GUI_ENABLE)
				GUICtrlSetState($Button_author, $GUI_ENABLE)
				GUICtrlSetPos($Button_backup, 1000, 511, 95, 50)
				GUICtrlSetFont($Button_backup, 9, 600)
				GUICtrlSetState($Button_backup, $GUI_ENABLE)
				GUICtrlSetState($Button_build, $GUI_ENABLE)
				GUICtrlSetState($Button_copy, $GUI_ENABLE)
				GUICtrlSetState($Button_covers, $GUI_ENABLE)
				GUICtrlSetState($Button_create, $GUI_ENABLE)
				GUICtrlSetState($Button_device, $GUI_ENABLE)
				GUICtrlSetState($Button_down, $GUI_ENABLE)
				GUICtrlSetState($Button_drive, $GUI_ENABLE)
				GUICtrlSetState($Button_empty, $GUI_ENABLE)
				GUICtrlSetState($Button_fix, $GUI_ENABLE)
				GUICtrlSetState($Button_fold, $GUI_ENABLE)
				GUICtrlSetState($Button_images, $GUI_ENABLE)
				GUICtrlSetState($Button_info, $GUI_ENABLE)
				GUICtrlSetState($Button_list, $GUI_ENABLE)
				GUICtrlSetState($Button_log, $GUI_ENABLE)
				GUICtrlSetState($Button_mark, $GUI_ENABLE)
				GUICtrlSetState($Button_missing, $GUI_ENABLE)
				GUICtrlSetState($Button_next, $GUI_ENABLE)
				GUICtrlSetState($Button_quit, $GUI_ENABLE)
				GUICtrlSetState($Button_refresh, $GUI_ENABLE)
				GUICtrlSetState($Button_reload, $GUI_ENABLE)
				GUICtrlSetState($Button_relocate, $GUI_ENABLE)
				GUICtrlSetState($Button_remove, $GUI_ENABLE)
				GUICtrlSetState($Button_setup, $GUI_ENABLE)
				GUICtrlSetState($Button_source, $GUI_ENABLE)
				GUICtrlSetState($Button_up, $GUI_ENABLE)
				GUICtrlSetState($Combo_image, $GUI_ENABLE)
				GUICtrlSetState($Button_subs, $GUI_SHOW)
			EndIf
		Case $msg = $Button_author
			; Fix the author name of selected ebook entry
			$ind = _GUICtrlListView_GetSelectedIndices($ListView_ebooks, True)
			If IsArray($ind) Then
				If $ind[0] > 0 Then
					$ind = $ind[1]
					$imageID = _GUICtrlListView_GetItemText($ListView_ebooks, $ind, 7)
					$mark = IniRead($resfile, $imageID, "mark", "")
					$rename = IniRead($resfile, $imageID, "rename", "")
					$idx = $lowid + $ind
					$author = GUICtrlRead($Input_author)
					If StringInStr($author, ", ") > 0 And $rename = "" Then
						$parts = StringSplit($author, ", ", 1)
						If $parts[0] = 2 Then
							$surname = $parts[1]
							$names = $parts[2]
							If StringInStr($surname, " ") < 1 Then
								$author = $names & " " & $surname
								GUICtrlSetData($Input_author, $author)
								_GUICtrlListView_SetItemText($ListView_ebooks, $ind, $author, 2)
								IniWrite($resfile, $imageID, "author", $author)
								$rename = 1
								IniWrite($resfile, $imageID, "rename", $rename)
								If $mark = 1 Then
									; Light Olive
									GUICtrlSetBkColor($idx, 0xA7BE01)
								Else
									GUICtrlSetBkColor($idx, $COLOR_AQUA)
								EndIf
								If $update = 1 Then
									; Update the SQLite file.
								EndIf
							EndIf
						EndIf
					ElseIf $rename = 1 Then
						If StringInStr($author, ", ") < 1 Then
							$pos = StringInStr($author, " ", 0, -1)
							If $pos > 0 Then
								$surname = StringMid($author, $pos + 1)
								$names = StringLeft($author, $pos - 1)
								$author = $surname & ", " & $names
								GUICtrlSetData($Input_author, $author)
								_GUICtrlListView_SetItemText($ListView_ebooks, $ind, $author, 2)
								IniWrite($resfile, $imageID, "author", $author)
								$rename = ""
								IniDelete($resfile, $imageID, "rename")
								If $mark = 1 Then
									GUICtrlSetBkColor($idx, $COLOR_YELLOW)
								Else
									If IsInt($idx / 2) = 1 Then
										GUICtrlSetBkColor($idx, 0xC0F0C0)
									Else
										GUICtrlSetBkColor($idx, 0xF0D0F0)
									EndIf
								EndIf
								If $update = 1 Then
									; Update the SQLite file.
								EndIf
							EndIf
						EndIf
					EndIf
				EndIf
			EndIf
		Case $msg = $Button_add
			; Add missing images to ebook folder
			If FileExists($imgfold) Then
				$continue = 1
				If $use = 1 Then
					CheckForAlternateDrive("ADD")
					If $altfold = "" Then
						$drvfold = ""
					Else
						$drvfold = $altfold
					EndIf
				Else
					$drvfold = ""
				EndIf
				If $continue = 1 Then
					$ind = _GUICtrlListView_GetSelectedIndices($ListView_ebooks, True)
					If IsArray($ind) Then
						If $ind[0] > 0 Then
							$ind = $ind[1]
							$title = _GUICtrlListView_GetItemText($ListView_ebooks, $ind, 1)
							$author = _GUICtrlListView_GetItemText($ListView_ebooks, $ind, 2)
							For $colnum = 4 To 6
								$image = _GUICtrlListView_GetItemText($ListView_ebooks, $ind, $colnum)
								If $image <> "" Then
									$pos = StringInStr($image, "\", 0, -1)
									$subs = StringLeft($image, $pos)
									If $drvfold <> "" Then $altfold = $drvfold & "\" & $subs
									$imageID = _GUICtrlListView_GetItemText($ListView_ebooks, $ind, 7)
									$covimg = GUICtrlRead($List_covers)
									If $covimg <> "" Then
										$covimg = $srcefold & "\" & $covimg
										If FileExists($covimg) Then
											_FileWriteLog($logfile, "Processing - " & $author & " - " & $title)
											$added = 0
											$skip = 0
											$image1 = _GUICtrlListView_GetItemText($ListView_ebooks, $ind, 4)
											If $image1 = "" Then
												$image1 = $subs & $imageID & " - N3_FULL.parsed"
												$imgfile = $imgfold & "\" & $image1
												$ans = MsgBox(262144 + 33, "ADD Query", $title & @LF & $author & @LF & @LF & _
													"Create the following image file -" & @LF & _
													$imgfile & @LF & @LF & _
													"Using the following source file -" & @LF & _
													$covimg & @LF & @LF & _
													"OK = Create the specified image." & @LF & _
													"CANCEL = Abort Creation.", 0, $ResultsGUI)
												If $ans = 1 Then
													_FileWriteLog($logfile, "Adding '" & $image1 & "' to device.")
													CreateFromImage($covimg, $imgfile, 1)
													_GUICtrlListView_SetItemText($ListView_ebooks, $ind, $image1, 4)
													$added = $added + 1
												Else
													$skip = $skip + 1
												EndIf
											EndIf
											$image2 = _GUICtrlListView_GetItemText($ListView_ebooks, $ind, 5)
											If $image2 = "" Then
												$image2 = $subs & $imageID & " - N3_LIBRARY_FULL.parsed"
												$imgfile = $imgfold & "\" & $image2
												$ans = MsgBox(262144 + 33, "ADD Query", $title & @LF & $author & @LF & @LF & _
													"Create the following image file -" & @LF & _
													$imgfile & @LF & @LF & _
													"Using the following source file -" & @LF & _
													$covimg & @LF & @LF & _
													"OK = Create the specified image." & @LF & _
													"CANCEL = Abort Creation.", 0, $ResultsGUI)
												If $ans = 1 Then
													_FileWriteLog($logfile, "Adding '" & $image2 & "' to device.")
													CreateFromImage($covimg, $imgfile, 2)
													_GUICtrlListView_SetItemText($ListView_ebooks, $ind, $image2, 4)
													$added = $added + 1
												Else
													$skip = $skip + 1
												EndIf
											EndIf
											$image3 = _GUICtrlListView_GetItemText($ListView_ebooks, $ind, 6)
											If $image3 = "" Then
												$image3 = $subs & $imageID & " - N3_LIBRARY_GRID.parsed"
												$imgfile = $imgfold & "\" & $image3
												$ans = MsgBox(262144 + 33, "ADD Query", $title & @LF & $author & @LF & @LF & _
													"Create the following image file -" & @LF & _
													$imgfile & @LF & @LF & _
													"Using the following source file -" & @LF & _
													$covimg & @LF & @LF & _
													"OK = Create the specified image." & @LF & _
													"CANCEL = Abort Creation.", 0, $ResultsGUI)
												If $ans = 1 Then
													_FileWriteLog($logfile, "Adding '" & $image3 & "' to device.")
													CreateFromImage($covimg, $imgfile, 3)
													_GUICtrlListView_SetItemText($ListView_ebooks, $ind, $image3, 4)
													$added = $added + 1
												Else
													$skip = $skip + 1
												EndIf
											EndIf
											If $added > 0 Then
												$idx = $lowid + $ind
												GUICtrlSetBkColor($idx, $COLOR_RED)
											EndIf
											If $skip = 3 Then
												_FileWriteLog($logfile, "All images skipped.")
											ElseIf $skip = 2 Then
												If ($one = 1 And $two = 1 And $three = 4) Or ($one = 1 And $two = 4 And $three = 1) Or ($one = 4 And $two = 1 And $three = 1) Then
													_FileWriteLog($logfile, "Two images skipped.")
												EndIf
											ElseIf $skip = 1 Then
												If ($one = 1 And $two = 4 And $three = 4) Or ($one = 4 And $two = 1 And $three = 4) Or ($one = 4 And $two = 4 And $three = 1) Then
													_FileWriteLog($logfile, "One image skipped.")
												EndIf
											EndIf
											_FileWriteLog($logfile, "Process Complete." & @CRLF & @CRLF)
										EndIf
									Else
										MsgBox(262192, "Selection Error", "No source cover image is selected!", 0, $ResultsGUI)
									EndIf
									ExitLoop
								EndIf
							Next
						Else
							MsgBox(262192, "Selection Error", "Badly selected entry!", 0, $ResultsGUI)
						EndIf
					Else
						MsgBox(262192, "Selection Error", "No entry is selected!", 0, $ResultsGUI)
					EndIf
				EndIf
			Else
				; If not found then several controls should be disabled.
				$disabled = 1
				GUICtrlSetState($Button_add, $GUI_DISABLE)
				GUICtrlSetState($Button_backup, $GUI_DISABLE)
				GUICtrlSetState($Button_build, $GUI_DISABLE)
				GUICtrlSetState($Button_create, $GUI_DISABLE)
				GUICtrlSetState($Button_fix, $GUI_DISABLE)
				GUICtrlSetState($Button_remove, $GUI_DISABLE)
				GUICtrlSetState($Button_relocate, $GUI_DISABLE)
				MsgBox(262144 + 48, "Alert", "The device '.kobo-images' folder does not exist" & @LF & _
					"or cannot be found. Please make sure your USB" & @LF & _
					"Kobo device is connected.", 0, $ResultsGUI)
			EndIf
		Case $msg = $List_covers
			; List of covers to use for ebook fixes
			$preview = GUICtrlRead($Combo_image)
			If $preview = "Source" Then
				$image = GUICtrlRead($List_covers)
				If $image = "" Then
					$image = $blackjpg
				Else
					$image = $srcefold & "\" & $image
				EndIf
				GUICtrlSetImage($Pic_cover, $image)
				$detail = ""
				GUICtrlSetData($Edit_detail, $detail)
			EndIf
		Case $msg = $ListView_ebooks Or $msg > $Button_quit
			; Ebooks Checked
			If $msg = $ListView_ebooks Then
				$colnum = GUICtrlGetState($ListView_ebooks)
				If StringInStr("012345", $colnum) > 0 Then
					_GUICtrlListView_BeginUpdate($ListView_ebooks)
					_GUICtrlListView_SimpleSort($ListView_ebooks, False, $colnum)
					_GUICtrlListView_EndUpdate($ListView_ebooks)
				EndIf
			Else
				$ind = _GUICtrlListView_GetSelectedIndices($ListView_ebooks, True)
				If IsArray($ind) Then
					If $ind[0] > 0 Then
						$ind = $ind[1]
						$title = _GUICtrlListView_GetItemText($ListView_ebooks, $ind, 1)
						GUICtrlSetData($Input_title, $title)
						$author = _GUICtrlListView_GetItemText($ListView_ebooks, $ind, 2)
						GUICtrlSetData($Input_author, $author)
						$images = _GUICtrlListView_GetItemText($ListView_ebooks, $ind, 3)
						If $images = 0 Then
							GUICtrlSetState($Input_subs, $GUI_ENABLE)
							GUICtrlSetState($Button_subs, $GUI_ENABLE)
						Else
							GUICtrlSetState($Input_subs, $GUI_DISABLE)
							GUICtrlSetState($Button_subs, $GUI_DISABLE)
						EndIf
						$subs = ""
						$image1 = _GUICtrlListView_GetItemText($ListView_ebooks, $ind, 4)
						GUICtrlSetData($Input_image_1, $image1)
						If $image1 <> "" Then
							$subs = $image1
						EndIf
						$image2 = _GUICtrlListView_GetItemText($ListView_ebooks, $ind, 5)
						GUICtrlSetData($Input_image_2, $image2)
						If $subs = "" And $image2 <> "" Then
							$subs = $image2
						EndIf
						$image3 = _GUICtrlListView_GetItemText($ListView_ebooks, $ind, 6)
						GUICtrlSetData($Input_image_3, $image3)
						If $subs = "" And $image3 <> "" Then
							$subs = $image3
						EndIf
						$imageID = _GUICtrlListView_GetItemText($ListView_ebooks, $ind, 7)
						$ISBN = IniRead($resfile, $imageID, "isbn", "")
						If StringInStr($ISBN, ":") > 0 Then
							$ISBN = StringSplit($ISBN, ":", 1)
							$ISBN = $ISBN[$ISBN[0]]
						EndIf
						GUICtrlSetData($Input_isbn, $ISBN)
						If $subs = "" Then
							$subs = IniRead($resfile, $imageID, "subs", "")
						Else
							$pos = StringInStr($subs, "\", 0, -1)
							$subs = StringLeft($subs, $pos - 1)
							GUICtrlSetData($Input_subs, $subs)
						EndIf
						GUICtrlSetData($Input_subs, $subs)
						;
						$image = $title & " - " & $ISBN & ".jpg"
						$image = StringReplace($image, ":", "")
						$image = StringReplace($image, "\", "&")
						$image = StringReplace($image, "/", "&")
						$image = StringStripWS($image, 7)
						$idx = _GUICtrlListBox_FindString($List_covers, $image, False)
						_GUICtrlListBox_SetCurSel($List_covers, $idx)
						;
						$detail = ""
						GUICtrlSetData($Edit_detail, $detail)
						$image = GUICtrlRead($Combo_image)
						If $image <> "Source" Then
							If $image3 = "" Then
								If $image2 = "" Then
									If $image1 = "" Then
										$image = $blackjpg
									Else
										$image = $imgfold & "\" & $image1
									EndIf
								Else
									$image = $imgfold & "\" & $image2
								EndIf
							Else
								$image = $imgfold & "\" & $image3
							EndIf
							GUICtrlSetImage($Pic_cover, $image)
						EndIf
					EndIf
				EndIf
			EndIf
		Case $msg = $Pic_cover
			; Click to see selected cover full size
			If $ind > -1 And $image <> $blackjpg Then
				$preview = GUICtrlRead($Combo_image)
				If $preview = "Source" Then
					$image = GUICtrlRead($List_covers)
					If $image = "" Then
						$preview = ""
					Else
						$preview = $srcefold & "\" & $image
					EndIf
				Else
					If $preview = "Image 1" Then
						$image = GUICtrlRead($Input_image_1)
						If $image = "" Then $preview = ""
					ElseIf $preview = "Image 2" Then
						$image = GUICtrlRead($Input_image_2)
						If $image = "" Then $preview = ""
					ElseIf $preview = "Image 3" Then
						$image = GUICtrlRead($Input_image_3)
						If $image = "" Then $preview = ""
					EndIf
					If $preview <> "" Then $preview = $imgfold & "\" & $image
				EndIf
				If $preview <> "" Then
					GUICtrlSetState($Pic_cover, $GUI_DISABLE)
					_GDIPlus_Startup()
					GetImageDetails($preview)
					GUICtrlSetData($Edit_detail, $detail)
					SplashImageOn("", $preview, $imgwidth, $imghigh, Default, Default, 17)
					Sleep(300)
					$mpos = MouseGetPos()
					$xpos = $mpos[0]
					$ypos = $mpos[1]
					Sleep(300)
					$dll = DllOpen("user32.dll")
					While 1
						$mpos = MouseGetPos()
						If $mpos[0] > $xpos + 40 Or $mpos[0] < $xpos - 40 Then ExitLoop
						If $mpos[1] > $ypos + 40 Or $mpos[1] < $ypos - 40 Then ExitLoop
						If _IsPressed("01", $dll) Then ExitLoop
						Sleep(300)
					WEnd
					DllClose($dll)
					SplashOff()
					GUICtrlSetState($Pic_cover, $GUI_ENABLE)
				EndIf
			EndIf
		Case Else
			;;;
		EndSelect
	WEnd
EndFunc ;=> ViewerGUI


Func CheckForAlternateDrive($button)
	$altfold = $drive & ".kobo-images"
	If $drive = "" Then
		$ans = MsgBox(262144 + 33 + 256, "Alternate Drive Query", "Use of an 'Alternate Export Drive' has been specified in" & @LF & _
			"program settings, but a drive has not been selected." & @LF & @LF & _
			"Do you want to continue anyway?" & @LF & @LF & _
			"OK = Continue without the second export location." & @LF & _
			"CANCEL = Abort " & $button & "." & @LF & @LF & _
			"NOTE - To set the drive, go to the 'Program Settings'" & @LF & _
			"window and select it.", 0, $ResultsGUI)
		If $ans = 2 Then
			$continue = ""
		EndIf
		$altfold = ""
	ElseIf Not FileExists($altfold) Then
		$ans = MsgBox(262144 + 33 + 256, "Alternate Drive Query", "Use of an 'Alternate Export Drive' has been specified in" & @LF & _
			"program settings, but the correct drive is not selected." & @LF & @LF & _
			"Do you want to continue anyway?" & @LF & @LF & _
			"OK = Continue without the second export location." & @LF & _
			"CANCEL = Abort " & $button & "." & @LF & @LF & _
			"NOTE - To set the drive, go to the 'Program Settings'" & @LF & _
			"window and select it. Or maybe connect your Kobo" & @LF & _
			"device first via USB, then select it.", 0, $ResultsGUI)
		If $ans = 2 Then
			$continue = ""
		EndIf
		$altfold = ""
	EndIf
EndFunc ;=> CheckForAlternateDrive

Func CreateFromImage($input, $output, $img)
	; BIG THANKS for bits of the following code to UEZ, funkey & Synapsee
	; https://www.autoitscript.com/forum/topic/120163-set-pixels-per-inch-using-gdi/?do=findComment&comment=834906
	; https://www.autoitscript.com/forum/topic/164388-changing-the-dpi-of-a-bmp/?do=findComment&comment=1198966
	; https://www.autoitscript.com/forum/topic/183492-problem-when-manipulating-images-with-different-dpi-using-gdiplus/?do=findComment&comment=1317885
	Local $dpival, $filesize, $imghorizon, $imgvertical, $percent, $resize, $result, $savfle
	Local $CLSID, $hBitmap, $hBMP, $hCompat, $hDC, $hFile, $hGraphic, $hWnd, $iHeight, $iWidth, $pData, $tData, $tGUID, $tParams
	;
	If FileExists($output) Then
		FileDelete($output)
		_FileWriteLog($logfile, "Existing ebook image file deleted.")
	EndIf
	;
	;$savfle = @ScriptDir & "\Test.parsed"
	$filesize = FileGetSize($input)
	If $filesize < 1024 Then
		$percent = IniRead($inifle, "Less Than 1024 Bytes", "percent", "")
	Else
		$filesize = $filesize / 1024
		If $filesize < 1024 Then
			If $filesize < 300 Then
				$percent = IniRead($inifle, "Less Than 300 Kilobytes", "percent", "")
			Else
				If $filesize < 400 Then
					$percent = IniRead($inifle, "Less Than 400 Kilobytes", "percent", "")
				ElseIf $filesize < 500 Then
					$percent = IniRead($inifle, "Less Than 500 Kilobytes", "percent", "")
				ElseIf $filesize < 600 Then
					$percent = IniRead($inifle, "Less Than 600 Kilobytes", "percent", "")
				ElseIf $filesize < 700 Then
					$percent = IniRead($inifle, "Less Than 700 Kilobytes", "percent", "")
				ElseIf $filesize < 800 Then
					$percent = IniRead($inifle, "Less Than 800 Kilobytes", "percent", "")
				ElseIf $filesize < 900 Then
					$percent = IniRead($inifle, "Less Than 900 Kilobytes", "percent", "")
				Else
					$percent = IniRead($inifle, "Less Than 1024 Kilobytes", "percent", "")
				EndIf
			EndIf
		Else
			$percent = IniRead($inifle, "One Megabyte Or More", "percent", "")
		EndIf
	EndIf
	_GDIPlus_Startup()
	$hFile = _GDIPlus_BitmapCreateFromFile($input)
	$imgwidth = _GDIPlus_ImageGetWidth($hFile)
	$imghigh = _GDIPlus_ImageGetHeight($hFile)
	; 1031 x 1600
	$resize = ""
	If $img = 1 Then
		If $imgwidth > $wide1 Then
			$resize = 1
			$iWidth = $wide1
		Else
			$iWidth = $imgwidth
		EndIf
		If $imghigh > $high1 Then
			$resize = 1
			$iHeight = $high1
		Else
			$iHeight = $imghigh
		EndIf
	ElseIf $img = 2 Then
		If $imgwidth > $wide2 Then
			$resize = 1
			$iWidth = $wide2
		Else
			$iWidth = $imgwidth
		EndIf
		If $imghigh > $high2 Then
			$resize = 1
			$iHeight = $high2
		Else
			$iHeight = $imghigh
		EndIf
	ElseIf $img = 3 Then
		If $imgwidth > $wide3 Then
			$resize = 1
			$iWidth = $wide3
		Else
			$iWidth = $imgwidth
		EndIf
		If $imghigh > $high3 Then
			$resize = 1
			$iHeight = $high3
		Else
			$iHeight = $imghigh
		EndIf
	EndIf
	;
	$imghorizon = _GDIPlus_ImageGetHorizontalResolution($hFile)
	$imgvertical = _GDIPlus_ImageGetVerticalResolution($hFile)
	$dpival = $imghorizon & " x " & $imgvertical
	;MsgBox(262192, "DPI Resolution", $dpival, 0, $ResultsGUI)
	;
	If $percent > 0 Or $dpival <> "300 x 300" Or $resize = 1 Then
		If $resize = 1 Then
			$hWnd = _WinAPI_GetDesktopWindow()
			$hDC = _WinAPI_GetDC($hWnd)
			$hCompat = _WinAPI_CreateCompatibleBitmap($hDC, $iWidth, $iHeight)
			_WinAPI_ReleaseDC($hWnd, $hDC)
			$hBitmap = _GDIPlus_BitmapCreateFromHBITMAP($hCompat)
			$hGraphic = _GDIPlus_ImageGetGraphicsContext($hBitmap)
			_GDIPLus_GraphicsDrawImageRect($hGraphic, $hFile, 0, 0, $iWidth, $iHeight)
			_GDIPlus_GraphicsDispose($hGraphic)
			_GDIPlus_BitmapDispose($hFile)
			_FileWriteLog($logfile, "Ebook image dimensions reduced.")
		Else
			$hBMP = _GDIPlus_BitmapCreateHBITMAPFromBitmap($hFile)
			_GDIPlus_BitmapDispose($hFile)
			$hBitmap = _GDIPlus_BitmapCreateFromHBITMAP($hBMP)
			_WinAPI_DeleteObject($hBMP)
		EndIf
		; DPI always seems to default to 96 x 96, so setting DPI anyway.
		$result = _GDIPlus_BitmapSetResolution($hBitmap, 300, 300)
		$CLSID = _GDIPlus_EncodersGetCLSID("JPG")
		If $percent = 0 Then
			;_GDIPlus_ImageSaveToFileEx($hBitmap, $savfle, $CLSID, 0)
			_GDIPlus_ImageSaveToFileEx($hBitmap, $output, $CLSID, 0)
		Else
			$tGUID = _WinAPI_GUIDFromString($CLSID)
			$tParams = _GDIPlus_ParamInit(1)
			$tData = DllStructCreate("int Quality")
			DllStructSetData($tData, "Quality", $percent)
			$pData = DllStructGetPtr($tData)
			_GDIPlus_ParamAdd($tParams, $GDIP_EPGQUALITY, 1, $GDIP_EPTLONG, $pData)
			;_GDIPlus_ImageSaveToFileEx($hBitmap, $savfle, $CLSID, $tParams)
			_GDIPlus_ImageSaveToFileEx($hBitmap, $output, $CLSID, $tParams)
			_FileWriteLog($logfile, "Ebook image file size reduced.")
		EndIf
		_GDIPlus_BitmapDispose($hBitmap)
		_WinAPI_DeleteObject($hBitmap)
		_FileWriteLog($logfile, "Ebook source image created on device.")
	Else
		FileCopy($input, $output)
		;FileCopy($input, $savfle)
		_FileWriteLog($logfile, "Ebook source image copied to device.")
	EndIf
	If $use = 1 Then
		If $altfold <> "" Then
			; Remove trailing slash for checking.
			$drvfold = StringTrimRight($altfold, 1)
			If FileExists($drvfold) Then
				FileCopy($output, $altfold, 1)
				_FileWriteLog($logfile, "Ebook source image copied to alternate drive.")
			Else
				MsgBox(262192, "Alternate Drive Result", "Drive does not exist. Check your USB connection maybe.", 0, $ResultsGUI)
			EndIf
		EndIf
	EndIf
	GetImageDetails($output)
	;GetImageDetails($savfle)
	If $resize = 1 Then
		$detail = $detail & @LF & @LF & "Image was Resized."
	EndIf
	MsgBox(262144 + 64, "Create Image Results", $detail, 0, $ResultsGUI)
	;
	_GDIPlus_BitmapDispose($hBitmap)
	_GDIPlus_Shutdown()
EndFunc ;=> CreateFromImage

Func FindEbookImages()
	Local $a, $ahead, $array, $array2, $cnt, $empty, $exist, $f, $failed, $found, $ind, $ISBN, $last, $line, $missing
	Local $num, $section, $split, $type
	;
	; Find Ebook Images that match
	If FileExists($ebooks) Then
		If FileExists($foldtxt) Then
			SplashTextOn("", "Searching for Images!", 220, 100, -1, -1, 33)
			$cnt = 0
			$empty = ""
			$exist = ""
			$failed = 0
			$found = 0
			$last = ""
			$missing = ""
			$ahead = ""
			$section = ""
			If FileExists($resfile) Then FileDelete($resfile)
			_FileCreate($missfle)
			_FileReadToArray($ebooks, $array, 1)
			$entries = $array[0] - 1
			_FileWriteLog($logfile, $entries & " ebook entries found.")
			_FileReadToArray($foldtxt, $array2, 1)
			For $e = 1 To $array[0]
				$line = $array[$e]
				If $line = "" Or StringLeft($line, 14) = "Total Ebooks =" Then
					ExitLoop
				Else
					$entries = StringSplit($line, " | ", 1)
					$title = $entries[1]
					$author = $entries[2]
					$ISBN = $entries[3]
					$imageID = $entries[4]
					For $a = 1 To $array2[0]
						$entry = $array2[$a]
						If StringInStr($entry, $imageID) > 0 Then
							$found = $found + 1
							;IniWrite($resfile, $imageID, "images", $found)
							$file = StringSplit($entry, ".kobo-images\", 1)
							$file = $file[2]
							$type = StringSplit($file, " - N3_", 1)
							$type = $type[2]
							If $type = "FULL.parsed" Then
								$num = 1
							ElseIf $type = "LIBRARY_FULL.parsed" Then
								$num = 2
							ElseIf $type = "LIBRARY_GRID.parsed" Then
								$num = 3
							EndIf
							;IniWrite($resfile, $imageID, $num, $file)
							If $section = "" Then
								$section = $num & "=" & $file
							Else
								$section = $section & @LF & $num & "=" & $file
							EndIf
							IniWrite($recfile, $imageID, "images", $found)
							IniWrite($recfile, $imageID, $num, $file)
						EndIf
						If $found = 3 Then ExitLoop
					Next
					;IniWrite($resfile, $imageID, "images", $found)
					If $found = 0 Then
						$failed = $failed + 1
						;IniWrite($resfile, $imageID, "images", $found)
						$entry = $title & "|" & $author & "|" & $imageID
						$missing &= $entry & @CRLF
					Else
						IniWrite($recfile, $imageID, "title", $title)
						IniWrite($recfile, $imageID, "author", $author)
						IniWrite($recfile, $imageID, "isbn", $ISBN)
					EndIf
					;IniWrite($resfile, $imageID, "title", $title)
					;IniWrite($resfile, $imageID, "author", $author)
					;IniWrite($resfile, $imageID, "isbn", $ISBN)
					$entry = "images=" & $found & @LF & "title=" & $title & @LF & "author=" & $author & @LF & "isbn=" & $ISBN
					If $section = "" Then
						$section = $entry
					Else
						$section = $entry & @LF & $section
					EndIf
					IniWriteSection($resfile, $imageID, $section)
					$found = 0
					$section = ""
				EndIf
			Next
			If $missing <> "" Then
				$missing = $missing & @CRLF & $failed & " ebooks without images."
				FileWrite($missfle, $missing)
				_FileWriteLog($logfile, $failed & " ebooks without images.")
			EndIf
			SplashTextOn("", "Find Empty Folders!", 220, 100, -1, -1, 33)
			_FileCreate($emptyfle)
			$empty = ""
			$exist = ""
			$last = ""
			$ahead = ""
			For $f = 1 To $array2[0]
				$entry = $array2[$f]
				$file = StringSplit($entry, ".kobo-images\", 1)
				$file = $file[2]
				$split = StringSplit($file, "\", 1)
				$split = $split[0]
				If $split = 2 Then
					If $last = "" Then
						$last = $entry
						$exist = ""
					ElseIf $ahead = 1 Then
						$last = $entry
						$ahead = ""
						$exist = ""
					ElseIf $exist = "" Then
						$empty &= $last & @CRLF
						$cnt = $cnt + 1
						$last = $entry
					EndIf
				ElseIf $split = 3 Then
					If StringInStr($entry, $last) > 0 Then
						$exist = 1
						$ahead = 1
					Else
						$exist = ""
						$last = ""
					EndIf
				EndIf
			Next
			If $empty <> "" Then
				FileWrite($emptyfle, $empty)
				FileWriteLine($emptyfle, @CRLF & $cnt & " empty folders.")
				_FileWriteLog($logfile, $cnt & " empty folders.")
				IniWrite($inifle, "Empty Folders", "count", $cnt)
			Else
				IniWrite($inifle, "Empty Folders", "count", $cnt)
			EndIf
			_FileWriteLog($logfile, "Process Complete." & @CRLF & @CRLF)
			SplashOff()
			If $failed > 0 Then MsgBox(262192, "Results", $failed & " ebooks did not have images.", 0, $Dropbox)
		Else
			_FileWriteLog($logfile, "'Folders.txt' file not found.")
			MsgBox(262192, "File Error", "The created 'Folders.txt' file could not be found." & @LF _
				& @LF & "This text file would have been created using" _
				& @LF & "the Dropbox with the 'KoboReader.sqlite' file.", 0, $Dropbox)
		EndIf
	Else
		_FileWriteLog($logfile, "'Ebooks.txt' file not found.")
		MsgBox(262192, "File Error", "The created 'Ebooks.txt' file could not be found." & @LF _
			& @LF & "This text file would have been created using" _
			& @LF & "the Dropbox with the 'KoboReader.sqlite' file.", 0, $Dropbox)
	EndIf
EndFunc ;=> FindEbookImages

Func GetContent()
	Local $dbfle
	;
	_SQLite_Startup()
	If @error Then
		SplashOff()
		_FileWriteLog($logfile, "SQLite3.dll cannot be Loaded.")
		MsgBox(262192, "SQLite Error", "SQLite3.dll cannot be Loaded!", 0, $Dropbox)
		Exit
	EndIf
	;
	$dbfle = _SQLite_Open($sqlfile)
	If @error Then
		SplashOff()
		_FileWriteLog($logfile, "Cannot open existing Database file.")
		MsgBox(262192, "SQLite Error", "Cannot open the existing Database file!", 0, $Dropbox)
	Else
		SplashTextOn("", "Retrieving Entries", 220, 100, Default, Default, 33)
		_FileCreate($ebooks)
		Sleep(1000)
		;
		; The following improved code provided by jchd an MVP from the AutoIt Forum, slightly modified by TheSaint.
        _SQLite_QuerySingleRow( _
            $dbfle, _
            "select group_concat(txt, char(13, 10)) || char(13, 10) || 'Total Ebooks = ' || count(*)" & _
            "       from (select Title || ' | ' || Attribution || ' | ' || ISBN || ' | ' || ImageID || ' | ' || ContentID as txt" & _
            "                    from content where Attribution <> '' and ___FileSize > '0' and IsDownloaded = 'true' order by Attribution)" & _
            "       group by 'abc'", _
            $entries)
		;
        $file = FileOpen($ebooks, 1)
        FileWriteLine($file, $entries[0])
		FileClose($file)
	EndIf
	;
	_SQLite_Close($dbfle)
	_SQLite_Shutdown()
EndFunc ;==> GetContent

Func GetDrives($device)
	Local $d, $drv, $drvpth, $hdd, $type
	;
	$hdd = DriveGetDrive($DT_ALL)
	If @error = 1 Or $hdd[0] = 0 Then
		$drives = "||"
	Else
		$drives = "||"
		For $d = 1 To $hdd[0]
			$drv = $hdd[$d] & "\"
			If $device = 1 Then
				; If found, then the path should be updated in settings.
				$drvpth = $drv & ".kobo-images"
				If FileExists($drvpth) Then
					$imgfold = $drvpth
					IniWrite($inifle, "Device Images Folder", "path", $imgfold)
					ExitLoop
				ElseIf FileExists($imgfold) Then
					ExitLoop
				EndIf
			Else
				$type = DriveGetType($drv)
				If $type = "Fixed" Or $type = "Removable" Then
					$drives = $drives & $drv & "|"
				EndIf
			EndIf
		Next
		If $device = "" Then $drives = StringUpper($drives)
	EndIf
EndFunc ;==> GetDrives

Func GetImageDetails($picfile)
	Local $dpival, $filesize, $hImage, $imgform, $imghorizon, $imgpixel, $imgtype, $imgvertical
	;
	$hImage = _GDIPlus_ImageLoadFromFile($picfile)
	$imgwidth = _GDIPlus_ImageGetWidth($hImage)
	$imghigh = _GDIPlus_ImageGetHeight($hImage)
	$imgtype = _GDIPlus_ImageGetType($hImage)
	If $imgtype = $GDIP_IMAGETYPE_BITMAP Then $imgtype = "Bitmap"
	$imgform = _GDIPlus_ImageGetRawFormat($hImage)
	$imgform = $imgform[1]
	$imgpixel = _GDIPlus_ImageGetPixelFormat($hImage)
	$imgpixel = $imgpixel[1]
	$imghorizon = _GDIPlus_ImageGetHorizontalResolution($hImage)
	$imgvertical = _GDIPlus_ImageGetVerticalResolution($hImage)
	$dpival = $imghorizon & " x " & $imgvertical
	_GDIPlus_ImageDispose($hImage)
	_GDIPlus_Shutdown()
	$filesize = FileGetSize($picfile)
	If $filesize < 1024 Then
		$filesize = $filesize & " bytes"
	Else
		$filesize = $filesize / 1024
		If $filesize < 1024 Then
			$filesize = Ceiling($filesize) & " Kb"
		Else
			$filesize = $filesize / 1024
			$filesize = Round($filesize, 2) & " Mb"
		EndIf
	EndIf
	$detail = "Width = " & $imgwidth & ". Height = " & $imghigh & "." & @CRLF & "Type = " & $imgtype & ". Format = " & $imgform _
		& @CRLF & "DPI = " & $dpival & @CRLF & "Pixel Format = " & $imgpixel & @CRLF & "File Size = " & $filesize
EndFunc ;==> GetImageDetails

Func GetMappedImage($prior, $next, $entries)
	Local $pic
	; Next Image
	If $prior = $blackjpg Then
		; Next Image (not found)
		$pic = $blackjpg
	Else
		$row = $row + 1
		If $row < $items Then
			; First Row
			$imageID = $entries[$row][1]
			If $imageID = $lastID Then
				; Next Row (First + 1)
				$row = $row + 1
				If $row < $items Then
					; Second Row
					$imageID = $entries[$row][1]
					If $imageID = $lastID Then
						; Next Row (Second + 1)
						$row = $row + 1
						If $row < $items Then
							; Third Row
							$imageID = $entries[$row][1]
							If $imageID = $lastID Then
								; Next Row (Third + 1)
								$row = $row + 1
								If $row < $items Then
									; 4th Row (final)
									; Next Image (4th Row)
									$item1 = $entries[$row][0] ; Subs
									$item3 = $entries[$row][2] ; N3
									$pic = $imgfold & "\" & $item1 & $imageID & " - " & $item3
									$lastID = $imageID
								Else
									; Next Image (not found)
									$pic = $blackjpg
								EndIf
							Else
								; Next Image (Third Row)
								$item1 = $entries[$row][0] ; Subs
								$item3 = $entries[$row][2] ; N3
								$pic = $imgfold & "\" & $item1 & $imageID & " - " & $item3
								$lastID = $imageID
							EndIf
						Else
							; Next Image (not found)
							$pic = $blackjpg
						EndIf
					Else
						; Next Image (Second Row)
						$item1 = $entries[$row][0] ; Subs
						$item3 = $entries[$row][2] ; N3
						$pic = $imgfold & "\" & $item1 & $imageID & " - " & $item3
						$lastID = $imageID
					EndIf
				Else
					; Next Image (not found)
					$pic = $blackjpg
				EndIf
			Else
				; Next Image (First Row)
				$item1 = $entries[$row][0] ; Subs
				$item3 = $entries[$row][2] ; N3
				$pic = $imgfold & "\" & $item1 & $imageID & " - " & $item3
				$lastID = $imageID
			EndIf
		Else
			; Next Image (not found)
			$pic = $blackjpg
		EndIf
	EndIf
	If $next = $pic_one Then
		$pic_one = $pic
	ElseIf $next = $pic_two Then
		$pic_two = $pic
	ElseIf $next = $pic_three Then
		$pic_three = $pic
	ElseIf $next = $pic_four Then
		$pic_four = $pic
	ElseIf $next = $pic_five Then
		$pic_five = $pic
	ElseIf $next = $pic_six Then
		$pic_six = $pic
	ElseIf $next = $pic_seven Then
		$pic_seven = $pic
	ElseIf $next = $pic_eight Then
		$pic_eight = $pic
	ElseIf $next = $pic_nine Then
		$pic_nine = $pic
	EndIf
EndFunc ;==> GetMappedImage

Func GetOthers()
	Local $array, $dbfle, $found, $ISBN, $line, $sections, $size
	;
	_SQLite_Startup()
	If @error Then
		SplashOff()
		_FileWriteLog($logfile, "SQLite3.dll cannot be Loaded.")
		MsgBox(262192, "SQLite Error", "SQLite3.dll cannot be Loaded!", 0, $Dropbox)
		Exit
	EndIf
	;
	$dbfle = _SQLite_Open($sqlfile)
	If @error Then
		SplashOff()
		_FileWriteLog($logfile, "Cannot open existing Database file.")
		MsgBox(262192, "SQLite Error", "Cannot open the existing Database file!", 0, $Dropbox)
	Else
		SplashTextOn("", "Retrieving Others", 220, 100, Default, Default, 33)
		_FileCreate($others)
		Sleep(1000)
		;
		; The following improved code provided by jchd an MVP from the AutoIt Forum, slightly modified by TheSaint.
        _SQLite_QuerySingleRow( _
            $dbfle, _
            "select group_concat(txt, char(13, 10)) || char(13, 10) || 'Total Ebooks = ' || count(*)" & _
            "       from (select Title || ' | ' || Attribution || ' | ' || ISBN || ' | ' || ImageID || ' | ' || ___FileSize as txt" & _
            "                    from content where Attribution <> '' and IsDownloaded = 'false' order by Attribution)" & _
            "       group by 'abc'", _
            $entries)
		; and ___FileSize <> '0'
		;
		SplashTextOn("", "Writing To File", 220, 100, Default, Default, 33)
		$entries = $entries[0]
		$found = 0
		$sections = ""
		$array = StringSplit($entries, @CRLF, 1)
		For $e = 1 To $array[0]
			$line = $array[$e]
			If $line = "" Or StringLeft($line, 14) = "Total Ebooks =" Then
				ExitLoop
			Else
				$found = $found + 1
				$entries = StringSplit($line, " | ", 1)
				$title = $entries[1]
				$author = $entries[2]
				$ISBN = $entries[3]
				$imageID = $entries[4]
				$size = $entries[5]
				$entry = "[" & $imageID & "]" & @CRLF & "title=" & $title & @CRLF & "author=" & $author & @CRLF & "isbn=" & $ISBN & @CRLF & "size=" & $size
				If $sections = "" Then
					$sections = $entry
				Else
					$sections = $sections & @CRLF & $entry
				EndIf
			EndIf
		Next
		If $sections <> "" And $found > 0 Then
			$file = FileOpen($others, 1)
			FileWriteLine($file, $sections)
			FileClose($file)
			$found = 0
			$section = ""
		EndIf
	EndIf
	;
	_SQLite_Close($dbfle)
	_SQLite_Shutdown()
EndFunc ;==> GetOthers

Func LoadTheList()
	Local $ind, $num, $numb, $s, $total
	;
	If $sort = 1 Then
		SplashTextOn("", "Please Wait!" & @LF & @LF & "(Reading List)", 180, 130, Default, Default, 33)
	Else
		SplashTextOn("", "Please Wait!" & @LF & @LF & "(Loading List)", 180, 130, Default, Default, 33)
	EndIf
	_GUICtrlListView_BeginUpdate($ListView_ebooks)
	$num = 0
	$entries = IniReadSectionNames($resfile)
	$total = $entries[0]
	; Add an additional column to have entries sorted correctly.
	Local $sorted[1][8] = [[$total, "", "", "", "", "", "", ""]]
	For $e = 1 To $total
		$imageID = $entries[$e]
		If $imageID <> "" Then
			$title = IniRead($resfile, $imageID, "title", "")
			$author = IniRead($resfile, $imageID, "author", "")
			$images = IniRead($resfile, $imageID, "images", "")
			$image1 = IniRead($resfile, $imageID, "1", "")
			$image2 = IniRead($resfile, $imageID, "2", "")
			$image3 = IniRead($resfile, $imageID, "3", "")
			If $sort = 1 Then
				; Also temporarily adding author and title to additional column for sorting.
				$entry = $title & "|" & $author & "|" & $images & "|" & $image1 & "|" & $image2 & "|" & $image3 & "|" & $imageID& "|" & $author & " " & $title
				_ArrayAdd($sorted, $entry)
			Else
				$num = $num + 1
				$numb = StringRight("000" & $num, 4)
				$entry = $numb & "|" & $title & "|" & $author & "|" & $images & "|" & $image1 & "|" & $image2 & "|" & $image3 & "|" & $imageID
				$idx = GUICtrlCreateListViewItem($entry, $ListView_ebooks)
				$mark = IniRead($resfile, $imageID, "mark", "")
				$rename = IniRead($resfile, $imageID, "rename", "")
				If $mark = 1 And $rename = 1 Then
					; Light Olive
					GUICtrlSetBkColor($idx, 0xA7BE01)
				ElseIf $mark = 1 Then
					GUICtrlSetBkColor($idx, $COLOR_YELLOW)
				ElseIf $rename = 1 Then
					GUICtrlSetBkColor($idx, $COLOR_AQUA)
				Else
					If IsInt($idx / 2) = 1 Then GUICtrlSetBkColor($idx, 0xC0F0C0)
				EndIf
			EndIf
		EndIf
	Next
	;
	If $sort = 1 Then
		SplashTextOn("", "Please Wait!" & @LF & @LF & "(Sorting List)", 180, 130, Default, Default, 33)
		;MsgBox(262192, "Total", $sorted[0][0], 0, $ResultsGUI)
		;_ArrayDisplay($sorted, "Unsorted", "", 0, "|", "Title|Author|Images|Image 1|Image 2|Image 3|Image ID|Sort")
		; Sort by additional column.
		_ArraySort($sorted, 0, 1, 0, 7)
		; Remove additional column.
		_ArrayColDelete($sorted, 7, False)
		;_ArrayDisplay($sorted, "Sorted Authors", "", 0, "|", "Title|Author|Images|Image 1|Image 2|Image 3|Image ID")
		SplashTextOn("", "Please Wait!" & @LF & @LF & "(Loading List)", 180, 130, Default, Default, 33)
		$num = 0
		For $s = 1 To $sorted[0][0]
			$title = $sorted[$s][0]
			$author = $sorted[$s][1]
			$images = $sorted[$s][2]
			$image1 = $sorted[$s][3]
			$image2 = $sorted[$s][4]
			$image3 = $sorted[$s][5]
			$imageID = $sorted[$s][6]
			$num = $num + 1
			$numb = StringRight("000" & $num, 4)
			$entry = $numb & "|" & $title & "|" & $author & "|" & $images & "|" & $image1 & "|" & $image2 & "|" & $image3 & "|" & $imageID
			$idx = GUICtrlCreateListViewItem($entry, $ListView_ebooks)
			$mark = IniRead($resfile, $imageID, "mark", "")
			$rename = IniRead($resfile, $imageID, "rename", "")
			If $mark = 1 And $rename = 1 Then
				; Light Olive
				GUICtrlSetBkColor($idx, 0xA7BE01)
			ElseIf $mark = 1 Then
				GUICtrlSetBkColor($idx, $COLOR_YELLOW)
			ElseIf $rename = 1 Then
				GUICtrlSetBkColor($idx, $COLOR_AQUA)
			Else
				If IsInt($idx / 2) = 1 Then GUICtrlSetBkColor($idx, 0xC0F0C0)
			EndIf
		Next
	EndIf
	_GUICtrlListView_JustifyColumn($ListView_ebooks, 0, 0)
	_GUICtrlListView_JustifyColumn($ListView_ebooks, 1, 0)
	_GUICtrlListView_JustifyColumn($ListView_ebooks, 2, 0)
	_GUICtrlListView_JustifyColumn($ListView_ebooks, 3, 2)
	_GUICtrlListView_JustifyColumn($ListView_ebooks, 4, 0)
	_GUICtrlListView_JustifyColumn($ListView_ebooks, 5, 0)
	_GUICtrlListView_JustifyColumn($ListView_ebooks, 6, 0)
	_GUICtrlListView_JustifyColumn($ListView_ebooks, 7, 0)
	_GUICtrlListView_SetColumnWidth($ListView_ebooks, 0, 40)
	_GUICtrlListView_SetColumnWidth($ListView_ebooks, 1, 345)
	_GUICtrlListView_SetColumnWidth($ListView_ebooks, 2, 230)
	_GUICtrlListView_SetColumnWidth($ListView_ebooks, 3, 50)
	_GUICtrlListView_SetColumnWidth($ListView_ebooks, 4, 190)
	_GUICtrlListView_SetColumnWidth($ListView_ebooks, 5, 190)
	_GUICtrlListView_SetColumnWidth($ListView_ebooks, 6, 190)
	_GUICtrlListView_SetColumnWidth($ListView_ebooks, 7, 5)
	If $num > 0 Then
		$ents = _GUICtrlListView_GetItemCount($ListView_ebooks)
		GUICtrlSetData($Group_ebooks, "Ebooks List (" & $ents & ")")
	EndIf
	_GUICtrlListView_EndUpdate($ListView_ebooks)
	SplashOff()
EndFunc ;==> LoadTheList

Func _UserFunc($entries, $rows)
	; NOTE - This needs to be a GUI so it can display the cover image of selected entry.
	; Consider making it a multi image viewer, with maybe fields to save an Author and Title to an INI file..
	; Perhap show 20 image thumbnails at a time, with next and previous buttons.
	; It should only show the first image found for an ebook, based on ImageID.
	;Local $imagefile, $item1, $item2, $item3, $item4, $items, $row, $selected
	Local $selected
	$selected = $rows[0]
	If $selected > 0 Then
		$row = $rows[1] ; Row
		If IsArray($entries) Then
			$items = $entries[0][0]
			; First Image
			$item1 = $entries[$row][0] ; Subs
			$imageID = $entries[$row][1]
			$item3 = $entries[$row][2] ; N3
			$pic_one = $imgfold & "\" & $item1 & $imageID & " - " & $item3
			$lastID = $imageID
			; 2nd Image
			GetMappedImage($pic_one, $pic_two, $entries)
			; 3rd Image
			GetMappedImage($pic_two, $pic_three, $entries)
			; 4th Image
			GetMappedImage($pic_three, $pic_four, $entries)
			; 5th Image
			GetMappedImage($pic_four, $pic_five, $entries)
			; 6th Image
			GetMappedImage($pic_five, $pic_six, $entries)
			; 7th Image
			GetMappedImage($pic_six, $pic_seven, $entries)
			; 8th Image
			GetMappedImage($pic_seven, $pic_eight, $entries)
			; 9th Image
			GetMappedImage($pic_eight, $pic_nine, $entries)
			;
			ImagesGUI($entries)
			;$item4 = $entries[$row][3] ; Author & Title
			;$imagefile = $imgfold & "\" & $item1 & $item2 & " - " & $item3
			;If FileExists($imagefile) Then ShellExecute($imagefile)
		EndIf
	Else
		;$row = ""
		;$item1 = ""
		;$item2 = ""
		;$item3 = ""
		;$item4 = ""
		MsgBox(262192, "Selection Error", "You need to select an entry!", 0, $OptionsGUI)
	EndIf
	;If IsArray($entries) Then
	;	$items = $entries[0][0]
	;Else
	;	$items = "not an array"
	;EndIf
	;MsgBox(262144 + 48, "Detail", "Array Display Function." & @LF & $row & @LF & $item1 & @LF & $item2 & @LF & $item3 & @LF & $item4 & @LF & $items, 0, $ResultsGUI) ; & @LF & $item5
EndFunc ;==> _UserFunc
