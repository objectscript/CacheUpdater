Class CacheUpdater.TextServices Extends %Compiler.UDL.TextServices
{

/// This method takes a namespace an integer subscripted array containing lines of text which represent a
/// class definition in the UDL class definition language. Subscript value 0 should contain a count
/// of lines of text which are defined as subscript value 1 ... n in the array
/// 
/// Unlike %Compiler.UDL.TextServices saves classes with grammar errors. Taken from Atelier API
/// 
/// It is important to realize that this method will replace the existing class definition if present and therefore
/// must contain a full representation of the class as can be obtained by calling the GetClassXXX() method(s) in
/// this class.  Note: The name of the class is derived from the name of the class defined within the text
ClassMethod SetTextFromArray(pNamespace As %String = {$namespace}, pClassname As %String, ByRef pDocumentArray As %String) As %Status
{
	#dim tSC,tStatus As %Status = $$$OK
	#dim e As %Exception.AbstractException
	
	#dim tErrList,tOneErr As %String
	#dim tResultCode,tI As %Integer

	Try {
		#; TODO: make sure pClassname and classname within the text match, else throw an error
		#; Remember pClassname has .cls extension!
		
		#; Swap namespace if necessary
		If pNamespace'=$namespace new $namespace Set $namespace=pNamespace
		
        #; Save the definition (just saves, doesn't compile)
        Set tFlags=16777216 ; 0x01000000 = IPARSE_UDL_SAVEWITHERRORS save even if parse errors
        
		Set tResultCode=$compile(pDocumentArray,128,tErrList,,,tFlags)
		If tResultCode {
	        For tI=1:1:$ll(tErrList) {
	            Set tOneErr = $list(tErrList,tI),tStatus=$$$ERROR($$$ClassSaveError,$li(tOneErr,4),$li(tOneErr,1),$li(tOneErr,2),$li(tOneErr,6))
	         	If tSC=$$$OK {   
	            	Set tSC=tStatus
	         	} else {
		         	Set tSC=$$$ADDSC(tSC,tStatus)
	         	}
	        }
	    }
	} Catch (e) {
		Set tSC=e.AsStatus()
	}
	Quit tSC
}

}
