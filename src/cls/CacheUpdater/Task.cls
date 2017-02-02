Class CacheUpdater.Task Extends (%SYS.Task.Definition, CacheUpdater.UDL)
{

Parameter TaskName = "GitHub Update";

/// Repository URL, like https://github.com/intersystems-ru/Cache-MDX2JSON
/// Increased to 500 to support long urls
Property GitHubURL As %String(MAXLEN = 500);

/// GitHub user, who has access to repository. Optional for public repositories.<br>
/// Note, that with Username/Password, you can make up to 5,000 requests per hour.
/// For unauthenticated requests, the rate limit allows to make up to 60 requests per hour.
/// Unauthenticated requests are associated with an IP address.<br>
/// Required, if you want to create webhooks
Property Username As %String;

/// GitHub password, corresponding to Username. Optional for public repositories.
Property Password As %String;

/// Namespace, where to download and compile repository
Property Namespace As %String [ InitialExpression = {$Namespace} ];

/// Repository branch, usually master. Leave empty, if you want to receive default branch.
Property Branch As %String [ InitialExpression = "master" ];

Method OnTask() As %Status
{
	Return:'##class(%SYS.Namespace).Exists(..Namespace) $$$ERROR($$$NamespaceUnavailable,..Namespace)

	Set Owner = $p(..GitHubURL,"/",4)
	Set Repository = $p(..GitHubURL,"/",5)

	Return ..Update(Owner, Repository, ..Branch, ..Username, ..Password, ..Namespace)
}

/// Downloads and compiles GitHub repository.<br>
/// <b>Owner</b> - The name of the repository owner.<br>
/// <b>Repository</b> - The name of the repository.<br>
/// <b>Branch</b> - The name of the commit/branch/tag. If skipped the repository’s default branch (usually master) would be used.<br>
/// <b>Username</b> - GitHub user, who has access to repository. Optional for public repositories.<br>
/// <b>Password</b> - GitHub password, corresponding to Username. Optional for public repositories.<br>
/// Note, that with Username, you can make up to 5,000 requests per hour.
/// For unauthenticated requests, the rate limit allows to make up to 60 requests per hour.
/// Unauthenticated requests are associated with an IP address.<br>
/// <b>Namespace</b> - Namespace, where to download and compile repository.<br>
/// 
/// For example in the repository: https://github.com/intersystems-ru/Cache-MDX2JSON<br>
/// Owner - intersystems-ru, Repository - Cache-MDX2JSON.<br> 
ClassMethod Update(Owner As %String, Repository As %String, Branch As %String = "", Username As %String = "", Password As %String = "", Namespace = {$Namespace}) As %Status
{
	#dim req As %Net.HttpRequest
	Set req = ..CreateRequest(Username, Password)
	Set req.Location = "repos/" _ Owner _ "/" _ Repository _ "/contents" 	// as described in https://developer.github.com/v3/repos/

 	Set links = ##class(%ListOfDataTypes).%New()
 	Set st = ..ProcessDirectory("",.req,Branch,.links)
 	Return:$$$ISERR(st) st

 	Set namespace = $Namespace
 	Zn Namespace
	Set st = ..DownloadFiles(links,req,.list)
	zw list
	Set st2 = $system.OBJ.CompileList(.list,"cuk /checkuptodate=expandedonly")
	Zn namespace

 	Return $$$ADDSC(st, st2)
}

/// Process one directory of GitHub repository. Recursive.<br>
/// <b>Path</b> -Internal repository path. Root is empty string<br>
/// <b>Request</b> - Authenticated/Set %Net.HttpRequest object.<br>
/// <b>Links</b> - List of links to raw files (which satisfy <b>IsCacheFile</b> conditions) from repository.<br>
ClassMethod ProcessDirectory(Path As %String = "", Request As %Net.HttpRequest, Branch As %String = "", ByRef Links As %ListOfDataTypes) As %Status
{
	Set location = Request.Location
	Set Request.Location = Request.Location _ Path
	Do:(Branch'="") Request.SetParam("ref",Branch)

	Set st = Request.Get()

	Return:$$$ISERR(st) st
	Return:(Request.HttpResponse.StatusCode = 404) $$$ERROR($$$GeneralError,"Repository doesn't exist OR you don't have access")
	Return:((Request.HttpResponse.StatusCode = 403) && (Request.HttpResponse.GetHeader("X-RATELIMIT-REMAINING")=0)) $$$ERROR($$$GeneralError,"API rate limit exceeded. Try logging in.")
 	Return:(Request.HttpResponse.StatusCode = 401) $$$ERROR($$$GeneralError,"We couldn't find that combination of username and password")
	Return:(Request.HttpResponse.StatusCode '= 200) $$$ERROR($$$GeneralError,"Received " _ Request.HttpResponse.StatusCode _ " expected 200")
	
 	#dim objects As List of %ZEN.proxyObject
 	#dim obj As %ZEN.proxyObject
	Set st = ##class(%ZEN.Auxiliary.jsonProvider).%ConvertJSONToObject(Request.HttpResponse.Data,,.objects,1)
	Return:$$$ISERR(st) st

	For i = 1:1:objects.Count() {
		Set obj = objects.GetAt(i)
		If (obj.type = "dir") {
			Set st = ..ProcessDirectory("/"_obj.name,Request,Branch,.Links)
			Return:$$$ISERR(st) st
		} ElseIf (obj.type = "file") {
			//Do:..IsCacheFile(obj) Links.Insert(obj."download_url")
			Do Links.Insert($LB(obj."download_url",..IsCacheFile(obj)))
		} Else {
			// obj.type = "symlink" or obj.type = "submodule"
		}
	}
	Set Request.Location = location // to keep track of where in the repository tree we are
	Return $$$OK
}

/// Check that incoming file is the one you need.
ClassMethod IsCacheFile(File As %ZEN.proxyObject) As %Boolean
{
	Set extensions = ",xml,cls,csp,csr,mac,int,bas,inc,gbl,prj,obj,pkg,gof,dfi,pivot,dashboard,html,css,js,ts,scss,"
	Return:($L(File.name,".")=1) 0 //no extension
	Set File.Extension = $P(File.name,".",$L(File.name,"."))
	Return $F(extensions,","_$ZCVT(File.Extension,"l")_",")
}

/// Download list of files on https://raw.githubusercontent.com/ server.<br>
/// <b>Links</b> - List of links to raw files.<br>
/// <b>Request</b> - Authenticated/Set %Net.HttpRequest object.<br>
/// <b>loadedlist</b> - Returns an array of the items loaded. 
ClassMethod DownloadFiles(Links As %ListOfDataTypes, Request As %Net.HttpRequest, Output Items) As %Status
{
	Kill Items
	Set Request.Server = "raw.githubusercontent.com"
	Set st = $$$OK
	Try
	{
		For i = 1:1:Links.Count()
		{
			Set link = $ListGet(Links.GetAt(i),1)
			Set bIsCacheFile = $ListGet(Links.GetAt(i),2)
			Set ^gitfiles(i,"link")=link
			Set ^gitfiles(i,"bIsCacheFile")=bIsCacheFile

			Set streq = Request.Get($e(link,35,*)) // Remove "https://raw.githubusercontent.com/" from URL.
			If $$$ISERR(streq)
			{
				Set st=$$$ADDSC(st, streq)
				Set ^gitfiles(i,"streq")=streq
				Continue
			}

			Set ^gitfiles(i,"stream")="starting..."
			Set binarystream = Request.HttpResponse.Data

			Do binarystream.Rewind() // just in case

			Set characterStream=##class(%GlobalCharacterStream).%New() //translating binary stream into character stream
			Set stTranslate=$$$OK
			Try
			{
				While 'binarystream.AtEnd
				{
					//Use eol to prevent breaking lines larger than 32Kb
					Set line=binarystream.ReadLine(, .stTranslate, .eol)
					Quit:$System.Status.IsError(stTranslate)

					If eol
					{
						Set stTranslate=characterStream.WriteLine(line)
					}
					Else
					{
						Set stTranslate=characterStream.Write(line)
					}
					Quit:$System.Status.IsError(stTranslate)
				}
				Quit:$System.Status.IsError(stTranslate)

				Do characterStream.Rewind()
			}
			Catch (oTranslateStreamException)
			{
				Set stTranslate=oTranslateStreamException.AsStatus()
			}

			If $System.Status.IsError(stTranslate)
			{
				//Could not convert binary stream to character stream
				//It is probably a binary file anyway
				Set characterStream=""
				Set st=$$$ADDSC(st, stTranslate)
				Set ^gitfiles(i,"stTranslate")=stTranslate
			}
			Set ^gitfiles(i,"stream")="Done"

			Do binarystream.Rewind()

			Set stload = $$$OK

			set items = ""
			If ('$IsObject(characterStream)) || (..IsUDLFile(characterStream))
			{
				Set ^gitfiles(i,"IsUDLFile")="1"
				Set stload = ..LoadUDLFile(characterStream, binarystream, link, .items)
			}
			ElseIf bIsCacheFile
			{
				Set ^gitfiles(i,"IsUDLFile")="0"
				Set stload = $system.OBJ.LoadStream(characterStream,"",.error,.items,,,,"UTF8")
			}
			Set ^gitfiles(i,"stload")=stload
	 		If $$$ISERR(stload)
	 		{
		 		Set st=$$$ADDSC(st, stload)
		 		Continue
	 		}
	 		Merge Items = items  // Does not overwrite existing array keys: Items(itemname)=""
		}

		Set Request.Server="api.github.com"
	}
	Catch (oException)
	{
		Set st = oException.AsStatus()
		If $D(i) Set ^gitfiles(i,"st final")=st
	}

	Quit st
}

ClassMethod CreateRequest(Username As %String, Password As %String) As %Net.HttpRequest
{
	Set namespace = $Namespace
 	Set SSLConfig = "GitHub"

 	Zn "%SYS"
 	Do:'##class(Security.SSLConfigs).Exists(SSLConfig) ##class(Security.SSLConfigs).Create(SSLConfig)
 	Zn namespace

 	Set req=##class(%Net.HttpRequest).%New()
 	Set req.Https=1
	Set req.SSLConfiguration=SSLConfig
	Set req.Server="api.github.com"
	Do req.SetHeader("Accept","application/vnd.github.v3+json") 			// we want 3rd version of api

	If ($d(Username) && $d(Password) && (Username'="") && (Password'="")) {	// supply Username and Password, if both are provided. GitHub accept Basic Auth
		Set req.Username = Username											// https://developer.github.com/v3/auth/
	 	Set req.Password = Password
	}

	Return req
}

}

