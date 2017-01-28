Class CacheUpdater.UDL Extends %RegisteredObject
{

/// Checks whether this file is in UDL format
/// <b>stream</b> - stream which contains file definition
ClassMethod IsUDLFile(stream As %GlobalCharacterStream) As %Boolean
{
	// probably 10 lines is enough
	set counter = 0
	while 'stream.AtEnd {
		if counter >= 10 {
			quit
		}
		set line = stream.ReadLine()
		if $find(line, "<Export") {
			do stream.Rewind()
			return $$$NO
		}
		set counter = counter + 1
	}
	do stream.Rewind()

	return $$$YES
}

/// Finds the first string in a line
/// <b>line</b> - any string.<br>
ClassMethod ReadName(line As %String) As %String
{
	set trimmed = $zstrip(line, "<>W")
	return $piece(trimmed, " ")
}

/// Finds a name of a class
/// <b>stream</b> - stream which contains a class definition<br>
/// <b>name</b> - name which contains the name of class<br>
ClassMethod GetClassName(stream As %GlobalCharacterStream, ByRef name As %String) As %Status
{
	while 'stream.AtEnd {
		set line = stream.ReadLine()

		if $extract(line, 1, 3) = "///" { // check for inline comments
			continue
		} elseif $zconvert($extract(line, 1, 5), "l") = "class" {
			set line = $extract(line, 6, *)
			set name = ..ReadName(line)
			if name = "" {
				return '$$$OK
			} else {
				return $$$OK
			}
		}
	}
	return '$$$OK
}

/// Finds a name of a routine
/// <b>stream</b> - stream which contains a routine definition<br>
/// <b>name</b> - name which contains the name of routine<br>
/// <b>type</b> - type of file {1 - mac, 2 - inc, 3 - int}
ClassMethod GetRoutineName(stream As %GlobalCharacterStream, ByRef name As %String, ByRef type As %Integer) As %Status
{
	while 'stream.AtEnd {
		set line = stream.ReadLine()
		set index = $find(line, "ROUTINE")
		// TODO - check whether the name on the next line
		// or something is between ROUTINE and name
		if index {
			if $find(line, "[Type=INC]") {
				set type = 2
			}
			elseif $find(line, "[Type=INT,Generated]") {
				set type = 3
			}
			else {
				set type = 1
			}
			set line = $extract(line, index, *)
			set name = ..ReadName(line)
			if name = "" {
				return '$$$OK
			} else {
				return $$$OK
			}
		}
	}
	return '$$$OK
}

/// Finds a name of a dfi
/// <b>stream</b> - stream which contains a dfi definition<br>
/// <b>name</b> - name which contains the name of dfi<br>
ClassMethod GetDFIName(stream As %GlobalCharacterStream, ByRef name As %String) As %Status
{
	#dim textreader As %XML.TextReader
	set dfiContent = ""

	// I don't know why but if i just parse stream it doesn't work
	while 'stream.AtEnd {
		set dfiContent = dfiContent _ stream.Read()
	}

	set st = ##class(%XML.TextReader).ParseString(dfiContent, .textreader)
	return:$$$ISERR(st) st

	while textreader.Read() {
		set node = textreader.Name
		if (node = "pivot") || (node = "dashboard") {
			do textreader.MoveToAttributeName("folderName")
	//		set dfiFolderName = $translate(textreader.Value, " ", "-")
			set dfiFolderName=textreader.Value
			
			do textreader.MoveToAttributeName("name")
	//		set dfiName = $translate(textreader.Value, " ", "-")
			set dfiName=textreader.Value
			set name = dfiFolderName _ "-" _ dfiName _ "." _ node _ ".dfi"
			return $$$OK
		}
	}
	return '$$$OK
}

/// Get extension of the file by url
/// <b>url</b> - the url where the file is located in the web.<br>
ClassMethod GetExt(url As %String) As %String
{
	//return $zconvert($piece(url, ".", *), "l")
	//AMIR: There are parameters after the extension that are not part of the extension
	return $zconvert($piece($piece(url, ".", *),"?"), "l")
}

/// Check whether a file is a web file
/// <b>ext</b> - extensions of the file<br>
ClassMethod IsWebFile(ext As %String) As %String
{
	set webExts = "csp,html,css,js,ts,scss"
	return $find(webExts, ext)
}

/// Imports the file in UDL file in the project
/// <b>contentStream</b> - the stream which contains the source code in udl format.<br>
/// <b>url</b> - the url where the file is located in the web.<br>
/// <b>list</b> - array of files to compile<br>
ClassMethod LoadUDLFile(contentStream As %GlobalCharacterStream, binaryStream As %Stream.FileCharacterGzip, url As %String, list As %String) As %Status
{
	set st = $$$OK

	set ext = ..GetExt(url)

	if ext = "cls" {
		set st = ..CreateClass(contentStream, url, .list)
	}
	elseif ext = "dfi" {
		set st = ..CreateDFI(contentStream, url, .list)
	}
	elseif (ext = "inc") || (ext = "mac") {
		set st = ..CreateRoutine(contentStream, url, .list)
	}
	else
	{
		set st = ..CreateWebFile(contentStream, binaryStream, url, ext, .list)
	}
	return st
}

/// Checks whether the class exists
/// <b>className</b> - name of the class.<br>
ClassMethod DoesClassExist(className As %String) As %Boolean
{
	Set query = "SELECT TOP 1 COUNT(ID) FROM %Dictionary.ClassDefinition WHERE ID = ?"
	Set statement = ##class(%SQL.Statement).%New()
	Set st = statement.%Prepare(query)
	Set rset = statement.%Execute(className)
	If (rset.%Next()) && (rset.%ROWCOUNT > 0) {
		Return $$$YES
	}
	Return $$$NO
}

/// Creates and imports the class into the project from stream
/// <b>contentStream</b> - the stream which contains the source code in udl format.<br>
/// <b>url</b> - the url where the file is located in the web.<br>
/// <b>list</b> - array of files to compile<br>
ClassMethod CreateClass(contentStream As %CharacterStream, url As %String, ByRef list As %String) As %Status
{
	Set st = ..GetClassName(contentStream, .className)
	Return:$$$ISERR(st) st

	set list(className _ ".cls") = ""

	Do contentStream.Rewind()

	if '(##class(%Dictionary.ClassDefinition).%ExistsId(className))  {
		Set clsDef = ##class(%Dictionary.ClassDefinition).%New()
		Set clsDef.Name = className
		Set st = clsDef.%Save()
		Return:$$$ISERR(st) st
	}


	Set namespace = $namespace
	Set st = ##class(%Compiler.UDL.TextServices).SetTextFromStream(namespace, className, contentStream)

	if st {
		w !, "Imported " _ className, !
	}

	Return st
}

/// Creates and imports the dfi file into the project from stream
/// <b>contentStream</b> - the stream which contains the source code in udl format.<br>
/// <b>list</b> - array of files to compile<br>
ClassMethod CreateDFI(contentStream As %CharacterStream, url As %String, ByRef list As %String) As %Status
{
	Set st = $$$OK
    Try {
	    Set st = ..GetDFIName(contentStream, .name)
	    Return:$$$ISERR(st) st

	    set list(name) = ""

        Set tDoc = ##class(%DeepSee.UI.FolderItemDocument).%New(name)
        Set st = tDoc.ImportFromXML(contentStream)
        Return:$$$ISERR(st) st

        Set st = tDoc.Save()
        if st {
		w !, "Imported " _ name, !
	}
        Return:$$$ISERR(st) st
    } Catch e {
        Set st = e.AsStatus()
    }
    Return st
}

/// Creates and imports mac, int, inc files into the project from stream
/// <b>contentStream</b> - the stream which contains the source code in udl format.<br>
/// <b>url</b> - the url where the file is located in the web.<br>
/// <b>list</b> - array of files to compile<br>
ClassMethod CreateRoutine(contentStream As %GlobalCharacterStream, url As %String, ByRef list As %String) As %Status
{
	Set st = ..GetRoutineName(contentStream, .name, .type)
	do contentStream.Rewind()

	return:$$$ISERR(st) st

	if type = 1 {
		set name = name _ ".mac"
	}
	elseif type = 2 {
		set name = name _ ".inc"
	}
	elseif type = 3 {
		set name = name _ ".int"
	}

	set list(name) = ""

	Set rtn = ##class(%Routine).%New(name)
	While 'contentStream.AtEnd {
		Set line = contentStream.ReadLine()
		If $Find(line, "ROUTINE") {
			Continue
		}
		Do rtn.WriteLine(line)
	}

	Set st = rtn.Save()
 	Return:$$$ISERR(st) st

 	if st {
		w !, "Imported " _ name, !
	}
 	Return st
}

/// Creates and imports mac, int, inc files into the project from stream
/// <b>contentStream</b> - the stream which contains the source code in udl format.<br>
/// <b>url</b> - the url where the file is located in the web.<br>
/// <b>ext</b> - extension of the file<br>
/// <b>list</b> - array of files to compile<br>
ClassMethod CreateWebFile(contentStream As %GlobalCharacterStream, binaryStream As %Stream.FileCharacterGzip, url As %String, ext As %String, ByRef list As %String) As %Status
{
	Set st = $$$OK
	Try
	{
		Set tCSPRootPath = $system.CSP.GetFileName($system.CSP.GetDefaultApp($namespace)_"/")
		
		Set tFileName = $Piece($Piece(url,"?",1),"/",*)
		Set tCSPSubPath = $Piece(url,"/",7,*-1)_"/"

		set tFileDirectory = tCSPRootPath_tCSPSubPath
		Set tFullFileName = tFileDirectory_tFileName

		//On Windows, tFullFileName will contain \ and / but CreateDirectoryChain() and
		//LinkToFile() already normalize the paths accordingly to the OS for us so
		//we don't have to worry about it.
		If '##class(%File).CreateDirectoryChain(tFileDirectory)
		{
			Set st = $System.Status.Error(5001,"Could nor create path chain '"_tFileDirectory_"'")
			Quit
		}

		Set filestream = ##class(%Stream.FileCharacter).%New()
		set st = filestream.LinkToFile(tFullFileName)
		Quit:$System.Status.IsError(st)

		If $IsObject(contentStream) && ..IsWebFile(ext)
		{
			Set st=filestream.CopyFrom(contentStream)
		}
		Else
		{
			Set st=filestream.CopyFrom(binaryStream)
		}
		Quit:$System.Status.IsError(st)

		set st = filestream.%Save()
		Quit:$System.Status.IsError(st)

		Write !, "Imported " _ tFullFileName, !
	}
	Catch (oException)
	{
		Set st = oException.AsStatus()
	}

	Quit st
}

}

